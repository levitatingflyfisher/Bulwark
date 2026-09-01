import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/promotion_gate.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/library/domain/enums.dart' show Evidence;
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/theme_toggle.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';

/// The backlog of queued habits, in queue order, plus the advisory
/// "I'm ready for another" flow. The promotion gate advises — it never blocks:
/// every verdict, kind or cautioning, ends with a way to go ahead anyway.
class QueueScreen extends ConsumerStatefulWidget {
  const QueueScreen({super.key});

  @override
  ConsumerState<QueueScreen> createState() => _QueueScreenState();
}

class _QueueScreenState extends ConsumerState<QueueScreen> {
  PromotionVerdict? _verdict;
  bool _busy = false;

  Future<void> _evaluate() async {
    final states = await ref.read(habitStateRepositoryProvider).getAll();
    final checkins = await ref
        .read(checkinRepositoryProvider)
        .since(DateTime.now().subtract(const Duration(days: 8)));
    if (!mounted) return;
    final pace = ref.read(profileProvider).valueOrNull?.pace ?? Pace.moderate;
    final verdict = const PromotionGate().evaluate(
      now: DateTime.now(),
      states: states,
      checkins: checkins,
      pace: pace,
    );
    setState(() => _verdict = verdict);
  }

  Future<void> _activateTop(String interventionId, String title) async {
    if (_busy) return;
    setState(() => _busy = true);
    final undo = ref.read(undoControllerProvider);
    final actions = ref.read(habitActionsProvider);
    final prior = await activateHabit(ref, interventionId);
    undo.show(
      message: '$title is on your Today list.',
      onUndo: () => actions.restore(interventionId, prior),
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verdict = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queuedAsync = ref.watch(queuedHabitsProvider);
    final paused = ref.watch(pausedHabitsProvider).valueOrNull ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Queue'),
        actions: const [ThemeToggle()],
      ),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: queuedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => OhErrorState.fromError(
            e,
            stackTrace: st,
            title: "Couldn’t load your queue",
            onRetry: () => ref.invalidate(queuedHabitsProvider),
          ),
          data: (queued) {
            if (queued.isEmpty && paused.isEmpty) return const _EmptyQueue();
            final top = queued.isEmpty ? null : queued.first;
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                if (top != null) ...[
                  _ReadyCard(
                    verdict: _verdict,
                    topTitle: top.intervention.title,
                    busy: _busy,
                    onCheck: _evaluate,
                    onActivateTop: () => _activateTop(
                        top.interventionId, top.intervention.title),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text('In your queue',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  for (final habit in queued)
                    _QueueRow(
                      title: habit.intervention.title,
                      action: habit.intervention.action,
                      evidence: habit.intervention.evidence,
                      onTap: () =>
                          context.push('/intervention/${habit.interventionId}'),
                    ),
                ],
                // Habits set aside from Today live here, each one tap from
                // active again, so nothing set aside is lost once its Undo
                // offer has gone.
                if (paused.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text('Set aside',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  for (final habit in paused)
                    _SetAsideRow(
                      habit: habit,
                      onOpen: () =>
                          context.push('/intervention/${habit.interventionId}'),
                      onActivate: () => _activateTop(
                          habit.interventionId, habit.intervention.title),
                    ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A set-aside habit: its name, and Activate to take it up again.
class _SetAsideRow extends StatelessWidget {
  const _SetAsideRow({
    required this.habit,
    required this.onOpen,
    required this.onActivate,
  });

  final ActiveHabit habit;
  final VoidCallback onOpen;
  final VoidCallback onActivate;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.xs, AppSpacing.xs),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(habit.intervention.title,
                  style: Theme.of(context).textTheme.titleMedium),
              TextButton(onPressed: onActivate, child: const Text('Activate')),
            ],
          ),
        ),
      ),
    );
  }
}

/// The "ready for another" affordance and, once checked, the gate's verdict.
class _ReadyCard extends StatelessWidget {
  const _ReadyCard({
    required this.verdict,
    required this.topTitle,
    required this.busy,
    required this.onCheck,
    required this.onActivateTop,
  });

  final PromotionVerdict? verdict;
  final String topTitle;
  final bool busy;
  final VoidCallback onCheck;
  final VoidCallback onActivateTop;

  static String _reasonCopy(GateReason reason) => switch (reason) {
        GateReason.tooSoon =>
          'You added one recently. Habits settle better with a little space.',
        GateReason.capReached =>
          'You have a full plate (10 active). Consider graduating one first.',
        GateReason.unsteady =>
          'A couple of current habits are still finding their footing.',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = verdict;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (v == null) ...[
              Text('Room for another?', style: text.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Bulwark will take a quick look at how your current habits are '
                'settling.',
                style: text.bodySmall
                    ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onCheck,
                  child: const Text("I’m ready for another"),
                ),
              ),
            ] else if (v.advisable) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.circleCheck,
                        size: 18, color: BulwarkPalette.of(context).lichen),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Looks like a good time.',
                        style: text.titleMedium?.copyWith(
                            color: BulwarkPalette.of(context).lichen)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onActivateTop,
                  child: Text('Activate $topTitle'),
                ),
              ),
            ] else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.info,
                        size: 18, color: BulwarkPalette.of(context).clay),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('A gentle heads-up',
                        style: text.titleMedium
                            ?.copyWith(color: BulwarkPalette.of(context).clay)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final reason in v.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child:
                      Text('• ${_reasonCopy(reason)}', style: text.bodySmall),
                ),
              const SizedBox(height: AppSpacing.sm),
              // Advisory, never blocking: the override is always offered.
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: busy ? null : onActivateTop,
                  child: Text('Add $topTitle anyway'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.title,
    required this.action,
    required this.evidence,
    required this.onTap,
  });

  final String title;
  final String action;
  final Evidence evidence;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: text.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: AppSpacing.xs),
              // What the habit IS: body text, whole, not a footnote.
              Text(action,
                  style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface)),
              const SizedBox(height: AppSpacing.sm),
              EvidenceTag(evidence),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Your queue is empty.',
                style: text.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Add habits from the Library and they will line up here for when '
              'you are ready.',
              style: text.bodyLarge
                  ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
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
