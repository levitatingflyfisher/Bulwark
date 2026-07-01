import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/starter_pack_selector.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/content_builders.dart';

const _selector = StarterPackSelector();

Profile _profile({
  Goal goal = Goal.general,
  Pace pace = Pace.moderate,
  int? lunchMinutes,
}) =>
    Profile(
      wakeMinutes: 7 * 60,
      bedMinutes: 22 * 60,
      lunchMinutes: lunchMinutes,
      goal: goal,
      pace: pace,
    );

void main() {
  test('returns exactly pace.starterPackSize items', () {
    final library = libraryOf([
      for (var i = 0; i < 6; i++) intervention(id: 'i$i'),
    ]);
    expect(_selector.select(_profile(pace: Pace.conservative), library),
        hasLength(1));
    expect(_selector.select(_profile(pace: Pace.moderate), library),
        hasLength(2));
    expect(_selector.select(_profile(pace: Pace.aggressive), library),
        hasLength(3));
  });

  test('is deterministic across repeated calls', () {
    final library = libraryOf([
      intervention(id: 'b', category: Category.sleep),
      intervention(id: 'a', category: Category.sleep),
      intervention(id: 'c', category: Category.nutrition),
      intervention(id: 'd', category: Category.stress, defaultPhase: 2),
    ]);
    final profile = _profile(goal: Goal.sleep, pace: Pace.aggressive);
    final first = _selector.select(profile, library).map((i) => i.id).toList();
    final second = _selector.select(profile, library).map((i) => i.id).toList();
    expect(first, second);
  });

  test('excludes non-free, over-10-minute, and asNeeded items', () {
    final library = libraryOf([
      intervention(id: 'free-ok'),
      intervention(id: 'paid', costTier: CostTier.oneTimeUnder50),
      intervention(id: 'slow', timeCostMinutes: 11),
      intervention(id: 'reference', anchor: Anchor.asNeeded),
    ]);
    final picked = _selector
        .select(_profile(pace: Pace.aggressive), library)
        .map((i) => i.id)
        .toSet();
    expect(picked, {'free-ok'});
  });

  test('a 10-minute item is included; 11 is excluded (boundary: timeCost <= 10)',
      () {
    final library = libraryOf([
      intervention(id: 'ten-min', timeCostMinutes: 10),
      intervention(id: 'eleven-min', timeCostMinutes: 11),
    ]);
    final picked = _selector
        .select(_profile(pace: Pace.aggressive), library)
        .map((i) => i.id)
        .toSet();
    expect(picked, contains('ten-min'));
    expect(picked, isNot(contains('eleven-min')));
  });

  test('does not pick a lunch-anchored item when the profile has no lunch', () {
    final library = libraryOf([
      intervention(id: 'lunch-item', anchor: Anchor.lunch),
      intervention(id: 'wake-item', anchor: Anchor.wake),
    ]);
    final picked = _selector
        .select(_profile(pace: Pace.moderate), library) // no lunchMinutes
        .map((i) => i.id)
        .toSet();
    expect(picked, isNot(contains('lunch-item')));
    expect(picked, contains('wake-item'));
  });

  test('picks it once a lunch time exists', () {
    final library = libraryOf([
      intervention(id: 'lunch-item', anchor: Anchor.lunch),
    ]);
    final picked = _selector
        .select(_profile(pace: Pace.conservative, lunchMinutes: 12 * 60), library)
        .map((i) => i.id)
        .toSet();
    expect(picked, {'lunch-item'});
  });

  test('goal affinity outranks a non-affinity item', () {
    final library = libraryOf([
      intervention(id: 'sleep-item', category: Category.sleep),
      intervention(id: 'dental-item', category: Category.dental),
    ]);
    final picked =
        _selector.select(_profile(goal: Goal.sleep, pace: Pace.conservative), library);
    expect(picked.single.id, 'sleep-item');
  });

  test('ties break deterministically by (defaultPhase, id)', () {
    final library = libraryOf([
      // all same category → equal affinity; phase then id decide
      intervention(id: 'z', category: Category.sleep, defaultPhase: 1),
      intervention(id: 'a', category: Category.sleep, defaultPhase: 1),
      intervention(id: 'm', category: Category.sleep, defaultPhase: 2),
    ]);
    final picked = _selector
        .select(_profile(goal: Goal.sleep, pace: Pace.aggressive), library)
        .map((i) => i.id)
        .toList();
    expect(picked, ['a', 'z', 'm']);
  });
}
