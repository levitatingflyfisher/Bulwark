import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late ProfileRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = ProfileRepository(db);
  });
  tearDown(() => db.close());

  const profile = Profile(
    wakeMinutes: 7 * 60,
    bedMinutes: 22 * 60,
    breakfastMinutes: 8 * 60,
    lunchMinutes: null,
    dinnerMinutes: 18 * 60,
    goal: Goal.longevity,
    pace: Pace.aggressive,
    checkInMinutes: 20 * 60,
    evidenceThreshold: 2,
    onboarded: true,
    newParentMode: false,
  );

  test('get returns null before any profile is saved', () async {
    expect(await repo.get(), isNull);
  });

  test('save then get round-trips every field (incl. pace + goal encoding)',
      () async {
    await repo.save(profile);
    expect(await repo.get(), profile);
  });

  test('saving again overwrites the single profile row', () async {
    await repo.save(profile);
    await repo.save(profile.copyWith(goal: Goal.sleep, pace: Pace.conservative));
    final got = await repo.get();
    expect(got!.goal, Goal.sleep);
    expect(got.pace, Pace.conservative);
    // still a single row
    expect(await repo.get(), isNotNull);
  });
}
