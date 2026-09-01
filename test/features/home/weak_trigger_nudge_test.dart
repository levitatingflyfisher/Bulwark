import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/home/presentation/home_screen.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:bulwark/shared/widgets/undo_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/adoption_harness.dart';

/// "Forgot" used to be a confession that bought nothing: forgotRate was
/// computed and read nowhere (audit writing-is-designing-09). Now a run of
/// forgets offers to hang the habit off a different moment.
void main() {
  late AppDatabase db;
  setUp(() => db = memoryDatabase());
  tearDown(() => db.close());

  Future<void> seed(WidgetTester tester, {int forgets = 3}) async {
    await tester.runAsync(() async {
      await ProfileRepository(db).save(const Profile(
        wakeMinutes: 7 * 60,
        bedMinutes: 22 * 60,
        goal: Goal.general,
        pace: Pace.moderate,
        onboarded: true,
      ));
      await HabitStateRepository(db).upsert(HabitState(
        interventionId: 'sleep-window',
        status: HabitStatus.active,
        activatedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
      ));
      final today = DateTime.now().dateOnly;
      for (var i = 1; i <= forgets; i++) {
        await CheckinRepository(db).upsert(Checkin(
            interventionId: 'sleep-window',
            date: today.subtract(Duration(days: i)),
            result: CheckinResult.forgot));
      }
    });
  }

  Future<void> pumpHome(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(420, 1600);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [...adoptionOverrides(db: db), ...backupOverrides()],
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => UndoHost(child: child!),
        home: const HomeScreen(),
      ),
    ));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pumpAndSettle();
  }

  testWidgets('no nudge for two forgets', (tester) async {
    await seed(tester, forgets: 2);
    await pumpHome(tester);
    expect(find.text('Change the moment'), findsNothing);
  });

  testWidgets('three forgets offer a new moment; choosing one re-anchors the '
      'habit, with Undo', (tester) async {
    await seed(tester);
    await pumpHome(tester);

    expect(find.textContaining('Forgot 3 times'), findsOneWidget);
    await tester.tap(find.text('Change the moment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('At bedtime'));
    await tester.pumpAndSettle();

    final row = await tester.runAsync(
        () => HabitStateRepository(db).byInterventionId('sleep-window'));
    expect(row!.triggerAnchorOverride, 'bed');
    expect(row.status, HabitStatus.active);
    // The card now says the moment it hangs off, and the offer is gone.
    expect(find.text('At bedtime'), findsOneWidget);
    expect(find.text('Change the moment'), findsNothing);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    final back = await tester.runAsync(
        () => HabitStateRepository(db).byInterventionId('sleep-window'));
    expect(back!.triggerAnchorOverride, isNull);
  });

  testWidgets('Not now waves the offer off until new forgets arrive',
      (tester) async {
    await seed(tester);
    await pumpHome(tester);

    await tester.tap(find.text('Not now'));
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pumpAndSettle();
    expect(find.text('Change the moment'), findsNothing);

    // A fresh start of the same screen still remembers.
    await tester.pumpWidget(const SizedBox());
    await pumpHome(tester);
    expect(find.text('Change the moment'), findsNothing);
  });
}
