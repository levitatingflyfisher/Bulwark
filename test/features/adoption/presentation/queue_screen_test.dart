import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/queue_screen.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/adoption_harness.dart';
import '../../../support/content_builders.dart';

void main() {
  late AppDatabase db;
  final library = libraryOf([intervention(id: 'sleep-window')]);

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> queue(String id) => HabitStateRepository(db).upsert(HabitState(
        interventionId: id,
        status: HabitStatus.queued,
        queuePosition: 0,
        createdAt: DateTime(2026, 1, 1),
      ));

  Future<void> activate(String id, DateTime at) =>
      HabitStateRepository(db).upsert(HabitState(
        interventionId: id,
        status: HabitStatus.active,
        activatedAt: at,
        createdAt: at,
      ));

  Future<void> pump(WidgetTester tester, {double textScale = 1.0}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db, library: library),
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const QueueScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapReady(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, "I'm ready for another"));
    await tester.pumpAndSettle();
  }

  testWidgets('a clean slate yields an advisable verdict', (tester) async {
    await queue('sleep-window');
    await pump(tester);
    await tapReady(tester);

    expect(find.text('Looks like a good time.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Activate sleep-window'),
        findsOneWidget);
  });

  testWidgets('tooSoon shows kind copy with an override', (tester) async {
    await queue('sleep-window');
    await activate('recent', DateTime.now()); // just activated
    await pump(tester);
    await tapReady(tester);

    expect(find.textContaining('added one recently'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add sleep-window anyway'),
        findsOneWidget);
  });

  testWidgets('capReached shows kind copy with an override', (tester) async {
    await queue('sleep-window');
    final long = DateTime.now().subtract(const Duration(days: 40));
    for (var i = 0; i < 10; i++) {
      await activate('a$i', long);
    }
    await pump(tester);
    await tapReady(tester);

    expect(find.textContaining('full plate'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add sleep-window anyway'),
        findsOneWidget);
  });

  testWidgets('unsteady shows kind copy with an override', (tester) async {
    await queue('sleep-window');
    await activate('shaky', DateTime.now().subtract(const Duration(days: 40)));
    final today = DateTime.now().dateOnly;
    await CheckinRepository(db).upsert(Checkin(
        interventionId: 'shaky',
        date: today.subtract(const Duration(days: 1)),
        result: CheckinResult.forgot));
    await CheckinRepository(db).upsert(Checkin(
        interventionId: 'shaky',
        date: today.subtract(const Duration(days: 2)),
        result: CheckinResult.skipped));
    await CheckinRepository(db).upsert(Checkin(
        interventionId: 'shaky',
        date: today.subtract(const Duration(days: 3)),
        result: CheckinResult.did));
    await pump(tester);
    await tapReady(tester);

    expect(find.textContaining('finding their footing'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Add sleep-window anyway'),
        findsOneWidget);
  });

  testWidgets('the override activates the queued item', (tester) async {
    await queue('sleep-window');
    await activate('recent', DateTime.now()); // forces tooSoon
    await pump(tester);
    await tapReady(tester);

    await tester
        .tap(find.widgetWithText(FilledButton, 'Add sleep-window anyway'));
    await tester.pumpAndSettle();

    final state =
        await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(state!.status, HabitStatus.active);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('the verdict card holds at 320dp and ${scale}x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await queue('sleep-window');
      await activate('recent', DateTime.now());
      await pump(tester, textScale: scale);
      await tapReady(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
