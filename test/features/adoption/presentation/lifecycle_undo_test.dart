import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/settings/data/local_settings_repository.dart';
import 'package:bulwark/features/adoption/presentation/habit_actions.dart';
import 'package:bulwark/features/library/presentation/intervention_detail_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openhearth_design/openhearth_design.dart';

import '../../../support/adoption_harness.dart';
import '../../../support/fake_notification_service.dart';

/// Nothing a person does to a habit is one-way any more (audit about-face-01,
/// design-of-everyday-things-01): every lifecycle change offers an Undo that
/// never times out, and an active habit can be set aside (the `paused` state
/// the schema always declared and nothing ever wrote).
class _Runner extends ConsumerWidget {
  const _Runner(this.onTap);
  final Future<void> Function(WidgetRef) onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
        home: Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => onTap(ref),
              child: const Text('run'),
            ),
          ),
        ),
      );
}

HabitState _active() => HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      activatedAt: DateTime(2026, 1, 2),
      triggerAnchorOverride: 'wake',
      reminderEnabled: true,
      createdAt: DateTime(2026, 1, 1),
    );

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> run(WidgetTester tester, Future<void> Function(WidgetRef) f) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: _Runner(f),
    ));
    await tester.tap(find.text('run'));
    await tester.pumpAndSettle();
  }

  testWidgets('setting a habit aside writes paused and keeps its fields, and '
      'hands back the row it replaced', (tester) async {
    await HabitStateRepository(db).upsert(_active());
    HabitState? prior;
    await run(tester, (ref) async {
      prior = await setAsideHabit(ref, 'sleep-window');
    });

    final row = await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(row!.status, HabitStatus.paused);
    expect(row.activatedAt, DateTime(2026, 1, 2));
    expect(row.triggerAnchorOverride, 'wake');
    expect(row.reminderEnabled, isTrue);
    expect(prior, _active());
  });

  testWidgets('restoring the prior row undoes a transition exactly',
      (tester) async {
    await HabitStateRepository(db).upsert(_active());
    await run(tester, (ref) async {
      final prior = await graduateHabit(ref, 'sleep-window');
      await restoreHabitState(ref, 'sleep-window', prior);
    });
    expect(await HabitStateRepository(db).byInterventionId('sleep-window'),
        _active());
  });

  testWidgets('undoing the first transition of a never-touched habit removes '
      'its row', (tester) async {
    await run(tester, (ref) async {
      final prior = await activateHabit(ref, 'sleep-window');
      expect(prior, isNull);
      await restoreHabitState(ref, 'sleep-window', prior);
    });
    expect(await HabitStateRepository(db).byInterventionId('sleep-window'),
        isNull);
  });

  Future<void> pumpDetail(WidgetTester tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => UndoHost(child: child!),
        home: const InterventionDetailScreen(id: 'sleep-window'),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('Activate on the detail screen offers an Undo that does not '
      'expire, and Undo puts the habit back', (tester) async {
    await pumpDetail(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();
    expect(find.byType(OhUndoBar), findsOneWidget);
    expect(find.textContaining('on your Today list'), findsOneWidget);

    // No timer: an hour later the offer is still there.
    await tester.pump(const Duration(hours: 1));
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await HabitStateRepository(db).byInterventionId('sleep-window'),
        isNull);
    expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);
  });

  testWidgets('an active habit can be set aside from its detail screen, with '
      'Undo', (tester) async {
    await HabitStateRepository(db).upsert(_active());
    await pumpDetail(tester);

    expect(find.text('Active now'), findsOneWidget);
    await tester.tap(find.widgetWithText(OutlinedButton, 'Set aside'));
    await tester.pumpAndSettle();

    expect((await HabitStateRepository(db).byInterventionId('sleep-window'))!
        .status, HabitStatus.paused);
    // A set-aside habit says so, and can be taken up again.
    expect(find.text('Set aside for now'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(await HabitStateRepository(db).byInterventionId('sleep-window'),
        _active());
  });

  testWidgets('Undo still works after the screen that made the change is '
      'gone', (tester) async {
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: MaterialApp(
        navigatorKey: nav,
        theme: AppTheme.light,
        builder: (context, child) => UndoHost(child: child!),
        home: const Scaffold(body: Text('HOME')),
      ),
    ));
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const InterventionDetailScreen(id: 'sleep-window')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(await HabitStateRepository(db).byInterventionId('sleep-window'),
        isNull);
  });

  for (final (name, change) in <(String, Future<HabitState?> Function(WidgetRef))>[
    ('set aside', (ref) => setAsideHabit(ref, 'sleep-window')),
    ('graduated', (ref) => graduateHabit(ref, 'sleep-window')),
    ('queued', (ref) => queueHabit(ref, 'sleep-window')),
  ]) {
    testWidgets('a habit $name stops sending its daily reminder, and '
        'activating it again brings the reminder back', (tester) async {
      await ProfileRepository(db).save(const Profile(
        wakeMinutes: 7 * 60,
        bedMinutes: 22 * 60,
        goal: Goal.general,
        pace: Pace.moderate,
        onboarded: true,
      ));
      await LocalSettingsRepository(db).setRemindersEnabled(true);
      await HabitStateRepository(db).upsert(_active());
      final fake = FakeNotificationService();
      // A wake-anchored habit rides in the batched morning cue.
      bool planned() => (fake.lastPlan ?? const []).any((n) =>
          n.id == 'habit-sleep-window' || n.body.contains('sleep-window'));

      await tester.pumpWidget(ProviderScope(
        overrides: adoptionOverrides(db: db, notifications: fake),
        child: _Runner((ref) async {
          await change(ref);
        }),
      ));
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();
      expect(fake.lastPlan, isNotNull, reason: 'the change re-plans');
      expect(planned(), isFalse);

      await tester.pumpWidget(ProviderScope(
        overrides: adoptionOverrides(db: db, notifications: fake),
        child: _Runner((ref) async {
          await activateHabit(ref, 'sleep-window');
        }),
      ));
      await tester.tap(find.text('run'));
      await tester.pumpAndSettle();
      expect(planned(), isTrue);
    });
  }
}
