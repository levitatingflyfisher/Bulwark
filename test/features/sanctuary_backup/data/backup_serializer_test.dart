import 'dart:convert';
import 'dart:typed_data';

import 'package:bulwark/core/storage/app_database.dart' hide UserPrefs;
import 'package:bulwark/features/adoption/data/checkin_repository.dart';
import 'package:bulwark/features/adoption/data/habit_state_repository.dart';
import 'package:bulwark/features/adoption/data/profile_repository.dart';
import 'package:bulwark/features/adoption/data/pulse_repository.dart';
import 'package:bulwark/features/adoption/data/shopping_repository.dart';
import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/sanctuary_backup/data/backup_serializer.dart';
import 'package:bulwark/features/settings/data/export_serializer.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

const _profile = Profile(
  wakeMinutes: 7 * 60,
  bedMinutes: 22 * 60,
  goal: Goal.sleep,
  pace: Pace.moderate,
  evidenceThreshold: 1,
  onboarded: true,
);

Future<void> _seedEverything(AppDatabase db) async {
  await ProfileRepository(db).save(_profile);
  await HabitStateRepository(db).upsert(HabitState(
    interventionId: 'morning-sunlight',
    status: HabitStatus.active,
    activatedAt: DateTime(2026, 3, 2, 6, 30),
    createdAt: DateTime(2026, 3, 1, 9),
    reminderEnabled: true,
    triggerAnchorOverride: 'wake',
  ));
  await CheckinRepository(db).upsert(Checkin(
    interventionId: 'morning-sunlight',
    date: DateTime(2026, 3, 3),
    result: CheckinResult.did,
    note: 'felt good',
  ));
  await PulseRepository(db).upsert(Pulse(
    interventionId: 'morning-sunlight',
    weekStart: DateTime(2026, 3, 2),
    result: PulseResult.solid,
  ));
  await ShoppingRepository(db).setPurchased('magnesium',
      purchased: true, purchasedAt: DateTime(2026, 1, 20, 14, 5));
}

Future<void> _expectAllEmpty(AppDatabase db) async {
  expect(await HabitStateRepository(db).getAll(), isEmpty);
  expect(await CheckinRepository(db).getAll(), isEmpty);
  expect(await PulseRepository(db).getAll(), isEmpty);
  expect(await ShoppingRepository(db).getAll(), isEmpty);
  expect(await ProfileRepository(db).get(), isNull);
}

void main() {
  late AppDatabase db;
  late BulwarkBackupSerializer serializer;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    serializer = BulwarkBackupSerializer(db);
  });

  tearDown(() => db.close());

  group('dumpAll', () {
    test('includes the app id, schema version, and every table', () async {
      await _seedEverything(db);
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      expect(json['app'], 'bulwark');
      expect(json['schemaVersion'], BulwarkExport.schemaVersion);
      expect((json['habits'] as List), hasLength(1));
      expect((json['checkins'] as List), hasLength(1));
      expect((json['pulses'] as List), hasLength(1));
      expect((json['shopping'] as List), hasLength(1));
      expect(json['profile'], isNotNull);
    });

    test('on an empty database produces a valid empty payload', () async {
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      expect(json['app'], 'bulwark');
      expect(json['profile'], isNull);
      expect(json['habits'], isEmpty);
      expect(json['checkins'], isEmpty);
      expect(json['pulses'], isEmpty);
      expect(json['shopping'], isEmpty);
    });

    test('stamps createdAt + exportedAt so preview never shows unknown age',
        () async {
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;

      final stamp = DateTime.tryParse(json['createdAt'] as String? ?? '');
      expect(stamp, isNotNull);
      expect(json['exportedAt'], json['createdAt']);

      // The package's preview manifest must actually see the stamp.
      final manifest = BackupEnvelope.describe(bytes);
      expect(manifest.createdAt, isNotNull);
    });

    test('does NOT include UserPrefs (shell prefs stay device-local)',
        () async {
      final bytes = await serializer.dumpAll();
      final json = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      expect(json.containsKey('userPrefs'), isFalse);
      expect(json.containsKey('isDarkMode'), isFalse);
      expect(json.containsKey('remindersEnabled'), isFalse);
    });
  });

  group('restoreAll', () {
    test('round-trips all data through the same database handle', () async {
      await _seedEverything(db);
      final bytes = await serializer.dumpAll();

      await serializer.restoreAll(bytes);

      final profile = await ProfileRepository(db).get();
      expect(profile, _profile);

      final habits = await HabitStateRepository(db).getAll();
      expect(habits, hasLength(1));
      expect(habits.first.interventionId, 'morning-sunlight');
      expect(habits.first.reminderEnabled, isTrue);

      final checkins = await CheckinRepository(db).getAll();
      expect(checkins, hasLength(1));
      expect(checkins.first.note, 'felt good');

      final pulses = await PulseRepository(db).getAll();
      expect(pulses, hasLength(1));
      expect(pulses.first.result, PulseResult.solid);

      final shopping = await ShoppingRepository(db).getAll();
      expect(shopping, hasLength(1));
      expect(shopping.first.purchased, isTrue);
    });

    test('wipes existing data before inserting (destructive replace)',
        () async {
      await _seedEverything(db);

      final db2 = AppDatabase(NativeDatabase.memory());
      addTearDown(db2.close);
      await ProfileRepository(db2).save(_profile.copyWith(goal: Goal.general));
      await HabitStateRepository(db2).upsert(HabitState(
        interventionId: 'box-breathing',
        status: HabitStatus.queued,
        createdAt: DateTime(2026, 1, 1),
      ));
      final otherDump = await BulwarkBackupSerializer(db2).dumpAll();

      await serializer.restoreAll(otherDump);

      final habits = await HabitStateRepository(db).getAll();
      expect(habits, hasLength(1));
      expect(habits.first.interventionId, 'box-breathing');

      // The old seeded rows are gone, not merged.
      final checkins = await CheckinRepository(db).getAll();
      expect(checkins, isEmpty);
      final pulses = await PulseRepository(db).getAll();
      expect(pulses, isEmpty);
      final shopping = await ShoppingRepository(db).getAll();
      expect(shopping, isEmpty);
    });

    test('a restore that throws leaves the original data untouched',
        () async {
      await _seedEverything(db);

      final badPayload = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'bulwark',
        'schemaVersion': 999,
      })));

      await expectLater(
        () => serializer.restoreAll(badPayload),
        throwsA(isA<BackupSchemaException>()),
      );

      // Nothing was wiped — the exception was thrown before the transaction
      // (single-transaction, all-or-nothing restore: SANCTUARY-BRIEF §2.5).
      final habits = await HabitStateRepository(db).getAll();
      expect(habits, hasLength(1));
    });

    test('rejects a backup from a different app', () async {
      final payload = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'lullaby',
        'schemaVersion': 1,
        'profile': null,
        'habits': <dynamic>[],
        'checkins': <dynamic>[],
        'pulses': <dynamic>[],
        'shopping': <dynamic>[],
      })));

      expect(
        () => serializer.restoreAll(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a payload with no app field at all', () async {
      final payload = Uint8List.fromList(utf8.encode(jsonEncode({
        'schemaVersion': 1,
        'habits': <dynamic>[],
      })));

      expect(
        () => serializer.restoreAll(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a future schema version', () async {
      final payload = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'bulwark',
        'schemaVersion': 999,
        'profile': null,
        'habits': <dynamic>[],
        'checkins': <dynamic>[],
        'pulses': <dynamic>[],
        'shopping': <dynamic>[],
      })));

      expect(
        () => serializer.restoreAll(payload),
        throwsA(isA<BackupSchemaException>()),
      );
    });

    test('rejects a payload with no schemaVersion at all', () async {
      final payload = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'bulwark',
        'habits': <dynamic>[],
      })));

      expect(
        () => serializer.restoreAll(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('an empty backup restores to an empty database', () async {
      await _seedEverything(db);
      final empty = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'bulwark',
        'schemaVersion': 1,
        'profile': null,
        'habits': <dynamic>[],
        'checkins': <dynamic>[],
        'pulses': <dynamic>[],
        'shopping': <dynamic>[],
      })));

      await serializer.restoreAll(empty);
      await _expectAllEmpty(db);
    });

    test('rejects a payload whose habits section is not a list', () async {
      final payload = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'bulwark',
        'schemaVersion': 1,
        'profile': null,
        'habits': 'not-a-list',
        'checkins': <dynamic>[],
        'pulses': <dynamic>[],
        'shopping': <dynamic>[],
      })));

      expect(
        () => serializer.restoreAll(payload),
        throwsA(isA<FormatException>()),
      );
    });

    test('skips a malformed row and restores the rest (skip-and-report)',
        () async {
      final payload = Uint8List.fromList(utf8.encode(jsonEncode({
        'app': 'bulwark',
        'schemaVersion': 1,
        'profile': null,
        'habits': [
          {
            'interventionId': 'morning-sunlight',
            'status': 'active',
            'reminderEnabled': true,
            'createdAt': DateTime(2026, 3, 1).toIso8601String(),
          },
          // Malformed: unknown status name — should be skipped, not abort
          // the whole restore.
          {
            'interventionId': 'broken',
            'status': 'not-a-real-status',
            'reminderEnabled': false,
            'createdAt': DateTime(2026, 3, 1).toIso8601String(),
          },
        ],
        'checkins': <dynamic>[],
        'pulses': <dynamic>[],
        'shopping': <dynamic>[],
      })));

      await serializer.restoreAll(payload);

      final habits = await HabitStateRepository(db).getAll();
      expect(habits, hasLength(1));
      expect(habits.first.interventionId, 'morning-sunlight');
    });
  });

  group('describeBackup (preview dry-run)', () {
    test('the serializer is previewable', () {
      expect(serializer, isA<PreviewableBackupSerializer>());
    });

    test('reports app id, schema version, stamp, and row counts', () async {
      await _seedEverything(db);
      final manifest = await (serializer as PreviewableBackupSerializer)
          .describeBackup(await serializer.dumpAll());

      expect(manifest.appId, 'bulwark');
      expect(manifest.schemaVersion, BulwarkExport.schemaVersion);
      expect(manifest.createdAt, isNotNull);
      expect(manifest.tableCounts['habits'], 1);
      expect(manifest.tableCounts['checkins'], 1);
      expect(manifest.tableCounts['pulses'], 1);
      expect(manifest.tableCounts['shopping'], 1);
    });

    test('rejects exactly what restoreAll rejects (shared gate)', () async {
      final previewable = serializer as PreviewableBackupSerializer;

      Uint8List blob(Map<String, dynamic> map) =>
          Uint8List.fromList(utf8.encode(jsonEncode(map)));

      // Wrong app.
      await expectLater(
        () => previewable.describeBackup(blob({
          'app': 'lullaby',
          'schemaVersion': 1,
          'habits': <dynamic>[],
        })),
        throwsA(isA<FormatException>()),
      );
      // Future schema.
      await expectLater(
        () => previewable.describeBackup(blob({
          'app': 'bulwark',
          'schemaVersion': 999,
          'habits': <dynamic>[],
        })),
        throwsA(isA<BackupSchemaException>()),
      );
      // Missing schemaVersion.
      await expectLater(
        () => previewable.describeBackup(blob({
          'app': 'bulwark',
          'habits': <dynamic>[],
        })),
        throwsA(isA<FormatException>()),
      );
      // A section that is not a list (the shape restoreAll requires).
      await expectLater(
        () => previewable.describeBackup(blob({
          'app': 'bulwark',
          'schemaVersion': 1,
          'habits': 'not-a-list',
        })),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('legacy shipped blob (wire-compat)', () {
    // The EXACT envelope every shipped Bulwark build wrote: flat domain
    // keys, no createdAt/exportedAt stamp of any kind.
    Uint8List legacyBlob() => Uint8List.fromList(utf8.encode(jsonEncode({
          'app': 'bulwark',
          'schemaVersion': 1,
          'profile': null,
          'habits': [
            {
              'interventionId': 'morning-sunlight',
              'status': 'active',
              'reminderEnabled': true,
              'createdAt': DateTime(2026, 3, 1).toIso8601String(),
            },
          ],
          'checkins': <dynamic>[],
          'pulses': <dynamic>[],
          'shopping': <dynamic>[],
        })));

    test('still restores', () async {
      await serializer.restoreAll(legacyBlob());
      final habits = await HabitStateRepository(db).getAll();
      expect(habits, hasLength(1));
      expect(habits.first.interventionId, 'morning-sunlight');
    });

    test('previews with unknown age (null createdAt), never an error',
        () async {
      final manifest = await (serializer as PreviewableBackupSerializer)
          .describeBackup(legacyBlob());
      expect(manifest.createdAt, isNull);
      expect(manifest.tableCounts['habits'], 1);
    });
  });
}
