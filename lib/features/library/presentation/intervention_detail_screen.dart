import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:lucide_flutter/lucide_flutter.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/weak_trigger.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/features/library/presentation/content_labels.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';

/// The full card for one intervention: what to do, when, why, the evidence, any
/// safety note, and generic buying criteria — plus state-aware actions. asNeeded
/// items are reference-only (no Activate). Every card ends on the disclaimer.
class InterventionDetailScreen extends ConsumerStatefulWidget {
  const InterventionDetailScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<InterventionDetailScreen> createState() =>
      _InterventionDetailScreenState();
}

class _InterventionDetailScreenState
    extends ConsumerState<InterventionDetailScreen> {
  bool _busy = false;

  /// Runs a lifecycle change and offers Undo for it (never a timeout). A
  /// failed write only says so; there is nothing to undo.
  Future<void> _run(
      Future<HabitState?> Function() action, String done) async {
    if (_busy) return;
    setState(() => _busy = true);
    // Read before the await: the change can take this screen's ref with it.
    final undo = ref.read(undoControllerProvider);
    final actions = ref.read(habitActionsProvider);
    final id = widget.id;
    try {
      final prior = await action();
      undo.show(
        message: done,
        onUndo: () => actions.restore(id, prior),
      );
    } catch (e, st) {
      // A write failure must not strand the button on "busy": report it
      // calmly and fall through to the finally that re-enables the action.
      debugPrint('Habit change failed: $e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text('That didn’t save. ${ohFriendlyErrorMessage(e)}')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(contentLibraryProvider);
    final statesAsync = ref.watch(habitStatesByIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Habit')),
      body: OhPage(
        padding: EdgeInsets.zero,
        child: libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => OhErrorState.fromError(
            e,
            stackTrace: st,
            title: "Couldn’t open this habit",
            onRetry: () => ref.invalidate(contentLibraryProvider),
          ),
          data: (library) {
            final intervention = library.byIdOrNull(widget.id);
            if (intervention == null) {
              return _centered('This habit is no longer in the library.');
            }
            final state = statesAsync.valueOrNull?[widget.id];
            return _Body(
              intervention: intervention,
              state: state,
              busy: _busy,
              onActivate: () => _run(() => activateHabit(ref, intervention.id),
                  '${intervention.title} is on your Today list.'),
              onQueue: () => _run(() => queueHabit(ref, intervention.id),
                  '${intervention.title} is in your queue.'),
              onSetAside: () => _run(
                  () => setAsideHabit(ref, intervention.id),
                  '${intervention.title} is set aside. It is off Today; '
                  'nothing is lost.'),
            );
          },
        ),
      ),
    );
  }

  Widget _centered(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _Body extends StatelessWidget {
  const _Body({
    required this.intervention,
    required this.state,
    required this.busy,
    required this.onActivate,
    required this.onQueue,
    required this.onSetAside,
  });

  final Intervention intervention;
  final HabitState? state;
  final bool busy;
  final VoidCallback onActivate;
  final VoidCallback onQueue;
  final VoidCallback onSetAside;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final i = intervention;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(i.title, style: text.headlineSmall),
              const SizedBox(height: AppSpacing.sm),
              Text(i.action, style: text.bodyLarge),
              const SizedBox(height: AppSpacing.md),
              _IconLine(
                icon: LucideIcons.anchor,
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: '${anchorLabel(effectiveAnchor(state, i))}: ',
                      style: text.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    // Moved by the person: the content's cue sentence names
                    // the old moment, so say where it came from instead.
                    TextSpan(
                        text: effectiveAnchor(state, i) != i.trigger.anchor
                            ? 'you moved it here from '
                                '${anchorLabel(i.trigger.anchor).toLowerCase()}.'
                            : i.trigger.note,
                        style: text.bodyMedium),
                  ]),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              _IconLine(
                icon: LucideIcons.activity,
                child: Text(i.mechanism, style: text.bodyMedium),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(i.details, style: text.bodyMedium),
              const SizedBox(height: AppSpacing.lg),
              // Evidence, explained in plain language.
              EvidenceTag(i.evidence),
              const SizedBox(height: AppSpacing.xs),
              Text(
                evidenceGloss(i.evidence),
                style: text.bodySmall
                    ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              ),
              const SizedBox(height: AppSpacing.md),
              // Metadata row.
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: [
                  _pill(context, categoryLabel(i.category)),
                  _pill(context, costLabel(i.cost.tier)),
                  _pill(context, timeLabel(i.timeCostMinutes)),
                ],
              ),
              if (i.cost.note != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(i.cost.note!,
                    style: text.bodySmall?.copyWith(
                        color: BulwarkPalette.of(context).secondaryText)),
              ],
              if (i.safety != null) ...[
                const SizedBox(height: AppSpacing.md),
                _SafetyNote(text: i.safety!),
              ],
              if (i.shopping != null) ...[
                const SizedBox(height: AppSpacing.md),
                _ShoppingCriteria(shopping: i.shopping!),
              ],
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Bulwark is habit-tracking with health education, not medical '
                'advice. For specific conditions, talk to a clinician.',
                style: text.labelSmall
                    ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
              ),
            ],
          ),
        ),
        _ActionBar(
          intervention: intervention,
          state: state,
          busy: busy,
          onActivate: onActivate,
          onQueue: onQueue,
          onSetAside: onSetAside,
        ),
      ],
    );
  }

  static Widget _pill(BuildContext context, String label) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 2),
      decoration: BoxDecoration(
        color: BulwarkPalette.of(context).secondaryText.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: text.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface)),
    );
  }
}

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.child});
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon,
              size: 16, color: BulwarkPalette.of(context).secondaryText),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: child),
      ],
    );
  }
}

/// Calm caution styling — clay, never red. A note, not an alarm.
class _SafetyNote extends StatelessWidget {
  const _SafetyNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final styles = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: BulwarkPalette.of(context).clay.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: BulwarkPalette.of(context).clay.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(LucideIcons.info,
                size: 16, color: BulwarkPalette.of(context).clay),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Good to know',
                    style: styles.titleSmall
                        ?.copyWith(color: BulwarkPalette.of(context).clay)),
                const SizedBox(height: AppSpacing.xs),
                Text(text, style: styles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Generic buying criteria — item + what to look for + where. Never a brand,
/// retailer, or link (the de-personalization law).
class _ShoppingCriteria extends StatelessWidget {
  const _ShoppingCriteria({required this.shopping});
  final Shopping shopping;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(LucideIcons.shoppingBasket,
                    size: 16, color: BulwarkPalette.of(context).secondaryText),
                const SizedBox(width: AppSpacing.sm),
                Text('What to look for', style: text.titleSmall),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(shopping.item, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(shopping.criteria,
                style: text.bodySmall?.copyWith(
                    color: BulwarkPalette.of(context).secondaryText)),
          ],
        ),
      ),
    );
  }
}

/// The state-aware bottom action bar. Reference-only items get a disabled note;
/// otherwise the buttons reflect the habit's current lifecycle state rather than
/// offering a duplicate transition.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.intervention,
    required this.state,
    required this.busy,
    required this.onActivate,
    required this.onQueue,
    required this.onSetAside,
  });

  final Intervention intervention;
  final HabitState? state;
  final bool busy;
  final VoidCallback onActivate;
  final VoidCallback onQueue;
  final VoidCallback onSetAside;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.md),
        child: _content(context),
      ),
    );
  }

  Widget _content(BuildContext context) {
    if (!intervention.isActivatable) {
      return _ReferenceOnly();
    }
    final status = state?.status;
    switch (status) {
      case HabitStatus.active:
        // The way off Today that isn't graduation or Erase (audit
        // design-of-everyday-things-01): set aside, keep everything.
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(
                icon: LucideIcons.circleCheck,
                color: BulwarkPalette.of(context).lichen,
                label: 'Active now'),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onSetAside,
                child: const Text('Set aside'),
              ),
            ),
          ],
        );
      case HabitStatus.graduated:
        return _StatusChip(
            icon: LucideIcons.check,
            color: BulwarkPalette.of(context).lichen,
            label: 'Made automatic');
      case HabitStatus.queued:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StatusChip(
                icon: LucideIcons.clock,
                color: BulwarkPalette.of(context).secondaryText,
                label: 'In your queue'),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onActivate,
                child: const Text('Activate now'),
              ),
            ),
          ],
        );
      case HabitStatus.paused:
      case null:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == HabitStatus.paused) ...[
              _StatusChip(
                  icon: LucideIcons.pause,
                  color: BulwarkPalette.of(context).secondaryText,
                  label: 'Set aside for now'),
              const SizedBox(height: AppSpacing.sm),
            ],
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: busy ? null : onActivate,
                child: const Text('Activate'),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: busy ? null : onQueue,
                child: const Text('Add to queue'),
              ),
            ),
          ],
        );
    }
  }
}

class _ReferenceOnly extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(LucideIcons.bookOpen,
            size: 16, color: BulwarkPalette.of(context).secondaryText),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            'Reference only for now. This one is used as needed, not tracked '
            'daily.',
            style: text.bodySmall
                ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
          ),
        ),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(
      {required this.icon, required this.color, required this.label});
  final IconData icon;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(label, style: text.titleSmall?.copyWith(color: color)),
        ),
      ],
    );
  }
}
