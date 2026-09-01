import 'package:openhearth_design/openhearth_design.dart';

/// User preferences persisted in the local drift key→value store.
///
/// Bulwark's full profile (wake/bed/meal anchors, goal, pace, evidence
/// threshold) lives in its own table; this holds only the app-shell toggles.
class UserPrefs {
  const UserPrefs({
    this.themeMode = OhThemeModePreference.defaultValue,
    this.remindersEnabled = false,
  });

  /// Light, dark, or follow the phone (the default, fleet ruling).
  final OhThemeModePreference themeMode;

  /// Master switch for local reminders. Defaults to off: notifications are
  /// opt-in (§1.7), so a fresh install is silent until the user turns them on
  /// (or opts into a check-in reminder during onboarding, which flips this on).
  final bool remindersEnabled;
}
