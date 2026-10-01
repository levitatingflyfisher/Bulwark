import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/features/settings/domain/user_prefs.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_flutter/lucide_flutter.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/testing.dart';

import '../../support/adoption_harness.dart';
import '../../support/content_builders.dart';

ActiveHabit _habit(String id) => ActiveHabit(
      state: HabitState(
        interventionId: id,
        status: HabitStatus.active,
        activatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ),
      intervention: intervention(id: id),
    );

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.general,
  pace: Pace.moderate,
  onboarded: true,
);

Widget _home({
  required List<ActiveHabit> habits,
  List<ActiveHabit> eligible = const [],
  Profile? profile = _profile,
  double textScale = 1.0,
  SecureKeyStore? keyStore,
  List<Checkin> checkins = const [],
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/library',
          builder: (_, __) => const Scaffold(body: Text('LIBRARY'))),
      GoRoute(
          path: '/intervention/:id',
          builder: (_, st) =>
              Scaffold(body: Text('DETAIL ${st.pathParameters['id']}'))),
    ],
  );
  return ProviderScope(
    overrides: [
      activeHabitsProvider.overrideWith((ref) async => habits),
      graduationEligibleProvider.overrideWith((ref) async => eligible),
      profileProvider.overrideWith((ref) async => profile),
      allCheckinsProvider.overrideWith((ref) async => checkins),
      weakTriggerIdsProvider.overrideWith((ref) async => const {}),
      userPrefsProvider.overrideWith((ref) => Stream.value(const UserPrefs())),
      ...backupOverrides(keyStore: keyStore),
    ],
    child: MaterialApp.router(
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
    ),
  );
}

void main() {
  testWidgets('day one teaches the loop: until the first check-in, Home says '
      'what the daily job is', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your first day'), findsOneWidget);
  });

  testWidgets('after the first check-in the day-one line is gone',
      (tester) async {
    await tester.pumpWidget(_home(
      habits: [_habit('sleep-window')],
      checkins: [
        Checkin(
            interventionId: 'sleep-window',
            date: DateTime(2026, 1, 2),
            result: CheckinResult.did),
      ],
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your first day'), findsNothing);
  });

  testWidgets('Home shows the dismissible Finish setup line until backup is '
      'set up', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();
    expect(find.textContaining("Backup isn't set up"), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await tester.pumpAndSettle();
    expect(find.textContaining("Backup isn't set up"), findsNothing);
  });

  testWidgets('Home draws no setup line once backup is finished',
      (tester) async {
    await tester.pumpWidget(_home(
      habits: [_habit('sleep-window')],
      keyStore: InMemorySecureKeyStore(
        mnemonic: 'abandon abandon abandon abandon abandon abandon abandon '
            'abandon abandon abandon abandon about',
        acknowledged: true,
        lastBackupAt: DateTime.now(),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining("Backup isn't set up"), findsNothing);
    expect(find.textContaining('Finish backup setup'), findsNothing);
  });

  testWidgets('renders an active habit card with its evidence tag',
      (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();

    expect(find.text('sleep-window'), findsOneWidget); // title
    expect(find.text('do sleep-window'), findsOneWidget); // action
    expect(find.textContaining('Evidence:'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Check in'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });

  // The card cut the mechanism at two lines with an ellipsis and no way to
  // the rest (audit top finding 7); Library rows with the same cut open the
  // detail. The card now does too.
  testWidgets('tapping a habit card opens its detail', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('because'));
    await tester.pumpAndSettle();
    expect(find.text('DETAIL sleep-window'), findsOneWidget);
  });

  testWidgets('shows the calm empty state when nothing is active',
      (tester) async {
    await tester.pumpWidget(_home(habits: const []));
    await tester.pumpAndSettle();

    expect(find.text('Your wall starts with one stone.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Browse the Library'),
        findsOneWidget);
    // No check-in affordance when there's nothing to check in on.
    expect(find.widgetWithText(FilledButton, 'Check in'), findsNothing);
  });

  testWidgets('the empty-state Browse button navigates to the Library',
      (tester) async {
    await tester.pumpWidget(_home(habits: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(OutlinedButton, 'Browse the Library'));
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // Sections live in the bottom bar now (core/router/section_bar_test);
  // Home's More menu holds the two places that are not sections.
  testWidgets('the More menu routes to Queue and Shopping', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('More'));
    await tester.pumpAndSettle();
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Library'), findsNothing);
  });

  testWidgets('an eligible active habit shows the graduation nudge',
      (tester) async {
    await tester.pumpWidget(_home(
      habits: [_habit('sleep-window')],
      eligible: [_habit('sleep-window')],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('looks automatic now'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Set it into my wall'),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Not yet'), findsOneWidget);
  });

  testWidgets('a non-eligible active habit shows no nudge', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('looks automatic now'), findsNothing);
  });

  testWidgets('"Not yet" dismisses the nudge without graduating',
      (tester) async {
    await tester.pumpWidget(_home(
      habits: [_habit('sleep-window')],
      eligible: [_habit('sleep-window')],
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(TextButton, 'Not yet'));
    await tester.pumpAndSettle();

    expect(find.textContaining('looks automatic now'), findsNothing);
    // The habit itself is untouched — still on Today.
    expect(find.text('sleep-window'), findsOneWidget);
  });

  testWidgets(
      'confirming the nudge graduates the habit and it leaves Today for the wall',
      (tester) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final now = DateTime.now();
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'sleep-window',
      status: HabitStatus.active,
      activatedAt: now.subtract(const Duration(days: 30)),
      createdAt: now.subtract(const Duration(days: 30)),
    ));
    final ci = CheckinRepository(db);
    for (var i = 0; i < 8; i++) {
      await ci.upsert(Checkin(
          interventionId: 'sleep-window',
          date: now.subtract(Duration(days: i)),
          result: CheckinResult.did));
    }
    for (var i = 8; i < 10; i++) {
      await ci.upsert(Checkin(
          interventionId: 'sleep-window',
          date: now.subtract(Duration(days: i)),
          result: CheckinResult.forgot));
    }

    await tester.pumpWidget(ProviderScope(
      overrides: [...adoptionOverrides(db: db), ...backupOverrides()],
      child: MaterialApp(
        builder: (context, child) => UndoHost(child: child!),
        home: const HomeScreen(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('looks automatic now'), findsOneWidget);
    // The offer says what graduating buys (audit badass-users-04), and is not
    // dressed as a badge.
    expect(find.textContaining('weekly check'), findsOneWidget);
    expect(find.byIcon(LucideIcons.sparkles), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Set it into my wall'));
    await tester.pumpAndSettle();

    // Persisted as graduated, with a graduatedAt stamp.
    final row = await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(row!.status, HabitStatus.graduated);
    expect(row.graduatedAt, isNotNull);
    // Off Today…
    expect(find.text('do sleep-window'), findsNothing);
    // …and onto the wall's data source (graduated habits).
    final graduated =
        await HabitStateRepository(db).byStatus(HabitStatus.graduated);
    expect(graduated.map((s) => s.interventionId), contains('sleep-window'));
    // The receipt says what it freed, and nothing earned can vanish by
    // accident: Undo is offered, with no timer.
    expect(find.textContaining('One fewer daily check-in'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    // The card that asked is gone; Undo must not need it.
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect((await HabitStateRepository(db).byInterventionId('sleep-window'))!
        .status, HabitStatus.active);
  });

  testWidgets('the graduation nudge holds at 320dp width and 3.0x text',
      (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(320, 740);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_home(
      habits: [_habit('sleep-window')],
      eligible: [_habit('sleep-window')],
      textScale: 3.0,
    ));
    await tester.pumpAndSettle();

    // At 3× the card is taller than the viewport, so the ListView lazily leaves
    // the nudge un-inflated; scroll it in to actually lay it out at 320 dp and
    // catch any horizontal overflow.
    await tester.scrollUntilVisible(
      find.textContaining('looks automatic now'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('looks automatic now'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('Home holds at 320dp width and ${scale}x text (cards)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_home(
        habits: [_habit('sleep-window'), _habit('eat-protein')],
        textScale: scale,
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('Home holds at 320dp width and ${scale}x text (empty)',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_home(habits: const [], textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
