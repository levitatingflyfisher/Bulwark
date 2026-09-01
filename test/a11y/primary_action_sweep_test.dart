import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/checkin/presentation/checkin_screen.dart';
import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oh_fleet_conformance/oh_fleet_conformance.dart';

import '../support/adoption_harness.dart';

/// The release gate for Bulwark's primary-action screens (C5-primaryScreens):
/// at 360dp x 1.3 text the primary action is on screen and tappable, and at
/// 320dp x 3.0 nothing overflows. Rendered with the real AppTheme, so the
/// fleet type ladder (body 16) is what is measured.
Future<AppDatabase> _seeded(WidgetTester tester) async {
  final db = memoryDatabase();
  await tester.runAsync(() async {
    await ProfileRepository(db).save(const Profile(
      wakeMinutes: 7 * 60,
      bedMinutes: 22 * 60,
      goal: Goal.general,
      pace: Pace.moderate,
      onboarded: true,
    ));
    for (final id in ['sleep-window', 'eat-protein', 'box-breathing']) {
      await HabitStateRepository(db).upsert(HabitState(
        interventionId: id,
        status: HabitStatus.active,
        activatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ));
    }
  });
  return db;
}

Future<void> _load(WidgetTester tester) async {
  await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home: Check in is reachable', (tester) async {
    final db = await _seeded(tester);
    await runPrimaryActionSweep(
      tester,
      pumpScreen: () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [...adoptionOverrides(db: db), ...backupOverrides()],
          child: MaterialApp(theme: AppTheme.light, home: const HomeScreen()),
        ));
        await _load(tester);
      },
      primaryAction: find.widgetWithText(FilledButton, 'Check in'),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });

  testWidgets('Check-in: the first habit\'s "Did it" is reachable',
      (tester) async {
    final db = await _seeded(tester);
    await runPrimaryActionSweep(
      tester,
      pumpScreen: () async {
        await tester.pumpWidget(ProviderScope(
          overrides: [...adoptionOverrides(db: db), ...backupOverrides()],
          child:
              MaterialApp(theme: AppTheme.light, home: const CheckinScreen()),
        ));
        await _load(tester);
      },
      primaryAction: find.widgetWithText(ChoiceChip, 'Did it').first,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(db.close);
  });
}
