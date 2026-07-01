import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/preset.dart';
import 'package:bulwark/features/notifications/notification_providers.dart';
import 'package:bulwark/features/settings/domain/user_prefs.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_builders.dart';
import 'fake_notification_service.dart';

/// A fresh in-memory drift database for a widget/repo test. Close it in
/// `tearDown` — overriding the provider with a value drops the production
/// `ref.onDispose(db.close)`.
AppDatabase memoryDatabase() => AppDatabase(NativeDatabase.memory());

/// A small but realistic library: free, wake-anchored, phase-1 items in the
/// categories the default (general) goal favours, so the starter-pack selector
/// returns a non-empty pick set. Includes a `newParent` preset.
ContentLibrary testLibrary() => ContentLibrary.build(
      interventions: [
        intervention(id: 'sleep-window', category: Category.sleep),
        intervention(id: 'eat-protein', category: Category.nutrition),
        intervention(
            id: 'box-breathing', category: Category.stress, defaultPhase: 2),
      ],
      presets: const [
        Preset(
          id: 'newParent',
          title: 'New parent survival stack',
          description: 'A bundle for fragmented sleep.',
          interventionIds: ['sleep-window', 'eat-protein'],
        ),
      ],
    );

/// The provider overrides every core-loop widget test needs: an in-memory DB,
/// a fixed content library, and a stubbed prefs stream (so the drift query
/// stream behind `ThemePill` never schedules the pending timer that trips
/// widget-test teardown).
List<Override> adoptionOverrides({
  required AppDatabase db,
  ContentLibrary? library,
  FakeNotificationService? notifications,
}) =>
    [
      appDatabaseProvider.overrideWithValue(db),
      contentLibraryProvider.overrideWith((ref) => library ?? testLibrary()),
      userPrefsProvider.overrideWith((ref) => Stream.value(const UserPrefs())),
      // A fake keeps every onboarding-completion / settings path off the real
      // platform channel; pass one in to assert on the scheduler wiring.
      notificationServiceProvider
          .overrideWithValue(notifications ?? FakeNotificationService()),
    ];
