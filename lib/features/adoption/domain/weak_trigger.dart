import 'package:bulwark/features/adoption/domain/adherence_stats.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';

/// Finds habits whose moment is not working: "Forgot" is kept apart from
/// "Skipped" precisely because a run of forgets says the cue is wrong, not
/// the person. The answer this enables is an offer to hang the habit off a
/// different moment, never a scolding. Pure, clock passed in.
class WeakTriggerCheck {
  const WeakTriggerCheck();

  /// How far back to look.
  static const window = Duration(days: 14);

  /// Fewer forgets than this is not a pattern yet.
  static const minForgets = 3;

  /// Forgets must be at least this share of the answers in the window, so a
  /// few misses among many did-its do not count.
  static const minForgotRate = 1 / 3;

  /// The ids with a weak trigger. [since] holds, per habit, when its moment
  /// was last changed or the offer last waved off: answers before that do
  /// not count, so the offer does not come straight back.
  Set<String> weakIds(
    List<Checkin> checkins, {
    required DateTime now,
    Map<String, DateTime> since = const {},
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final from = today.subtract(window);
    final tally = <String, WeekAdherence>{};
    for (final c in checkins) {
      if (c.date.isBefore(from)) continue;
      final after = since[c.interventionId];
      if (after != null && !c.date.isAfter(after)) continue;
      tally[c.interventionId] =
          (tally[c.interventionId] ?? const WeekAdherence()).plus(c.result);
    }
    return {
      for (final e in tally.entries)
        if (e.value.forgot >= minForgets &&
            e.value.forgotRate >= minForgotRate)
          e.key,
    };
  }
}

/// The moment a habit actually hangs off: the person's override when it names
/// a real moment, otherwise the content's own anchor.
Anchor effectiveAnchor(HabitState? state, Intervention intervention) {
  final override = state?.triggerAnchorOverride;
  if (override != null) {
    for (final a in Anchor.values) {
      if (a.name == override) return a;
    }
  }
  return intervention.trigger.anchor;
}

/// The moments offered when re-anchoring a habit: the ones a day map or a
/// daily routine can name. (As-needed, weekly and "its own time" are not
/// daily moments; stress and "through the day" are not moments at all.)
const reanchorMoments = [
  Anchor.wake,
  Anchor.morning,
  Anchor.breakfast,
  Anchor.midday,
  Anchor.lunch,
  Anchor.dinner,
  Anchor.postMeal,
  Anchor.evening,
  Anchor.brushing,
  Anchor.shower,
  Anchor.bed,
];

/// Only an active habit is checked in daily, so only it can have a weak
/// trigger worth offering to fix.
bool canHaveWeakTrigger(HabitState s) => s.status == HabitStatus.active;
