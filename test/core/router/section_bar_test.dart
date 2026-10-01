import 'package:bulwark/core/router/app_router.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adoption_harness.dart';

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.general,
  pace: Pace.moderate,
  onboarded: true,
);

/// Navigation was one hamburger on Home holding five destinations; nothing
/// else carried the sections or said where you were, so Library to Progress
/// was back, summon, choose (audit top finding 5). Ruling: a persistent
/// worded bottom bar, Today · Progress · Library · Settings, current marked.
void main() {
  Future<void> pumpApp(WidgetTester tester, {Size size = const Size(360, 800),
      double scale = 1.0}) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    final db = memoryDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...adoptionOverrides(db: db),
        ...backupOverrides(),
        profileProvider.overrideWith((ref) async => _profile),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: ref.watch(appRouterProvider),
          builder: (c, child) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder inNav(String w) =>
      find.descendant(of: find.byType(NavigationBar), matching: find.text(w));

  testWidgets('every section is one tap away, by name, with the current one '
      'marked', (tester) async {
    await pumpApp(tester);
    for (final w in ['Today', 'Progress', 'Library', 'Settings']) {
      expect(inNav(w), findsOneWidget, reason: w);
    }
    NavigationBar bar() => tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar().selectedIndex, 0);

    await tester.tap(inNav('Progress'));
    await tester.pumpAndSettle();
    expect(bar().selectedIndex, 1);
    expect(find.widgetWithText(AppBar, 'Progress'), findsOneWidget);

    // Library to Progress is one tap, not back-summon-choose.
    await tester.tap(inNav('Library'));
    await tester.pumpAndSettle();
    expect(bar().selectedIndex, 2);
    await tester.tap(inNav('Progress'));
    await tester.pumpAndSettle();
    expect(bar().selectedIndex, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar holds at 320 dp and 3x text', (tester) async {
    await pumpApp(tester, size: const Size(320, 800), scale: 3.0);
    expect(tester.takeException(), isNull);
    expect(find.byType(NavigationBar), findsOneWidget);
  });
}
