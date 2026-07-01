import 'package:bulwark/core/storage/app_database.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/shopping_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/presentation/shopping_screen.dart';
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/adoption_harness.dart';
import '../../../support/content_builders.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> activate(String id) => HabitStateRepository(db).upsert(HabitState(
        interventionId: id,
        status: HabitStatus.active,
        activatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ));

  Future<void> pump(WidgetTester tester, ContentLibrary library,
      {double textScale = 1.0}) async {
    await tester.pumpWidget(ProviderScope(
      overrides: adoptionOverrides(db: db, library: library),
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const ShoppingScreen(),
      ),
    ));
    await tester.pumpAndSettle();
  }

  final shoppable = libraryOf([
    intervention(
      id: 'acv',
      shopping: const Shopping(
        item: 'Apple cider vinegar',
        criteria: 'any ACV; always dilute',
        recurring: true,
        where: ShopWhere.grocery,
      ),
    ),
  ]);

  testWidgets('derives a grouped need from an active habit', (tester) async {
    await activate('acv');
    await pump(tester, shoppable);

    expect(find.text('Restock'), findsOneWidget); // recurring group
    expect(find.text('Grocery'), findsOneWidget); // where subheader
    expect(find.text('Apple cider vinegar'), findsOneWidget);
  });

  testWidgets('checking the box persists a purchase', (tester) async {
    await activate('acv');
    await pump(tester, shoppable);

    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();

    final state = await ShoppingRepository(db).byInterventionId('acv');
    expect(state, isNotNull);
    expect(state!.purchased, isTrue);
  });

  testWidgets('shows the calm empty state when nothing needs buying',
      (tester) async {
    final noSupplies = libraryOf([intervention(id: 'sleep-window')]);
    await activate('sleep-window');
    await pump(tester, noSupplies);

    expect(find.text('Nothing to buy.'), findsOneWidget);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('Shopping rows hold at 320dp and ${scale}x text',
        (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 740);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await activate('acv');
      await pump(tester, shoppable, textScale: scale);
      expect(tester.takeException(), isNull);
    });
  }
}
