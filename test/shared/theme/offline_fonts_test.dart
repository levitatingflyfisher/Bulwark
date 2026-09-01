import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bulwark/shared/theme/app_theme.dart';

/// Bulwark is local-first: fonts must resolve from a bundled asset, never be
/// fetched from fonts.gstatic.com at runtime. google_fonts sets the family to
/// a variant name like 'Lora_regular' and fetches the .ttf from Google on
/// first use, which is a data egress on launch.
///
/// Since openhearth_design 0.7.2 the bundle is that package's, not a copy
/// Bulwark ships itself, so the family is the package-qualified
/// 'packages/openhearth_design/Lora' / '.../Nunito': still a local asset.
/// These assertions lock out a regression back to runtime font egress and
/// prove the promised fonts are declared and resolvable, not merely named (a
/// declared-but-missing asset fails silently at first paint, not at pub get).
const _package = 'openhearth_design';
const _lora = 'packages/$_package/Lora';
const _nunito = 'packages/$_package/Nunito';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('text theme uses the package Lora/Nunito families (no runtime fetch)',
      () {
    final t = AppTheme.light.textTheme;
    expect(t.displayLarge!.fontFamily, _lora);
    expect(t.headlineMedium!.fontFamily, _lora);
    expect(t.titleLarge!.fontFamily, _nunito);
    expect(t.bodyMedium!.fontFamily, _nunito);
  });

  test('dark theme also uses the package families', () {
    final t = AppTheme.dark.textTheme;
    expect(t.displaySmall!.fontFamily, _lora);
    expect(t.bodySmall!.fontFamily, _nunito);
  });

  test('every Lora weight the theme asks for has a file (no engine-faked '
      'weight)', () {
    // The package ships Lora 400, 500, 700 (no 600). A headline asking for
    // w600 would be synthesised differently on every platform.
    const shipped = {FontWeight.w400, FontWeight.w500, FontWeight.w700};
    final t = AppTheme.light.textTheme;
    for (final s in [
      t.displayLarge,
      t.displayMedium,
      t.displaySmall,
      t.headlineLarge,
      t.headlineMedium,
      t.headlineSmall,
    ]) {
      expect(s!.fontFamily, _lora);
      expect(shipped, contains(s.fontWeight ?? FontWeight.w400));
    }
  });

  test(
      'openhearth_design declares Lora/Nunito as package fonts, and the '
      'assets they name actually resolve', () async {
    final manifest =
        json.decode(await rootBundle.loadString('FontManifest.json'))
            as List<dynamic>;
    final families = manifest
        .cast<Map<String, dynamic>>()
        .map((e) => e['family'] as String)
        .toSet();
    expect(families, containsAll([_lora, _nunito]));
    expect(families.contains('Lora'), isFalse,
        reason: 'the app-local Lora copy is gone; only the package declares it');
    for (final asset in [
      'packages/openhearth_design/fonts/Lora-Regular.ttf',
      'packages/openhearth_design/fonts/Nunito-Regular.ttf',
    ]) {
      final bytes = await rootBundle.load(asset);
      expect(bytes.lengthInBytes, greaterThan(0), reason: asset);
    }
  });
}
