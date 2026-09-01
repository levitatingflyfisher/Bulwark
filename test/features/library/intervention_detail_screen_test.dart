import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/providers.dart';
import 'package:bulwark/features/library/data/content_loader.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/features/library/presentation/intervention_detail_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adoption_harness.dart';
import '../../support/content_builders.dart';

/// A repository whose reads throw, to prove the action buttons recover from a
/// mid-write failure rather than sticking on "busy".
class _ThrowingHabitRepo extends HabitStateRepository {
  _ThrowingHabitRepo(super.db);
  @override
  Future<HabitState?> byInterventionId(String interventionId) async =>
      throw StateError('write failed');
}

/// A stateless (no-DB) harness: the library is fixed and no habit has any state.
Widget _detail(String id, ContentLibrary library, {double textScale = 1.0}) =>
    ProviderScope(
      overrides: [
        contentLibraryProvider.overrideWith((ref) => library),
        habitStatesByIdProvider
            .overrideWith((ref) async => <String, HabitState>{}),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: InterventionDetailScreen(id: id),
      ),
    );

void main() {
  testWidgets('an asNeeded item is reference-only (no Activate)',
      (tester) async {
    final library = libraryOf([intervention(id: 'zinc', anchor: Anchor.asNeeded)]);
    await tester.pumpWidget(_detail('zinc', library));
    await tester.pumpAndSettle();

    expect(find.textContaining('Reference only'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Activate'), findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Add to queue'), findsNothing);
  });

  testWidgets('an activatable item offers Activate and Add to queue',
      (tester) async {
    final library = libraryOf([intervention(id: 'sleep-window')]);
    await tester.pumpWidget(_detail('sleep-window', library));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(FilledButton, 'Activate'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Add to queue'), findsOneWidget);
    expect(find.textContaining('not medical advice'), findsOneWidget);
  });

  testWidgets('shows safety and shopping criteria when present', (tester) async {
    final library = libraryOf([
      intervention(
        id: 'acv',
        shopping: const Shopping(
          item: 'Apple cider vinegar',
          criteria: 'any ACV; always dilute',
          recurring: true,
          where: ShopWhere.grocery,
        ),
        safety: 'Dilute in water to protect enamel.',
      ),
    ]);
    await tester.pumpWidget(_detail('acv', library));
    await tester.pumpAndSettle();

    expect(find.text('Apple cider vinegar'), findsOneWidget);
    expect(find.textContaining('always dilute'), findsOneWidget);
    expect(find.textContaining('protect enamel'), findsOneWidget);
    expect(find.text('Good to know'), findsOneWidget);
  });

  testWidgets('Activate writes an active HabitState', (tester) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final library = libraryOf([intervention(id: 'sleep-window')]);

    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db, library: library),
      child: const MaterialApp(
        home: InterventionDetailScreen(id: 'sleep-window'),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();

    final state = await HabitStateRepository(db).byInterventionId('sleep-window');
    expect(state, isNotNull);
    expect(state!.status, HabitStatus.active);
    expect(state.activatedAt, isNotNull);
  });

  testWidgets('Activate re-enables the button when the write throws',
      (tester) async {
    final db = memoryDatabase();
    addTearDown(db.close);
    final library = libraryOf([intervention(id: 'sleep-window')]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        contentLibraryProvider.overrideWith((ref) => library),
        habitStatesByIdProvider
            .overrideWith((ref) async => <String, HabitState>{}),
        habitStateRepositoryProvider
            .overrideWithValue(_ThrowingHabitRepo(db)),
      ],
      child: const MaterialApp(
        home: InterventionDetailScreen(id: 'sleep-window'),
      ),
    ));
    await tester.pumpAndSettle();

    FilledButton activateButton() => tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Activate'));
    expect(activateButton().onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Activate'));
    await tester.pumpAndSettle();

    // The throw must leave the button usable again, not stuck disabled, and
    // surface a calm message rather than an uncaught error.
    expect(activateButton().onPressed, isNotNull);
    expect(find.textContaining('That didn’t save.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('Detail holds at 320dp and ${scale}x text', (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final library = libraryOf([
        intervention(
          id: 'acv',
          shopping: const Shopping(
            item: 'Apple cider vinegar',
            criteria: 'any ACV; always dilute in water',
            recurring: true,
            where: ShopWhere.grocery,
          ),
          safety: 'Dilute in water and consider a straw to protect enamel.',
          details:
              'A longer paragraph of detail that must wrap comfortably even at '
              'triple text scale on a very narrow phone screen without any '
              'overflow.',
        ),
      ]);
      await tester.pumpWidget(_detail('acv', library, textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
