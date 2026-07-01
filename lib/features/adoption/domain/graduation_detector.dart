import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';

/// Detects when an active habit has become automatic and can be suggested for
/// graduation. Pure; suggestion only — the user confirms "this is automatic
/// now". [now] is injectable so the rule is testable.
class GraduationDetector {
  const GraduationDetector();

  /// Days a habit must have been active before it can graduate.
  static const int minActiveDays = 21;

  /// The trailing window the did-rate is measured over.
  static const int windowDays = 14;

  /// Minimum check-ins in the window so a one-off "did" cannot graduate a
  /// habit.
  static const int minSample = 7;

  /// Required share of "did" check-ins in the window.
  static const double minDidRate = 0.8;

  bool detect(HabitState state, List<Checkin> checkins, {DateTime? now}) {
    if (state.status != HabitStatus.active) return false;
    final activatedAt = state.activatedAt;
    if (activatedAt == null) return false;

    final at = now ?? DateTime.now();
    // Calendar days, not wall-clock: 21 days after an evening activation is
    // reached even though the raw elapsed time is a few hours short of 21×24h.
    if (daysBetweenDates(activatedAt, at) < minActiveDays) return false;

    final windowStart = at.subtract(const Duration(days: windowDays));
    final window = checkins.where((c) =>
        c.interventionId == state.interventionId &&
        !c.date.isBefore(windowStart) &&
        !c.date.isAfter(at));

    final total = window.length;
    if (total < minSample) return false;

    final did = window.where((c) => c.result == CheckinResult.did).length;
    return did / total >= minDidRate;
  }
}
