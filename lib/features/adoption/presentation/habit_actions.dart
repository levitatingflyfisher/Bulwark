// Write-side habit transitions shared by the Detail, Queue, Home, and Progress
// screens. Each persists a HabitState change, then refreshes the keepAlive read
// models the value screens watch (the invalidate-then-await pattern the core
// loop already uses). Advisory only — no gate is enforced here; screens decide
// when to call. A transition changes only the fields it owns and carries every
// other persisted field forward untouched (the row upsert overwrites all
// columns, so an omitted field would silently reset to its default).
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';

/// Activates [interventionId] now: status → active, `activatedAt` = now, and it
/// leaves the queue (`queuePosition` cleared). Every other field —
/// `triggerAnchorOverride`, `reminderEnabled`, `graduatedAt`, `createdAt` — is
/// carried forward from the existing row, so promoting a queued item or
/// repointing a graduated one does not discard the user's per-habit settings.
Future<void> activateHabit(WidgetRef ref, String interventionId) async {
  final repo = ref.read(habitStateRepositoryProvider);
  final existing = await repo.byInterventionId(interventionId);
  final now = DateTime.now();
  await repo.upsert(HabitState(
    interventionId: interventionId,
    status: HabitStatus.active,
    activatedAt: now,
    queuePosition: null,
    graduatedAt: existing?.graduatedAt,
    triggerAnchorOverride: existing?.triggerAnchorOverride,
    reminderEnabled: existing?.reminderEnabled ?? false,
    createdAt: existing?.createdAt ?? now,
  ));
  await _refresh(ref);
}

/// Appends [interventionId] to the end of the queue. Idempotent-ish: re-queuing
/// an already-queued item just rewrites it at a fresh tail position. Carries the
/// existing per-habit fields forward untouched.
Future<void> queueHabit(WidgetRef ref, String interventionId) async {
  final repo = ref.read(habitStateRepositoryProvider);
  final existing = await repo.byInterventionId(interventionId);
  final queued = await repo.byStatus(HabitStatus.queued);
  final maxPos = queued.fold<int>(
      -1, (m, s) => (s.queuePosition ?? -1) > m ? (s.queuePosition ?? -1) : m);
  final now = DateTime.now();
  await repo.upsert(HabitState(
    interventionId: interventionId,
    status: HabitStatus.queued,
    queuePosition: maxPos + 1,
    activatedAt: existing?.activatedAt,
    graduatedAt: existing?.graduatedAt,
    triggerAnchorOverride: existing?.triggerAnchorOverride,
    reminderEnabled: existing?.reminderEnabled ?? false,
    createdAt: existing?.createdAt ?? now,
  ));
  await _refresh(ref);
}

/// Graduates [interventionId]: status → graduated, `graduatedAt` = now. This is
/// the payoff of the adoption loop — the habit sets a stone on the wall and
/// starts owing a weekly maintenance pulse. Never automatic: a screen calls this
/// only after the user confirms. Every other field (`activatedAt`,
/// `triggerAnchorOverride`, `reminderEnabled`, `createdAt`) is preserved, so the
/// wall can still show when the habit was first taken up.
Future<void> graduateHabit(WidgetRef ref, String interventionId) async {
  final repo = ref.read(habitStateRepositoryProvider);
  final existing = await repo.byInterventionId(interventionId);
  final now = DateTime.now();
  await repo.upsert(HabitState(
    interventionId: interventionId,
    status: HabitStatus.graduated,
    graduatedAt: now,
    activatedAt: existing?.activatedAt,
    queuePosition: null,
    triggerAnchorOverride: existing?.triggerAnchorOverride,
    reminderEnabled: existing?.reminderEnabled ?? false,
    createdAt: existing?.createdAt ?? now,
  ));
  await _refresh(ref);
}

/// Reloads every habit-derived read model, then awaits the id-keyed map so the
/// caller can navigate knowing the new state is visible. Covers the full set a
/// status transition can move a habit between: the Today/Queue/Wall lists, the
/// id-keyed lookup, the pulse-due list a fresh graduation joins, and the
/// graduation-eligibility list a graduation drops out of.
Future<void> _refresh(WidgetRef ref) async {
  ref.invalidate(activeHabitsProvider);
  ref.invalidate(queuedHabitsProvider);
  ref.invalidate(graduatedHabitsProvider);
  ref.invalidate(habitStatesByIdProvider);
  ref.invalidate(pulseDueProvider);
  ref.invalidate(graduationEligibleProvider);
  await ref.read(habitStatesByIdProvider.future);
}
