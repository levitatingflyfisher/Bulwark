import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/promotion_gate.dart';
import 'package:flutter_test/flutter_test.dart';

const _gate = PromotionGate();
final _now = DateTime(2026, 3, 1, 12);

HabitState _active(String id, {DateTime? activatedAt}) => HabitState(
      interventionId: id,
      status: HabitStatus.active,
      activatedAt: activatedAt,
      createdAt: DateTime(2026, 1, 1),
    );

Checkin _ci(String id, DateTime date, CheckinResult r) =>
    Checkin(interventionId: id, date: date, result: r);

PromotionVerdict _verdict({
  List<HabitState> states = const [],
  List<Checkin> checkins = const [],
  Pace pace = Pace.moderate,
}) =>
    _gate.evaluate(now: _now, states: states, checkins: checkins, pace: pace);

void main() {
  group('tooSoon boundary (moderate = 5 days)', () {
    test('exactly minDaysBetween since last activation is advisable', () {
      final v = _verdict(
        states: [_active('a', activatedAt: _now.subtract(const Duration(days: 5)))],
      );
      expect(v.reasons, isNot(contains(GateReason.tooSoon)));
      expect(v.advisable, isTrue);
    });

    test('one day short is tooSoon', () {
      final v = _verdict(
        states: [_active('a', activatedAt: _now.subtract(const Duration(days: 4)))],
      );
      expect(v.reasons, contains(GateReason.tooSoon));
      expect(v.advisable, isFalse);
    });

    test('uses the most-recent activation, not the oldest', () {
      final v = _verdict(states: [
        _active('a', activatedAt: _now.subtract(const Duration(days: 40))),
        _active('b', activatedAt: _now.subtract(const Duration(days: 2))),
      ]);
      expect(v.reasons, contains(GateReason.tooSoon));
    });

    test('no activated habit yet is never tooSoon', () {
      final v = _verdict(states: [_active('a')]); // activatedAt null
      expect(v.reasons, isNot(contains(GateReason.tooSoon)));
    });

    test('counts calendar days, not wall-clock, across an evening activation', () {
      // Activated 2026-03-15 20:00, evaluated 2026-03-20 12:00: five calendar
      // days elapsed, so a moderate pace (5) is advisable. A wall-clock
      // difference is 4d16h → truncates to 4 and wrongly reads tooSoon.
      final v = _gate.evaluate(
        now: DateTime(2026, 3, 20, 12),
        states: [
          HabitState(
            interventionId: 'a',
            status: HabitStatus.active,
            activatedAt: DateTime(2026, 3, 15, 20),
            createdAt: DateTime(2026, 1, 1),
          ),
        ],
        checkins: const [],
        pace: Pace.moderate,
      );
      expect(v.reasons, isNot(contains(GateReason.tooSoon)));
      expect(v.advisable, isTrue);
    });
  });

  group('capReached boundary (10 active)', () {
    test('nine active is under the cap', () {
      final states = [
        for (var i = 0; i < 9; i++)
          _active('a$i', activatedAt: _now.subtract(const Duration(days: 30))),
      ];
      expect(_verdict(states: states).reasons, isNot(contains(GateReason.capReached)));
    });

    test('ten active reaches the cap', () {
      final states = [
        for (var i = 0; i < 10; i++)
          _active('a$i', activatedAt: _now.subtract(const Duration(days: 30))),
      ];
      expect(_verdict(states: states).reasons, contains(GateReason.capReached));
    });
  });

  group('unsteady boundary (did-rate < 0.5 over 7 days, >=3 check-ins)', () {
    List<Checkin> mix(String id, int did, int miss) => [
          for (var i = 0; i < did; i++)
            _ci(id, _now.subtract(Duration(days: i)), CheckinResult.did),
          for (var i = 0; i < miss; i++)
            _ci(id, _now.subtract(Duration(days: did + i)), CheckinResult.forgot),
        ];

    test('did-rate exactly 0.5 is steady', () {
      final v = _verdict(
        states: [_active('a', activatedAt: _now.subtract(const Duration(days: 30)))],
        checkins: mix('a', 2, 2), // 2/4 = 0.5
      );
      expect(v.reasons, isNot(contains(GateReason.unsteady)));
    });

    test('did-rate below 0.5 is unsteady', () {
      final v = _verdict(
        states: [_active('a', activatedAt: _now.subtract(const Duration(days: 30)))],
        checkins: mix('a', 1, 2), // 1/3 ≈ 0.33
      );
      expect(v.reasons, contains(GateReason.unsteady));
    });

    test('fewer than three check-ins is never unsteady', () {
      final v = _verdict(
        states: [_active('a', activatedAt: _now.subtract(const Duration(days: 30)))],
        checkins: mix('a', 0, 2), // 0/2, but sample too small
      );
      expect(v.reasons, isNot(contains(GateReason.unsteady)));
    });

    test('old misses outside the 7-day window do not count', () {
      final v = _verdict(
        states: [_active('a', activatedAt: _now.subtract(const Duration(days: 30)))],
        checkins: [
          for (var i = 0; i < 5; i++)
            _ci('a', _now.subtract(Duration(days: 20 + i)), CheckinResult.forgot),
        ],
      );
      expect(v.reasons, isNot(contains(GateReason.unsteady)));
    });
  });

  test('a clean slate is advisable with no reasons', () {
    expect(_verdict().advisable, isTrue);
    expect(_verdict().reasons, isEmpty);
  });

  test('never throws even on empty inputs', () {
    expect(() => _verdict(), returnsNormally);
  });
}
