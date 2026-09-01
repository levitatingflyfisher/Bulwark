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

  Future<GoRouter> pumpCheckin(WidgetTester tester,
      {double textScale = 1.0, CheckinRepository? repo}) async {
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
      overrides: [
        ...adoptionOverrides(db: db),
        if (repo != null) checkinRepositoryProvider.overrideWithValue(repo),
      ],
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
    return router;
  }

  testWidgets('records "did it" and returns Home', (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Did it'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    final rows = await CheckinRepository(db).getAll();
    expect(rows, hasLength(1));
    expect(rows.single.interventionId, 'sleep-window');
    expect(rows.single.result, CheckinResult.did);
    expect(rows.single.date, DateTime.now().dateOnly);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('each tap is saved as it happens: leave without Done, come '
      'back, and the answers are there (persona T2)', (tester) async {
    await activate('sleep-window');
    await activate('eat-protein');
    final router = await pumpCheckin(tester);

    Finder chip(String habit, String label) => find.descendant(
        of: find.ancestor(of: find.text(habit), matching: find.byType(Card)),
        matching: find.widgetWithText(ChoiceChip, label));
    await tester.tap(chip('sleep-window', 'Did it'));
    await tester.pumpAndSettle();
    await tester.tap(chip('eat-protein', 'Forgot'));
    await tester.pumpAndSettle();

    // Leave the way back does: no Done, no Save.
    router.go('/');
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    final rows = {
      for (final c in await CheckinRepository(db).getAll())
        c.interventionId: c.result
    };
    expect(rows, {
      'sleep-window': CheckinResult.did,
      'eat-protein': CheckinResult.forgot,
    });

    router.go('/checkin');
    await tester.pumpAndSettle();
    bool selected(String habit, String label) =>
        tester.widget<ChoiceChip>(chip(habit, label)).selected;
    expect(selected('sleep-window', 'Did it'), isTrue);
    expect(selected('eat-protein', 'Forgot'), isTrue);
  });

  testWidgets('a note is saved with its answer as you type', (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester);

    // No answer yet, so nowhere for a note to live: no Add note.
    expect(find.text('Add note'), findsNothing);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Skipped'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add note'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'late shift');
    await tester.pumpAndSettle();

    final row = (await CheckinRepository(db).getAll()).single;
    expect(row.result, CheckinResult.skipped);
    expect(row.note, 'late shift');
  });

  testWidgets('a tap that fails to save is undone on screen and says so',
      (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester, repo: _FailingCheckinRepository(db));

    await tester.tap(find.widgetWithText(ChoiceChip, 'Did it'));
    await tester.pumpAndSettle();

    expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Did it'))
            .selected,
        isFalse);
    expect(find.textContaining('didn’t save'), findsOneWidget);
  });

  testWidgets('records "forgot"', (tester) async {
    await activate('sleep-window');
    await pumpCheckin(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'Forgot'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
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
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
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

class _FailingCheckinRepository extends CheckinRepository {
  _FailingCheckinRepository(super.db);

  @override
  Future<void> upsert(Checkin c) async => throw StateError('disk full');
}
