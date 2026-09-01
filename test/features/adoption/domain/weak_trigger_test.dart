import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/weak_trigger.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/content_builders.dart';

/// "Forgot" is kept apart from "Skipped" because a run of forgets says the
/// moment is wrong, not the person (enums.dart). This is the check that
/// finally reads it (audit writing-is-designing-09).
void main() {
  final now = DateTime(2026, 9, 27, 20);
  Checkin c(String id, int daysAgo, CheckinResult r) => Checkin(
      interventionId: id,
      date: DateTime(2026, 9, 27 - daysAgo),
      result: r);
  List<Checkin> run(String id, List<CheckinResult> newestFirst) => [
        for (var i = 0; i < newestFirst.length; i++) c(id, i, newestFirst[i])
      ];
  const f = CheckinResult.forgot, d = CheckinResult.did, s = CheckinResult.skipped;
  const check = WeakTriggerCheck();

  test('three forgets in two weeks, a third of the answers: weak', () {
    expect(check.weakIds(run('a', [f, d, f, d, f, d]), now: now), {'a'});
  });

  test('two forgets is not a pattern yet', () {
    expect(check.weakIds(run('a', [f, d, f, d]), now: now), isEmpty);
  });

  test('three forgets drowned in did-its is not a weak trigger', () {
    expect(
        check.weakIds(run('a', [f, d, d, f, d, d, f, d, d, d, d]), now: now),
        isEmpty);
  });

  test('skips are a choice, not a weak trigger', () {
    expect(check.weakIds(run('a', [s, s, s, s]), now: now), isEmpty);
  });

  test('forgets older than two weeks do not count', () {
    final old = [for (var i = 15; i < 20; i++) c('a', i, f)];
    expect(check.weakIds(old, now: now), isEmpty);
  });

  test('answers before the moment was last changed do not count', () {
    final history = run('a', [f, f, f, f]);
    expect(
        check.weakIds(history,
            now: now, since: {'a': DateTime(2026, 9, 26)}),
        isEmpty);
  });

  test('the effective moment is the override when set, else the content', () {
    final i = intervention(id: 'a', anchor: Anchor.wake);
    HabitState st(String? o) => HabitState(
        interventionId: 'a',
        status: HabitStatus.active,
        triggerAnchorOverride: o,
        createdAt: DateTime(2026));
    expect(effectiveAnchor(st(null), i), Anchor.wake);
    expect(effectiveAnchor(st('bed'), i), Anchor.bed);
    expect(effectiveAnchor(st('not-a-moment'), i), Anchor.wake);
    expect(effectiveAnchor(null, i), Anchor.wake);
  });
}
