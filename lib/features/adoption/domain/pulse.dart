import 'package:bulwark/features/adoption/domain/enums.dart';

/// A graduated habit's weekly maintenance pulse. [weekStart] is the date-only
/// first day of the pulse week; at most one pulse exists per
/// (interventionId, weekStart) — enforced by the drift unique key. Immutable.
class Pulse {
  final String interventionId;
  final DateTime weekStart;
  final PulseResult result;

  const Pulse({
    required this.interventionId,
    required this.weekStart,
    required this.result,
  });

  @override
  bool operator ==(Object other) =>
      other is Pulse &&
      other.interventionId == interventionId &&
      other.weekStart == weekStart &&
      other.result == result;

  @override
  int get hashCode => Object.hash(interventionId, weekStart, result);
}
