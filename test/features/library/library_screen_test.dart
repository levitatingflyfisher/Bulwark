import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/presentation/library_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/content_builders.dart';

ContentLibrary _library() => libraryOf([
      intervention(
          id: 'sleep-window',
          category: Category.sleep,
          evidence: Evidence.rct),
      intervention(
          id: 'eat-protein',
          category: Category.nutrition,
          evidence: Evidence.observational),
      intervention(
          id: 'box-breathing',
          category: Category.stress,
          evidence: Evidence.mechanistic),
    ]);

const _profile = Profile(
  wakeMinutes: 420,
  bedMinutes: 1350,
  goal: Goal.general,
  pace: Pace.moderate,
  onboarded: true,
);

Widget _screen({double textScale = 1.0}) => ProviderScope(
      overrides: [
        contentLibraryProvider.overrideWith((ref) => _library()),
        profileProvider.overrideWith((ref) async => _profile),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const LibraryScreen(),
      ),
    );

void main() {
  testWidgets('a row\'s action, the sentence that says what the habit is, '
      'reads as body text in full, not as a truncated footnote', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    final action = tester.widget<Text>(find.text('do sleep-window'));
    final theme = AppTheme.light;
    expect(action.maxLines, isNull);
    expect(action.style!.fontSize, theme.textTheme.bodyMedium!.fontSize);
    expect(action.style!.color, theme.colorScheme.onSurface);
  });

  testWidgets('lists every intervention by default', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    expect(find.text('sleep-window'), findsOneWidget);
    expect(find.text('eat-protein'), findsOneWidget);
    expect(find.text('box-breathing'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sleep');
    await tester.pumpAndSettle();

    expect(find.text('sleep-window'), findsOneWidget);
    expect(find.text('eat-protein'), findsNothing);
    expect(find.text('box-breathing'), findsNothing);
  });

  testWidgets('a category chip narrows the list', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilterChip, 'Nutrition'));
    await tester.pumpAndSettle();

    expect(find.text('eat-protein'), findsOneWidget);
    expect(find.text('sleep-window'), findsNothing);
  });

  testWidgets('the facet sheet filters by evidence', (tester) async {
    await tester.pumpWidget(_screen());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Trials only'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Done'));
    await tester.pumpAndSettle();

    expect(find.text('sleep-window'), findsOneWidget); // rct
    expect(find.text('eat-protein'), findsNothing); // observational
    expect(find.text('box-breathing'), findsNothing); // mechanistic
  });

  // The sheet deferred everything to Apply: the list behind it never moved,
  // dragging it away threw the choices out, Clear also reset the category
  // strip it doesn't show, Cost had no neutral choice, and a 4 px dot was
  // the only sign a filter was on (audit top finding 11).
  group('the facet sheet filters live and says what is on', () {
    testWidgets('a choice applies at once and survives dismissing the sheet',
        (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Trials only'));
      await tester.pumpAndSettle();
      // Dismiss without any button (tap the scrim above the sheet).
      await tester.tapAt(const Offset(20, 20));
      await tester.pumpAndSettle();

      expect(find.text('eat-protein'), findsNothing);
      expect(find.text('sleep-window'), findsOneWidget);
    });

    testWidgets('Clear resets only what the sheet shows', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Nutrition'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Trials only'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Clear'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      // The category from the strip stays on.
      expect(find.text('eat-protein'), findsOneWidget);
      expect(find.text('sleep-window'), findsNothing);
    });

    testWidgets('Cost has an Any choice', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      final anyCost = find.byKey(const ValueKey('cost-any'));
      expect(anyCost, findsOneWidget);
      expect(tester.widget<ChoiceChip>(anyCost).selected, isTrue);
    });

    testWidgets('what is on is named on the screen, and removable',
        (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'Trials only'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Done'));
      await tester.pumpAndSettle();

      final on = find.widgetWithText(InputChip, 'Trials only');
      expect(on, findsOneWidget);
      await tester.tap(find.descendant(
          of: on, matching: find.byIcon(Icons.clear)));
      await tester.pumpAndSettle();
      expect(on, findsNothing);
      expect(find.text('eat-protein'), findsOneWidget);
    });
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('Library rows hold at 320dp and ${scale}x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen(textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('the filter sheet holds at 320dp and ${scale}x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_screen(textScale: scale));
      await tester.pumpAndSettle();

      // Open the facet sheet — the Clear/Done row is what overflowed at 320 dp.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
