import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/promotion_gate.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/library/domain/enums.dart' show Evidence;
import 'package:bulwark/shared/theme/app_colors.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';

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
    final pace =
        ref.read(profileProvider).valueOrNull?.pace ?? Pace.moderate;
    final verdict = const PromotionGate().evaluate(
      now: DateTime.now(),
      states: states,
      checkins: checkins,
      pace: pace,
    );
    setState(() => _verdict = verdict);
  }

  Future<void> _activateTop(String interventionId) async {
    if (_busy) return;
    setState(() => _busy = true);
    await activateHabit(ref, interventionId);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _verdict = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Activated. It is on your Today list.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final queuedAsync = ref.watch(queuedHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Queue')),
      body: queuedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child:
                Text('Something went wrong.\n$e', textAlign: TextAlign.center),
          ),
        ),
        data: (queued) {
          if (queued.isEmpty) return const _EmptyQueue();
          final top = queued.first;
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              _ReadyCard(
                verdict: _verdict,
                topTitle: top.intervention.title,
                busy: _busy,
                onCheck: _evaluate,
                onActivateTop: () => _activateTop(top.interventionId),
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
          );
        },
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
          'You added one recently — habits settle better with a little space.',
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
                style: text.bodySmall?.copyWith(color: AppColors.stone),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onCheck,
                  child: const Text("I'm ready for another"),
                ),
              ),
            ] else if (v.advisable) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.circleCheck,
                        size: 18, color: AppColors.lichen),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('Looks like a good time.',
                        style: text.titleMedium
                            ?.copyWith(color: AppColors.lichen)),
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
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(LucideIcons.info,
                        size: 18, color: AppColors.clay),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text('A gentle heads-up',
                        style:
                            text.titleMedium?.copyWith(color: AppColors.clay)),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final reason in v.reasons)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Text('• ${_reasonCopy(reason)}',
                      style: text.bodySmall),
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
              Text(action,
                  style: text.bodySmall?.copyWith(color: AppColors.stone),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
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
