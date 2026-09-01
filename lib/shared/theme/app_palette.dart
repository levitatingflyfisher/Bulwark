import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Bulwark's own colour roles, resolved per brightness.
///
/// Feature code never names an [AppColors] constant: a raw light-mode hex
/// printed on a dark card is how the shopping list's item names ended up at
/// 1.1:1 (audit design-for-hackers-01). Text and marks read these roles, or
/// the [ColorScheme]'s, so the value flips with the theme.
///
/// Every text role here is at least 4.5:1 on both the scaffold and the card
/// of its theme; `test/shared/theme/contrast_test.dart` holds that.
@immutable
class BulwarkPalette extends ThemeExtension<BulwarkPalette> {
  const BulwarkPalette({
    required this.secondaryText,
    required this.lichen,
    required this.clay,
    required this.wallSet,
    required this.wallSetEdge,
    required this.wallForming,
    required this.wallFormingEdge,
  });

  /// Metadata text and quiet icons: evidence tags, trigger notes, dates.
  final Color secondaryText;

  /// "Did it", graduation, success. Text-grade, so it can carry words.
  final Color lichen;

  /// Gentle attention (forgot, shaky, erase). Never red. Text-grade.
  final Color clay;

  /// A set stone's fill (lerped toward [wallForming] for texture) and edge.
  final Color wallSet;
  final Color wallSetEdge;

  /// A forming stone's fill and outline.
  final Color wallForming;
  final Color wallFormingEdge;

  static const light = BulwarkPalette(
    secondaryText: AppColors.stoneText,
    lichen: AppColors.lichenText,
    clay: AppColors.clayText,
    wallSet: AppColors.basalt,
    wallSetEdge: AppColors.basalt700,
    wallForming: AppColors.stone,
    wallFormingEdge: AppColors.basalt,
  );

  static const dark = BulwarkPalette(
    secondaryText: AppColors.stone,
    lichen: AppColors.lichenOnDark,
    clay: AppColors.clayOnDark,
    wallSet: AppColors.stone,
    wallSetEdge: AppColors.stoneOnDarkEdge,
    wallForming: AppColors.slateOnDark,
    wallFormingEdge: AppColors.stone,
  );

  /// The palette of the nearest theme; falls back by brightness for a
  /// ThemeData that did not attach one (a bare test theme).
  static BulwarkPalette of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<BulwarkPalette>() ??
        (theme.brightness == Brightness.dark ? dark : light);
  }

  @override
  BulwarkPalette copyWith({
    Color? secondaryText,
    Color? lichen,
    Color? clay,
    Color? wallSet,
    Color? wallSetEdge,
    Color? wallForming,
    Color? wallFormingEdge,
  }) =>
      BulwarkPalette(
        secondaryText: secondaryText ?? this.secondaryText,
        lichen: lichen ?? this.lichen,
        clay: clay ?? this.clay,
        wallSet: wallSet ?? this.wallSet,
        wallSetEdge: wallSetEdge ?? this.wallSetEdge,
        wallForming: wallForming ?? this.wallForming,
        wallFormingEdge: wallFormingEdge ?? this.wallFormingEdge,
      );

  @override
  BulwarkPalette lerp(BulwarkPalette? other, double t) {
    if (other == null) return this;
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return BulwarkPalette(
      secondaryText: l(secondaryText, other.secondaryText),
      lichen: l(lichen, other.lichen),
      clay: l(clay, other.clay),
      wallSet: l(wallSet, other.wallSet),
      wallSetEdge: l(wallSetEdge, other.wallSetEdge),
      wallForming: l(wallForming, other.wallForming),
      wallFormingEdge: l(wallFormingEdge, other.wallFormingEdge),
    );
  }
}
