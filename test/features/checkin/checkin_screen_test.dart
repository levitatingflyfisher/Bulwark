import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/pulse_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/checkin/presentation/checkin_screen.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../support/adoption_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> activate(String id) => HabitStateRepository(db).upsert(HabitState(
        interventionId: id,
        status: HabitStatus.active,
        activatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ));

  Future<void> pumpCheckin(WidgetTester tester, {double textScale = 1.0}) async {
    final router = GoRouter(
      initialLocation: '/checkin',
      routes: [
        GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(body: Text('HOME'))),
        GoRoute(path: '/checkin', builder: (_, __) => const CheckinScreen()),
      ],
    );
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: MaterialApp.router(
        theme: AppTheme.light,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('records "did it" and returns Home', (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Did it'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final rows = await CheckinRepository(db).getAll();
    expect(rows, hasLength(1));
    expect(rows.single.interventionId, 'sleep-window');
    expect(rows.single.result, CheckinResult.did);
    expect(rows.single.date, DateTime.now().dateOnly);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('records "forgot"', (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Forgot'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final rows = await CheckinRepository(db).getAll();
    expect(rows.single.result, CheckinResult.forgot);
  });

  testWidgets('re-checking upserts today rather than duplicating',
      (tester) async {
    await activate('sleep-window');
    // A "did" already logged today — the screen should seed to it.
    await CheckinRepository(db).upsert(Checkin(
      interventionId: 'sleep-window',
      date: DateTime.now().dateOnly,
      result: CheckinResult.did,
    ));
    await pumpCheckin(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Skipped'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final rows = await CheckinRepository(db).getAll();
    expect(rows, hasLength(1)); // upserted, not duplicated
    expect(rows.single.result, CheckinResult.skipped);
  });

  testWidgets('submitting refreshes the keepAlive Progress read models',
      (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester);

    // Materialize allCheckins BEFORE the write — a keepAlive provider serves its
    // cache until invalidated, so a naive after-only read would false-pass. This
    // catches a regression where the Progress wall/adherence go stale mid-session.
    final container =
        ProviderScope.containerOf(tester.element(find.byType(CheckinScreen)));
    expect(await container.read(allCheckinsProvider.future), isEmpty);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Did it'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    expect(await container.read(allCheckinsProvider.future), hasLength(1));
  });

  testWidgets('logs a weekly pulse for a graduated habit due one',
      (tester) async {
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'box-breathing',
      status: HabitStatus.graduated,
      activatedAt: DateTime(2025, 1, 1),
      graduatedAt: DateTime(2025, 2, 1),
      createdAt: DateTime(2025, 1, 1),
    ));
    await pumpCheckin(tester);

    expect(find.text('Weekly pulse'), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Solid'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();

    final pulses = await PulseRepository(db).getAll();
    expect(pulses, hasLength(1));
    expect(pulses.single.interventionId, 'box-breathing');
    expect(pulses.single.weekStart, DateTime.now().startOfWeek);
    expect(pulses.single.result, PulseResult.solid);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('Check-in holds at 320dp width and ${scale}x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await activate('sleep-window');
      await activate('eat-protein');
      await pumpCheckin(tester, textScale: scale);

      expect(find.byType(ChoiceChip), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
