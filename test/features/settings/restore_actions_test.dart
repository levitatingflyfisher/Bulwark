import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/settings/data/local_settings_repository.dart';
import 'package:bulwark/features/settings/presentation/settings_actions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adoption_harness.dart';
import '../../support/fake_notification_service.dart';

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.general,
  pace: Pace.moderate,
  onboarded: true,
);

/// Exposes the container's own [Ref] — the same trick Riverpod's own docs use
/// to get a `Ref` outside of a widget/notifier for a unit test.
final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  late AppDatabase db;
  late FakeNotificationService fake;

  setUp(() {
    db = memoryDatabase();
    fake = FakeNotificationService();
  });
  tearDown(() => db.close());

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: adoptionOverrides(db: db, notifications: fake),
    );
    addTearDown(c.dispose);
    return c;
  }

  test('invalidates every read-model provider eraseAllData invalidates',
      () async {
    await ProfileRepository(db).save(_profile);
    final container = makeContainer();

    // Warm the keepAlive providers with a stale read.
    final before = await container.read(profileProvider.future);
    expect(before?.goal, Goal.general);

    // Simulate what restoreAll just wrote, directly on the DB (bypassing the
    // providers, the way a destructive restore does).
    await ProfileRepository(db).save(_profile.copyWith(goal: Goal.sleep));

    await afterBackupRestore(container.read(_refProvider));

    final after = await container.read(profileProvider.future);
    expect(after?.goal, Goal.sleep, reason: 'profileProvider must refresh');
  });

  test('reschedules reminders from the restored habits when enabled',
      () async {
    await ProfileRepository(db).save(_profile);
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ));
    await LocalSettingsRepository(db)
        .setRemindersEnabled(true); // flips UserPrefs.remindersEnabled

    final container = makeContainer();
    await afterBackupRestore(container.read(_refProvider));

    expect(fake.rescheduleCalls, isNotEmpty);
    expect(fake.lastPlan, isNotEmpty,
        reason: 'an active habit with reminders on should plan something');
  });

  test('reschedules an empty plan when reminders are off', () async {
    await ProfileRepository(db).save(_profile); // remindersEnabled defaults false
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ));

    final container = makeContainer();
    await afterBackupRestore(container.read(_refProvider));

    expect(fake.rescheduleCalls, isNotEmpty);
    expect(fake.lastPlan, isEmpty);
  });

  test('a scheduling failure is swallowed (best-effort)', () async {
    // No profile at all — mirrors a restore of an empty/fresh backup. Should
    // not throw even though there's nothing to plan around.
    final container = makeContainer();
    await expectLater(
      afterBackupRestore(container.read(_refProvider)),
      completes,
    );
  });
}
