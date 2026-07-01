import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/notifications/notification_providers.dart';
import 'package:bulwark/features/settings/data/local_settings_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/content_builders.dart';
import '../../support/fake_notification_service.dart';

/// A one-button widget that runs [onTap] with a real [WidgetRef], so an action
/// that reads providers can be exercised without a full screen.
class _Runner extends ConsumerWidget {
  const _Runner(this.onTap);
  final Future<void> Function(WidgetRef) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(ref),
              child: const Text('run'),
            ),
          ),
        ),
      );
}

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.general,
  pace: Pace.moderate,
  onboarded: true,
);

Future<void> _seed(AppDatabase db, {required bool remindersOn}) async {
  await ProfileRepository(db).save(_profile);
  await HabitStateRepository(db).upsert(HabitState(
    interventionId: 'sunlight',
    status: HabitStatus.active,
    activatedAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
  ));
  await LocalSettingsRepository(db).setRemindersEnabled(remindersOn);
}

void main() {
  late AppDatabase db;
  late FakeNotificationService fake;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    fake = FakeNotificationService();
  });
  tearDown(() => db.close());

  Widget app(Future<void> Function(WidgetRef) action) => ProviderScope(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          contentLibraryProvider.overrideWith(
            (ref) => libraryOf([intervention(id: 'sunlight', anchor: Anchor.wake)]),
          ),
          notificationServiceProvider.overrideWithValue(fake),
        ],
        child: _Runner(action),
      );

  testWidgets('with reminders on, the planner output is handed to reschedule',
      (tester) async {
    await _seed(db, remindersOn: true);
    await tester.pumpWidget(app(rescheduleNotifications));
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(fake.rescheduleCalls, hasLength(1));
    final plan = fake.lastPlan!;
    expect(plan, isNotEmpty);
    // The wake-anchored active habit batches into a single morning cue.
    expect(plan.map((n) => n.id), contains('batch-morning'));
  });

  testWidgets('with reminders off, reschedule is called with an empty plan',
      (tester) async {
    await _seed(db, remindersOn: false);
    await tester.pumpWidget(app(rescheduleNotifications));
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();

    expect(fake.rescheduleCalls, hasLength(1));
    expect(fake.lastPlan, isEmpty); // empty plan cancels everything
  });
}
