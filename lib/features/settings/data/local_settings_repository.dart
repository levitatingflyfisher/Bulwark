import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/settings/domain/settings_repository.dart';
import 'package:bulwark/features/settings/domain/user_prefs.dart';

class LocalSettingsRepository implements SettingsRepository {
  LocalSettingsRepository(this._db);
  final AppDatabase _db;

  static const _kDarkMode = 'theme';
  static const _kReminders = 'reminders';

  Future<void> _set(String key, String value) => _db
      .into(_db.userPrefs)
      .insertOnConflictUpdate(UserPrefsCompanion.insert(key: key, value: value));

  @override
  Future<UserPrefs> getUserPrefs() async {
    final rows = await _db.select(_db.userPrefs).get();
    final map = {for (final r in rows) r.key: r.value};
    return _fromMap(map);
  }

  @override
  Stream<UserPrefs> watchUserPrefs() =>
      _db.select(_db.userPrefs).watch().map((rows) {
        final map = {for (final r in rows) r.key: r.value};
        return _fromMap(map);
      });

  @override
  Future<void> setDarkMode(bool dark) =>
      _set(_kDarkMode, dark ? 'dark' : 'light');

  @override
  Future<void> setRemindersEnabled(bool enabled) =>
      _set(_kReminders, enabled ? 'on' : 'off');

  UserPrefs _fromMap(Map<String, String> map) => UserPrefs(
        isDarkMode: map[_kDarkMode] == 'dark',
        // Absent → false: reminders stay opt-in until explicitly turned on.
        remindersEnabled: map[_kReminders] == 'on',
      );
}
