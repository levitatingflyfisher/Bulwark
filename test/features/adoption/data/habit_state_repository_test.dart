import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late HabitStateRepository repo;

  final created = DateTime(2026, 1, 1, 9);

  HabitState state(String id, HabitStatus status, {DateTime? activatedAt}) =>
      HabitState(
        interventionId: id,
        status: status,
        activatedAt: activatedAt,
        createdAt: created,
      );

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = HabitStateRepository(db);
  });
  tearDown(() => db.close());

  test('upsert then read round-trips every field', () async {
    final s = HabitState(
      interventionId: 'morning-light',
      status: HabitStatus.active,
      queuePosition: 3,
      activatedAt: DateTime(2026, 1, 2, 7, 30),
      graduatedAt: null,
      triggerAnchorOverride: 'wake',
      reminderEnabled: true,
      createdAt: created,
    );
    await repo.upsert(s);
    expect(await repo.byInterventionId('morning-light'), s);
  });

  test('upsert on the same interventionId updates rather than duplicating',
      () async {
    await repo.upsert(state('a', HabitStatus.queued));
    await repo.upsert(state('a', HabitStatus.active,
        activatedAt: DateTime(2026, 1, 3)));
    final all = await repo.getAll();
    expect(all, hasLength(1));
    expect(all.single.status, HabitStatus.active);
  });

  test('activeStates returns only active habits', () async {
    await repo.upsert(state('a', HabitStatus.active));
    await repo.upsert(state('b', HabitStatus.queued));
    await repo.upsert(state('c', HabitStatus.active));
    await repo.upsert(state('d', HabitStatus.graduated));
    final active = await repo.activeStates();
    expect(active.map((s) => s.interventionId).toSet(), {'a', 'c'});
  });

  test('byInterventionId returns null when absent', () async {
    expect(await repo.byInterventionId('nope'), isNull);
  });

  test('delete removes the row', () async {
    await repo.upsert(state('a', HabitStatus.active));
    await repo.delete('a');
    expect(await repo.byInterventionId('a'), isNull);
  });

  test('watchAll emits after a write', () async {
    final done = expectLater(
      repo.watchAll().map((rows) => rows.length),
      emitsThrough(1),
    );
    await repo.upsert(state('a', HabitStatus.active));
    await done;
  });
}
