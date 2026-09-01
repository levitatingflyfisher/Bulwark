// Destructive settings actions. Kept out of the widget so the erase path is a
// single, testable unit: wipe the tables, cancel reminders, refresh every
// keepAlive read model, then await the (now-null) profile so the router's
// redirect is ready to bounce back to onboarding before the caller navigates.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/features/adoption/domain/notification_planner.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/notifications/notification_providers.dart';

/// What "Erase all data" did.
enum EraseOutcome {
  /// A verified safety copy is in Previous backups; restoring it undoes the
  /// erase.
  erasedWithSafetyCopy,

  /// No recovery words, so no copy could be sealed; the person agreed in a
  /// dialog that said there is no way back.
  erasedNoCopy,

  /// The safety copy failed, so nothing was erased.
  keptBecauseSnapshotFailed,
}

/// The erase, behind sanctuary_backup_ui's pre-wipe snapshot: wipe only once
/// a verified copy of the current data is in the vault, never after the copy
/// failed. With no recovery words there is no copy to take, and the wipe goes
/// ahead only if the person was told so ([promisedCopy] false): someone who
/// agreed to an erase with a safety copy did not agree to one without.
Future<EraseOutcome> eraseAfterSnapshot({
  required Future<PreWipeSnapshot> Function() snapshot,
  required Future<void> Function() wipe,
  required bool promisedCopy,
}) async {
  final snap = await snapshot();
  switch (snap.outcome) {
    case PreWipeOutcome.taken:
      await wipe();
      return EraseOutcome.erasedWithSafetyCopy;
    case PreWipeOutcome.noKey:
      if (promisedCopy) return EraseOutcome.keptBecauseSnapshotFailed;
      await wipe();
      return EraseOutcome.erasedNoCopy;
    case PreWipeOutcome.failed:
      return EraseOutcome.keptBecauseSnapshotFailed;
  }
}

/// Erase every habit, check-in, pulse, shopping state, and the profile, then
/// cancel all reminders. Shell prefs (theme, reminders switch) survive. The
/// caller navigates to `/onboarding` once this resolves.
Future<void> eraseAllData(WidgetRef ref) async {
  await ref.read(appDatabaseProvider).eraseUserData();

  // Cancel all scheduled reminders (empty plan = cancelAll). Best-effort: a
  // notification-platform failure must not abort the wipe the user asked for.
  try {
    await ref.read(notificationServiceProvider).reschedule(const []);
  } catch (_) {}

  ref.invalidate(profileProvider);
  ref.invalidate(activeHabitsProvider);
  ref.invalidate(queuedHabitsProvider);
  ref.invalidate(graduatedHabitsProvider);
  ref.invalidate(habitStatesByIdProvider);
  ref.invalidate(shoppingStatesProvider);
  ref.invalidate(allCheckinsProvider);
  ref.invalidate(allPulsesProvider);
  ref.invalidate(todaysCheckinsProvider);
  ref.invalidate(pulseDueProvider);

  // Wait for the profile to resolve to null so the redirect holds still (it
  // only acts once the async has a value) when the caller pushes onboarding.
  await ref.read(profileProvider.future);
}

/// Mirrors [eraseAllData]'s provider-invalidation set, for the `Ref`-typed
/// hook `SanctuaryBackupConfig.onAfterRestore` runs after a destructive
/// encrypted-backup restore (SANCTUARY-BRIEF §4.W2). Not literally shared
/// with [eraseAllData]: that function is typed to `WidgetRef` (called from a
/// settings-screen `onTap`), which is a distinct type from the
/// `BackupController` Notifier's `Ref` — Riverpod gives them no common
/// supertype, so the invalidation list (and the reminder replan below) is
/// duplicated here rather than shared.
///
/// Unlike erase, a restore can *reintroduce* reminder-eligible habits, so
/// this recomputes the day's plan from the restored data instead of
/// rescheduling blank. Returns a [Future] (rather than firing-and-forgetting
/// internally, like [eraseAllData] does) so callers can await it directly in
/// tests; the production `onAfterRestore` wraps the call in `unawaited()`.
Future<void> afterBackupRestore(Ref ref) async {
  ref.invalidate(profileProvider);
  ref.invalidate(activeHabitsProvider);
  ref.invalidate(queuedHabitsProvider);
  ref.invalidate(graduatedHabitsProvider);
  ref.invalidate(habitStatesByIdProvider);
  ref.invalidate(shoppingStatesProvider);
  ref.invalidate(allCheckinsProvider);
  ref.invalidate(allPulsesProvider);
  ref.invalidate(todaysCheckinsProvider);
  ref.invalidate(pulseDueProvider);

  // Best-effort, mirroring eraseAllData's reschedule: a scheduling failure
  // must not surface to the user or undo the restore that already
  // succeeded.
  try {
    final service = ref.read(notificationServiceProvider);
    final prefs = await ref.read(settingsRepositoryProvider).getUserPrefs();
    final profile = await ref.read(profileProvider.future);
    if (!prefs.remindersEnabled || profile == null) {
      await service.reschedule(const []);
      return;
    }
    final library = await ref.read(contentLibraryProvider.future);
    final active =
        await ref.read(habitStateRepositoryProvider).activeStates();
    final planned = const NotificationPlanner()
        .plan(profile: profile, active: active, library: library);
    await service.reschedule(planned);
  } catch (_) {}
}
