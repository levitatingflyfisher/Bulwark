import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/settings/presentation/settings_screen.dart';
import 'package:bulwark/shared/theme/app_palette.dart';
import 'package:bulwark/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

import '../../support/adoption_harness.dart';
import '../../support/fake_notification_service.dart';

class MockSecureKeyStore extends Mock implements SecureKeyStore {}

/// A ghost-tier (no seed phrase yet) key store — the default state for these
/// tests, matching a fresh install. `BackupSettingsSection` renders its
/// "Set up encrypted backup" / "Restore from backup" tiles from this state.
SecureKeyStore _ghostKeyStore() {
  final store = MockSecureKeyStore();
  when(() => store.readMnemonic()).thenAnswer((_) async => null);
  when(() => store.readSeedAcknowledged()).thenAnswer((_) async => false);
  when(() => store.readLastBackupAt()).thenAnswer((_) async => null);
  return store;
}

/// A key store that already has an acknowledged seed phrase — the heavier
/// "Export backup" + "Remove recovery words" tiles are visible in this state, the
/// widest the backup section gets.
SecureKeyStore _ackedKeyStore() {
  final store = MockSecureKeyStore();
  when(() => store.readMnemonic()).thenAnswer((_) async =>
      'abandon abandon abandon abandon abandon abandon abandon abandon '
      'abandon abandon abandon about');
  when(() => store.readSeedAcknowledged()).thenAnswer((_) async => true);
  when(() => store.readLastBackupAt()).thenAnswer((_) async => null);
  return store;
}

Future<void> _seedProfile(
  AppDatabase db, {
  int? checkIn,
  bool newParent = false,
}) =>
    ProfileRepository(db).save(Profile(
      wakeMinutes: 7 * 60,
      bedMinutes: 22 * 60,
      goal: Goal.general,
      pace: Pace.moderate,
      checkInMinutes: checkIn,
      onboarded: true,
      newParentMode: newParent,
    ));

Widget _app(
  AppDatabase db,
  FakeNotificationService fake, {
  double textScale = 1.0,
  SecureKeyStore? keyStore,
  VaultStore? vault,
}) {
  final router = GoRouter(
    initialLocation: '/settings',
    routes: [
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
      GoRoute(
          path: '/about', builder: (_, __) => const Scaffold(body: Text('ABOUT'))),
      GoRoute(
          path: '/onboarding',
          builder: (_, __) => const Scaffold(body: Text('ONBOARDING'))),
    ],
  );
  return ProviderScope(
    overrides: [
      ...adoptionOverrides(db: db, notifications: fake),
      // sanctuary_backup_ui's providers throw by default until overridden —
      // every widget test that renders SettingsScreen now reaches
      // BackupSettingsSection, so these need a real (fake) auth/backup
      // stack, not just the adoption-feature overrides above.
      secureKeyStoreProvider.overrideWithValue(keyStore ?? _ghostKeyStore()),
      cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
      sanctuaryBackupConfigProvider.overrideWithValue(
        const SanctuaryBackupConfig(
          appId: 'bulwark',
          aadContext: 'bulwark-backup/v1',
          appDisplayName: 'Bulwark',
        ),
      ),
      backupSerializerProvider.overrideWithValue(FakeBackupSerializer()),
      backupReminderStoreProvider
          .overrideWithValue(InMemoryBackupReminderStore()),
      vaultStoreProvider.overrideWithValue(vault ?? InMemoryVaultStore()),
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

/// A tall viewport so the whole settings list is within the build/cache extent —
/// otherwise a ListView lazily skips building off-screen tiles and finders for
/// them return nothing.
void _tallView(WidgetTester tester) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = const Size(420, 2600);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  late AppDatabase db;
  late FakeNotificationService fake;

  setUp(() {
    db = memoryDatabase();
    fake = FakeNotificationService();
  });
  tearDown(() => db.close());

  testWidgets('editing a setting persists and re-plans reminders',
      (tester) async {
    _tallView(tester);
    await _seedProfile(db, newParent: false);
    await tester.pumpWidget(_app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(SwitchListTile, 'New Parent Mode'));
    await tester.pumpAndSettle();

    final profile = await ProfileRepository(db).get();
    expect(profile?.newParentMode, isTrue);
    expect(fake.rescheduleCalls, isNotEmpty); // wiring fired
  });

  testWidgets('clearing the check-in reminder sets it back to no-reminder',
      (tester) async {
    _tallView(tester);
    await _seedProfile(db, checkIn: 20 * 60);
    await tester.pumpWidget(_app(db, fake));
    await tester.pumpAndSettle();

    // Only the check-in tile has a value set, so there's a single Clear.
    expect(find.byTooltip('Clear'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    final profile = await ProfileRepository(db).get();
    expect(profile?.checkInMinutes, isNull);
  });

  testWidgets('About link navigates to the About screen', (tester) async {
    _tallView(tester);
    await _seedProfile(db);
    await tester.pumpWidget(_app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('About Bulwark'));
    await tester.pumpAndSettle();
    expect(find.text('ABOUT'), findsOneWidget);
  });

  testWidgets('erase confirms, wipes data, cancels reminders, and returns '
      'to onboarding', (tester) async {
    _tallView(tester);
    await _seedProfile(db);
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'a',
      status: HabitStatus.active,
      createdAt: DateTime(2026, 1, 1),
    ));
    await tester.pumpWidget(_app(db, fake));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erase all data'));
    await tester.pumpAndSettle();

    // The confirmation's buttons answer its question (writing-is-designing
    // -10), and the destructive one is clay with an icon, never red.
    expect(find.text('Erase all data?'), findsOneWidget);
    expect(find.textContaining('no copy to restore'), findsOneWidget);
    expect(find.text('Keep my data'), findsOneWidget);
    final confirm = find.ancestor(
        of: find.text('Erase everything'),
        matching: find.bySubtype<FilledButton>());
    expect(confirm, findsOneWidget);
    final bg = tester
        .widget<FilledButton>(confirm)
        .style!
        .backgroundColor!
        .resolve(<WidgetState>{});
    expect(bg, BulwarkPalette.light.clay);
    await tester.tap(confirm);
    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(await ProfileRepository(db).get(), isNull);
    expect(await HabitStateRepository(db).getAll(), isEmpty);
    expect(fake.lastPlan, isEmpty); // reminders cancelled
  });

  testWidgets('with recovery words, erase puts a safety copy in Previous '
      'backups first and says so', (tester) async {
    _tallView(tester);
    await _seedProfile(db);
    final vault = InMemoryVaultStore();
    await tester.pumpWidget(
        _app(db, fake, keyStore: _ackedKeyStore(), vault: vault));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erase all data'));
    await tester.pumpAndSettle();
    expect(find.textContaining('safety copy goes into Previous backups'),
        findsOneWidget);
    await tester.tap(find.text('Erase everything'));
    await tester.pumpAndSettle();

    expect(find.text('ONBOARDING'), findsOneWidget);
    expect(await ProfileRepository(db).get(), isNull);
    expect(await vault.list(), hasLength(1));
  });

  testWidgets('if the safety copy fails, nothing is erased', (tester) async {
    _tallView(tester);
    await _seedProfile(db);
    final vault = InMemoryVaultStore()..failNextPut = true;
    await tester.pumpWidget(
        _app(db, fake, keyStore: _ackedKeyStore(), vault: vault));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Erase all data'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erase everything'));
    await tester.pumpAndSettle();

    expect(find.textContaining('nothing was erased'), findsOneWidget);
    expect(find.text('ONBOARDING'), findsNothing);
    expect(await ProfileRepository(db).get(), isNotNull);
  });

  testWidgets('Export tile is labelled unencrypted; the backup section '
      'offers its own encrypted export', (tester) async {
    _tallView(tester);
    await _seedProfile(db);
    await tester.pumpWidget(_app(db, fake));
    await tester.pumpAndSettle();

    expect(find.textContaining('unencrypted'), findsOneWidget);
    expect(find.text('Backup'), findsOneWidget);
    expect(find.text('Set up encrypted backup'), findsOneWidget);
    expect(find.text('Restore from backup'), findsOneWidget);
  });

  testWidgets(
      'the fully set-up backup state (Export + Remove recovery words) renders',
      (tester) async {
    _tallView(tester);
    await _seedProfile(db);
    await tester.pumpWidget(_app(db, fake, keyStore: _ackedKeyStore()));
    await tester.pumpAndSettle();

    expect(find.text('Export backup'), findsOneWidget);
    expect(find.text('Remove recovery words'), findsOneWidget);
    expect(find.text('Set up encrypted backup'), findsNothing);
  });

  for (final scale in [1.0, 3.0]) {
    testWidgets('Settings holds at 320dp width and ${scale}x text',
        (tester) async {
      // Tall so every tile lays out under the 320 width — a short viewport would
      // let a ListView skip building lower tiles, hiding their overflow.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _seedProfile(db, checkIn: 20 * 60);
      await tester.pumpWidget(_app(db, fake, textScale: scale));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets(
        'Settings holds at 320dp width and ${scale}x text with the backup '
        'section fully expanded (Export + Remove recovery words)', (tester) async {
      // The widest the backup section gets — Export, "last backup" subtitle,
      // and the danger-zone Remove recovery words tile all visible at once.
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(320, 4000);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _seedProfile(db, checkIn: 20 * 60);
      await tester.pumpWidget(
        _app(db, fake, textScale: scale, keyStore: _ackedKeyStore()),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
