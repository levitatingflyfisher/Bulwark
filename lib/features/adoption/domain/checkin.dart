import 'package:bulwark/features/adoption/domain/enums.dart';

/// One day's self-report for an active habit. [date] is date-only (midnight);
/// at most one check-in exists per (interventionId, date) — enforced by the
/// drift unique key. Immutable.
class Checkin {
  final String interventionId;
  final DateTime date;
  final CheckinResult result;
  final String? note;

  const Checkin({
    required this.interventionId,
    required this.date,
    required this.result,
    this.note,
  });

  @override
  bool operator ==(Object other) =>
      other is Checkin &&
      other.interventionId == interventionId &&
      other.date == date &&
      other.result == result &&
      other.note == note;

  @override
  int get hashCode => Object.hash(interventionId, date, result, note);
}
