import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/adoption_harness.dart';

/// A one-button harness that runs a write-side action against the shared
/// container so the keepAlive read models see the mutation exactly as the app
/// does.
class _Runner extends ConsumerWidget {
  const _Runner(this.onTap);
  final Future<void> Function(WidgetRef) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(ref),
              child: const Text('run'),
            ),
          ),
        ),
      );
}

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  testWidgets('activate preserves triggerAnchorOverride and reminderEnabled',
      (tester) async {
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.queued,
      queuePosition: 0,
      triggerAnchorOverride: 'wake',
      reminderEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: _Runner((ref) => activateHabit(ref, 'sleep-window')),
    ));
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    final row = await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(row, isNotNull);
    expect(row!.status, HabitStatus.active);
    expect(row.activatedAt, isNotNull);
    expect(row.queuePosition, isNull); // left the queue
    // The transition must not silently zero the per-habit fields.
    expect(row.triggerAnchorOverride, 'wake');
    expect(row.reminderEnabled, isTrue);
    expect(row.createdAt, DateTime(2026, 1, 1));
  });

  testWidgets('queue preserves the per-habit fields it does not change',
      (tester) async {
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      activatedAt: DateTime(2026, 1, 2),
      triggerAnchorOverride: 'evening',
      reminderEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    ));

    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: _Runner((ref) => queueHabit(ref, 'sleep-window')),
    ));
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    final row = await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(row!.status, HabitStatus.queued);
    expect(row.queuePosition, 0);
    expect(row.triggerAnchorOverride, 'evening');
    expect(row.reminderEnabled, isTrue);
    expect(row.createdAt, DateTime(2026, 1, 1));
  });

  testWidgets(
      'graduate persists graduated+graduatedAt, preserves fields, and fully '
      'refreshes the read models', (tester) async {
    final container = ProviderContainer(overrides: adoptionOverrides(db: db));
    addTearDown(container.dispose);

    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      activatedAt: DateTime(2026, 1, 2),
      triggerAnchorOverride: 'wake',
      reminderEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    ));

    // Materialize the keepAlive read models BEFORE the write. A broken
    // invalidation would leave these stale caches in place; an after-only read
    // would recompute from the DB and false-pass.
    final beforeActive = await container.read(activeHabitsProvider.future);
    final beforeGraduated = await container.read(graduatedHabitsProvider.future);
    await container.read(pulseDueProvider.future);
    expect(beforeActive.map((h) => h.interventionId), contains('sleep-window'));
    expect(beforeGraduated, isEmpty);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: _Runner((ref) => graduateHabit(ref, 'sleep-window')),
    ));
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    // Persisted as graduated, with every earlier field intact.
    final row = await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(row!.status, HabitStatus.graduated);
    expect(row.graduatedAt, isNotNull);
    expect(row.activatedAt, DateTime(2026, 1, 2));
    expect(row.triggerAnchorOverride, 'wake');
    expect(row.reminderEnabled, isTrue);
    expect(row.createdAt, DateTime(2026, 1, 1));

    // Read models refreshed against the SAME container: off the active list,
    // onto the wall (graduatedHabits), and now owed a maintenance pulse.
    final afterActive = await container.read(activeHabitsProvider.future);
    final afterGraduated = await container.read(graduatedHabitsProvider.future);
    final afterPulseDue = await container.read(pulseDueProvider.future);
    expect(afterActive.map((h) => h.interventionId),
        isNot(contains('sleep-window')));
    expect(
        afterGraduated.map((h) => h.interventionId), contains('sleep-window'));
    expect(afterPulseDue.map((h) => h.interventionId), contains('sleep-window'));
  });

  test('graduationEligible includes an automatic habit, excludes a fresh one',
      () async {
    final container = ProviderContainer(overrides: adoptionOverrides(db: db));
    addTearDown(container.dispose);

    final now = DateTime.now();
    // sleep-window: 30 days active, 8/10 "did" in the last 14 days → eligible.
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      activatedAt: now.subtract(const Duration(days: 30)),
      createdAt: now.subtract(const Duration(days: 30)),
    ));
    // eat-protein: active only 3 days → not yet automatic.
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'eat-protein',
      status: HabitStatus.active,
      activatedAt: now.subtract(const Duration(days: 3)),
      createdAt: now.subtract(const Duration(days: 3)),
    ));
    final ci = CheckinRepository(db);
    for (var i = 0; i < 8; i++) {
      await ci.upsert(Checkin(
          interventionId: 'sleep-window',
          date: now.subtract(Duration(days: i)),
          result: CheckinResult.did));
    }
    for (var i = 8; i < 10; i++) {
      await ci.upsert(Checkin(
          interventionId: 'sleep-window',
          date: now.subtract(Duration(days: i)),
          result: CheckinResult.forgot));
    }

    final eligible = await container.read(graduationEligibleProvider.future);
    final ids = eligible.map((h) => h.interventionId);
    expect(ids, contains('sleep-window'));
    expect(ids, isNot(contains('eat-protein')));
  });
}
