// Presentation-layer wiring for the adoption feature: the five state
// repositories built over the shared drift database, plus the derived read
// models the core-loop screens (Today, Check-in) watch. All read models are
// one-shot Futures (never drift `.watch()` streams) so widget tests don't trip
// the pending-timer teardown that query streams schedule; screens refresh them
// explicitly after a write.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/data/pulse_repository.dart';
import 'package:bulwark/features/adoption/data/shopping_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/graduation_detector.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/domain/shopping_state.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';

part 'providers.g.dart';

/// Pairs a habit's persisted [state] with its shipped [intervention] content,
/// so a screen has both in hand. Named for its first user (the Today list) but
/// reused for any state+content pairing — queued, graduated, or active.
/// Immutable.
class ActiveHabit {
  final HabitState state;
  final Intervention intervention;

  const ActiveHabit({required this.state, required this.intervention});

  String get interventionId => intervention.id;
}

// ─── Repositories over the shared drift database ────────────────────────────

@riverpod
HabitStateRepository habitStateRepository(Ref ref) =>
    HabitStateRepository(ref.watch(appDatabaseProvider));

@riverpod
CheckinRepository checkinRepository(Ref ref) =>
    CheckinRepository(ref.watch(appDatabaseProvider));

@riverpod
PulseRepository pulseRepository(Ref ref) =>
    PulseRepository(ref.watch(appDatabaseProvider));

@riverpod
ShoppingRepository shoppingRepository(Ref ref) =>
    ShoppingRepository(ref.watch(appDatabaseProvider));

@riverpod
ProfileRepository profileRepository(Ref ref) =>
    ProfileRepository(ref.watch(appDatabaseProvider));

// ─── Derived read models ────────────────────────────────────────────────────

/// The single onboarding [Profile], or null when no row exists yet (a fresh,
/// un-onboarded install). keepAlive so the router's redirect and the screens
/// share one cached value; onboarding refreshes it on completion.
@Riverpod(keepAlive: true)
Future<Profile?> profile(Ref ref) =>
    ref.watch(profileRepositoryProvider).get();

/// Active habits joined to their shipped content, ordered by activation then id
/// so the Today list is stable. A missing content id (a retired intervention a
/// stale row still references) is skipped rather than crashing.
@Riverpod(keepAlive: true)
Future<List<ActiveHabit>> activeHabits(Ref ref) async {
  final library = await ref.watch(contentLibraryProvider.future);
  final states = await ref.watch(habitStateRepositoryProvider).activeStates();

  final habits = <ActiveHabit>[];
  for (final s in states) {
    final intervention = library.byIdOrNull(s.interventionId);
    if (intervention != null) {
      habits.add(ActiveHabit(state: s, intervention: intervention));
    }
  }
  habits.sort((a, b) {
    final at = a.state.activatedAt ?? a.state.createdAt;
    final bt = b.state.activatedAt ?? b.state.createdAt;
    final byTime = at.compareTo(bt);
    return byTime != 0 ? byTime : a.interventionId.compareTo(b.interventionId);
  });
  return habits;
}

/// Today's check-ins (date-only), the Check-in screen's prefill source.
// DEFER (documented, not fixed): `today` is captured once at build time and the
// value is keepAlive, so an app left open across midnight prefills against
// yesterday until something invalidates this provider. Minor staleness only
// (the write path still keys off the real current date); a date-tick refresh
// belongs with a broader "day rollover" pass.
@Riverpod(keepAlive: true)
Future<List<Checkin>> todaysCheckins(Ref ref) async {
  final today = DateTime.now().dateOnly;
  final since = await ref.watch(checkinRepositoryProvider).since(today);
  return since.where((c) => c.date == today).toList();
}

/// Graduated habits still owed a maintenance pulse this ISO week — the rows the
/// Check-in screen surfaces as solid/shaky. Empty for a fresh user (nothing has
/// graduated yet); once a pulse is logged for the week the habit drops out.
@Riverpod(keepAlive: true)
Future<List<ActiveHabit>> pulseDue(Ref ref) async {
  final library = await ref.watch(contentLibraryProvider.future);
  final states =
      await ref.watch(habitStateRepositoryProvider).byStatus(HabitStatus.graduated);
  final pulses = await ref.watch(pulseRepositoryProvider).getAll();

  final weekStart = DateTime.now().startOfWeek;
  final loggedThisWeek = pulses
      .where((p) => p.weekStart == weekStart)
      .map((p) => p.interventionId)
      .toSet();

  final due = <ActiveHabit>[];
  for (final s in states) {
    if (loggedThisWeek.contains(s.interventionId)) continue;
    final intervention = library.byIdOrNull(s.interventionId);
    if (intervention != null) {
      due.add(ActiveHabit(state: s, intervention: intervention));
    }
  }
  due.sort((a, b) => a.interventionId.compareTo(b.interventionId));
  return due;
}

/// Queued habits joined to their shipped content, in queue order (position, then
/// id for stability). A queued row referencing missing content is skipped.
@Riverpod(keepAlive: true)
Future<List<ActiveHabit>> queuedHabits(Ref ref) async {
  final library = await ref.watch(contentLibraryProvider.future);
  final states =
      await ref.watch(habitStateRepositoryProvider).byStatus(HabitStatus.queued);

  final habits = <ActiveHabit>[];
  for (final s in states) {
    final intervention = library.byIdOrNull(s.interventionId);
    if (intervention != null) {
      habits.add(ActiveHabit(state: s, intervention: intervention));
    }
  }
  habits.sort((a, b) {
    const unranked = 1 << 30;
    final byPos = (a.state.queuePosition ?? unranked)
        .compareTo(b.state.queuePosition ?? unranked);
    return byPos != 0 ? byPos : a.interventionId.compareTo(b.interventionId);
  });
  return habits;
}

/// Graduated habits joined to their shipped content, oldest-graduated first so
/// the wall lays stones in the order they were set. A missing content id is
/// skipped.
@Riverpod(keepAlive: true)
Future<List<ActiveHabit>> graduatedHabits(Ref ref) async {
  final library = await ref.watch(contentLibraryProvider.future);
  final states = await ref
      .watch(habitStateRepositoryProvider)
      .byStatus(HabitStatus.graduated);

  final habits = <ActiveHabit>[];
  for (final s in states) {
    final intervention = library.byIdOrNull(s.interventionId);
    if (intervention != null) {
      habits.add(ActiveHabit(state: s, intervention: intervention));
    }
  }
  habits.sort((a, b) {
    final at = a.state.graduatedAt ?? a.state.createdAt;
    final bt = b.state.graduatedAt ?? b.state.createdAt;
    final byTime = at.compareTo(bt);
    return byTime != 0 ? byTime : a.interventionId.compareTo(b.interventionId);
  });
  return habits;
}

/// Every persisted habit state keyed by interventionId — the Detail screen's
/// lookup for whether an intervention is already queued/active/graduated.
@Riverpod(keepAlive: true)
Future<Map<String, HabitState>> habitStatesById(Ref ref) async {
  final states = await ref.watch(habitStateRepositoryProvider).getAll();
  return {for (final s in states) s.interventionId: s};
}

/// Purchase state keyed by interventionId — the Shopping screen's checkbox
/// source.
@Riverpod(keepAlive: true)
Future<Map<String, ShoppingState>> shoppingStates(Ref ref) async {
  final states = await ref.watch(shoppingRepositoryProvider).getAll();
  return {for (final s in states) s.interventionId: s};
}

/// All check-ins ever recorded — the Progress screen's weekly-adherence input.
@Riverpod(keepAlive: true)
Future<List<Checkin>> allCheckins(Ref ref) =>
    ref.watch(checkinRepositoryProvider).getAll();

/// All weekly pulses ever recorded — the erosion check's input on Progress.
@Riverpod(keepAlive: true)
Future<List<Pulse>> allPulses(Ref ref) =>
    ref.watch(pulseRepositoryProvider).getAll();

/// The active habits the [GraduationDetector] judges automatic (≥21 days active,
/// ≥80% "did" over the trailing window). These are the ones Home offers to set
/// into the wall — never automatically; the user confirms. Built from the
/// already-loaded active list and every check-in, so no extra query is issued.
/// [now] is captured at build time; a status transition invalidates this list,
/// so a graduated habit drops off it immediately.
@Riverpod(keepAlive: true)
Future<List<ActiveHabit>> graduationEligible(Ref ref) async {
  final active = await ref.watch(activeHabitsProvider.future);
  final checkins = await ref.watch(allCheckinsProvider.future);

  final byHabit = <String, List<Checkin>>{};
  for (final c in checkins) {
    byHabit.putIfAbsent(c.interventionId, () => []).add(c);
  }

  const detector = GraduationDetector();
  final now = DateTime.now();
  return active
      .where((h) => detector.detect(
            h.state,
            byHabit[h.interventionId] ?? const [],
            now: now,
          ))
      .toList();
}
