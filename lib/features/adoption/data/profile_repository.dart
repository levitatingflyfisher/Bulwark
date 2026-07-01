import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:drift/drift.dart';

/// Persistence for the single-row [Profile]. The row is pinned to id = 1, so
/// [save] overwrites in place.
class ProfileRepository {
  ProfileRepository(this._db);
  final AppDatabase _db;

  static const _rowId = 1;

  Future<void> save(Profile p) =>
      _db.into(_db.profiles).insertOnConflictUpdate(_toCompanion(p));

  Future<Profile?> get() async {
    final row = await (_db.select(_db.profiles)
          ..where((t) => t.id.equals(_rowId)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  ProfilesCompanion _toCompanion(Profile p) => ProfilesCompanion.insert(
        id: const Value(_rowId),
        wakeMinutes: p.wakeMinutes,
        bedMinutes: p.bedMinutes,
        breakfastMinutes: Value(p.breakfastMinutes),
        lunchMinutes: Value(p.lunchMinutes),
        dinnerMinutes: Value(p.dinnerMinutes),
        goal: p.goal.name,
        // Stored as index + 1 (conservative 1, moderate 2, aggressive 3).
        pace: p.pace.index + 1,
        checkInMinutes: Value(p.checkInMinutes),
        evidenceThreshold: Value(p.evidenceThreshold),
        onboarded: Value(p.onboarded),
        newParentMode: Value(p.newParentMode),
      );

  Profile _fromRow(ProfileRow r) => Profile(
        wakeMinutes: r.wakeMinutes,
        bedMinutes: r.bedMinutes,
        breakfastMinutes: r.breakfastMinutes,
        lunchMinutes: r.lunchMinutes,
        dinnerMinutes: r.dinnerMinutes,
        goal: Goal.values.byName(r.goal),
        pace: Pace.values[r.pace - 1],
        checkInMinutes: r.checkInMinutes,
        evidenceThreshold: r.evidenceThreshold,
        onboarded: r.onboarded,
        newParentMode: r.newParentMode,
      );
}
