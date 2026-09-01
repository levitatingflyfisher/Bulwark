import 'package:bulwark/features/settings/domain/user_prefs.dart';
import 'package:openhearth_design/openhearth_design.dart';

abstract interface class SettingsRepository {
  Future<UserPrefs> getUserPrefs();
  Stream<UserPrefs> watchUserPrefs();
  Future<void> setThemeMode(OhThemeModePreference mode);
  Future<void> setRemindersEnabled(bool enabled);
}
