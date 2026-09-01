import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/features/library/presentation/library_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/adoption_harness.dart';

/// Top-bar actions are an icon plus a short visible word (fleet ruling); a
/// tooltip is never a command's only name. Home's menu was one unlabelled
/// hamburger holding every destination (audit humane-interface-09), and
/// Library's Filters named itself only on hover (dont-make-me-think-08).
void main() {
  Future<void> pump(WidgetTester tester, Widget screen, double width,
      double scale) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 800);
    addTearDown(tester.view.reset);
    final db = memoryDatabase();
    addTearDown(db.close);
    await tester.pumpWidget(ProviderScope(
      overrides: [...adoptionOverrides(db: db), ...backupOverrides()],
      child: MaterialApp(
        theme: AppTheme.light,
        home: screen,
        builder: (c, child) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Finder inBar(String word) => find.descendant(
      of: find.byType(AppBar), matching: find.text(word));

  for (final (width, scale) in [
    (360.0, 1.0),
    (360.0, 1.3),
    (320.0, 2.0),
    (320.0, 3.0),
  ]) {
    testWidgets('Home bar names its menu in words at ${width}dp x$scale',
        (tester) async {
      await pump(tester, const HomeScreen(), width, scale);
      expect(inBar('Menu'), findsOneWidget);
      expect(inBar('Auto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('Library bar names Filters in words at ${width}dp x$scale',
        (tester) async {
      await pump(tester, const LibraryScreen(), width, scale);
      expect(inBar('Filters'), findsOneWidget);
      expect(inBar('Auto'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
