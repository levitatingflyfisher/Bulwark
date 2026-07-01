import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';

/// Finds graduated habits that have weathered: two *consecutive* shaky weekly
/// pulses. Pure and deterministic — returns the offending interventionIds
/// sorted. Consecutive means the two shaky pulses are exactly one week apart,
/// so a skipped (unrecorded) week does not chain two distant shaky weeks.
class ErosionCheck {
  const ErosionCheck();

  List<String> erodedIds(List<Pulse> pulses) {
    final byId = <String, List<Pulse>>{};
    for (final p in pulses) {
      byId.putIfAbsent(p.interventionId, () => []).add(p);
    }

    final eroded = <String>[];
    for (final entry in byId.entries) {
      final sorted = entry.value.toList()
        ..sort((a, b) => a.weekStart.compareTo(b.weekStart));
      for (var i = 0; i + 1 < sorted.length; i++) {
        final a = sorted[i];
        final b = sorted[i + 1];
        // Calendar-week gap, DST-safe: a naive difference.inDays truncates
        // 167h to 6 across a daylight-saving transition and would miss the
        // second shaky week.
        final consecutive = daysBetweenDates(a.weekStart, b.weekStart) == 7;
        if (consecutive &&
            a.result == PulseResult.shaky &&
            b.result == PulseResult.shaky) {
          eroded.add(entry.key);
          break;
        }
      }
    }

    eroded.sort();
    return eroded;
  }
}
