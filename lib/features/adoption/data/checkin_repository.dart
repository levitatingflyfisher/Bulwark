import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:drift/drift.dart';

/// Persistence for daily [Checkin]s. Upserts target the
/// (interventionId, date) unique key so re-recording a day overwrites it.
class CheckinRepository {
  CheckinRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(Checkin c) => _db.into(_db.checkins).insert(
        _toCompanion(c),
        onConflict: DoUpdate(
          (_) => _toCompanion(c),
          target: [_db.checkins.interventionId, _db.checkins.date],
        ),
      );

  Future<List<Checkin>> forIntervention(String interventionId) async {
    final rows = await (_db.select(_db.checkins)
          ..where((t) => t.interventionId.equals(interventionId))
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  /// Every check-in on or after [date] (date-only), across all interventions —
  /// the engine's window query for adherence/gate/graduation.
  Future<List<Checkin>> since(DateTime date) async {
    final rows = await (_db.select(_db.checkins)
          ..where((t) => t.date.isBiggerOrEqualValue(date))
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<Checkin>> getAll() async =>
      (await _db.select(_db.checkins).get()).map(_fromRow).toList();

  CheckinsCompanion _toCompanion(Checkin c) => CheckinsCompanion.insert(
        interventionId: c.interventionId,
        // Store the date-only key so a caller that passes a timestamped date
        // can't slip a second row past the (interventionId, date) conflict
        // target for the same calendar day.
        date: c.date.dateOnly,
        result: c.result.index,
        note: Value(c.note),
      );

  Checkin _fromRow(CheckinRow r) => Checkin(
        interventionId: r.interventionId,
        date: r.date,
        result: CheckinResult.values[r.result],
        note: r.note,
      );
}
