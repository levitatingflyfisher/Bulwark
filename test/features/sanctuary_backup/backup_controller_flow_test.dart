import 'dart:typed_data';

import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_auth_core/sanctuary_auth_core.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';
import 'package:sanctuary_backup_ui/testing.dart';

/// End-to-end net for the wiring: Bulwark's real serializer + the real
/// crypto core, driven through the package's BackupController with
/// Bulwark's actual config (appId 'bulwark', appDomain 'bulwark',
/// aadContext 'bulwark-backup/v1'). The controller's own generic behaviour
/// (RestoreOutcome mapping, seed flows) is unit-tested in the package; this
/// proves Bulwark's wiring works against the real sanctuary_auth_core
/// (SANCTUARY-BRIEF §4.W2 deliverable 5).
const _validPhrase =
    'abandon abandon abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon about';

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.sleep,
  pace: Pace.moderate,
  onboarded: true,
);

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  ProviderContainer makeContainer({
    required AppDatabase database,
    required SecureKeyStore store,
    void Function(Ref ref)? onAfterRestore,
  }) {
    final c = ProviderContainer(overrides: [
      secureKeyStoreProvider.overrideWithValue(store),
      cryptoServiceProvider.overrideWithValue(const DefaultCryptoService()),
      // v0.2.0's mandatory pre-restore snapshot writes to the vault before
      // any restore; without an in-memory store the platform store fails in
      // tests and every restore short-circuits as snapshotFailed.
      vaultStoreProvider.overrideWithValue(InMemoryVaultStore()),
      backupSerializerProvider
          .overrideWith((ref) => BulwarkBackupSerializer(database)),
      sanctuaryBackupConfigProvider.overrideWithValue(
        SanctuaryBackupConfig(
          appId: 'bulwark',
          aadContext: 'bulwark-backup/v1',
          appDisplayName: 'Bulwark',
          onAfterRestore: onAfterRestore,
        ),
      ),
      // Bulwark is a new app: isolates its key material rather than
      // inheriting Lullaby's legacy null-domain derivation.
      sanctuaryAppDomainProvider.overrideWithValue('bulwark'),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  test('export -> restore round-trips Bulwark data through the controller',
      () async {
    await ProfileRepository(db).save(_profile);
    await HabitStateRepository(db).upsert(HabitState(
      interventionId: 'morning-sunlight',
      status: HabitStatus.active,
      createdAt: DateTime(2026, 3, 1),
    ));

    final src = makeContainer(
      database: db,
      store: InMemorySecureKeyStore(
          mnemonic: _validPhrase, acknowledged: true),
    );
    final result =
        await src.read(backupControllerProvider.notifier).exportBackup();
    expect(result, isNotNull);
    expect(result!.filename,
        matches(RegExp(r'^bulwark-backup-\d{4}-\d{2}-\d{2}\.ohbk$')));
    // OHBK magic bytes.
    expect(result.bytes.sublist(0, 4), equals([0x4F, 0x48, 0x42, 0x4B]));

    // Restore into a fresh DB with a fresh (empty) keychain, by phrase.
    final db2 = AppDatabase(NativeDatabase.memory());
    addTearDown(db2.close);
    var refreshed = false;
    final dst = makeContainer(
      database: db2,
      store: InMemorySecureKeyStore(),
      onAfterRestore: (_) => refreshed = true,
    );
    final outcome = await dst
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(result.bytes, _validPhrase);

    expect(outcome, RestoreOutcome.success);
    expect(refreshed, isTrue, reason: 'onAfterRestore must fire');

    final habits = await HabitStateRepository(db2).getAll();
    expect(habits, hasLength(1));
    expect(habits.first.interventionId, 'morning-sunlight');
    final profile = await ProfileRepository(db2).get();
    expect(profile, _profile);
  });

  test('a non-OHBK blob restores as corruptFile', () async {
    final c = makeContainer(database: db, store: InMemorySecureKeyStore());
    final outcome = await c
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(Uint8List.fromList(List.filled(64, 0)), _validPhrase);
    expect(outcome, RestoreOutcome.corruptFile);
  });

  test('a backup made under a different appDomain does not decrypt here',
      () async {
    // Same phrase, but exported under appDomain null (Lullaby-style legacy
    // derivation) instead of 'bulwark' — proves the per-app key isolation
    // (SANCTUARY-BRIEF §2.1) actually binds.
    final legacyContainer = ProviderContainer(overrides: [
      secureKeyStoreProvider.overrideWithValue(
          InMemorySecureKeyStore(mnemonic: _validPhrase, acknowledged: true)),
      cryptoServiceProvider.overrideWithValue(const DefaultCryptoService()),
      vaultStoreProvider.overrideWithValue(InMemoryVaultStore()),
      backupSerializerProvider.overrideWith((ref) => BulwarkBackupSerializer(db)),
      sanctuaryBackupConfigProvider.overrideWithValue(
        const SanctuaryBackupConfig(
          appId: 'bulwark',
          aadContext: 'bulwark-backup/v1',
          appDisplayName: 'Bulwark',
        ),
      ),
      // appDomain left at its null default on purpose.
    ]);
    addTearDown(legacyContainer.dispose);

    final legacyExport = await legacyContainer
        .read(backupControllerProvider.notifier)
        .exportBackup();
    expect(legacyExport, isNotNull);

    final bulwarkDomainContainer =
        makeContainer(database: db, store: InMemorySecureKeyStore());
    final outcome = await bulwarkDomainContainer
        .read(backupControllerProvider.notifier)
        .restoreWithPhrase(legacyExport!.bytes, _validPhrase);

    expect(outcome, RestoreOutcome.wrongPhrase);
  });
}
