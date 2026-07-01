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

  // Lichen — success, "did it", graduated accents
  static const lichen = Color(0xFF6E7F4F);

  // Clay — gentle attention ("forgot" trace, erosion). Never red.
  static const clay = Color(0xFFA66A4A);

  // Ink — text
  static const ink = Color(0xFF2A3238);

  // Stone — secondary text, disabled, queued
  static const stone = Color(0xFF8C979E);

  // Dark surfaces (ink-family, cool and quiet)
  static const darkSurface = Color(0xFF1B2126);
  static const darkSurface2 = Color(0xFF232B31);
}
