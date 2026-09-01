import 'package:flutter/material.dart';

/// Bulwark's palette — stone and lichen; calm, permanent.
class AppColors {
  AppColors._();

  // Basalt — weathered stone blue-grey (primary: app bar, primary buttons)
  static const basalt = Color(0xFF4E5D66);
  static const basalt600 = Color(0xFF3F4C54);
  static const basalt700 = Color(0xFF313C43);

  // Mortar — warm stone paper (background); mortar2 for cards/raised surfaces
  static const mortar = Color(0xFFF2EEE6);
  static const mortar2 = Color(0xFFE8E2D5);

  // Lichen — success, "did it", graduated accents. As text it is 3.4:1, so
  // words use lichenText / lichenOnDark.
  static const lichen = Color(0xFF6E7F4F);

  // Clay — gentle attention ("forgot" trace, erosion). Never red. As text
  // it is 3.4:1, so words use clayText / clayOnDark.
  static const clay = Color(0xFFA66A4A);

  // Ink — text
  static const ink = Color(0xFF2A3238);

  // Stone — the quiet grey. As text it only clears 4.5:1 on the dark
  // surfaces; on mortar it measured 2.58:1 (audit mind-in-mind-01), so light
  // text uses stoneText. Pick through BulwarkPalette, never directly.
  static const stone = Color(0xFF8C979E);

  // Text-grade variants, measured against the card (the worse ground):
  // light on mortar2 #E8E2D5, dark on darkSurface2 #232B31, all >= 4.5:1.
  static const stoneText = Color(0xFF5A666E); // 4.57 on mortar2
  static const lichenText = Color(0xFF56663A); // 4.85 on mortar2
  static const clayText = Color(0xFF8A5236); // 4.87 on mortar2
  static const lichenOnDark = Color(0xFF9DB07A); // 6.11 on darkSurface2
  static const clayOnDark = Color(0xFFD0906E); // 5.40 on darkSurface2

  // Dark-theme wall: a set stone's edge, and the darker end of its texture.
  static const stoneOnDarkEdge = Color(0xFFB7C0C6);
  static const slateOnDark = Color(0xFF5E6A72);

  // Dark surfaces (ink-family, cool and quiet)
  static const darkSurface = Color(0xFF1B2126);
  static const darkSurface2 = Color(0xFF232B31);
}
