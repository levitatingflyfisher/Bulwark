import 'package:bulwark/core/providers/core_providers.dart';
import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/sanctuary_backup/backup_config.dart';
import 'package:bulwark/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:bulwark/main.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The silent freshness snapshot (BACKUP_RETENTION_SPEC §3): when a backup
/// key exists and the newest vault snapshot is older than 7 days (or there
/// is none), booting the app takes one — post-frame, fire-and-forget.
/// This pins the wiring: BulwarkApp must actually call
/// runStartupMaintenance after the first frame.
void main() {
  testWidgets(
      'first frame triggers a freshness snapshot into the vault '
      'when a backup key exists', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final vault = InMemoryVaultStore();
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWith((ref) => db),
          secureKeyStoreProvider.overrideWithValue(InMemorySecureKeyStore(
            mnemonic: 'abandon abandon abandon abandon abandon abandon '
                'abandon abandon abandon abandon abandon about',
            acknowledged: true,
          )),
          cryptoServiceProvider.overrideWithValue(FakeCryptoService()),
          vaultStoreProvider.overrideWithValue(vault),
          sanctuaryBackupConfigProvider.overrideWithValue(bulwarkBackupConfig),
          sanctuaryAppDomainProvider.overrideWithValue('bulwark'),
          backupSerializerProvider
              .overrideWith((ref) => BulwarkBackupSerializer(db)),
        ],
        child: const BulwarkApp(),
      ),
    );

    // First frame is built; the post-frame callback has been scheduled and
    // fired. The maintenance chain (auth load -> dumpAll -> seal -> vault
    // put) mixes microtask futures with real async work, so interleave
    // fake-clock pumps with short real-time waits (tester.runAsync) until
    // the fire-and-forget future lands.
    var entries = await vault.list();
    for (var i = 0; i < 50 && entries.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)));
      entries = await vault.list();
    }

    expect(entries, hasLength(1),
        reason: 'boot must leave exactly one freshness snapshot');

    // Tear the app down and let any straggler timers (router/animation
    // internals) expire so the binding's timersPending invariant holds.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(minutes: 1));
  });
}
