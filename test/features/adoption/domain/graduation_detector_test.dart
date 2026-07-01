import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/graduation_detector.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:flutter_test/flutter_test.dart';

const _detector = GraduationDetector();
final _now = DateTime(2026, 4, 1, 12);

HabitState _active(String id, {required int daysActive}) => HabitState(
      interventionId: id,
      status: HabitStatus.active,
      activatedAt: _now.subtract(Duration(days: daysActive)),
      createdAt: DateTime(2026, 1, 1),
    );

/// [did] "did" then [miss] "forgot" check-ins, one per day counting back from
/// [from], all inside the 14-day window when [from] == _now.
List<Checkin> _checkins(String id, {required int did, required int miss}) => [
      for (var i = 0; i < did; i++)
        Checkin(
            interventionId: id,
            date: _now.subtract(Duration(days: i)),
            result: CheckinResult.did),
      for (var i = 0; i < miss; i++)
        Checkin(
            interventionId: id,
            date: _now.subtract(Duration(days: did + i)),
            result: CheckinResult.forgot),
    ];

void main() {
  test('graduates: >=21 days active and >=80% did over the last 14 days', () {
    final state = _active('a', daysActive: 30);
    final checkins = _checkins('a', did: 12, miss: 2); // 12/14 ≈ 0.857
    expect(_detector.detect(state, checkins, now: _now), isTrue);
  });

  test('does not graduate before 21 active days', () {
    final state = _active('a', daysActive: 20);
    final checkins = _checkins('a', did: 12, miss: 2);
    expect(_detector.detect(state, checkins, now: _now), isFalse);
  });

  test('does not graduate below the 0.8 did-rate', () {
    final state = _active('a', daysActive: 30);
    final checkins = _checkins('a', did: 10, miss: 4); // 10/14 ≈ 0.71
    expect(_detector.detect(state, checkins, now: _now), isFalse);
  });

  test('a 1/1 record does not graduate (sample too small)', () {
    final state = _active('a', daysActive: 30);
    final checkins = _checkins('a', did: 1, miss: 0);
    expect(_detector.detect(state, checkins, now: _now), isFalse);
  });

  test('exactly seven check-ins is a large enough sample', () {
    final state = _active('a', daysActive: 30);
    final checkins = _checkins('a', did: 7, miss: 0); // 7/7 = 1.0
    expect(_detector.detect(state, checkins, now: _now), isTrue);
  });

  test('old check-ins outside the 14-day window are ignored', () {
    final state = _active('a', daysActive: 60);
    final checkins = [
      for (var i = 0; i < 10; i++)
        Checkin(
            interventionId: 'a',
            date: _now.subtract(Duration(days: 20 + i)),
            result: CheckinResult.did),
    ];
    expect(_detector.detect(state, checkins, now: _now), isFalse);
  });

  test('a non-active habit never graduates', () {
    final state = HabitState(
      interventionId: 'a',
      status: HabitStatus.queued,
      createdAt: DateTime(2026, 1, 1),
    );
    expect(_detector.detect(state, _checkins('a', did: 12, miss: 2), now: _now),
        isFalse);
  });

  test('graduates at exactly 21 calendar days despite an evening activation', () {
    // Activated 2026-03-01 20:00, evaluated 2026-03-22 12:00 = 21 calendar
    // days. A wall-clock difference is 20d16h → truncates to 20 and misses
    // the >=21 gate; the calendar-day helper reads 21.
    final at = DateTime(2026, 3, 22, 12);
    final state = HabitState(
      interventionId: 'a',
      status: HabitStatus.active,
      activatedAt: DateTime(2026, 3, 1, 20),
      createdAt: DateTime(2026, 1, 1),
    );
    final checkins = [
      for (var i = 0; i < 8; i++)
        Checkin(
            interventionId: 'a',
            date: at.subtract(Duration(days: i)),
            result: CheckinResult.did),
      for (var i = 0; i < 2; i++)
        Checkin(
            interventionId: 'a',
            date: at.subtract(Duration(days: 8 + i)),
            result: CheckinResult.forgot),
    ];
    expect(_detector.detect(state, checkins, now: at), isTrue);
  });

  test('a did-rate of exactly 0.8 graduates (boundary)', () {
    final state = _active('a', daysActive: 30);
    final checkins = _checkins('a', did: 8, miss: 2); // 8/10 = 0.8
    expect(_detector.detect(state, checkins, now: _now), isTrue);
  });
}
