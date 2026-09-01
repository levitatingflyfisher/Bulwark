import 'package:flutter/material.dart';
import 'package:openhearth_design/openhearth_design.dart';
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
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/theme_toggle.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';

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
      appBar: AppBar(
        title: const Text('Progress'),
        actions: const [ThemeToggle()],
      ),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: (graduatedAsync.isLoading || activeAsync.isLoading)
            ? const Center(child: CircularProgressIndicator())
            : _ProgressBody(
                graduated: graduatedAsync.valueOrNull ?? const [],
                active: activeAsync.valueOrNull ?? const [],
                pulses: pulses,
                checkins: checkins,
              ),
      ),
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  const _ProgressBody({
    required this.graduated,
    required this.active,
    required this.pulses,
    required this.checkins,
  });

  final List<ActiveHabit> graduated;
  final List<ActiveHabit> active;
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
    final erodedIds = ordered
        .where((g) => erodedSet.contains(g.interventionId))
        .map((g) => g.interventionId)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text('Your wall', style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          // The same counts WallLayout.pack draws from, so the words and the
          // stones can't disagree.
          wallCaption(set: graduated.length, forming: active.length),
          style: text.bodySmall
              ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
        ),
        const SizedBox(height: AppSpacing.md),
        _Wall(
          ordered: ordered,
          forming: active,
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
            'weeks, and Bulwark will suggest it when it is ready.',
            style: text.bodySmall
                ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
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
          BuildContext context, WidgetRef ref, ActiveHabit habit) =>
      repointHabit(ref, habit);
}

/// The line under "Your wall", built from the same two counts the wall is
/// drawn from: [set] graduated stones (set or weathered) and [forming]
/// outlined ones for active habits.
String wallCaption({required int set, required int forming}) {
  if (set == 0 && forming == 0) {
    return 'No stones yet. Activate a habit and its outline appears here; it '
        'sets when the habit becomes automatic.';
  }
  if (set == 0) {
    return forming == 1
        ? '1 outlined stone: the habit you are working on now. None is set '
            'yet; it sets when the habit becomes automatic.'
        : '$forming outlined stones: the habits you are working on now. None '
            'is set yet; each sets when its habit becomes automatic.';
  }
  final setWords = set == 1 ? '1 stone set' : '$set stones set';
  if (forming == 0) {
    return '$setWords, one for each habit you have made automatic. Tap a '
        'stone to see which.';
  }
  return '$setWords and $forming outlined (the habit${forming == 1 ? '' : 's'} '
      'you are working on now). Tap a stone to see which.';
}

/// Repoint: a weathered stone's habit goes back to daily, with Undo.
Future<void> repointHabit(WidgetRef ref, ActiveHabit habit) async {
  final undo = ref.read(undoControllerProvider);
  final actions = ref.read(habitActionsProvider);
  final id = habit.interventionId;
  final prior = await activateHabit(ref, id);
  undo.show(
    message: '${habit.intervention.title} is active again.',
    onUndo: () => actions.restore(id, prior),
  );
}

/// The tappable wall. Column count, packing, and hit-testing all derive from the
/// same [LayoutBuilder] width so drawing and taps never disagree.
class _Wall extends ConsumerWidget {
  const _Wall({
    required this.ordered,
    required this.forming,
    required this.erodedIds,
    required this.erodedSet,
  });

  final List<ActiveHabit> ordered;

  /// The active habits, drawn as outlined stones after the set ones.
  final List<ActiveHabit> forming;
  final List<String> erodedIds;
  final Set<String> erodedSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = WallGeometry.columnsFor(constraints.maxWidth);
        final placements = const WallLayout().pack(
          graduatedCount: ordered.length,
          activeCount: forming.length,
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
            } else if (globalIndex - ordered.length < forming.length) {
              // An outlined stone answers a tap too (it used to swallow it).
              _revealForming(context, forming[globalIndex - ordered.length]);
            }
          },
          child: CustomPaint(
            key: const Key('wall-canvas'),
            size: size,
            painter: WallPainter(
              placements: placements,
              columns: columns,
              palette: BulwarkPalette.of(context),
            ),
          ),
        );
      },
    );
  }

  void _revealForming(BuildContext context, ActiveHabit habit) {
    final since = habit.state.activatedAt;
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
                  since == null
                      ? 'Being set. It sets into the wall when it becomes '
                          'automatic.'
                      : 'Being set, active since '
                          '${DateFormat.yMMMd().format(since)}. It sets into '
                          'the wall when it becomes automatic.',
                  style: text.bodyMedium?.copyWith(
                      color: BulwarkPalette.of(context).secondaryText),
                ),
              ],
            ),
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
                  style: text.bodyMedium?.copyWith(
                      color: BulwarkPalette.of(context).secondaryText),
                ),
                if (eroded) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('This one has felt shaky lately.',
                      style: text.bodySmall
                          ?.copyWith(color: BulwarkPalette.of(context).clay)),
                  const SizedBox(height: AppSpacing.sm),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await repointHabit(ref, habit);
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
        style: text.bodySmall
            ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
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
                        style: text.labelSmall?.copyWith(
                            color: BulwarkPalette.of(context).secondaryText)),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    height: (rates[week]! * _barMaxHeight)
                        .clamp(2.0, _barMaxHeight),
                    decoration: BoxDecoration(
                      color: BulwarkPalette.of(context)
                          .lichen
                          .withValues(alpha: 0.75),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(DateFormat('M/d').format(week),
                        maxLines: 1,
                        softWrap: false,
                        style: text.labelSmall?.copyWith(
                            color: BulwarkPalette.of(context).secondaryText)),
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
                    color: eroded
                        ? BulwarkPalette.of(context).clay
                        : BulwarkPalette.of(context).lichen,
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
                          style: text.bodySmall?.copyWith(
                              color: BulwarkPalette.of(context).secondaryText),
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
                    foregroundColor: BulwarkPalette.of(context).clay,
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
