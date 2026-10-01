import 'dart:io';
import 'dart:math' as math;

import 'package:bulwark/features/adoption/presentation/wall_painter.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// WCAG 2.x contrast ratio between two opaque colours.
double _ratio(Color a, Color b) {
  double channel(double c) =>
      c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
  double lum(Color c) =>
      0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
  final la = lum(a), lb = lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Every colour that carries words, and every mark that carries meaning, in
/// both themes, measured against the scaffold and the card (the card is the
/// worse ground in both). Light-theme secondary text used to measure 2.31:1
/// on the card (audit mind-in-mind-01), and dark mode printed light-mode ink
/// at 1.10:1 (design-for-hackers-01).
void main() {
  for (final entry in {'light': AppTheme.light, 'dark': AppTheme.dark}.entries) {
    final theme = entry.value;
    final cs = theme.colorScheme;
    final p = theme.extension<BulwarkPalette>();
    final grounds = {
      'scaffold': theme.scaffoldBackgroundColor,
      'card': theme.cardTheme.color!,
    };

    test('${entry.key}: the theme attaches Bulwark\'s palette', () {
      expect(p, isNotNull);
    });

    final text = {
      'onSurface': cs.onSurface,
      'onSurfaceVariant': cs.onSurfaceVariant,
      'error (clay, never red)': cs.error,
      'secondaryText': p!.secondaryText,
      'lichen': p.lichen,
      'clay': p.clay,
    };
    for (final t in text.entries) {
      for (final g in grounds.entries) {
        test('${entry.key}: ${t.key} text on the ${g.key} is at least 4.5:1',
            () {
          expect(_ratio(t.value, g.value), greaterThanOrEqualTo(4.5),
              reason: '${t.value} on ${g.value}');
        });
      }
    }

    test('${entry.key}: a set stone reads against the page at 3:1 across its '
        'whole texture range', () {
      for (final t in [0.0, 0.5]) {
        final fill = Color.lerp(p.wallSet, p.wallForming, t)!;
        expect(_ratio(fill, theme.scaffoldBackgroundColor),
            greaterThanOrEqualTo(3.0),
            reason: 'lerp $t');
      }
    });

    // A forming stone is told apart by its outline (its fill is a faint
    // tint on purpose: the stone is still being set). The outline is the
    // indicator, so it owes 3:1 on the page; at alpha 0.55 it measured
    // 2.35:1 light and 2.61:1 dark (audit design-for-hackers-02).
    test('${entry.key}: a forming stone\'s outline reads at 3:1', () {
      final bg = theme.scaffoldBackgroundColor;
      final edge = Color.alphaBlend(
          p.wallFormingEdge.withValues(alpha: WallPainter.formingEdgeAlpha),
          bg);
      expect(_ratio(edge, bg), greaterThanOrEqualTo(3.0));
    });

    test('${entry.key}: the error role is not red', () {
      final hsl = HSLColor.fromColor(cs.error);
      // Clay sits near 20-25 degrees; seeded Material error is ~0-10.
      expect(hsl.hue, greaterThan(15));
    });
  }

  test('no feature code names an AppColors constant (roles only)', () {
    final hits = <String>[];
    for (final f in Directory('lib/features')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (lines[i].contains('AppColors.')) hits.add('${f.path}:${i + 1}');
      }
    }
    expect(hits, isEmpty,
        reason: 'use BulwarkPalette.of(context) or the ColorScheme, so the '
            'colour flips with the theme');
  });
}
