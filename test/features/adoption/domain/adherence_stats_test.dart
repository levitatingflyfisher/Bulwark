import 'package:bulwark/features/adoption/domain/adherence_stats.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

const _stats = AdherenceStats();

// The week of Mon 2026-05-04 .. Sun 2026-05-10.
final _mon = DateTime(2026, 5, 4);
final _thu = DateTime(2026, 5, 7);
final _sun = DateTime(2026, 5, 10);
final _nextMon = DateTime(2026, 5, 11);

Checkin _c(DateTime date, CheckinResult r, {String id = 'a'}) =>
    Checkin(interventionId: id, date: date, result: r);

void main() {
  test('weekly did-rate is did / (did + skipped + forgot)', () {
    final rates = _stats.weeklyDidRate([
      _c(_mon, CheckinResult.did),
      _c(_thu, CheckinResult.did),
      _c(_sun, CheckinResult.did),
      _c(DateTime(2026, 5, 5), CheckinResult.skipped),
      _c(DateTime(2026, 5, 6), CheckinResult.forgot),
    ]);
    expect(rates[_mon], closeTo(3 / 5, 1e-9));
  });

  test('a forgot counts as a miss in the denominator', () {
    final rates = _stats.weeklyDidRate([
      _c(_mon, CheckinResult.did),
      _c(_thu, CheckinResult.did),
      _c(DateTime(2026, 5, 5), CheckinResult.forgot),
      _c(DateTime(2026, 5, 6), CheckinResult.forgot),
    ]);
    expect(rates[_mon], closeTo(2 / 4, 1e-9));
  });

  test('check-ins group into their Monday-anchored week', () {
    final result = _stats.weekly([
      _c(_thu, CheckinResult.did), // week of _mon
      _c(_sun, CheckinResult.did), // still week of _mon
      _c(_nextMon, CheckinResult.forgot), // next week
    ]);
    expect(result.keys.toSet(), {_mon, _nextMon});
    expect(result[_mon]!.did, 2);
    expect(result[_nextMon]!.forgot, 1);
  });

  test('forgot is queryable separately from the did-rate', () {
    final week = _stats.weekly([
      _c(_mon, CheckinResult.did),
      _c(_thu, CheckinResult.skipped),
      _c(_sun, CheckinResult.forgot),
    ])[_mon]!;
    expect(week.did, 1);
    expect(week.skipped, 1);
    expect(week.forgot, 1);
    expect(week.total, 3);
    expect(week.forgotRate, closeTo(1 / 3, 1e-9));
    expect(week.didRate, closeTo(1 / 3, 1e-9));
  });

  test('empty check-ins yield an empty map', () {
    expect(_stats.weeklyDidRate(const []), isEmpty);
    expect(_stats.weekly(const []), isEmpty);
  });
}
