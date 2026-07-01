import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late CheckinRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = CheckinRepository(db);
  });
  tearDown(() => db.close());

  Checkin ci(String id, DateTime date, CheckinResult r, {String? note}) =>
      Checkin(interventionId: id, date: date, result: r, note: note);

  test('upsert then read round-trips', () async {
    final c = ci('a', DateTime(2026, 1, 5), CheckinResult.did, note: 'easy');
    await repo.upsert(c);
    final got = await repo.forIntervention('a');
    expect(got, [c]);
  });

  test('the (interventionId, date) unique key updates rather than duplicating',
      () async {
    await repo.upsert(ci('a', DateTime(2026, 1, 5), CheckinResult.forgot));
    await repo.upsert(ci('a', DateTime(2026, 1, 5), CheckinResult.did));
    final got = await repo.forIntervention('a');
    expect(got, hasLength(1));
    expect(got.single.result, CheckinResult.did);
  });

  test('a time component is normalized so the same calendar day dedups',
      () async {
    // A writer that forgets to strip the time must not create a second
    // "same day" row — the repo stores the date-only key.
    await repo.upsert(ci('a', DateTime(2026, 1, 5, 8, 30), CheckinResult.forgot));
    await repo.upsert(ci('a', DateTime(2026, 1, 5, 21, 15), CheckinResult.did));
    final got = await repo.forIntervention('a');
    expect(got, hasLength(1));
    expect(got.single.result, CheckinResult.did);
    expect(got.single.date, DateTime(2026, 1, 5)); // stored date-only
  });

  test('a different date is a distinct row', () async {
    await repo.upsert(ci('a', DateTime(2026, 1, 5), CheckinResult.did));
    await repo.upsert(ci('a', DateTime(2026, 1, 6), CheckinResult.skipped));
    expect(await repo.forIntervention('a'), hasLength(2));
  });

  test('since filters to check-ins on/after the given date', () async {
    await repo.upsert(ci('a', DateTime(2026, 1, 1), CheckinResult.did));
    await repo.upsert(ci('a', DateTime(2026, 1, 5), CheckinResult.did));
    await repo.upsert(ci('b', DateTime(2026, 1, 6), CheckinResult.did));
    final recent = await repo.since(DateTime(2026, 1, 5));
    expect(recent.map((c) => c.date).toSet(),
        {DateTime(2026, 1, 5), DateTime(2026, 1, 6)});
  });
}
