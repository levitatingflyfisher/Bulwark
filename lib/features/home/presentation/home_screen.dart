import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/presentation/content_labels.dart';
import 'package:bulwark/features/adoption/domain/weak_trigger.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/theme_toggle.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';

/// Today: the active habits as calm cards, a subtle next-up hint, and a
/// prominent Check-in. No streaks, no counts, no guilt — missed days are data,
/// not a broken chain.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    // The active habits the detector judges automatic — Home offers each a
    // quiet, dismissible "set it into your wall" nudge. Best-effort: a loading
    // or errored list simply shows no nudges.
    final eligibleIds = {
      for (final h in ref.watch(graduationEligibleProvider).valueOrNull ??
          const <ActiveHabit>[])
        h.interventionId,
    };
    // Habits whose moment keeps not working (a run of "Forgot"); Home offers
    // each a different moment. Best-effort like the graduation nudge.
    final weakIds = ref.watch(weakTriggerIdsProvider).valueOrNull ?? const {};
    // Day one teaches the loop until the first answer is logged (audit: "day
    // one teaches nothing"; first-run ruling: open into the task).
    final firstDay =
        ref.watch(allCheckinsProvider).valueOrNull?.isEmpty ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulwark'),
        centerTitle: false,
        // The fleet bar folds by space so "Bulwark" stays whole (it read
        // "B..." at 320 dp x 3.0).
        actions: const [
          OhBarActions(children: [_MoreMenu(), ThemeToggle()]),
        ],
      ),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: habitsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => OhErrorState.fromError(
            e,
            stackTrace: st,
            title: "Couldn’t load today’s habits",
            onRetry: () => ref.invalidate(activeHabitsProvider),
          ),
          data: (habits) => habits.isEmpty
              ? const _EmptyBody()
              : _TodayBody(
                  habits: habits,
                  profile: profile,
                  eligibleIds: eligibleIds,
                  weakIds: weakIds,
                  firstDay: firstDay,
                ),
        ),
      ),
    );
  }
}

/// Home's worded More menu: the two places that are not sections of their
/// own (Queue and Shopping). Today, Progress, Library and Settings are in
/// the persistent bottom bar.
class _MoreMenu extends StatelessWidget {
  const _MoreMenu();

  @override
  Widget build(BuildContext context) => OhBarOverflow<String>(
        onSelected: (route) => context.push(route),
        itemBuilder: (_) => const [
          PopupMenuItem(value: '/queue', child: Text('Queue')),
          PopupMenuItem(value: '/shopping', child: Text('Shopping')),
        ],
      );
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.habits,
    required this.profile,
    required this.eligibleIds,
    this.weakIds = const {},
    this.firstDay = false,
  });

  final List<ActiveHabit> habits;
  final Profile? profile;
  final Set<String> eligibleIds;
  final Set<String> weakIds;
  final bool firstDay;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final nextUp = _nextUpLabel(habits, profile);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            children: [
              // Unfinished backup setup stays in sight, dismissible, never a
              // gate (fleet first-run ruling); it scrolls with the day's
              // cards and draws nothing once backup is set up.
              const BackupSetupReminder(),
              if (firstDay) ...[
                Text(
                  'Your first day: do each habit when its moment comes. '
                  'Tonight, tap Check in and mark each one. That is the whole '
                  'daily job, and it takes under a minute.',
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              if (nextUp != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(LucideIcons.arrowRight,
                          size: 16,
                          color: BulwarkPalette.of(context).secondaryText),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Next up: $nextUp',
                        style: text.labelMedium?.copyWith(
                            color: BulwarkPalette.of(context).secondaryText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              for (final habit in habits)
                _HabitCard(
                  // Key by id so the per-card nudge's dismiss-state can't attach
                  // to a neighbour if the active list reorders.
                  key: ValueKey(habit.interventionId),
                  habit: habit,
                  graduationEligible:
                      eligibleIds.contains(habit.interventionId),
                  weakTrigger: weakIds.contains(habit.interventionId),
                ),
            ],
          ),
        ),
        const _CheckInBar(),
      ],
    );
  }

  /// One subtle line: the action of the habit whose anchor time comes soonest.
  /// Best-effort only — returns null if there's no profile or no clock-anchored
  /// habit to resolve, and never participates in a layout that could overflow.
  static String? _nextUpLabel(List<ActiveHabit> habits, Profile? profile) {
    if (profile == null) return null;
    final now = DateTime.now();
    final nowMinutes = now.hour * 60 + now.minute;

    int? anchorMinutes(Anchor anchor) => switch (anchor) {
          Anchor.wake => profile.wakeMinutes,
          Anchor.morning => profile.wakeMinutes + 30,
          Anchor.breakfast => profile.breakfastMinutes,
          Anchor.lunch => profile.lunchMinutes,
          Anchor.dinner => profile.dinnerMinutes,
          Anchor.evening => profile.bedMinutes - 120,
          Anchor.bed => profile.bedMinutes,
          _ => null,
        };

    ActiveHabit? best;
    int? bestDelta;
    for (final h in habits) {
      final m = anchorMinutes(effectiveAnchor(h.state, h.intervention));
      if (m == null) continue;
      final delta = (m - nowMinutes + 1440) % 1440; // minutes until, wrapping
      if (bestDelta == null || delta < bestDelta) {
        bestDelta = delta;
        best = h;
      }
    }
    return best?.intervention.action;
  }
}

class _HabitCard extends StatelessWidget {
  const _HabitCard({
    super.key,
    required this.habit,
    this.graduationEligible = false,
    this.weakTrigger = false,
  });

  final ActiveHabit habit;
  final bool graduationEligible;
  final bool weakTrigger;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Intervention i = habit.intervention;
    // Once the person has moved the habit to another moment, the content's
    // cue sentence describes the old one, so the card names the new moment.
    final moved = habit.state.triggerAnchorOverride != null &&
        effectiveAnchor(habit.state, i) != i.trigger.anchor;
    // The card opens the habit's detail, where the whole mechanism lives:
    // it cuts the WHY at two lines, as the Library rows that open the same
    // page do (audit top finding 7).
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
       onTap: () => context.push('/intervention/${habit.interventionId}'),
       child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(i.title, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(i.action, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.anchor,
                      size: 14,
                      color: BulwarkPalette.of(context).secondaryText),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    moved
                        ? anchorLabel(effectiveAnchor(habit.state, i))
                        : i.trigger.note,
                    style: text.bodySmall?.copyWith(
                        color: BulwarkPalette.of(context).secondaryText),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              i.mechanism,
              style: text.bodySmall
                  ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            EvidenceTag(i.evidence),
            if (weakTrigger)
              _MomentNudge(
                interventionId: habit.interventionId,
                title: i.title,
                current: effectiveAnchor(habit.state, i),
              ),
            if (graduationEligible)
              _GraduationNudge(
                interventionId: habit.interventionId,
                title: i.title,
              ),
          ],
        ),
       ),
      ),
    );
  }
}

/// Offered when a habit keeps being marked "Forgot": the moment may be the
/// problem, not the person, so it offers to hang the habit off another one
/// (audit writing-is-designing-09). Choosing one writes the override the
/// reminder planner already honours, with Undo; "Not now" waves it off until
/// new forgets arrive. Never a scolding, and no count shown as a score.
class _MomentNudge extends ConsumerWidget {
  const _MomentNudge({
    required this.interventionId,
    required this.title,
    required this.current,
  });

  final String interventionId;
  final String title;
  final Anchor current;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<Anchor>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
              child: Text('Hang $title off a different moment',
                  style: Theme.of(sheetContext).textTheme.titleMedium),
            ),
            for (final a in reanchorMoments)
              ListTile(
                title: Text(anchorLabel(a)),
                trailing: a == current ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(sheetContext).pop(a),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    final undo = ref.read(undoControllerProvider);
    final actions = ref.read(habitActionsProvider);
    final prior = await setTriggerAnchor(ref, interventionId, picked);
    undo.show(
      message: '$title now hangs off a new moment: '
          '${anchorLabel(picked).toLowerCase()}.',
      onUndo: () => actions.restore(interventionId, prior),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final palette = BulwarkPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.clay.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.clock, size: 16, color: palette.clay),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'You’ve marked this Forgot ${WeakTriggerCheck.minForgets} '
                  'times or more in two weeks. The moment may be the '
                  'problem, not you. Try a different one?',
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: () => _change(context, ref),
                style: TextButton.styleFrom(foregroundColor: palette.clay),
                child: const Text('Change the moment'),
              ),
              TextButton(
                onPressed: () => ackForgotNudge(ref, interventionId),
                style: TextButton.styleFrom(
                    foregroundColor: palette.secondaryText),
                child: const Text('Not now'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A quiet, dismissible affordance offered on an active habit the detector
/// judges automatic. It says what graduating frees up rather than dressing
/// it as a badge, and it is never a prod: the user either sets the
/// habit into their wall (an explicit confirm — graduation is never automatic)
/// or waves it off with "Not yet". Laid out to hold at 320 dp × 3.0× text —
/// the label wraps freely and the two actions Wrap onto their own lines rather
/// than overflowing.
class _GraduationNudge extends ConsumerStatefulWidget {
  const _GraduationNudge({required this.interventionId, required this.title});

  final String interventionId;
  final String title;

  @override
  ConsumerState<_GraduationNudge> createState() => _GraduationNudgeState();
}

class _GraduationNudgeState extends ConsumerState<_GraduationNudge> {
  bool _dismissed = false;
  bool _busy = false;

  Future<void> _graduate() async {
    if (_busy) return;
    setState(() => _busy = true);
    // Read before the await: graduating takes this card off Today.
    final undo = ref.read(undoControllerProvider);
    final actions = ref.read(habitActionsProvider);
    final id = widget.interventionId;
    try {
      final prior = await graduateHabit(ref, id);
      undo.show(
        // Say what the stone buys (audit badass-users-04): the habit leaves
        // the daily list and the promotion gate counts one fewer.
        message: '${widget.title} is set into your wall. One fewer daily '
            'check-in; a weekly check keeps it standing, and there is room '
            'for your next habit.',
        onUndo: () => actions.restore(id, prior),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: BulwarkPalette.of(context).lichen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.brickWall,
                    size: 16, color: BulwarkPalette.of(context).lichen),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'This looks automatic now. Set it into your wall? It leaves '
                  'your daily check-in for a weekly check, and frees a place '
                  'for the next habit.',
                  style: text.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                onPressed: _busy ? null : _graduate,
                style: TextButton.styleFrom(
                  foregroundColor: BulwarkPalette.of(context).lichen,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Set it into my wall'),
              ),
              TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _dismissed = true),
                style: TextButton.styleFrom(
                  foregroundColor: BulwarkPalette.of(context).secondaryText,
                  padding:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Not yet'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckInBar extends StatelessWidget {
  const _CheckInBar();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/checkin'),
                child: const Text('Check in'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Bulwark is habit-tracking with health education, not medical '
              'advice.',
              style: text.labelSmall
                  ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBody extends StatelessWidget {
  const _EmptyBody();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BackupSetupReminder(),
            Text(
              'Your wall starts with one stone.',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add a habit from the Library.',
              style: text.bodyLarge
                  ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => context.go('/library'),
              child: const Text('Browse the Library'),
            ),
          ],
        ),
      ),
    );
  }
}
