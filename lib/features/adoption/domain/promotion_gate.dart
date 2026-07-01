import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';

/// Why the gate advises waiting before taking on another habit.
enum GateReason { tooSoon, capReached, unsteady }

/// The gate's read-only opinion. [advisable] is true exactly when [reasons] is
/// empty — the UI may always override.
class PromotionVerdict {
  final bool advisable;
  final List<GateReason> reasons;

  const PromotionVerdict({required this.advisable, required this.reasons});
}

/// Advises — never blocks — on whether now is a good time to activate another
/// habit. Pure; forgiveness over prevention (a Sundial value): it only reports.
class PromotionGate {
  const PromotionGate();

  /// The most active habits the gate will let ride comfortably before it starts
  /// advising a pause.
  static const int activeCap = 10;

  PromotionVerdict evaluate({
    required DateTime now,
    required List<HabitState> states,
    required List<Checkin> checkins,
    required Pace pace,
  }) {
    final reasons = <GateReason>[];
    final active =
        states.where((s) => s.status == HabitStatus.active).toList();

    // tooSoon: less than the pace's minimum gap since the most-recent
    // activation of any habit.
    final activations =
        states.map((s) => s.activatedAt).whereType<DateTime>().toList();
    if (activations.isNotEmpty) {
      final mostRecent = activations.reduce((a, b) => a.isAfter(b) ? a : b);
      // Compare calendar days, not wall-clock: an evening activation followed
      // by a midday evaluation is a full elapsed day even though < 24h passed.
      if (daysBetweenDates(mostRecent, now) < pace.minDaysBetween) {
        reasons.add(GateReason.tooSoon);
      }
    }

    // capReached: too many habits already in flight.
    if (active.length >= activeCap) {
      reasons.add(GateReason.capReached);
    }

    // unsteady: any active habit with a shaky recent record — at least three
    // check-ins in the last 7 days and fewer than half of them "did".
    final windowStart = now.subtract(const Duration(days: 7));
    final anyUnsteady = active.any((s) {
      final window = checkins.where((c) =>
          c.interventionId == s.interventionId &&
          !c.date.isBefore(windowStart) &&
          !c.date.isAfter(now));
      final total = window.length;
      if (total < 3) return false;
      final did = window.where((c) => c.result == CheckinResult.did).length;
      return did / total < 0.5;
    });
    if (anyUnsteady) {
      reasons.add(GateReason.unsteady);
    }

    return PromotionVerdict(advisable: reasons.isEmpty, reasons: reasons);
  }
}
