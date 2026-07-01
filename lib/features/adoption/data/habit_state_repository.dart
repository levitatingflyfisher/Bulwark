import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:drift/drift.dart';

/// Persistence for [HabitState], keyed by `interventionId` (a unique column,
/// not the primary key), so upserts target that index.
class HabitStateRepository {
  HabitStateRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(HabitState s) => _db.into(_db.habitStates).insert(
        _toCompanion(s),
        onConflict: DoUpdate(
          (_) => _toCompanion(s),
          target: [_db.habitStates.interventionId],
        ),
      );

  Future<HabitState?> byInterventionId(String interventionId) async {
    final row = await (_db.select(_db.habitStates)
          ..where((t) => t.interventionId.equals(interventionId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<List<HabitState>> getAll() async =>
      (await _db.select(_db.habitStates).get()).map(_fromRow).toList();

  Future<List<HabitState>> byStatus(HabitStatus status) async {
    final rows = await (_db.select(_db.habitStates)
          ..where((t) => t.status.equals(status.index)))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<HabitState>> activeStates() => byStatus(HabitStatus.active);

  Stream<List<HabitState>> watchAll() =>
      _db.select(_db.habitStates).watch().map((r) => r.map(_fromRow).toList());

  Future<void> delete(String interventionId) =>
      (_db.delete(_db.habitStates)
            ..where((t) => t.interventionId.equals(interventionId)))
          .go();

  HabitStatesCompanion _toCompanion(HabitState s) => HabitStatesCompanion.insert(
        interventionId: s.interventionId,
        status: s.status.index,
        queuePosition: Value(s.queuePosition),
        activatedAt: Value(s.activatedAt),
        graduatedAt: Value(s.graduatedAt),
        triggerAnchorOverride: Value(s.triggerAnchorOverride),
        reminderEnabled: Value(s.reminderEnabled),
        createdAt: s.createdAt,
      );

  HabitState _fromRow(HabitStateRow r) => HabitState(
        interventionId: r.interventionId,
        status: HabitStatus.values[r.status],
        queuePosition: r.queuePosition,
        activatedAt: r.activatedAt,
        graduatedAt: r.graduatedAt,
        triggerAnchorOverride: r.triggerAnchorOverride,
        reminderEnabled: r.reminderEnabled,
        createdAt: r.createdAt,
      );
}
