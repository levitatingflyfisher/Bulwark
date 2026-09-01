// Write-side habit transitions shared by the Detail, Queue, Home, and Progress
// screens. Each persists a HabitState change, then refreshes the keepAlive read
// models the value screens watch (the invalidate-then-await pattern the core
// loop already uses). Advisory only — no gate is enforced here; screens decide
// when to call. A transition changes only the fields it owns and carries every
// other persisted field forward untouched (the row upsert overwrites all
// columns, so an omitted field would silently reset to its default).
//
// Every transition returns the row it replaced (null when the habit had
// none), so a screen can offer Undo through [restoreHabitState].
//
// The work runs on [HabitActions], which lives as long as the app, not on the
// calling widget's WidgetRef. A transition often removes the widget that
// asked for it (graduation takes the card off Today, a new moment takes the
// nudge away), and an Undo is tapped long after; a disposed widget's ref
// throws. The top-level functions only look the service up, synchronously.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/domain/enums.dart' show Anchor;
import 'package:bulwark/features/notifications/notification_providers.dart';

/// The app-lived habit write service. Not autoDispose, so its [Ref] stays
/// valid for as long as the app runs.
final habitActionsProvider = Provider<HabitActions>(HabitActions.new);

/// Activates [interventionId] now: status → active, `activatedAt` = now, and it
/// leaves the queue (`queuePosition` cleared). Every other field —
/// `triggerAnchorOverride`, `reminderEnabled`, `graduatedAt`, `createdAt` — is
/// carried forward from the existing row, so promoting a queued item or
/// repointing a graduated one does not discard the user's per-habit settings.
Future<HabitState?> activateHabit(WidgetRef ref, String interventionId) =>
    ref.read(habitActionsProvider).activate(interventionId);

/// Appends [interventionId] to the end of the queue. Idempotent-ish: re-queuing
/// an already-queued item just rewrites it at a fresh tail position. Carries the
/// existing per-habit fields forward untouched.
Future<HabitState?> queueHabit(WidgetRef ref, String interventionId) =>
    ref.read(habitActionsProvider).queue(interventionId);

/// Graduates [interventionId]: status → graduated, `graduatedAt` = now. This is
/// the payoff of the adoption loop — the habit sets a stone on the wall and
/// starts owing a weekly maintenance pulse. Never automatic: a screen calls this
/// only after the user confirms. Every other field (`activatedAt`,
/// `triggerAnchorOverride`, `reminderEnabled`, `createdAt`) is preserved, so the
/// wall can still show when the habit was first taken up.
Future<HabitState?> graduateHabit(WidgetRef ref, String interventionId) =>
    ref.read(habitActionsProvider).graduate(interventionId);

/// Sets [interventionId] aside: status → paused. It leaves Today and the
/// check-in, keeps every field (activation date, anchor override, reminder),
/// and is one Activate away from active again. Nothing about it is deleted.
Future<HabitState?> setAsideHabit(WidgetRef ref, String interventionId) =>
    ref.read(habitActionsProvider).setAside(interventionId);

/// Hangs [interventionId] off a different moment ([anchor]; null restores
/// the content's own). Status and every other field are kept. Answers given
/// before now no longer count toward the "keeps forgetting" offer, and the
/// day's reminders are re-planned for the new moment.
Future<HabitState?> setTriggerAnchor(
        WidgetRef ref, String interventionId, Anchor? anchor) =>
    ref.read(habitActionsProvider).setTriggerAnchor(interventionId, anchor);

/// Waves off the "keeps forgetting" offer for [interventionId]: only forgets
/// after today can bring it back.
Future<void> ackForgotNudge(WidgetRef ref, String interventionId) =>
    ref.read(habitActionsProvider).ackForgotNudge(interventionId);

/// Undo for any transition above: writes [prior] back exactly, or removes
/// the row when the habit had none before. For an Undo bar, capture
/// `ref.read(habitActionsProvider)` when the change is made and call its
/// [HabitActions.restore] from the bar, so no widget's ref is needed later.
Future<void> restoreHabitState(
        WidgetRef ref, String interventionId, HabitState? prior) =>
    ref.read(habitActionsProvider).restore(interventionId, prior);

class HabitActions {
  HabitActions(this._ref);
  final Ref _ref;

  Future<HabitState?> activate(String interventionId) async {
    final repo = _ref.read(habitStateRepositoryProvider);
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
    await _refresh();
    return existing;
  }

  Future<HabitState?> queue(String interventionId) async {
    final repo = _ref.read(habitStateRepositoryProvider);
    final existing = await repo.byInterventionId(interventionId);
    final queued = await repo.byStatus(HabitStatus.queued);
    final maxPos = queued.fold<int>(-1,
        (m, s) => (s.queuePosition ?? -1) > m ? (s.queuePosition ?? -1) : m);
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
    await _refresh();
    return existing;
  }

  Future<HabitState?> graduate(String interventionId) async {
    final repo = _ref.read(habitStateRepositoryProvider);
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
    await _refresh();
    return existing;
  }

  Future<HabitState?> setAside(String interventionId) async {
    final repo = _ref.read(habitStateRepositoryProvider);
    final existing = await repo.byInterventionId(interventionId);
    if (existing == null) return null;
    await repo.upsert(HabitState(
      interventionId: interventionId,
      status: HabitStatus.paused,
      activatedAt: existing.activatedAt,
      queuePosition: null,
      graduatedAt: existing.graduatedAt,
      triggerAnchorOverride: existing.triggerAnchorOverride,
      reminderEnabled: existing.reminderEnabled,
      createdAt: existing.createdAt,
    ));
    await _refresh();
    return existing;
  }

  Future<HabitState?> setTriggerAnchor(
      String interventionId, Anchor? anchor) async {
    final repo = _ref.read(habitStateRepositoryProvider);
    final existing = await repo.byInterventionId(interventionId);
    if (existing == null) return null;
    await repo.upsert(HabitState(
      interventionId: interventionId,
      status: existing.status,
      queuePosition: existing.queuePosition,
      activatedAt: existing.activatedAt,
      graduatedAt: existing.graduatedAt,
      triggerAnchorOverride: anchor?.name,
      reminderEnabled: existing.reminderEnabled,
      createdAt: existing.createdAt,
    ));
    await _ref
        .read(nudgeRepositoryProvider)
        .ackForgot(interventionId, DateTime.now());
    await _refresh();
    return existing;
  }

  Future<void> ackForgotNudge(String interventionId) async {
    await _ref
        .read(nudgeRepositoryProvider)
        .ackForgot(interventionId, DateTime.now());
    _ref.invalidate(weakTriggerIdsProvider);
  }

  Future<void> restore(String interventionId, HabitState? prior) async {
    final repo = _ref.read(habitStateRepositoryProvider);
    if (prior == null) {
      await repo.delete(interventionId);
    } else {
      await repo.upsert(prior);
    }
    await _refresh();
  }

  /// Reloads every habit-derived read model, then awaits the id-keyed map so
  /// the caller can navigate knowing the new state is visible. Covers the full
  /// set a status transition can move a habit between: the Today/Queue/Wall
  /// lists, the id-keyed lookup, the pulse-due list a fresh graduation joins,
  /// the graduation-eligibility list a graduation drops out of, and the
  /// weak-trigger offers. Then re-plans the day's reminders: only active
  /// habits get one, so every transition changes the plan (a set-aside or
  /// graduated habit must stop reminding; an activated one must start).
  Future<void> _refresh() async {
    _ref.invalidate(activeHabitsProvider);
    _ref.invalidate(queuedHabitsProvider);
    _ref.invalidate(pausedHabitsProvider);
    _ref.invalidate(graduatedHabitsProvider);
    _ref.invalidate(habitStatesByIdProvider);
    _ref.invalidate(pulseDueProvider);
    _ref.invalidate(graduationEligibleProvider);
    _ref.invalidate(weakTriggerIdsProvider);
    await _ref.read(habitStatesByIdProvider.future);
    await rescheduleNotificationsFrom(_ref.read);
  }
}
