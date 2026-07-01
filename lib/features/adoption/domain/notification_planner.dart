import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';

/// A single scheduled local notification. Pure data — the platform side turns
/// [minutesSinceMidnight] into an actual daily trigger (Android) or ignores it
/// (web no-op).
class PlannedNotification {
  final int minutesSinceMidnight;
  final String title;
  final String body;
  final String id;

  const PlannedNotification({
    required this.minutesSinceMidnight,
    required this.title,
    required this.body,
    required this.id,
  });
}

/// Plans the day's local notifications from the profile and active habits.
/// Pure: enforces at most [maxPerDay], batches all morning anchors into one
/// morning cue and all evening/bed anchors into one evening cue, drops anything
/// inside the quiet window, and adds the opt-in check-in reminder. Non-clock
/// anchors (brushing, hourly, custom, …) are ambient and schedule nothing.
class NotificationPlanner {
  const NotificationPlanner();

  static const int maxPerDay = 5;
  static const int _middayDefault = 13 * 60;
  static const int _eveningLeadMinutes = 60; // fire an hour before bed

  List<PlannedNotification> plan({
    required Profile profile,
    required List<HabitState> active,
    required ContentLibrary library,
  }) {
    final morningTitles = <String>[];
    final eveningTitles = <String>[];
    final timed = <PlannedNotification>[];

    for (final s in active) {
      if (s.status != HabitStatus.active) continue;
      final intervention = library.byIdOrNull(s.interventionId);
      if (intervention == null) continue;
      final anchor = _resolveAnchor(s, intervention);

      switch (anchor) {
        case Anchor.wake:
        case Anchor.morning:
          morningTitles.add(intervention.title);
        case Anchor.evening:
        case Anchor.bed:
          eveningTitles.add(intervention.title);
        case Anchor.breakfast:
          _addTimed(timed, profile.breakfastMinutes, intervention);
        case Anchor.lunch:
          _addTimed(timed, profile.lunchMinutes, intervention);
        case Anchor.midday:
          _addTimed(timed, profile.lunchMinutes ?? _middayDefault, intervention);
        case Anchor.dinner:
          _addTimed(timed, profile.dinnerMinutes, intervention);
        default:
          break; // ambient / non-clock anchor → no notification
      }
    }

    // Priority-ordered candidates: the batched cues and the check-in reminder
    // survive the daily cap before individually-timed habits do.
    final candidates = <PlannedNotification>[];
    if (morningTitles.isNotEmpty) {
      candidates.add(PlannedNotification(
        minutesSinceMidnight: profile.wakeMinutes,
        title: 'Morning habits',
        body: morningTitles.join(', '),
        id: 'batch-morning',
      ));
    }
    if (eveningTitles.isNotEmpty) {
      candidates.add(PlannedNotification(
        // Wrap around midnight so a bedtime under an hour past 00:00 yields a
        // valid late-evening minute (e.g. bed 00:30 → 23:30) rather than a
        // negative minutes-since-midnight.
        minutesSinceMidnight:
            (profile.bedMinutes - _eveningLeadMinutes + 1440) % 1440,
        title: 'Evening habits',
        body: eveningTitles.join(', '),
        id: 'batch-evening',
      ));
    }
    if (profile.checkInMinutes != null) {
      candidates.add(PlannedNotification(
        minutesSinceMidnight: profile.checkInMinutes!,
        title: 'Daily check-in',
        body: 'How did today go?',
        id: 'checkin',
      ));
    }

    timed.sort(_byTimeThenId);
    final ordered = [...candidates, ...timed]
        .where((n) =>
            !_inQuiet(n.minutesSinceMidnight, profile.bedMinutes, profile.wakeMinutes))
        .take(maxPerDay)
        .toList()
      ..sort(_byTimeThenId);
    return ordered;
  }

  void _addTimed(
      List<PlannedNotification> out, int? minute, Intervention i) {
    if (minute == null) return;
    out.add(PlannedNotification(
      minutesSinceMidnight: minute,
      title: i.title,
      body: i.trigger.note,
      id: 'habit-${i.id}',
    ));
  }

  Anchor _resolveAnchor(HabitState s, Intervention i) {
    final override = s.triggerAnchorOverride;
    if (override != null) {
      for (final a in Anchor.values) {
        if (a.name == override) return a;
      }
    }
    return i.trigger.anchor;
  }

  /// Quiet window is `[bed, wake)`; when bed is later in the day than wake the
  /// window wraps past midnight.
  static bool _inQuiet(int m, int bed, int wake) {
    if (bed == wake) return false;
    if (bed < wake) return m >= bed && m < wake;
    return m >= bed || m < wake;
  }

  static int _byTimeThenId(PlannedNotification a, PlannedNotification b) {
    final byTime = a.minutesSinceMidnight.compareTo(b.minutesSinceMidnight);
    return byTime != 0 ? byTime : a.id.compareTo(b.id);
  }
}
