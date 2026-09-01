import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/data/pulse_repository.dart';
import 'package:bulwark/features/adoption/data/shopping_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/notifications/notification_providers.dart';
import 'package:bulwark/features/settings/presentation/settings_actions.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import '../../support/fake_notification_service.dart';

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.general,
  pace: Pace.moderate,
  onboarded: true,
);

Future<void> _seedEverything(AppDatabase db) async {
  await ProfileRepository(db).save(_profile);
  await HabitStateRepository(db).upsert(HabitState(
    interventionId: 'a',
    status: HabitStatus.active,
    createdAt: DateTime(2026, 1, 1),
  ));
  await CheckinRepository(db).upsert(Checkin(
    interventionId: 'a',
    date: DateTime(2026, 1, 2),
    result: CheckinResult.did,
  ));
  await PulseRepository(db).upsert(Pulse(
    interventionId: 'a',
    weekStart: DateTime(2026, 1, 5),
    result: PulseResult.solid,
  ));
  await ShoppingRepository(db).setPurchased('a', purchased: true);
}

Future<void> _expectAllEmpty(AppDatabase db) async {
  expect(await HabitStateRepository(db).getAll(), isEmpty);
  expect(await CheckinRepository(db).getAll(), isEmpty);
  expect(await PulseRepository(db).getAll(), isEmpty);
  expect(await ShoppingRepository(db).getAll(), isEmpty);
  expect(await ProfileRepository(db).get(), isNull);
}

class _Runner extends ConsumerWidget {
  const _Runner(this.onTap);
  final Future<void> Function(WidgetRef) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(ref),
              child: const Text('erase'),
            ),
          ),
        ),
      );
}

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('AppDatabase.eraseUserData clears every user-data table', () async {
    await _seedEverything(db);
    await db.eraseUserData();
    await _expectAllEmpty(db);
  });

  testWidgets('eraseAllData wipes the tables and cancels notifications',
      (tester) async {
    await _seedEverything(db);
    final fake = FakeNotificationService();

    await tester.pumpWidget(ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        notificationServiceProvider.overrideWithValue(fake),
      ],
      child: const _Runner(eraseAllData),
    ));
    await tester.tap(find.text('erase'));
    await tester.pumpAndSettle();

    await _expectAllEmpty(db);
    // Reminders cancelled via an empty reschedule.
    expect(fake.rescheduleCalls, isNotEmpty);
    expect(fake.lastPlan, isEmpty);
  });

  group('eraseAfterSnapshot (the pre-wipe contract)', () {
    Future<(EraseOutcome, bool)> run(PreWipeOutcome o,
        {required bool promised}) async {
      var wiped = false;
      final outcome = await eraseAfterSnapshot(
        snapshot: () async => (outcome: o, entry: null),
        wipe: () async => wiped = true,
        promisedCopy: promised,
      );
      return (outcome, wiped);
    }

    test('a verified copy was taken: wipe', () async {
      expect(await run(PreWipeOutcome.taken, promised: true),
          (EraseOutcome.erasedWithSafetyCopy, true));
    });

    test('the copy failed: nothing is wiped', () async {
      expect(await run(PreWipeOutcome.failed, promised: true),
          (EraseOutcome.keptBecauseSnapshotFailed, false));
    });

    test('no words, and the dialog said there is no copy: wipe', () async {
      expect(await run(PreWipeOutcome.noKey, promised: false),
          (EraseOutcome.erasedNoCopy, true));
    });

    test('a copy was promised but there is no key: nothing is wiped',
        () async {
      expect(await run(PreWipeOutcome.noKey, promised: true),
          (EraseOutcome.keptBecauseSnapshotFailed, false));
    });
  });
}
