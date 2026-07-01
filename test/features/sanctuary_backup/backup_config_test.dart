import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/sanctuary_backup/backup_config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adoption_harness.dart';
import '../../support/fake_notification_service.dart';

final _refProvider = Provider<Ref>((ref) => ref);

void main() {
  group('bulwarkBackupConfig', () {
    test('identifies the app for the AAD context and appDomain isolation',
        () {
      expect(bulwarkBackupConfig.appId, 'bulwark');
      expect(bulwarkBackupConfig.aadContext, 'bulwark-backup/v1');
      expect(bulwarkBackupConfig.appDisplayName, 'Bulwark');
    });

    test(
        'restoreReplaceConsequence discloses every table eraseUserData '
        'wipes — including the profile, which is easy to omit', () {
      final copy = bulwarkBackupConfig.restoreReplaceConsequence;
      expect(copy, isNotNull);

      // AppDatabase.eraseUserData() wipes habitStates, checkins, pulses,
      // shoppingStates, AND profiles — restore replaces all five with the
      // backup's contents. The confirm dialog must say so plainly (brief
      // §2.5): a user restoring to "get my habits back" should not be
      // surprised their day-map/goal/pace/reminders changed too.
      expect(copy, contains('habit'));
      expect(copy, contains('check-in'));
      expect(copy, contains('pulse'));
      expect(copy, contains('shopping'));
      expect(copy!.toLowerCase(), contains('profile'));
    });

    test('onAfterRestore is wired to invalidate the read-model providers',
        () async {
      final db = memoryDatabase();
      addTearDown(db.close);
      await ProfileRepository(db).save(const Profile(
        wakeMinutes: 7 * 60,
        bedMinutes: 22 * 60,
        goal: Goal.general,
        pace: Pace.moderate,
        onboarded: true,
      ));

      final container = ProviderContainer(
        overrides: adoptionOverrides(
          db: db,
          notifications: FakeNotificationService(),
        ),
      );
      addTearDown(container.dispose);

      // Warm the keepAlive provider, then mutate the DB directly (as a real
      // restore would) and confirm the config's onAfterRestore hook — not a
      // test-supplied stand-in — actually refreshes it.
      await container.read(profileProvider.future);
      await HabitStateRepository(db).upsert(HabitState(
        interventionId: 'sleep-window',
        status: HabitStatus.active,
        createdAt: DateTime(2026, 1, 1),
      ));

      expect(bulwarkBackupConfig.onAfterRestore, isNotNull);
      bulwarkBackupConfig.onAfterRestore!(container.read(_refProvider));

      final active = await container.read(activeHabitsProvider.future);
      expect(active, hasLength(1),
          reason: 'onAfterRestore must invalidate activeHabitsProvider');
    });
  });
}
