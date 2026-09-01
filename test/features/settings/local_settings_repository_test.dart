import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/settings/data/local_settings_repository.dart';

void main() {
  late AppDatabase db;
  late LocalSettingsRepository repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = LocalSettingsRepository(db);
  });

  tearDown(() => db.close());

  group('LocalSettingsRepository', () {
    test('theme follows the phone on an empty store (the default)', () async {
      final prefs = await repo.getUserPrefs();
      expect(prefs.themeMode, OhThemeModePreference.system);
    });

    test('each theme choice persists and round-trips', () async {
      for (final mode in OhThemeModePreference.values) {
        await repo.setThemeMode(mode);
        expect((await repo.getUserPrefs()).themeMode, mode);
      }
    });

    test('an unreadable stored theme falls back to following the phone',
        () async {
      await db.into(db.userPrefs).insertOnConflictUpdate(
          UserPrefsCompanion.insert(key: 'theme_mode', value: 'sepia'));
      expect((await repo.getUserPrefs()).themeMode,
          OhThemeModePreference.system);
    });

    test('watchUserPrefs emits the updated prefs after a write', () async {
      final emitted = expectLater(
        repo.watchUserPrefs().map((p) => p.themeMode),
        emitsThrough(OhThemeModePreference.dark),
      );
      await repo.setThemeMode(OhThemeModePreference.dark);
      await emitted;
    });

    test('remindersEnabled defaults to false (reminders are opt-in)', () async {
      final prefs = await repo.getUserPrefs();
      expect(prefs.remindersEnabled, isFalse);
    });

    test('setRemindersEnabled(true) persists and round-trips off', () async {
      await repo.setRemindersEnabled(true);
      expect((await repo.getUserPrefs()).remindersEnabled, isTrue);
      await repo.setRemindersEnabled(false);
      expect((await repo.getUserPrefs()).remindersEnabled, isFalse);
    });

    test('reminders and theme persist independently', () async {
      await repo.setRemindersEnabled(true);
      await repo.setThemeMode(OhThemeModePreference.light);
      final prefs = await repo.getUserPrefs();
      expect(prefs.remindersEnabled, isTrue);
      expect(prefs.themeMode, OhThemeModePreference.light);
    });
  });
}
