/// Static app identity for the About screen and the license page.
///
/// [appVersion] is kept in sync by hand with `pubspec.yaml`'s `version:` field
/// (a hardcoded constant avoids a package_info_plus dependency for one string).
/// If you bump the pubspec version, bump this too.
class AppInfo {
  AppInfo._();

  static const String appName = 'Bulwark';
  static const String appVersion = '0.1.0';
  static const String tagline = 'A wall between you and entropy.';
}
