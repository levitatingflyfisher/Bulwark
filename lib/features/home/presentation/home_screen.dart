import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/shared/theme/app_colors.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/theme_pill.dart';

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

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulwark'),
        centerTitle: false,
        actions: const [
          _NavMenu(),
          Padding(padding: EdgeInsets.only(right: 8), child: ThemePill()),
        ],
      ),
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _ErrorBody(error: e),
        data: (habits) => habits.isEmpty
            ? const _EmptyBody()
            : _TodayBody(
                habits: habits,
                profile: profile,
                eligibleIds: eligibleIds,
              ),
      ),
    );
  }
}

/// The Home hub: a compact overflow menu to the value screens. Home is the one
/// always-reachable surface, so the routes to Library/Queue/Shopping/Progress
/// and Settings hang off it.
class _NavMenu extends StatelessWidget {
  const _NavMenu();

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      icon: const Icon(LucideIcons.menu),
      tooltip: 'Menu',
      onSelected: (route) => context.push(route),
      itemBuilder: (_) => const [
        PopupMenuItem(value: '/library', child: Text('Library')),
        PopupMenuItem(value: '/queue', child: Text('Queue')),
        PopupMenuItem(value: '/shopping', child: Text('Shopping')),
        PopupMenuItem(value: '/progress', child: Text('Progress')),
        PopupMenuItem(value: '/settings', child: Text('Settings')),
      ],
    );
  }
}

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.habits,
    required this.profile,
    required this.eligibleIds,
  });

  final List<ActiveHabit> habits;
  final Profile? profile;
  final Set<String> eligibleIds;

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
              if (nextUp != null) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(LucideIcons.arrowRight,
                          size: 16, color: AppColors.stone),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        'Next up: $nextUp',
                        style:
                            text.labelMedium?.copyWith(color: AppColors.stone),
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
      final m = anchorMinutes(h.intervention.trigger.anchor);
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
  const _HabitCard(
      {super.key, required this.habit, this.graduationEligible = false});

  final ActiveHabit habit;
  final bool graduationEligible;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final Intervention i = habit.intervention;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(LucideIcons.anchor,
                      size: 14, color: AppColors.stone),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    i.trigger.note,
                    style: text.bodySmall?.copyWith(color: AppColors.stone),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              i.mechanism,
              style: text.bodySmall?.copyWith(color: AppColors.stone),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            EvidenceTag(i.evidence),
            if (graduationEligible)
              _GraduationNudge(
                interventionId: habit.interventionId,
                title: i.title,
              ),
          ],
        ),
      ),
    );
  }
}

/// A quiet, dismissible affordance offered on an active habit the detector
/// judges automatic. It is a reward, never a prod: the user either sets the
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
    try {
      await graduateHabit(ref, widget.interventionId);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${widget.title} is set into your wall.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.lichen.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(LucideIcons.sparkles,
                    size: 16, color: AppColors.lichen),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  'This looks automatic now — set it into your wall?',
                  style: text.bodySmall?.copyWith(color: AppColors.ink),
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
                  foregroundColor: AppColors.lichen,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  minimumSize: const Size(0, 36),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Set it into my wall'),
              ),
              TextButton(
                onPressed:
                    _busy ? null : () => setState(() => _dismissed = true),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.stone,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
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
              style: text.labelSmall?.copyWith(color: AppColors.stone),
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
            Text(
              'Your wall starts with one stone.',
              style: text.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add a habit from the Library.',
              style: text.bodyLarge?.copyWith(color: AppColors.stone),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              onPressed: () => context.push('/library'),
              child: const Text('Browse the Library'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBody extends StatelessWidget {
  const _ErrorBody({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text('Something went wrong.\n$error',
            textAlign: TextAlign.center),
      ),
    );
  }
}
