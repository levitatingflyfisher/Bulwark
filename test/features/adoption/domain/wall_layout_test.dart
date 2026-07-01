import 'package:bulwark/features/adoption/domain/wall_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _wall = WallLayout();

List<StonePlacement> _layout({
  int graduatedCount = 0,
  int activeCount = 0,
  List<String> erodedIds = const [],
  int coursesWidth = 5,
}) =>
    _wall.pack(
      graduatedCount: graduatedCount,
      activeCount: activeCount,
      erodedIds: erodedIds,
      coursesWidth: coursesWidth,
    );

void main() {
  test('no stones yields an empty wall', () {
    expect(_layout(), isEmpty);
  });

  test('a single graduated habit is one set stone at course 0, index 0', () {
    final stones = _layout(graduatedCount: 1);
    expect(stones, hasLength(1));
    expect(stones.single.course, 0);
    expect(stones.single.index, 0);
    expect(stones.single.kind, StoneKind.set);
  });

  test('twelve graduated stones pack bottom-up across courses of width five',
      () {
    final stones = _layout(graduatedCount: 12);
    expect(stones, hasLength(12));
    // course 0: indices 0..4, course 1: 0..4, course 2: 0..1
    expect(stones[0].course, 0);
    expect(stones[0].index, 0);
    expect(stones[4].course, 0);
    expect(stones[4].index, 4);
    expect(stones[5].course, 1);
    expect(stones[5].index, 0);
    expect(stones[11].course, 2);
    expect(stones[11].index, 1);
    expect(stones.every((s) => s.kind == StoneKind.set), isTrue);
  });

  test('an eroded graduated habit renders as a weathered stone', () {
    final stones = _layout(graduatedCount: 3, erodedIds: ['x']);
    final weathered = stones.where((s) => s.kind == StoneKind.weathered);
    final set = stones.where((s) => s.kind == StoneKind.set);
    expect(weathered, hasLength(1));
    expect(set, hasLength(2));
  });

  test('active habits render as forming stones above the graduated ones', () {
    // width 3: graduated fill course 0 indices 0,1; forming continue from there.
    final stones = _layout(graduatedCount: 2, activeCount: 3, coursesWidth: 3);
    final forming = stones.where((s) => s.kind == StoneKind.forming).toList();
    expect(forming, hasLength(3));
    expect(forming[0].course, 0);
    expect(forming[0].index, 2); // finishes the partial top course
    expect(forming[1].course, 1); // wraps to the next course up
    expect(forming[1].index, 0);
    expect(forming[2].course, 1);
    expect(forming[2].index, 1);
  });

  test('erosion beyond the graduated count is clamped', () {
    final stones = _layout(graduatedCount: 1, erodedIds: ['x', 'y', 'z']);
    expect(stones.where((s) => s.kind == StoneKind.weathered), hasLength(1));
  });

  test('is deterministic', () {
    final a = _layout(graduatedCount: 7, activeCount: 2, erodedIds: ['e']);
    final b = _layout(graduatedCount: 7, activeCount: 2, erodedIds: ['e']);
    expect(a.map((s) => '${s.course}:${s.index}:${s.kind}'),
        b.map((s) => '${s.course}:${s.index}:${s.kind}'));
  });
}
