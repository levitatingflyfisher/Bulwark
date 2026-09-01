import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openhearth_design/openhearth_design.dart';
import 'package:go_router/go_router.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/starter_pack_selector.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/adoption/presentation/widgets/evidence_tag.dart';
import 'package:bulwark/features/notifications/notification_providers.dart';
import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';

/// The three-step onboarding: a welcome that states the disclaimer, map your
/// day, then meet your starter pack. Matter-of-fact tone throughout, no hype,
/// no pressure. The disclaimer is standing text, not a tick that must be
/// operated before anything else works (fleet first-run ruling; audit
/// humane-interface-03): the same sentence stands on Home, every detail card
/// and About.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _step = 0;

  // Step 2 — lifestyle map. Sensible defaults so the form is always valid and
  // the user can proceed by adjusting only what matters to them.
  TimeOfDay _wake = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay _bed = const TimeOfDay(hour: 22, minute: 30);
  TimeOfDay? _breakfast;
  TimeOfDay? _lunch;
  TimeOfDay? _dinner;
  Goal _goal = Goal.general;
  int _capacity = 2; // 1 conservative … 3 aggressive
  bool _newParent = false;
  TimeOfDay? _checkInReminder;

  bool _saving = false;

  static int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  Pace get _pace => Pace.values[_capacity - 1];

  Profile _buildProfile() => Profile(
        wakeMinutes: _mins(_wake),
        bedMinutes: _mins(_bed),
        breakfastMinutes: _breakfast == null ? null : _mins(_breakfast!),
        lunchMinutes: _lunch == null ? null : _mins(_lunch!),
        dinnerMinutes: _dinner == null ? null : _mins(_dinner!),
        goal: _goal,
        pace: _pace,
        checkInMinutes: _checkInReminder == null ? null : _mins(_checkInReminder!),
        onboarded: true,
        newParentMode: _newParent,
      );

  Future<void> _pickTime({
    required TimeOfDay? initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (!mounted) return;
    if (picked != null) setState(() => onPicked(picked));
  }

  Future<void> _confirm(ContentLibrary library, List<Intervention> picks) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final profile = _buildProfile();
      final now = DateTime.now();
      final habitRepo = ref.read(habitStateRepositoryProvider);

      await ref.read(profileRepositoryProvider).save(profile);

      final activeIds = <String>{};
      for (final pick in picks) {
        await habitRepo.upsert(HabitState(
          interventionId: pick.id,
          status: HabitStatus.active,
          activatedAt: now,
          createdAt: now,
        ));
        activeIds.add(pick.id);
      }

      // New Parent Mode pre-queues the survival stack (minus anything already an
      // active starter pick, e.g. morning-sunlight), skipping ids that don't
      // resolve in the shipped library.
      if (profile.newParentMode) {
        final preset = library.presetById('newParent');
        if (preset != null) {
          var position = 0;
          for (final id in preset.interventionIds) {
            if (activeIds.contains(id)) continue;
            if (library.byIdOrNull(id) == null) continue;
            await habitRepo.upsert(HabitState(
              interventionId: id,
              status: HabitStatus.queued,
              queuePosition: position++,
              createdAt: now,
            ));
          }
        }
      }

      // Reload the shared read models from the freshly-written rows before the
      // redirect re-evaluates, so Home shows the new habits and the router lets
      // us onto '/'. Mirror erase's full invalidation set (defensive; cheap) so
      // no stale read model survives, then await active + profile so the
      // redirect sees onboarded=true with the new habits materialized.
      ref.invalidate(activeHabitsProvider);
      ref.invalidate(queuedHabitsProvider);
      ref.invalidate(graduatedHabitsProvider);
      ref.invalidate(habitStatesByIdProvider);
      ref.invalidate(shoppingStatesProvider);
      ref.invalidate(allCheckinsProvider);
      ref.invalidate(allPulsesProvider);
      ref.invalidate(todaysCheckinsProvider);
      ref.invalidate(pulseDueProvider);
      ref.invalidate(graduationEligibleProvider);
      ref.invalidate(profileProvider);
      await ref.read(activeHabitsProvider.future);
      await ref.read(profileProvider.future);

      // Reminders are opt-in (§1.7): flip the master switch on only if the user
      // chose a daily check-in time, ask for OS permission at that opt-in moment
      // (Android 13+ suppresses notifications silently without it), then plan.
      if (profile.checkInMinutes != null) {
        await ref.read(settingsRepositoryProvider).setRemindersEnabled(true);
        try {
          await ref.read(notificationServiceProvider).requestPermission();
        } catch (_) {}
      }
      await rescheduleNotifications(ref);

      if (mounted) context.go('/');
    } finally {
      // Reset the saving flag in a finally so a mid-write throw re-enables the
      // "Start tonight" button instead of stranding it on "Setting up…".
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(contentLibraryProvider);
    return Scaffold(
      // OhPage brings its own SafeArea, and caps the steps at phone width
      // on a tablet or in the browser.
      body: OhPage(
        padding: EdgeInsets.zero,
        child: libraryAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => OhErrorState.fromError(
            e,
            stackTrace: st,
            title: "Couldn’t open the habit library",
            onRetry: () => ref.invalidate(contentLibraryProvider),
          ),
          data: (library) => _stepBody(library),
        ),
      ),
    );
  }

  Widget _stepBody(ContentLibrary library) {
    switch (_step) {
      case 0:
        return _IntroStep(
          onContinue: () => setState(() => _step = 1),
        );
      case 1:
        return _LifestyleStep(
          wake: _wake,
          bed: _bed,
          breakfast: _breakfast,
          lunch: _lunch,
          dinner: _dinner,
          goal: _goal,
          capacity: _capacity,
          newParent: _newParent,
          checkInReminder: _checkInReminder,
          onPickWake: () =>
              _pickTime(initial: _wake, onPicked: (t) => _wake = t),
          onPickBed: () => _pickTime(initial: _bed, onPicked: (t) => _bed = t),
          onPickBreakfast: () =>
              _pickTime(initial: _breakfast, onPicked: (t) => _breakfast = t),
          onPickLunch: () =>
              _pickTime(initial: _lunch, onPicked: (t) => _lunch = t),
          onPickDinner: () =>
              _pickTime(initial: _dinner, onPicked: (t) => _dinner = t),
          onPickCheckIn: () => _pickTime(
              initial: _checkInReminder, onPicked: (t) => _checkInReminder = t),
          onClearCheckIn: () => setState(() => _checkInReminder = null),
          onGoal: (g) => setState(() => _goal = g),
          onCapacity: (c) => setState(() => _capacity = c),
          onNewParent: (v) => setState(() => _newParent = v),
          onBack: () => setState(() => _step = 0),
          onContinue: () => setState(() => _step = 2),
        );
      default:
        final picks = const StarterPackSelector().select(
          _buildProfile(),
          library,
        );
        return _RevealStep(
          picks: picks,
          saving: _saving,
          onBack: _saving ? null : () => setState(() => _step = 1),
          onConfirm: () => _confirm(library, picks),
        );
    }
  }
}

// ─── Step 1: intro + disclaimer ─────────────────────────────────────────────

class _IntroStep extends StatelessWidget {
  const _IntroStep({required this.onContinue});

  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _StepScaffold(
      primaryLabel: 'Continue',
      onPrimary: onContinue,
      children: [
        Text('Welcome to Bulwark', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.md),
        Text(
          'A wall between you and entropy. Bulwark introduces healthy habits a '
          'few at a time, attached to things you already do, and quietly helps '
          'you keep them.',
          style: text.bodyLarge,
        ),
        const SizedBox(height: AppSpacing.lg),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Before we start', style: text.titleMedium),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Bulwark is habit-tracking with health education, not medical '
                  'advice. For specific conditions, talk to a clinician.',
                  style: text.bodyMedium,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 2: lifestyle map ──────────────────────────────────────────────────

class _LifestyleStep extends StatelessWidget {
  const _LifestyleStep({
    required this.wake,
    required this.bed,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.goal,
    required this.capacity,
    required this.newParent,
    required this.checkInReminder,
    required this.onPickWake,
    required this.onPickBed,
    required this.onPickBreakfast,
    required this.onPickLunch,
    required this.onPickDinner,
    required this.onPickCheckIn,
    required this.onClearCheckIn,
    required this.onGoal,
    required this.onCapacity,
    required this.onNewParent,
    required this.onBack,
    required this.onContinue,
  });

  final TimeOfDay wake;
  final TimeOfDay bed;
  final TimeOfDay? breakfast;
  final TimeOfDay? lunch;
  final TimeOfDay? dinner;
  final Goal goal;
  final int capacity;
  final bool newParent;
  final TimeOfDay? checkInReminder;
  final VoidCallback onPickWake;
  final VoidCallback onPickBed;
  final VoidCallback onPickBreakfast;
  final VoidCallback onPickLunch;
  final VoidCallback onPickDinner;
  final VoidCallback onPickCheckIn;
  final VoidCallback onClearCheckIn;
  final ValueChanged<Goal> onGoal;
  final ValueChanged<int> onCapacity;
  final ValueChanged<bool> onNewParent;
  final VoidCallback onBack;
  final VoidCallback onContinue;

  static String _goalLabel(Goal g) => switch (g) {
        Goal.sleep => 'Sleep',
        Goal.energy => 'Energy',
        Goal.pain => 'Pain',
        Goal.longevity => 'Longevity',
        Goal.immune => 'Immunity',
        Goal.general => 'General health',
      };

  static String _capacityLabel(int c) => switch (c) {
        1 => 'One at a time',
        2 => 'A couple',
        _ => 'A few',
      };

  String _time(TimeOfDay t) => minutesToLabel(t.hour * 60 + t.minute);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return _StepScaffold(
      primaryLabel: 'See your starter pack',
      onPrimary: onContinue,
      onBack: onBack,
      children: [
        Text('Map your day', style: text.headlineSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Habits stick when they hang off things you already do. These anchor '
          'your habits to the right moments.',
          style: text.bodyMedium?.copyWith(color: BulwarkPalette.of(context).secondaryText),
        ),
        const SizedBox(height: AppSpacing.md),
        _TimeField(label: 'Wake', value: _time(wake), onTap: onPickWake),
        _TimeField(label: 'Bed', value: _time(bed), onTap: onPickBed),
        const SizedBox(height: AppSpacing.sm),
        Text('Meals (optional)', style: text.titleSmall),
        _TimeField(
          label: 'Breakfast',
          value: breakfast == null ? 'Not set' : _time(breakfast!),
          onTap: onPickBreakfast,
        ),
        _TimeField(
          label: 'Lunch',
          value: lunch == null ? 'Not set' : _time(lunch!),
          onTap: onPickLunch,
        ),
        _TimeField(
          label: 'Dinner',
          value: dinner == null ? 'Not set' : _time(dinner!),
          onTap: onPickDinner,
        ),
        const SizedBox(height: AppSpacing.md),
        Text('What matters most right now?', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final g in Goal.values)
              ChoiceChip(
                label: Text(_goalLabel(g)),
                selected: goal == g,
                onSelected: (_) => onGoal(g),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        Text('How much do you want to take on?', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final c in [1, 2, 3])
              ChoiceChip(
                label: Text(_capacityLabel(c)),
                selected: capacity == c,
                onSelected: (_) => onCapacity(c),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Caring for a newborn?'),
          subtitle: const Text(
              'Adds a survival stack tuned for fragmented sleep.'),
          value: newParent,
          onChanged: onNewParent,
        ),
        const SizedBox(height: AppSpacing.sm),
        Text('Daily check-in reminder (optional)', style: text.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onPickCheckIn,
                child: Text(checkInReminder == null
                    ? 'Set a time'
                    : _time(checkInReminder!)),
              ),
            ),
            if (checkInReminder != null)
              TextButton(onPressed: onClearCheckIn, child: const Text('Clear')),
          ],
        ),
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField(
      {required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          children: [
            Expanded(child: Text(label, style: text.bodyLarge)),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                style: text.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                textAlign: TextAlign.right,
              ),
            ),
            Icon(Icons.schedule, size: 18, color: BulwarkPalette.of(context).secondaryText),
          ],
        ),
      ),
    );
  }
}

// ─── Step 3: starter-pack reveal ────────────────────────────────────────────

class _RevealStep extends StatelessWidget {
  const _RevealStep({
    required this.picks,
    required this.saving,
    required this.onBack,
    required this.onConfirm,
  });

  final List<Intervention> picks;
  final bool saving;
  final VoidCallback? onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final n = picks.length;
    return _StepScaffold(
      primaryLabel: saving ? 'Setting up…' : 'Start tonight',
      onPrimary: saving ? null : onConfirm,
      onBack: onBack,
      children: [
        Text(
          n == 1 ? 'Your first stone' : 'Your first $n',
          style: text.headlineSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          n == 0
              ? 'We could not find a match. You can add habits from the '
                  'Library once you are set up.'
              : 'All free. You can start tonight. Add more when these feel '
                  'automatic.',
          style: text.bodyMedium?.copyWith(color: BulwarkPalette.of(context).secondaryText),
        ),
        const SizedBox(height: AppSpacing.md),
        for (final p in picks) ...[
          _PickCard(intervention: p),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _PickCard extends StatelessWidget {
  const _PickCard({required this.intervention});

  final Intervention intervention;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intervention.title, style: text.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(intervention.action, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.sm),
            Text(
              intervention.trigger.note,
              style: text.bodySmall?.copyWith(color: BulwarkPalette.of(context).secondaryText),
            ),
            const SizedBox(height: AppSpacing.sm),
            EvidenceTag(intervention.evidence),
          ],
        ),
      ),
    );
  }
}

// ─── Shared step chrome ─────────────────────────────────────────────────────

/// A scrollable step body with a fixed action row, so long forms survive small
/// screens and large text scales without overflowing.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.onBack,
  });

  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg, AppSpacing.sm, AppSpacing.lg, AppSpacing.lg),
          // Stacked full-width buttons: a Back-beside-primary row would starve
          // the primary of width at large text scales on a narrow screen,
          // exploding the wrapped label vertically.
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onPrimary,
                  child: Text(primaryLabel, textAlign: TextAlign.center),
                ),
              ),
              if (onBack != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: onBack,
                    child: const Text('Back'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
