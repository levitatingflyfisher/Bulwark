import 'package:flutter/material.dart';

import 'package:bulwark/features/adoption/domain/wall_layout.dart';
import 'package:bulwark/shared/theme/app_palette.dart';

/// One stone's on-canvas cell — the uniform grid rect used for both drawing and
/// tap hit-testing. Drawing insets a slightly-irregular stone inside the cell so
/// the wall reads as masonry, but the tap target stays the whole cell.
class WallStone {
  final StonePlacement placement;
  final Rect cell;
  const WallStone({required this.placement, required this.cell});
}

/// Pure geometry for the drystone wall. It maps [StonePlacement]s (from the
/// unit-tested [WallLayout]) to canvas rects, and is the single source of truth
/// shared by [WallPainter] (drawing) and the Progress screen (hit-testing), so
/// the two can never disagree about where a stone is. No widgets — unit-tested.
class WallGeometry {
  const WallGeometry._();

  /// Nominal height of one course, in logical pixels.
  static const double courseHeight = 30;

  /// Target stone width; the column count is chosen to land near this.
  static const double targetStoneWidth = 58;

  /// How many stone columns fit across [availableWidth] (never below 1).
  static int columnsFor(double availableWidth) {
    if (availableWidth <= 0) return 1;
    final n = (availableWidth / targetStoneWidth).floor();
    return n < 1 ? 1 : n;
  }

  /// The wall's total height for [placements] packed at [columns] columns:
  /// course count (at least 1 — the wall never collapses to nothing) times
  /// [courseHeight].
  static double heightFor(List<StonePlacement> placements, int columns) {
    var maxCourse = 0;
    for (final p in placements) {
      if (p.course > maxCourse) maxCourse = p.course;
    }
    final courses = placements.isEmpty ? 1 : maxCourse + 1;
    return courses * courseHeight;
  }

  /// The cell rect for every placement at paint [size] and [columns] columns.
  /// Course 0 sits on the bottom (largest y); index runs left→right.
  static List<WallStone> stones(
    List<StonePlacement> placements,
    Size size,
    int columns,
  ) {
    final width = columns < 1 ? 1 : columns;
    final cellWidth = size.width / width;
    return [
      for (final p in placements)
        WallStone(
          placement: p,
          cell: Rect.fromLTWH(
            p.index * cellWidth,
            size.height - (p.course + 1) * courseHeight,
            cellWidth,
            courseHeight,
          ),
        ),
    ];
  }

  /// The placement whose cell contains [point], or null. Cells never overlap, so
  /// the hit is unambiguous.
  static StonePlacement? hitTest(List<WallStone> stones, Offset point) {
    for (final s in stones) {
      if (s.cell.contains(point)) return s.placement;
    }
    return null;
  }
}

/// Paints the drystone wall: a `set` stone per graduated habit (basalt, mortar
/// gaps), `forming` stones for active habits (outlined, being set), and
/// `weathered` stones for eroded graduated habits (cracked, clay-tinted). Slight
/// deterministic per-stone variation keeps it masonry, not a grid.
class WallPainter extends CustomPainter {
  WallPainter({
    required this.placements,
    required this.columns,
    this.palette = BulwarkPalette.light,
  });

  final List<StonePlacement> placements;
  final int columns;

  /// The theme's wall colours, so the dark wall is drawn for a dark ground.
  final BulwarkPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    // Confine drawing to the paint bounds — odd courses are shifted for the
    // running-bond look and a half-stone at the ends is meant to clip.
    canvas.clipRect(Offset.zero & size);
    for (final stone in WallGeometry.stones(placements, size, columns)) {
      _paintStone(canvas, stone);
    }
  }

  void _paintStone(Canvas canvas, WallStone stone) {
    final cell = stone.cell;
    final seed = stone.placement.course * 31 + stone.placement.index;
    final jitterX = _frac(seed) * 3 - 1.5; // ±1.5px horizontal wobble
    final widthTrim = _frac(seed * 7 + 1) * 6; // up to 6px narrower
    final lightness = _frac(seed * 13 + 3); // fill variation

    // Running bond: shift every other course by half a stone so the vertical
    // mortar joints stagger between courses instead of stacking into a grid.
    // Only the *drawn* rect moves — the hit-test cell stays put.
    final bond = stone.placement.course.isOdd ? cell.width * 0.5 : 0.0;

    const gap = 2.5; // the mortar joint
    final rect = Rect.fromLTWH(
      cell.left + gap + jitterX + bond,
      cell.top + gap,
      (cell.width - gap * 2 - widthTrim).clamp(2.0, cell.width),
      cell.height - gap * 2,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));

    switch (stone.placement.kind) {
      case StoneKind.set:
        final fill =
            Color.lerp(palette.wallSet, palette.wallForming, lightness * 0.5)!;
        canvas.drawRRect(rrect, Paint()..color = fill);
        canvas.drawRRect(rrect, _stroke(palette.wallSetEdge, 1));
      case StoneKind.forming:
        canvas.drawRRect(
            rrect, Paint()..color = palette.wallForming.withValues(alpha: 0.12));
        canvas.drawRRect(
            rrect, _stroke(palette.wallFormingEdge.withValues(alpha: 0.55), 1.4));
      case StoneKind.weathered:
        canvas.drawRRect(
            rrect, Paint()..color = palette.clay.withValues(alpha: 0.18));
        canvas.drawRRect(
            rrect, _stroke(palette.clay.withValues(alpha: 0.7), 1.4));
        _paintCrack(canvas, rect, seed);
    }
  }

  /// A single hairline crack for a weathered stone — a diagonal with one kink.
  void _paintCrack(Canvas canvas, Rect r, int seed) {
    final x = r.left + r.width * (0.35 + _frac(seed * 5) * 0.3);
    final path = Path()
      ..moveTo(x, r.top + 2)
      ..lineTo(x + 3, r.center.dy)
      ..lineTo(x - 2, r.bottom - 2);
    canvas.drawPath(path, _stroke(palette.clay.withValues(alpha: 0.6), 1));
  }

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  /// Deterministic pseudo-random fraction in [0, 1) from an integer seed.
  static double _frac(int seed) {
    final v = (seed * 1103515245 + 12345) & 0x7fffffff;
    return (v % 1000) / 1000.0;
  }

  @override
  bool shouldRepaint(WallPainter oldDelegate) =>
      oldDelegate.columns != columns ||
      oldDelegate.palette != palette ||
      !_sameStones(oldDelegate.placements);

  bool _sameStones(List<StonePlacement> other) {
    if (other.length != placements.length) return false;
    for (var i = 0; i < placements.length; i++) {
      final a = placements[i];
      final b = other[i];
      if (a.course != b.course || a.index != b.index || a.kind != b.kind) {
        return false;
      }
    }
    return true;
  }
}
