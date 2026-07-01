import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/erosion_check.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:flutter_test/flutter_test.dart';

const _check = ErosionCheck();
final _w1 = DateTime(2026, 5, 4); // Mondays, one week apart
final _w2 = DateTime(2026, 5, 11);
final _w3 = DateTime(2026, 5, 18);

Pulse _p(String id, DateTime week, PulseResult r) =>
    Pulse(interventionId: id, weekStart: week, result: r);

void main() {
  test('two consecutive shaky weeks erode', () {
    final eroded = _check.erodedIds([
      _p('a', _w1, PulseResult.shaky),
      _p('a', _w2, PulseResult.shaky),
    ]);
    expect(eroded, ['a']);
  });

  test('shaky, solid, shaky is not consecutive → no erosion', () {
    final eroded = _check.erodedIds([
      _p('a', _w1, PulseResult.shaky),
      _p('a', _w2, PulseResult.solid),
      _p('a', _w3, PulseResult.shaky),
    ]);
    expect(eroded, isEmpty);
  });

  test('two shaky weeks with a missing week between are not consecutive', () {
    final eroded = _check.erodedIds([
      _p('a', _w1, PulseResult.shaky),
      _p('a', _w3, PulseResult.shaky), // _w2 skipped → 14 days apart
    ]);
    expect(eroded, isEmpty);
  });

  test('input order does not matter', () {
    final eroded = _check.erodedIds([
      _p('a', _w2, PulseResult.shaky),
      _p('a', _w1, PulseResult.shaky),
    ]);
    expect(eroded, ['a']);
  });

  test('reports per intervention and is sorted', () {
    final eroded = _check.erodedIds([
      _p('b', _w1, PulseResult.shaky),
      _p('b', _w2, PulseResult.shaky),
      _p('a', _w1, PulseResult.shaky),
      _p('a', _w2, PulseResult.shaky),
      _p('c', _w1, PulseResult.shaky),
      _p('c', _w2, PulseResult.solid), // only one shaky → fine
    ]);
    expect(eroded, ['a', 'b']);
  });

  test('an empty pulse list erodes nothing', () {
    expect(_check.erodedIds(const []), isEmpty);
  });

  test('two shaky weeks straddling US spring-forward still erode (DST-safe)', () {
    // 2026-03-08 is the US spring-forward. These two Mondays are one calendar
    // week apart, but a naive difference.inDays over the local midnights
    // truncates 167h to 6 in a DST zone and misses the erosion.
    final eroded = _check.erodedIds([
      _p('a', DateTime(2026, 3, 2), PulseResult.shaky),
      _p('a', DateTime(2026, 3, 9), PulseResult.shaky),
    ]);
    expect(eroded, ['a']);
  });
}
