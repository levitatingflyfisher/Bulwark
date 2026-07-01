import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/adherence_stats.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/erosion_check.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/domain/wall_layout.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/wall_painter.dart';
import 'package:bulwark/shared/theme/app_colors.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';

/// The signature Progress screen: the drystone wall (a stone per graduated
/// habit), a weekly adherence trend, and the "made automatic" list. No streaks,
/// no per-habit shaming — the wall never shrinks; stones weather, they don't
/// vanish.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final graduatedAsync = ref.watch(graduatedHabitsProvider);
    final activeAsync = ref.watch(activeHabitsProvider);
    final pulses = ref.watch(allPulsesProvider).valueOrNull ?? const <Pulse>[];
    final checkins =
        ref.watch(allCheckinsProvider).valueOrNull ?? const <Checkin>[];

    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: (graduatedAsync.isLoading || activeAsync.isLoading)
          ? const Center(child: CircularProgressIndicator())
          : _ProgressBody(
              graduated: graduatedAsync.valueOrNull ?? const [],
              activeCount: (activeAsync.valueOrNull ?? const []).length,
              pulses: pulses,
              checkins: checkins,
            ),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  const _ProgressBody({
    required this.graduated,
    required this.activeCount,
    required this.pulses,
    required this.checkins,
  });

  final List<ActiveHabit> graduated;
  final int activeCount;
  final List<Pulse> pulses;
  final List<Checkin> checkins;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;

    // Which graduated habits have eroded (2 consecutive shaky weeks), intersected
    // with the *current* graduated set — pulses persist, so raw erosion output
    // can name a habit that is no longer graduated.
    final graduatedIds = {for (final g in graduated) g.interventionId};
    final erodedSet = const ErosionCheck()
        .erodedIds(pulses)
        .where(graduatedIds.contains)
        .toSet();

    // Order graduated stones non-eroded first, eroded last, so WallLayout's
    // last-N weathering aligns stone→habit with the eroded set.
    final ordered = [
      ...graduated.where((g) => !erodedSet.contains(g.interventionId)),
      ...graduated.where((g) => erodedSet.contains(g.interventionId)),
    ];
    final erodedIds =
        ordered.where((g) => erodedSet.contains(g.interventionId)).map((g) => g.interventionId).toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Your wall', style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          graduated.isEmpty
              ? 'Every habit you make automatic sets a stone. None yet — keep '
                  'checking in.'
              : 'One stone for every habit you have made automatic. Tap a stone '
                  'to see which.',
          style: text.bodySmall?.copyWith(color: AppColors.stone),
        ),
        const SizedBox(height: AppSpacing.md),
        _Wall(
          ordered: ordered,
          activeCount: activeCount,
          erodedIds: erodedIds,
          erodedSet: erodedSet,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Weekly adherence', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        _AdherenceTrend(checkins: checkins),
        const SizedBox(height: AppSpacing.lg),
        Text('Made automatic', style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        if (graduated.isEmpty)
          Text(
            'Nothing here yet. A habit becomes automatic after a few steady '
            'weeks — Bulwark will suggest it when it is ready.',
            style: text.bodySmall?.copyWith(color: AppColors.stone),
          )
        else
          for (final g in graduated.reversed)
            _GraduatedRow(
              habit: g,
              eroded: erodedSet.contains(g.interventionId),
              onRepoint: () => _repoint(context, ref, g),
            ),
      ],
    );
  }

  Future<void> _repoint(
      BuildContext context, WidgetRef ref, ActiveHabit habit) async {
    await activateHabit(ref, habit.interventionId);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('${habit.intervention.title} is active again.')),
    );
  }
}

/// The tappable wall. Column count, packing, and hit-testing all derive from the
/// same [LayoutBuilder] width so drawing and taps never disagree.
class _Wall extends ConsumerWidget {
  const _Wall({
    required this.ordered,
    required this.activeCount,
    required this.erodedIds,
    required this.erodedSet,
  });

  final List<ActiveHabit> ordered;
  final int activeCount;
  final List<String> erodedIds;
  final Set<String> erodedSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = WallGeometry.columnsFor(constraints.maxWidth);
        final placements = const WallLayout().pack(
          graduatedCount: ordered.length,
          activeCount: activeCount,
          erodedIds: erodedIds,
          coursesWidth: columns,
        );
        final height = WallGeometry.heightFor(placements, columns);
        final size = Size(constraints.maxWidth, height);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (d) {
            final stones = WallGeometry.stones(placements, size, columns);
            final hit = WallGeometry.hitTest(stones, d.localPosition);
            if (hit == null) return;
            final globalIndex = hit.course * columns + hit.index;
            if (globalIndex < ordered.length) {
              _revealStone(context, ref, ordered[globalIndex],
                  erodedSet.contains(ordered[globalIndex].interventionId));
            }
          },
          child: CustomPaint(
            key: const Key('wall-canvas'),
            size: size,
            painter: WallPainter(placements: placements, columns: columns),
          ),
        );
      },
    );
  }

  void _revealStone(
      BuildContext context, WidgetRef ref, ActiveHabit habit, bool eroded) {
    final graduatedAt = habit.state.graduatedAt;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        final text = Theme.of(sheetContext).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(habit.intervention.title, style: text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  graduatedAt == null
                      ? 'Made automatic.'
                      : 'Made automatic on ${DateFormat.yMMMd().format(graduatedAt)}.',
                  style: text.bodyMedium?.copyWith(color: AppColors.stone),
                ),
                if (eroded) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('This one has felt shaky lately.',
                      style: text.bodySmall?.copyWith(color: AppColors.clay)),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await activateHabit(ref, habit.interventionId);
                    },
                    icon: const Icon(LucideIcons.wrench, size: 16),
                    label: const Text('Repoint (make it active again)'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A calm weekly did-rate trend — bars, weekly, no daily streak. Shows the most
/// recent weeks only so the row stays readable.
class _AdherenceTrend extends StatelessWidget {
  const _AdherenceTrend({required this.checkins});

  final List<Checkin> checkins;

  static const int _maxWeeks = 8;
  static const double _barMaxHeight = 72;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final rates = const AdherenceStats().weeklyDidRate(checkins);
    if (rates.isEmpty) {
      return Text(
        'Check in through the week and your adherence trend appears here.',
        style: text.bodySmall?.copyWith(color: AppColors.stone),
      );
    }
    final weeks = rates.keys.toList()..sort();
    final recent = weeks.length <= _maxWeeks
        ? weeks
        : weeks.sublist(weeks.length - _maxWeeks);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final week in recent)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // FittedBox so the % / date labels shrink to fit the narrow
                  // column at large text scales instead of wrapping into an
                  // illegible vertical stack of single digits.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('${(rates[week]! * 100).round()}%',
                        maxLines: 1,
                        softWrap: false,
                        style:
                            text.labelSmall?.copyWith(color: AppColors.stone)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (rates[week]! * _barMaxHeight).clamp(2.0, _barMaxHeight),
                    decoration: BoxDecoration(
                      color: AppColors.lichen.withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(DateFormat('M/d').format(week),
                        maxLines: 1,
                        softWrap: false,
                        style:
                            text.labelSmall?.copyWith(color: AppColors.stone)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _GraduatedRow extends StatelessWidget {
  const _GraduatedRow({
    required this.habit,
    required this.eroded,
    required this.onRepoint,
  });

  final ActiveHabit habit;
  final bool eroded;
  final VoidCallback onRepoint;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final graduatedAt = habit.state.graduatedAt;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    eroded ? LucideIcons.triangleAlert : LucideIcons.check,
                    size: 16,
                    color: eroded ? AppColors.clay : AppColors.lichen,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(habit.intervention.title,
                          style: text.titleSmall,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (graduatedAt != null)
                        Text(
                          'Automatic since ${DateFormat.yMMMd().format(graduatedAt)}',
                          style: text.bodySmall
                              ?.copyWith(color: AppColors.stone),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (eroded) ...[
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onRepoint,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.clay,
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(LucideIcons.wrench, size: 16),
                  label: const Text('Repoint'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
