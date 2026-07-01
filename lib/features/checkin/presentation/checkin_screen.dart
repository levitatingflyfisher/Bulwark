import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_colors.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';

/// The daily check-in: one inline row per active habit — did / skipped /
/// forgot — plus a weekly solid/shaky pulse for any graduated habit still owed
/// one this week. Under thirty seconds, no modal per habit, kind on the way
/// out. Re-checking a habit upserts on (interventionId, date), so today's row
/// is corrected in place rather than duplicated.
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
  bool _saving = false;

  Future<void> _submit() async {
    if (_saving) return;
    setState(() => _saving = true);

    final today = DateTime.now().dateOnly;
    final weekStart = DateTime.now().startOfWeek;
    final checkinRepo = ref.read(checkinRepositoryProvider);
    final pulseRepo = ref.read(pulseRepositoryProvider);

    for (final entry in _results.entries) {
      await checkinRepo.upsert(Checkin(
        interventionId: entry.key,
        date: today,
        result: entry.value,
        note: _notes[entry.key]?.trim().isEmpty ?? true
            ? null
            : _notes[entry.key]!.trim(),
      ));
    }
    for (final entry in _pulses.entries) {
      await pulseRepo.upsert(Pulse(
        interventionId: entry.key,
        weekStart: weekStart,
        result: entry.value,
      ));
    }

    ref.invalidate(todaysCheckinsProvider);
    ref.invalidate(pulseDueProvider);
    // The Progress screen's erosion + adherence read models are keepAlive and
    // outlive this write, so refresh them too — otherwise a freshly-logged pulse
    // or check-in wouldn't surface on the wall until an app restart.
    ref.invalidate(allCheckinsProvider);
    ref.invalidate(allPulsesProvider);
    await ref.read(todaysCheckinsProvider.future);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Logged. See you tomorrow.')),
    );
    context.go('/');
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
      body: habitsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Something went wrong.\n$e',
                textAlign: TextAlign.center),
          ),
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
            onResult: (id, r) => setState(() => _results[id] = r),
            noteOpen: _notesOpen.contains,
            noteFor: (id) => _notes[id] ?? '',
            onToggleNote: (id) => setState(() =>
                _notesOpen.contains(id) ? _notesOpen.remove(id) : _notesOpen.add(id)),
            onNote: (id, v) => _notes[id] = v,
            pulseFor: (id) => _pulses[id],
            onPulse: (id, r) => setState(() => _pulses[id] = r),
            saving: _saving,
            onSubmit: _submit,
          );
        },
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
    required this.saving,
    required this.onSubmit,
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
  final bool saving;
  final VoidCallback onSubmit;

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
                  style: text.bodySmall?.copyWith(color: AppColors.stone),
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
                onPressed: saving ? null : onSubmit,
                child: Text(saving ? 'Saving…' : 'Save'),
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
                  color: AppColors.lichen,
                  selected: selected == CheckinResult.did,
                  onTap: () => onResult(CheckinResult.did),
                ),
                _ResultChip(
                  label: 'Skipped',
                  color: AppColors.stone,
                  selected: selected == CheckinResult.skipped,
                  onTap: () => onResult(CheckinResult.skipped),
                ),
                _ResultChip(
                  label: 'Forgot',
                  color: AppColors.clay,
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
            else
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
                  color: AppColors.lichen,
                  selected: selected == PulseResult.solid,
                  onTap: () => onPulse(PulseResult.solid),
                ),
                _ResultChip(
                  label: 'Shaky',
                  color: AppColors.clay,
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
          : BorderSide(color: AppColors.stone.withValues(alpha: 0.4)),
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
          style: text.bodyLarge?.copyWith(color: AppColors.stone),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
