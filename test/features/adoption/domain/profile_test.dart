import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/library/domain/enums.dart' show Anchor;
import 'package:flutter_test/flutter_test.dart';

Profile _profile({
  int? breakfastMinutes,
  int? lunchMinutes,
  int? dinnerMinutes,
  Pace pace = Pace.moderate,
}) =>
    Profile(
      wakeMinutes: 7 * 60,
      bedMinutes: 22 * 60,
      breakfastMinutes: breakfastMinutes,
      lunchMinutes: lunchMinutes,
      dinnerMinutes: dinnerMinutes,
      goal: Goal.general,
      pace: pace,
    );

void main() {
  group('Pace', () {
    test('minDaysBetween is 7/5/3 for conservative/moderate/aggressive', () {
      expect(Pace.conservative.minDaysBetween, 7);
      expect(Pace.moderate.minDaysBetween, 5);
      expect(Pace.aggressive.minDaysBetween, 3);
    });

    test('starterPackSize is 1/2/3 for conservative/moderate/aggressive', () {
      expect(Pace.conservative.starterPackSize, 1);
      expect(Pace.moderate.starterPackSize, 2);
      expect(Pace.aggressive.starterPackSize, 3);
    });
  });

  group('Profile.hasAnchor', () {
    test('every non-meal anchor is always available', () {
      final p = _profile();
      for (final anchor in Anchor.values) {
        if (anchor == Anchor.breakfast ||
            anchor == Anchor.lunch ||
            anchor == Anchor.dinner) {
          continue;
        }
        expect(p.hasAnchor(anchor), isTrue, reason: '$anchor should be available');
      }
    });

    test('a meal anchor is gated on its matching *Minutes field', () {
      final p = _profile(breakfastMinutes: 8 * 60); // only breakfast set
      expect(p.hasAnchor(Anchor.breakfast), isTrue);
      expect(p.hasAnchor(Anchor.lunch), isFalse);
      expect(p.hasAnchor(Anchor.dinner), isFalse);
    });

    test('all meal anchors available when all meal times are set', () {
      final p = _profile(
        breakfastMinutes: 8 * 60,
        lunchMinutes: 12 * 60,
        dinnerMinutes: 18 * 60,
      );
      expect(p.hasAnchor(Anchor.breakfast), isTrue);
      expect(p.hasAnchor(Anchor.lunch), isTrue);
      expect(p.hasAnchor(Anchor.dinner), isTrue);
    });
  });

  group('Profile value semantics', () {
    test('copyWith replaces only the named fields', () {
      final p = _profile(lunchMinutes: 12 * 60);
      final q = p.copyWith(onboarded: true, pace: Pace.aggressive);
      expect(q.onboarded, isTrue);
      expect(q.pace, Pace.aggressive);
      expect(q.lunchMinutes, p.lunchMinutes);
      expect(q.wakeMinutes, p.wakeMinutes);
      expect(q.goal, p.goal);
    });

    test('equality is by value', () {
      expect(_profile(), _profile());
      expect(_profile().hashCode, _profile().hashCode);
      expect(_profile(pace: Pace.aggressive), isNot(_profile()));
    });
  });
}
