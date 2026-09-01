import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:go_router/go_router.dart';

import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';

/// The daily check-in: one inline row per active habit — did / skipped /
/// forgot — plus a weekly solid/shaky pulse for any graduated habit still owed
/// one this week. Under thirty seconds, no modal per habit, kind on the way
/// out. Each answer is saved as it is tapped (there is no Save to forget);
/// re-checking a habit upserts on (interventionId, date), so today's row is
/// corrected in place rather than duplicated. Done only goes back.
class CheckinScreen extends ConsumerStatefulWidget {
  const CheckinScreen({super.key});

  @override
  ConsumerState<CheckinScreen> createState() => _CheckinScreenState();
}

class _CheckinScreenState extends ConsumerState<CheckinScreen> {
  final Map<String, CheckinResult> _results = {};
  final Map<String, String> _notes = {};
  final Set<String> _notesOpen = {};
  final Map<String, PulseResult> _pulses = {};
  bool _seeded = false;

  // Every answer is written the moment it is given (audit humane-interface-01:
  // a day's answers used to live in widget state until a Save that the back
  // gesture skipped). The repository upserts on (interventionId, date), so a
  // changed mind corrects today's row in place.

  /// Refreshes the read models a write touches. Progress's erosion and
  /// adherence models are keepAlive and outlive this screen, so they are
  /// invalidated too, or a fresh answer would not reach the wall.
  void _refreshReadModels() {
    ref.invalidate(todaysCheckinsProvider);
    ref.invalidate(pulseDueProvider);
    ref.invalidate(allCheckinsProvider);
    ref.invalidate(allPulsesProvider);
  }

  void _saveFailed(Object e, StackTrace st) {
    debugPrint('Check-in write failed: $e\n$st');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('That answer didn’t save. ${ohFriendlyErrorMessage(e)}')));
  }

  Future<void> _writeCheckin(String id) async {
    final result = _results[id];
    if (result == null) return; // a note waits for its answer
    final note = _notes[id]?.trim() ?? '';
    await ref.read(checkinRepositoryProvider).upsert(Checkin(
          interventionId: id,
          date: DateTime.now().dateOnly,
          result: result,
          note: note.isEmpty ? null : note,
        ));
    _refreshReadModels();
  }

  Future<void> _answer(String id, CheckinResult r) async {
    final before = _results[id];
    setState(() => _results[id] = r);
    try {
      await _writeCheckin(id);
    } catch (e, st) {
      // Show what is actually stored, not what was tapped.
      if (mounted) {
        setState(() =>
            before == null ? _results.remove(id) : _results[id] = before);
      }
      _saveFailed(e, st);
    }
  }

  Future<void> _note(String id, String v) async {
    _notes[id] = v;
    try {
      await _writeCheckin(id);
    } catch (e, st) {
      _saveFailed(e, st);
    }
  }

  Future<void> _pulse(String id, PulseResult r) async {
    final before = _pulses[id];
    setState(() => _pulses[id] = r);
    try {
      await ref.read(pulseRepositoryProvider).upsert(Pulse(
            interventionId: id,
            weekStart: DateTime.now().startOfWeek,
            result: r,
          ));
      _refreshReadModels();
    } catch (e, st) {
      if (mounted) {
        setState(
            () => before == null ? _pulses.remove(id) : _pulses[id] = before);
      }
      _saveFailed(e, st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final habitsAsync = ref.watch(activeHabitsProvider);
    final checkinsAsync = ref.watch(todaysCheckinsProvider);
    final pulseDueAsync = ref.watch(pulseDueProvider);

    // Seed the working selections from any check-ins already logged today, once
    // the data is in hand — so re-opening the screen shows prior answers.
    if (!_seeded && checkinsAsync.hasValue) {
      for (final c in checkinsAsync.value!) {
        _results[c.interventionId] = c.result;
        if (c.note != null) _notes[c.interventionId] = c.note!;
      }
      _seeded = true;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Check in')),
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
          data: (habits) {
            final pulseDue = pulseDueAsync.valueOrNull ?? const [];
            if (habits.isEmpty && pulseDue.isEmpty) {
              return const _NothingToLog();
            }
            return _CheckinBody(
              habits: habits,
              pulseDue: pulseDue,
              resultFor: (id) => _results[id],
              onResult: _answer,
              noteOpen: _notesOpen.contains,
              noteFor: (id) => _notes[id] ?? '',
              onToggleNote: (id) => setState(() => _notesOpen.contains(id)
                  ? _notesOpen.remove(id)
                  : _notesOpen.add(id)),
              onNote: _note,
              pulseFor: (id) => _pulses[id],
              onPulse: _pulse,
              // Nothing to commit: every answer is already saved.
              onDone: () => context.go('/'),
            );
          },
        ),
      ),
    );
  }
}

class _CheckinBody extends StatelessWidget {
  const _CheckinBody({
    required this.habits,
    required this.pulseDue,
    required this.resultFor,
    required this.onResult,
    required this.noteOpen,
    required this.noteFor,
    required this.onToggleNote,
    required this.onNote,
    required this.pulseFor,
    required this.onPulse,
    required this.onDone,
  });

  final List<ActiveHabit> habits;
  final List<ActiveHabit> pulseDue;
  final CheckinResult? Function(String id) resultFor;
  final void Function(String id, CheckinResult r) onResult;
  final bool Function(String id) noteOpen;
  final String Function(String id) noteFor;
  final void Function(String id) onToggleNote;
  final void Function(String id, String v) onNote;
  final PulseResult? Function(String id) pulseFor;
  final void Function(String id, PulseResult r) onPulse;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.sm),
            children: [
              for (final habit in habits)
                _HabitRow(
                  habit: habit,
                  selected: resultFor(habit.interventionId),
                  onResult: (r) => onResult(habit.interventionId, r),
                  noteOpen: noteOpen(habit.interventionId),
                  note: noteFor(habit.interventionId),
                  onToggleNote: () => onToggleNote(habit.interventionId),
                  onNote: (v) => onNote(habit.interventionId, v),
                ),
              if (pulseDue.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Weekly pulse', style: text.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'A quick maintenance check on habits that are automatic now.',
                  style: text.bodySmall?.copyWith(
                      color: BulwarkPalette.of(context).secondaryText),
                ),
                const SizedBox(height: AppSpacing.sm),
                for (final habit in pulseDue)
                  _PulseRow(
                    habit: habit,
                    selected: pulseFor(habit.interventionId),
                    onPulse: (r) => onPulse(habit.interventionId, r),
                  ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.md),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onDone,
                child: const Text('Done'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HabitRow extends StatelessWidget {
  const _HabitRow({
    required this.habit,
    required this.selected,
    required this.onResult,
    required this.noteOpen,
    required this.note,
    required this.onToggleNote,
    required this.onNote,
  });

  final ActiveHabit habit;
  final CheckinResult? selected;
  final ValueChanged<CheckinResult> onResult;
  final bool noteOpen;
  final String note;
  final VoidCallback onToggleNote;
  final ValueChanged<String> onNote;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(habit.intervention.title, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            // Wrap so the three choices reflow instead of overflowing at large
            // text scales on narrow screens.
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _ResultChip(
                  label: 'Did it',
                  color: BulwarkPalette.of(context).lichen,
                  selected: selected == CheckinResult.did,
                  onTap: () => onResult(CheckinResult.did),
                ),
                _ResultChip(
                  label: 'Skipped',
                  color: BulwarkPalette.of(context).secondaryText,
                  selected: selected == CheckinResult.skipped,
                  onTap: () => onResult(CheckinResult.skipped),
                ),
                _ResultChip(
                  label: 'Forgot',
                  color: BulwarkPalette.of(context).clay,
                  selected: selected == CheckinResult.forgot,
                  onTap: () => onResult(CheckinResult.forgot),
                ),
              ],
            ),
            if (noteOpen)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: TextFormField(
                  initialValue: note,
                  onChanged: onNote,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Note (optional)',
                    isDense: true,
                  ),
                ),
              )
            // A note belongs to an answer, so it is offered once there is one.
            else if (selected != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onToggleNote,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 32),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Add note'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PulseRow extends StatelessWidget {
  const _PulseRow({
    required this.habit,
    required this.selected,
    required this.onPulse,
  });

  final ActiveHabit habit;
  final PulseResult? selected;
  final ValueChanged<PulseResult> onPulse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(habit.intervention.title, style: text.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                _ResultChip(
                  label: 'Solid',
                  color: BulwarkPalette.of(context).lichen,
                  selected: selected == PulseResult.solid,
                  onTap: () => onPulse(PulseResult.solid),
                ),
                _ResultChip(
                  label: 'Shaky',
                  color: BulwarkPalette.of(context).clay,
                  selected: selected == PulseResult.shaky,
                  onTap: () => onPulse(PulseResult.shaky),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  const _ResultChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: color.withValues(alpha: 0.22),
      showCheckmark: false,
      side: selected
          ? BorderSide(color: color)
          : BorderSide(
              color: BulwarkPalette.of(context)
                  .secondaryText
                  .withValues(alpha: 0.4)),
    );
  }
}

class _NothingToLog extends StatelessWidget {
  const _NothingToLog();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          'Nothing to log yet.\nActivate a habit and it will appear here.',
          style: text.bodyLarge
              ?.copyWith(color: BulwarkPalette.of(context).secondaryText),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
