import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/settings/data/export_serializer.dart';
import 'package:bulwark/features/settings/data/export_share.dart';
import 'package:bulwark/features/settings/presentation/settings_actions.dart';
import 'package:bulwark/features/notifications/notification_providers.dart';
import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_colors.dart';
import 'package:bulwark/shared/theme/app_spacing.dart';
import 'package:bulwark/shared/widgets/confirm_dialog.dart';

/// Settings: adjust the day-map times, pace, evidence bar, the reminder
/// switches, and reach About / Export / Erase. Edits autosave and re-plan
/// reminders; the tone stays calm and reversible throughout.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _seeded = false;

  late TimeOfDay _wake;
  late TimeOfDay _bed;
  TimeOfDay? _breakfast;
  TimeOfDay? _lunch;
  TimeOfDay? _dinner;
  TimeOfDay? _checkIn;
  late Pace _pace;
  late int _evidence;
  late bool _newParent;

  static int _mins(TimeOfDay t) => t.hour * 60 + t.minute;
  static TimeOfDay _tod(int m) => TimeOfDay(hour: (m ~/ 60) % 24, minute: m % 60);
  static TimeOfDay? _todOrNull(int? m) => m == null ? null : _tod(m);

  void _seed(Profile p) {
    _wake = _tod(p.wakeMinutes);
    _bed = _tod(p.bedMinutes);
    _breakfast = _todOrNull(p.breakfastMinutes);
    _lunch = _todOrNull(p.lunchMinutes);
    _dinner = _todOrNull(p.dinnerMinutes);
    _checkIn = _todOrNull(p.checkInMinutes);
    _pace = p.pace;
    _evidence = p.evidenceThreshold;
    _newParent = p.newParentMode;
    _seeded = true;
  }

  Profile _compose() => Profile(
        wakeMinutes: _mins(_wake),
        bedMinutes: _mins(_bed),
        breakfastMinutes: _breakfast == null ? null : _mins(_breakfast!),
        lunchMinutes: _lunch == null ? null : _mins(_lunch!),
        dinnerMinutes: _dinner == null ? null : _mins(_dinner!),
        goal: ref.read(profileProvider).valueOrNull?.goal ?? Goal.general,
        pace: _pace,
        checkInMinutes: _checkIn == null ? null : _mins(_checkIn!),
        evidenceThreshold: _evidence,
        onboarded: true,
        newParentMode: _newParent,
      );

  /// Persist the composed profile, refresh the shared read model, and re-plan
  /// reminders (which honors the master switch).
  Future<void> _persist() async {
    await ref.read(profileRepositoryProvider).save(_compose());
    ref.invalidate(profileProvider);
    await ref.read(profileProvider.future);
    await rescheduleNotifications(ref);
  }

  Future<void> _pick({
    required TimeOfDay? initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: initial ?? const TimeOfDay(hour: 8, minute: 0),
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() => onPicked(picked));
    await _persist();
  }

  Future<void> _setReminders(bool enabled) async {
    await ref.read(settingsRepositoryProvider).setRemindersEnabled(enabled);
    // Ask for OS permission only at this opt-in moment, never inside reschedule.
    if (enabled) {
      try {
        await ref.read(notificationServiceProvider).requestPermission();
      } catch (_) {}
    }
    await rescheduleNotifications(ref);
  }

  Future<void> _export() async {
    final habits = await ref.read(habitStateRepositoryProvider).getAll();
    final checkins = await ref.read(checkinRepositoryProvider).getAll();
    final pulses = await ref.read(pulseRepositoryProvider).getAll();
    final shopping = await ref.read(shoppingRepositoryProvider).getAll();
    final export = BulwarkExport(
      profile: ref.read(profileProvider).valueOrNull,
      habits: habits,
      checkins: checkins,
      pulses: pulses,
      shopping: shopping,
    );
    try {
      await shareExport(
        content: export.toPrettyJson(),
        fileName: exportFileName(DateTime.now()),
      );
    } catch (e) {
      if (!mounted) return;
      final msg =
          e is UnsupportedError ? (e.message ?? '$e') : 'Could not export.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _erase() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Erase all data?',
      message: 'This clears every habit, check-in, and setting on this device. '
          "Your data is only here, so this can't be undone.",
      confirmLabel: 'Erase everything',
      confirmColor: AppColors.clay,
    );
    if (!confirmed) return;
    await eraseAllData(ref);
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(profileProvider);
    final prefs = ref.watch(userPrefsProvider).valueOrNull;
    final remindersOn = prefs?.remindersEnabled ?? false;
    final darkOn = prefs?.isDarkMode ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load settings.\n$e',
                textAlign: TextAlign.center),
          ),
        ),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile yet.'));
          }
          if (!_seeded) _seed(profile);
          return _form(remindersOn: remindersOn, darkOn: darkOn);
        },
      ),
    );
  }

  Widget _form({required bool remindersOn, required bool darkOn}) {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      children: [
        const _SectionHeader('Your day'),
        _TimeTile(
          label: 'Wake',
          value: minutesToLabel(_mins(_wake)),
          onTap: () => _pick(initial: _wake, onPicked: (t) => _wake = t),
        ),
        _TimeTile(
          label: 'Bed',
          value: minutesToLabel(_mins(_bed)),
          onTap: () => _pick(initial: _bed, onPicked: (t) => _bed = t),
        ),
        _MealTile(
          label: 'Breakfast',
          value: _breakfast,
          onPick: () =>
              _pick(initial: _breakfast, onPicked: (t) => _breakfast = t),
          onClear: () async {
            setState(() => _breakfast = null);
            await _persist();
          },
        ),
        _MealTile(
          label: 'Lunch',
          value: _lunch,
          onPick: () => _pick(initial: _lunch, onPicked: (t) => _lunch = t),
          onClear: () async {
            setState(() => _lunch = null);
            await _persist();
          },
        ),
        _MealTile(
          label: 'Dinner',
          value: _dinner,
          onPick: () => _pick(initial: _dinner, onPicked: (t) => _dinner = t),
          onClear: () async {
            setState(() => _dinner = null);
            await _persist();
          },
        ),

        const _SectionHeader('Reminders'),
        SwitchListTile(
          title: const Text('Reminders'),
          subtitle: const Text(
              'Gentle daily nudges, batched morning and evening. Off means silence.'),
          value: remindersOn,
          onChanged: _setReminders,
        ),
        _MealTile(
          label: 'Daily check-in reminder',
          value: _checkIn,
          emptyLabel: 'No reminder',
          onPick: () =>
              _pick(initial: _checkIn, onPicked: (t) => _checkIn = t),
          onClear: () async {
            setState(() => _checkIn = null);
            await _persist();
          },
        ),

        const _SectionHeader('Adoption'),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, AppSpacing.xs, AppSpacing.md, 0),
          child: Text('How fast to take on new habits',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final p in Pace.values)
                ChoiceChip(
                  label: Text(_paceLabel(p)),
                  selected: _pace == p,
                  onSelected: (_) async {
                    setState(() => _pace = p);
                    await _persist();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.md, 0, AppSpacing.md, 0),
          child: Text('Evidence shown: ${_evidenceLabel(_evidence)}',
              style: Theme.of(context).textTheme.bodyMedium),
        ),
        Slider(
          value: _evidence.toDouble(),
          min: 0,
          max: 3,
          divisions: 3,
          label: _evidenceLabel(_evidence),
          onChanged: (d) => setState(() => _evidence = d.round()),
          onChangeEnd: (_) => _persist(),
        ),
        SwitchListTile(
          title: const Text('New Parent Mode'),
          subtitle:
              const Text('Bias toward a survival stack tuned for fragmented sleep.'),
          value: _newParent,
          onChanged: (v) async {
            setState(() => _newParent = v);
            await _persist();
          },
        ),

        const _SectionHeader('Appearance'),
        SwitchListTile(
          title: const Text('Dark mode'),
          value: darkOn,
          onChanged: (v) =>
              ref.read(settingsRepositoryProvider).setDarkMode(v),
        ),

        const _SectionHeader('Your data'),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About Bulwark'),
          onTap: () => context.push('/about'),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share),
          title: const Text('Export my data'),
          subtitle:
              const Text('Save everything as a JSON file you own (unencrypted).'),
          onTap: _export,
        ),
        const BackupSettingsSection(),
        ListTile(
          leading: const Icon(Icons.delete_outline, color: AppColors.clay),
          title: const Text('Erase all data',
              style: TextStyle(color: AppColors.clay)),
          onTap: _erase,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  static String _paceLabel(Pace p) => switch (p) {
        Pace.conservative => 'One at a time',
        Pace.moderate => 'A couple',
        Pace.aggressive => 'A few',
      };

  static String _evidenceLabel(int e) => switch (e) {
        0 => 'All',
        1 => 'Mechanistic and up',
        2 => 'Observational and up',
        _ => 'RCT only',
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.stone,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _TimeTile extends StatelessWidget {
  const _TimeTile(
      {required this.label, required this.value, required this.onTap});
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // The value lives in the subtitle (not trailing) so it wraps instead of
    // consuming the whole tile width at large text scales.
    return ListTile(
      title: Text(label),
      subtitle: Text(value,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.basalt)),
      trailing: const Icon(Icons.schedule, color: AppColors.stone),
      onTap: onTap,
    );
  }
}

/// A time tile that can also be empty/cleared — for the optional meal anchors
/// and the optional check-in reminder. Shows a Clear button when a value is set.
class _MealTile extends StatelessWidget {
  const _MealTile({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
    this.emptyLabel = 'Not set',
  });

  final String label;
  final TimeOfDay? value;
  final VoidCallback onPick;
  final VoidCallback onClear;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final v = value;
    return ListTile(
      title: Text(label),
      subtitle: Text(
        v == null ? emptyLabel : minutesToLabel(v.hour * 60 + v.minute),
        style: text.bodyMedium?.copyWith(
            color: v == null ? AppColors.stone : AppColors.basalt),
      ),
      trailing: v == null
          ? const Icon(Icons.schedule, color: AppColors.stone)
          : IconButton(
              icon: const Icon(Icons.clear, color: AppColors.stone),
              tooltip: 'Clear',
              onPressed: onClear,
            ),
      onTap: onPick,
    );
  }
}
