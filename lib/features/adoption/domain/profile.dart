import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/library/domain/enums.dart' show Anchor;

/// The user's onboarding answers: daily anchor times, goal, pace, and the
/// display/behaviour flags. Persisted as the single row of the `Profile`
/// drift table. Immutable value object.
class Profile {
  final int wakeMinutes;
  final int bedMinutes;
  final int? breakfastMinutes;
  final int? lunchMinutes;
  final int? dinnerMinutes;
  final Goal goal;
  final Pace pace;

  /// Minutes-since-midnight for the optional daily check-in reminder; null
  /// means the user opted out of that reminder.
  final int? checkInMinutes;

  /// Minimum evidence strength the user wants surfaced, on [Evidence.strength]'s
  /// 0..3 scale (0 = show all, 3 = RCT-only).
  final int evidenceThreshold;

  final bool onboarded;
  final bool newParentMode;

  const Profile({
    required this.wakeMinutes,
    required this.bedMinutes,
    this.breakfastMinutes,
    this.lunchMinutes,
    this.dinnerMinutes,
    required this.goal,
    required this.pace,
    this.checkInMinutes,
    this.evidenceThreshold = 0,
    this.onboarded = false,
    this.newParentMode = false,
  });

  /// True for every anchor the profile can service. Meal anchors
  /// (breakfast/lunch/dinner) are gated on the matching `*Minutes` field being
  /// set; every non-meal anchor is always available.
  bool hasAnchor(Anchor anchor) => switch (anchor) {
        Anchor.breakfast => breakfastMinutes != null,
        Anchor.lunch => lunchMinutes != null,
        Anchor.dinner => dinnerMinutes != null,
        _ => true,
      };

  Profile copyWith({
    int? wakeMinutes,
    int? bedMinutes,
    int? breakfastMinutes,
    int? lunchMinutes,
    int? dinnerMinutes,
    Goal? goal,
    Pace? pace,
    int? checkInMinutes,
    int? evidenceThreshold,
    bool? onboarded,
    bool? newParentMode,
  }) =>
      Profile(
        wakeMinutes: wakeMinutes ?? this.wakeMinutes,
        bedMinutes: bedMinutes ?? this.bedMinutes,
        breakfastMinutes: breakfastMinutes ?? this.breakfastMinutes,
        lunchMinutes: lunchMinutes ?? this.lunchMinutes,
        dinnerMinutes: dinnerMinutes ?? this.dinnerMinutes,
        goal: goal ?? this.goal,
        pace: pace ?? this.pace,
        checkInMinutes: checkInMinutes ?? this.checkInMinutes,
        evidenceThreshold: evidenceThreshold ?? this.evidenceThreshold,
        onboarded: onboarded ?? this.onboarded,
        newParentMode: newParentMode ?? this.newParentMode,
      );

  @override
  bool operator ==(Object other) =>
      other is Profile &&
      other.wakeMinutes == wakeMinutes &&
      other.bedMinutes == bedMinutes &&
      other.breakfastMinutes == breakfastMinutes &&
      other.lunchMinutes == lunchMinutes &&
      other.dinnerMinutes == dinnerMinutes &&
      other.goal == goal &&
      other.pace == pace &&
      other.checkInMinutes == checkInMinutes &&
      other.evidenceThreshold == evidenceThreshold &&
      other.onboarded == onboarded &&
      other.newParentMode == newParentMode;

  @override
  int get hashCode => Object.hash(
        wakeMinutes,
        bedMinutes,
        breakfastMinutes,
        lunchMinutes,
        dinnerMinutes,
        goal,
        pace,
        checkInMinutes,
        evidenceThreshold,
        onboarded,
        newParentMode,
      );
}
