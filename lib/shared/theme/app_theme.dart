import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'app_colors.dart';
import 'app_palette.dart';

class AppTheme {
  AppTheme._();

  // Fonts come from openhearth_design's package fonts (0.7.2+) and are
  // referenced by family, never fetched from fonts.gstatic.com at runtime.
  // This keeps the app fully local-first: no font egress on first launch.
  // See test/shared/theme/offline_fonts_test.dart.
  //
  // The Material text ladder is the shared openhearth_design one (0.7.0 moved
  // it onto the fleet type ladder: body 16, no Lora w600). It is locked by
  // the whole-TextStyle equivalence test; Bulwark has no goldens. Bulwark's
  // basalt/mortar surfaces below stay app-local: they are identity, not
  // shared tokens.
  static const TextTheme _textTheme = OhTypography.materialTextTheme;

  static final light = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.basalt,
      brightness: Brightness.light,
      surface: AppColors.mortar,
      onSurface: AppColors.ink,
      // Set, not left to fromSeed: secondary text must clear 4.5:1 on the
      // card, and the seeded value is not guaranteed to.
      onSurfaceVariant: AppColors.stoneText,
      // Bulwark's palette law: nothing is red. The error role (read by
      // shared widgets) is text-grade clay.
      error: AppColors.clayText,
      onError: AppColors.mortar,
    ),
    extensions: const [BulwarkPalette.light, OhColorRoles.light],
    scaffoldBackgroundColor: AppColors.mortar,
    shadowColor: AppColors.ink.withValues(alpha: 0.15),
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.basalt,
      foregroundColor: AppColors.mortar,
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.mortar2,
      shadowColor: AppColors.ink.withValues(alpha: 0.1),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.basalt,
      brightness: Brightness.dark,
      surface: AppColors.darkSurface,
      onSurface: AppColors.mortar,
      onSurfaceVariant: AppColors.stone,
      error: AppColors.clayOnDark,
      onError: AppColors.darkSurface,
    ),
    extensions: const [BulwarkPalette.dark, OhColorRoles.hearthDark],
    scaffoldBackgroundColor: AppColors.darkSurface,
    shadowColor: Colors.black.withValues(alpha: 0.3),
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.darkSurface2,
      foregroundColor: AppColors.mortar,
    ),
    cardTheme: CardThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 0,
      color: AppColors.darkSurface2,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      elevation: 4,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}
