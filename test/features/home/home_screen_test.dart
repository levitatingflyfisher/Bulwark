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
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/library',
          builder: (_, __) => const Scaffold(body: Text('LIBRARY'))),
    ],
  );
  return ProviderScope(
    overrides: [
      activeHabitsProvider.overrideWith((ref) async => habits),
      graduationEligibleProvider.overrideWith((ref) async => eligible),
      profileProvider.overrideWith((ref) async => profile),
      userPrefsProvider.overrideWith((ref) => Stream.value(const UserPrefs())),
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

  testWidgets('the nav menu routes to the value screens', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    expect(find.text('Library'), findsOneWidget);
    expect(find.text('Queue'), findsOneWidget);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('Progress'), findsOneWidget);

    await tester.tap(find.text('Library'));
    await tester.pumpAndSettle();
    expect(find.text('LIBRARY'), findsOneWidget);
  });

  testWidgets('an eligible active habit shows the graduation nudge',
      (tester) async {
    await tester.pumpWidget(_home(
      habits: [_habit('sleep-window')],
      eligible: [_habit('sleep-window')],
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('set it into your wall'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Set it into my wall'),
        findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Not yet'), findsOneWidget);
  });

  testWidgets('a non-eligible active habit shows no nudge', (tester) async {
    await tester.pumpWidget(_home(habits: [_habit('sleep-window')]));
    await tester.pumpAndSettle();

    expect(find.textContaining('set it into your wall'), findsNothing);
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

    expect(find.textContaining('set it into your wall'), findsNothing);
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
      overrides: adoptionOverrides(db: db),
      child: const MaterialApp(home: HomeScreen()),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('set it into your wall'), findsOneWidget);
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
      find.textContaining('set it into your wall'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('set it into your wall'), findsOneWidget);
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
