import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
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
    test('isDarkMode defaults to false on an empty store', () async {
      final prefs = await repo.getUserPrefs();
      expect(prefs.isDarkMode, isFalse);
    });

    test('setDarkMode(true) persists', () async {
      await repo.setDarkMode(true);
      final prefs = await repo.getUserPrefs();
      expect(prefs.isDarkMode, isTrue);
    });

    test('dark mode round-trips back to light', () async {
      await repo.setDarkMode(true);
      await repo.setDarkMode(false);
      final prefs = await repo.getUserPrefs();
      expect(prefs.isDarkMode, isFalse);
    });

    test('watchUserPrefs emits the updated prefs after a write', () async {
      final emitted = expectLater(
        repo.watchUserPrefs().map((p) => p.isDarkMode),
        emitsThrough(isTrue),
      );
      await repo.setDarkMode(true);
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

    test('reminders and dark mode persist independently', () async {
      await repo.setRemindersEnabled(true);
      await repo.setDarkMode(true);
      final prefs = await repo.getUserPrefs();
      expect(prefs.remindersEnabled, isTrue);
      expect(prefs.isDarkMode, isTrue);
    });
  });
}
