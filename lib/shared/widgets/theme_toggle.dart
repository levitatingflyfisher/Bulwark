import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';

import 'package:bulwark/core/providers/core_providers.dart';

/// The one theme control: light, dark, or follow the phone, as an icon plus
/// a short word in the app bar of every top-level screen (fleet ruling: at
/// most two taps from any primary screen). Replaces the icon-only sun/moon
/// pill and the Settings switch, which could not say "follow the phone".
class ThemeToggle extends ConsumerWidget {
  const ThemeToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(userPrefsProvider).valueOrNull?.themeMode ??
        OhThemeModePreference.defaultValue;
    // Bar words stop growing at 2x (still the 200% WCAG asks for) so the
    // title keeps room at 320 dp and 3x text.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 2.0,
      child: OhThemeToggle(
        value: mode,
        onChanged: (m) => ref.read(settingsRepositoryProvider).setThemeMode(m),
      ),
    );
  }
}
