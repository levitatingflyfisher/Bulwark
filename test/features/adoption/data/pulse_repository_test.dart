import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/pulse_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late PulseRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = PulseRepository(db);
  });
  tearDown(() => db.close());

  Pulse pulse(String id, DateTime week, PulseResult r) =>
      Pulse(interventionId: id, weekStart: week, result: r);

  test('upsert then read round-trips, ordered by weekStart', () async {
    await repo.upsert(pulse('a', DateTime(2026, 1, 12), PulseResult.shaky));
    await repo.upsert(pulse('a', DateTime(2026, 1, 5), PulseResult.solid));
    final got = await repo.forIntervention('a');
    expect(got.map((p) => p.weekStart).toList(),
        [DateTime(2026, 1, 5), DateTime(2026, 1, 12)]);
  });

  test('the (interventionId, weekStart) unique key updates in place', () async {
    await repo.upsert(pulse('a', DateTime(2026, 1, 5), PulseResult.solid));
    await repo.upsert(pulse('a', DateTime(2026, 1, 5), PulseResult.shaky));
    final got = await repo.forIntervention('a');
    expect(got, hasLength(1));
    expect(got.single.result, PulseResult.shaky);
  });

  test('a mid-week / timestamped weekStart normalizes to the ISO Monday',
      () async {
    // 2026-01-07 is a Wednesday, 2026-01-09 a Friday — same week. Both must
    // collapse to Monday 2026-01-05 so a writer can't create two "same week"
    // rows.
    await repo.upsert(pulse('a', DateTime(2026, 1, 7, 10), PulseResult.shaky));
    await repo.upsert(pulse('a', DateTime(2026, 1, 9, 3), PulseResult.solid));
    final got = await repo.forIntervention('a');
    expect(got, hasLength(1));
    expect(got.single.weekStart, DateTime(2026, 1, 5));
    expect(got.single.result, PulseResult.solid);
  });

  test('getAll returns pulses across interventions', () async {
    await repo.upsert(pulse('a', DateTime(2026, 1, 5), PulseResult.solid));
    await repo.upsert(pulse('b', DateTime(2026, 1, 5), PulseResult.shaky));
    expect(await repo.getAll(), hasLength(2));
  });
}
