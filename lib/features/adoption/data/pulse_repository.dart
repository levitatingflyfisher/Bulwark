import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:drift/drift.dart';

/// Persistence for graduated-habit weekly [Pulse]s. Upserts target the
/// (interventionId, weekStart) unique key.
class PulseRepository {
  PulseRepository(this._db);
  final AppDatabase _db;

  Future<void> upsert(Pulse p) => _db.into(_db.pulses).insert(
        _toCompanion(p),
        onConflict: DoUpdate(
          (_) => _toCompanion(p),
          target: [_db.pulses.interventionId, _db.pulses.weekStart],
        ),
      );

  Future<List<Pulse>> forIntervention(String interventionId) async {
    final rows = await (_db.select(_db.pulses)
          ..where((t) => t.interventionId.equals(interventionId))
          ..orderBy([(t) => OrderingTerm(expression: t.weekStart)]))
        .get();
    return rows.map(_fromRow).toList();
  }

  Future<List<Pulse>> getAll() async =>
      (await _db.select(_db.pulses).get()).map(_fromRow).toList();

  PulsesCompanion _toCompanion(Pulse p) => PulsesCompanion.insert(
        interventionId: p.interventionId,
        // Normalize to the ISO-week Monday so a caller passing any day within
        // the week can't slip a second row past the (interventionId, weekStart)
        // conflict target for the same week.
        weekStart: p.weekStart.startOfWeek,
        result: p.result.index,
      );

  Pulse _fromRow(PulseRow r) => Pulse(
        interventionId: r.interventionId,
        weekStart: r.weekStart,
        result: PulseResult.values[r.result],
      );
}
