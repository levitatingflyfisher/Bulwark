import 'dart:ui';

import 'package:bulwark/features/adoption/domain/wall_layout.dart';
import 'package:bulwark/features/adoption/presentation/wall_painter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('columnsFor', () {
    test('fits whole stones and never drops below one', () {
      expect(WallGeometry.columnsFor(288), 4); // 288 / 58 -> 4
      expect(WallGeometry.columnsFor(0), 1);
      expect(WallGeometry.columnsFor(30), 1); // narrower than one stone
    });
  });

  group('stones', () {
    test('maps placements to non-overlapping cells, course 0 on the bottom', () {
      final placements = const WallLayout().pack(
        graduatedCount: 5,
        activeCount: 0,
        erodedIds: const [],
        coursesWidth: 4,
      );
      const size = Size(400, 60); // 2 courses tall
      final stones = WallGeometry.stones(placements, size, 4);

      // Bottom-left stone (course 0, index 0) sits on the bottom course.
      final bottomLeft = stones.firstWhere(
          (s) => s.placement.course == 0 && s.placement.index == 0);
      expect(bottomLeft.cell, const Rect.fromLTWH(0, 30, 100, 30));

      // The 5th stone wraps to course 1, index 0 — above the bottom course.
      final wrapped = stones.firstWhere(
          (s) => s.placement.course == 1 && s.placement.index == 0);
      expect(wrapped.cell, const Rect.fromLTWH(0, 0, 100, 30));
    });
  });

  group('hitTest', () {
    final placements = const WallLayout().pack(
      graduatedCount: 3,
      activeCount: 0,
      erodedIds: const [],
      coursesWidth: 3,
    );
    const size = Size(300, 30);
    final stones = WallGeometry.stones(placements, size, 3);

    test('a point inside a cell returns that placement', () {
      final hit = WallGeometry.hitTest(stones, const Offset(150, 15)); // middle cell
      expect(hit, isNotNull);
      expect(hit!.index, 1);
      expect(hit.course, 0);
    });

    test('a point outside every cell returns null', () {
      expect(WallGeometry.hitTest(stones, const Offset(150, 100)), isNull);
    });
  });

  group('heightFor', () {
    test('is one course tall for an empty wall (never collapses)', () {
      expect(WallGeometry.heightFor(const [], 4), WallGeometry.courseHeight);
    });

    test('grows with course count', () {
      final placements = const WallLayout().pack(
        graduatedCount: 9,
        activeCount: 0,
        erodedIds: const [],
        coursesWidth: 4,
      );
      // 9 stones over 4 columns -> 3 courses.
      expect(WallGeometry.heightFor(placements, 4),
          3 * WallGeometry.courseHeight);
    });
  });
}
