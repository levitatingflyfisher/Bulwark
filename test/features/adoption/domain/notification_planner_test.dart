import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/content_builders.dart';

const _planner = NotificationPlanner();

Profile _profile({
  int wakeMinutes = 7 * 60, // 07:00
  int bedMinutes = 22 * 60, // 22:00 → quiet window [22:00, 07:00)
  int? breakfastMinutes = 8 * 60,
  int? lunchMinutes = 12 * 60,
  int? dinnerMinutes = 18 * 60,
  int? checkInMinutes,
}) =>
    Profile(
      wakeMinutes: wakeMinutes,
      bedMinutes: bedMinutes,
      breakfastMinutes: breakfastMinutes,
      lunchMinutes: lunchMinutes,
      dinnerMinutes: dinnerMinutes,
      goal: Goal.general,
      pace: Pace.moderate,
      checkInMinutes: checkInMinutes,
    );

HabitState _habit(String id, {String? override}) => HabitState(
      interventionId: id,
      status: HabitStatus.active,
      triggerAnchorOverride: override,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  test('all morning-anchored habits batch into one morning notification', () {
    final library = libraryOf([
      intervention(id: 'a', anchor: Anchor.wake),
      intervention(id: 'b', anchor: Anchor.morning),
      intervention(id: 'c', anchor: Anchor.wake),
    ]);
    final plan = _planner.plan(
      profile: _profile(),
      active: [_habit('a'), _habit('b'), _habit('c')],
      library: library,
    );
    final morning = plan.where((n) => n.id == 'batch-morning').toList();
    expect(morning, hasLength(1));
    expect(morning.single.minutesSinceMidnight, 7 * 60);
    for (final title in ['a', 'b', 'c']) {
      expect(morning.single.body, contains(title));
    }
    expect(plan, hasLength(1)); // nothing else scheduled
  });

  test('all evening/bed-anchored habits batch into one evening notification',
      () {
    final library = libraryOf([
      intervention(id: 'a', anchor: Anchor.evening),
      intervention(id: 'b', anchor: Anchor.bed),
    ]);
    final plan = _planner.plan(
      profile: _profile(),
      active: [_habit('a'), _habit('b')],
      library: library,
    );
    final evening = plan.where((n) => n.id == 'batch-evening').toList();
    expect(evening, hasLength(1));
    expect(evening.single.minutesSinceMidnight, lessThan(22 * 60));
  });

  test('never schedules more than five notifications a day', () {
    final library = libraryOf([
      for (var i = 0; i < 8; i++) intervention(id: 'b$i', anchor: Anchor.breakfast),
    ]);
    final plan = _planner.plan(
      profile: _profile(),
      active: [for (var i = 0; i < 8; i++) _habit('b$i')],
      library: library,
    );
    expect(plan.length, lessThanOrEqualTo(5));
    expect(plan, hasLength(5));
  });

  test('includes the check-in reminder when checkInMinutes is set', () {
    final plan = _planner.plan(
      profile: _profile(checkInMinutes: 20 * 60),
      active: const [],
      library: libraryOf(const []),
    );
    expect(plan.where((n) => n.id == 'checkin'), hasLength(1));
  });

  test('omits the check-in reminder when checkInMinutes is null', () {
    final plan = _planner.plan(
      profile: _profile(checkInMinutes: null),
      active: const [],
      library: libraryOf(const []),
    );
    expect(plan.where((n) => n.id == 'checkin'), isEmpty);
  });

  group('quiet window [22:00, 07:00) wraps midnight', () {
    test('a check-in at 02:00 (after midnight) is dropped', () {
      final plan = _planner.plan(
        profile: _profile(checkInMinutes: 2 * 60),
        active: const [],
        library: libraryOf(const []),
      );
      expect(plan, isEmpty);
    });

    test('a check-in at 23:30 (before midnight) is dropped', () {
      final plan = _planner.plan(
        profile: _profile(checkInMinutes: 23 * 60 + 30),
        active: const [],
        library: libraryOf(const []),
      );
      expect(plan, isEmpty);
    });

    test('a check-in at 10:00 (inside waking hours) survives', () {
      final plan = _planner.plan(
        profile: _profile(checkInMinutes: 10 * 60),
        active: const [],
        library: libraryOf(const []),
      );
      expect(plan.where((n) => n.id == 'checkin'), hasLength(1));
    });
  });

  test('non-clock anchors (brushing, hourly, custom) schedule nothing', () {
    final library = libraryOf([
      intervention(id: 'a', anchor: Anchor.brushing),
      intervention(id: 'b', anchor: Anchor.hourly),
      intervention(id: 'c', anchor: Anchor.custom),
    ]);
    final plan = _planner.plan(
      profile: _profile(),
      active: [_habit('a'), _habit('b'), _habit('c')],
      library: library,
    );
    expect(plan, isEmpty);
  });

  test('a trigger-anchor override re-buckets the habit', () {
    final library = libraryOf([intervention(id: 'a', anchor: Anchor.custom)]);
    final plan = _planner.plan(
      profile: _profile(),
      active: [_habit('a', override: 'wake')],
      library: library,
    );
    expect(plan.where((n) => n.id == 'batch-morning'), hasLength(1));
  });

  test('an after-midnight bedtime wraps the evening cue instead of going negative',
      () {
    // bed 00:30 → lead of 60 would put the cue at -30; it must wrap to 23:30.
    final library = libraryOf([intervention(id: 'a', anchor: Anchor.bed)]);
    final plan = _planner.plan(
      profile: _profile(bedMinutes: 30, wakeMinutes: 7 * 60),
      active: [_habit('a')],
      library: library,
    );
    final evening = plan.where((n) => n.id == 'batch-evening').toList();
    expect(evening, hasLength(1));
    expect(evening.single.minutesSinceMidnight, 1410); // 23:30, not -30
  });

  test('a timed cue at exactly bedMinutes is in the quiet window and dropped', () {
    final plan = _planner.plan(
      profile: _profile(checkInMinutes: 22 * 60), // == bed
      active: const [],
      library: libraryOf(const []),
    );
    expect(plan.where((n) => n.id == 'checkin'), isEmpty);
  });

  test('a timed cue at exactly wakeMinutes is outside quiet and kept', () {
    final plan = _planner.plan(
      profile: _profile(checkInMinutes: 7 * 60), // == wake
      active: const [],
      library: libraryOf(const []),
    );
    expect(plan.where((n) => n.id == 'checkin'), hasLength(1));
  });

  test('results are ordered by time of day', () {
    final library = libraryOf([
      intervention(id: 'm', anchor: Anchor.wake),
      intervention(id: 'd', anchor: Anchor.dinner),
    ]);
    final plan = _planner.plan(
      profile: _profile(checkInMinutes: 12 * 60),
      active: [_habit('m'), _habit('d')],
      library: library,
    );
    final minutes = plan.map((n) => n.minutesSinceMidnight).toList();
    final sorted = [...minutes]..sort();
    expect(minutes, sorted);
  });
}
