/// How a stone in the wall renders.
enum StoneKind {
  /// A graduated, healthy habit — a stone that is set.
  set,

  /// An active habit — an outlined stone being set on the top course.
  forming,

  /// A graduated habit that has eroded — a cracked, clay-tinted stone.
  weathered,
}

/// One stone's position in the drystone wall. [course] counts up from the
/// bottom (0), [index] runs left→right within a course.
class StonePlacement {
  final int course;
  final int index;
  final StoneKind kind;

  const StonePlacement({
    required this.course,
    required this.index,
    required this.kind,
  });
}

/// Packs the signature wall for the Progress screen. Pure and deterministic:
/// graduated habits are laid bottom-up into courses (the last few weathered if
/// eroded), then active habits continue as forming stones on the top course.
/// The wall never shrinks — active stones only ever add above the graduated
/// ones.
class WallLayout {
  const WallLayout();

  List<StonePlacement> pack({
    required int graduatedCount,
    required int activeCount,
    required List<String> erodedIds,
    required int coursesWidth,
  }) {
    final width = coursesWidth < 1 ? 1 : coursesWidth;
    // Only graduated stones can weather; clamp erosion to the graduated count.
    final weatheredCount =
        erodedIds.length > graduatedCount ? graduatedCount : erodedIds.length;
    final firstWeathered = graduatedCount - weatheredCount;

    final stones = <StonePlacement>[];
    for (var i = 0; i < graduatedCount; i++) {
      stones.add(StonePlacement(
        course: i ~/ width,
        index: i % width,
        kind: i >= firstWeathered ? StoneKind.weathered : StoneKind.set,
      ));
    }
    for (var j = 0; j < activeCount; j++) {
      final pos = graduatedCount + j;
      stones.add(StonePlacement(
        course: pos ~/ width,
        index: pos % width,
        kind: StoneKind.forming,
      ));
    }
    return stones;
  }
}
