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
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    await tester.pumpAndSettle();

    expect(find.text('sleep-window'), findsOneWidget); // rct
    expect(find.text('eat-protein'), findsNothing); // observational
    expect(find.text('box-breathing'), findsNothing); // mechanistic
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

      // Open the facet sheet — the Clear/Apply row is what overflowed at 320 dp.
      await tester.tap(find.text('Filters'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Clear'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
