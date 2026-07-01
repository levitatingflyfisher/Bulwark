import 'package:bulwark/features/adoption/domain/enums.dart';

/// Per-intervention adoption state: where a habit sits in the queue→active→
/// graduated lifecycle, plus the timestamps and per-habit overrides the engine
/// and UI need. Keyed by [interventionId] (the shipped content id). Immutable.
class HabitState {
  final String interventionId;
  final HabitStatus status;

  /// Rank within the queue while [status] is [HabitStatus.queued]; null once
  /// the habit leaves the queue.
  final int? queuePosition;

  final DateTime? activatedAt;
  final DateTime? graduatedAt;

  /// Overrides the intervention's default trigger anchor (`.name`) when the
  /// user re-anchors a habit; null keeps the content default.
  final String? triggerAnchorOverride;

  final bool reminderEnabled;
  final DateTime createdAt;

  const HabitState({
    required this.interventionId,
    required this.status,
    this.queuePosition,
    this.activatedAt,
    this.graduatedAt,
    this.triggerAnchorOverride,
    this.reminderEnabled = false,
    required this.createdAt,
  });

  HabitState copyWith({
    HabitStatus? status,
    int? queuePosition,
    DateTime? activatedAt,
    DateTime? graduatedAt,
    String? triggerAnchorOverride,
    bool? reminderEnabled,
  }) =>
      HabitState(
        interventionId: interventionId,
        status: status ?? this.status,
        queuePosition: queuePosition ?? this.queuePosition,
        activatedAt: activatedAt ?? this.activatedAt,
        graduatedAt: graduatedAt ?? this.graduatedAt,
        triggerAnchorOverride:
            triggerAnchorOverride ?? this.triggerAnchorOverride,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        createdAt: createdAt,
      );

  @override
  bool operator ==(Object other) =>
      other is HabitState &&
      other.interventionId == interventionId &&
      other.status == status &&
      other.queuePosition == queuePosition &&
      other.activatedAt == activatedAt &&
      other.graduatedAt == graduatedAt &&
      other.triggerAnchorOverride == triggerAnchorOverride &&
      other.reminderEnabled == reminderEnabled &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(
        interventionId,
        status,
        queuePosition,
        activatedAt,
        graduatedAt,
        triggerAnchorOverride,
        reminderEnabled,
        createdAt,
      );
}
