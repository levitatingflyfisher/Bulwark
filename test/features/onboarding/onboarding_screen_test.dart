import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/onboarding/presentation/onboarding_screen.dart';
import 'package:bulwark/main.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adoption_harness.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  testWidgets('a fresh install lands on onboarding via the redirect',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: const BulwarkApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to Bulwark'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsWidgets);
  });

  testWidgets('the disclaimer is standing text, not a tick that holds '
      'Continue hostage (persona T1)', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: const BulwarkApp(),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('not medical advice'), findsWidgets);
    expect(find.byType(Checkbox), findsNothing);
    expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Continue'))
            .onPressed,
        isNotNull);
  });

  testWidgets('happy path: welcome → map → reveal → land on Home',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db),
      child: const BulwarkApp(),
    ));
    await tester.pumpAndSettle();

    // Step 1: read and continue.
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    // Step 2: accept the defaults and reveal the starter pack.
    expect(find.text('Map your day'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'See your starter pack'));
    await tester.pumpAndSettle();

    // Step 3: the deterministic starter pack for the general/moderate default.
    expect(find.widgetWithText(FilledButton, 'Start tonight'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Start tonight'));
    await tester.pumpAndSettle();

    // Landed on Home with the activated habits and a check-in affordance.
    expect(find.widgetWithText(FilledButton, 'Check in'), findsOneWidget);
    expect(find.text('do sleep-window'), findsOneWidget);

    // The profile persisted as onboarded, and two habits went active.
    final profile = await ProfileRepository(db).get();
    expect(profile?.onboarded, isTrue);
    expect(profile?.goal, Goal.general);
    final active = await HabitStateRepository(db).activeStates();
    expect(active.map((s) => s.interventionId).toSet(),
        {'sleep-window', 'eat-protein'});
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('onboarding step 2 holds at 320dp width and ${scale}x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(ProviderScope(
        overrides: adoptionOverrides(db: db),
        child: MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const OnboardingScreen(),
        ),
      ));
      await tester.pumpAndSettle();

      // Advance to the lifestyle-map step, the densest form.
      await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
      await tester.pumpAndSettle();

      expect(find.text('Map your day'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
