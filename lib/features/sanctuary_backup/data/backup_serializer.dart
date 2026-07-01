import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:sanctuary_backup_ui/sanctuary_backup_ui.dart';

import '../../../core/storage/app_database.dart';
import '../../adoption/data/checkin_repository.dart';
import '../../adoption/data/habit_state_repository.dart';
import '../../adoption/data/profile_repository.dart';
import '../../adoption/data/pulse_repository.dart';
import '../../adoption/data/shopping_repository.dart';
import '../../settings/data/export_serializer.dart';

/// Serializes Bulwark's user data to/from a JSON [Uint8List] for encrypted
/// backup via `sanctuary_backup_ui`.
///
/// Wraps the existing plaintext-export machinery ([BulwarkExport]) rather
/// than inventing a second envelope (SANCTUARY-BRIEF §4.W2: "reuse the app's
/// existing export machinery where it exists"). Reads/writes go through the
/// [AppDatabase] handle the caller passes in — the same one the rest of the
/// app uses, never a second connection.
///
/// [UserPrefs] (shell prefs: theme, the reminders master switch)
/// intentionally stays OUT of the backup, matching both the existing
/// plaintext export's scope and `AppDatabase.eraseUserData()`'s erase
/// boundary — a restored backup should not silently flip the current
/// device's theme or reminder switch out from under it. Shell prefs are a
/// device preference, not user *data*; only [restoreAll]'s destructive
/// replace touches the five domain tables `eraseUserData()` already
/// enumerates.
class BulwarkBackupSerializer
    implements BackupSerializer, PreviewableBackupSerializer {
  final AppDatabase _db;

  const BulwarkBackupSerializer(this._db);

  static const String _appId = 'bulwark';

  @override
  Future<Uint8List> dumpAll() async {
    final profile = await ProfileRepository(_db).get();
    final habits = await HabitStateRepository(_db).getAll();
    final checkins = await CheckinRepository(_db).getAll();
    final pulses = await PulseRepository(_db).getAll();
    final shopping = await ShoppingRepository(_db).getAll();

    final export = BulwarkExport(
      profile: profile,
      habits: habits,
      checkins: checkins,
      pulses: pulses,
      shopping: shopping,
      // Stamps createdAt/exportedAt (ADDITIVE keys — the shipped restore
      // path ignores them) so preview-before-restore shows the backup's
      // real age instead of "unknown".
      createdAt: DateTime.now(),
    );
    return Uint8List.fromList(utf8.encode(export.toPrettyJson()));
  }

  /// The dry-run parse behind preview-before-restore and export
  /// verify-by-read-back: validates exactly like [restoreAll] (wrong app,
  /// future schema, malformed section shape) and reports the stamp plus
  /// per-section row counts — but never writes.
  @override
  Future<BackupManifest> describeBackup(Uint8List plaintext) async {
    _requireExportShape(_unwrap(plaintext).payload);
    return BackupEnvelope.describe(plaintext);
  }

  /// Envelope validation via the shared fleet helper: rejects a blob from
  /// a different app or a future schema — defense in depth behind the AEAD
  /// context (SANCTUARY-BRIEF §2.8). Bulwark's shipped envelopes have
  /// always carried the `app` key, so the default `requireAppKey: true`
  /// stands.
  UnwrappedBackup _unwrap(Uint8List data) => BackupEnvelope.unwrap(
        data,
        expectedAppId: _appId,
        currentSchemaVersion: BulwarkExport.schemaVersion,
      );

  /// The payload-shape gate [restoreAll] applies — shared with
  /// [describeBackup] so preview and restore can never drift apart.
  ///
  /// Deliberately no stricter than restoreAll's own lenient row-skip
  /// parse ([BulwarkExport.fromJsonLenient]): each section, WHEN present,
  /// must have the right container type (lists of rows; a map or null for
  /// profile) — an absent section is fine, and malformed individual rows
  /// stay skip-and-report, not a rejection.
  static void _requireExportShape(Map<String, Object?> payload) {
    for (final key in const ['habits', 'checkins', 'pulses', 'shopping']) {
      final section = payload[key];
      if (section != null && section is! List) {
        throw FormatException("Backup section '$key' is not a list");
      }
    }
    final profile = payload['profile'];
    if (profile != null && profile is! Map<String, dynamic>) {
      throw const FormatException("Backup section 'profile' is not an object");
    }
  }

  /// **Destructive** — wipes the five domain tables ([AppDatabase.
  /// eraseUserData]'s exact set) and re-inserts inside a single transaction,
  /// so a failure partway through leaves the original data intact rather
  /// than a half-restored mix (SANCTUARY-BRIEF §2.5).
  ///
  /// Throws [FormatException] for a payload from a different app, a payload
  /// missing the `app`/`schemaVersion` envelope fields, invalid JSON, or a
  /// section with the wrong container type. Throws [BackupSchemaException]
  /// when the payload's schema is newer than this app understands.
  /// Individual malformed rows within an otherwise valid payload are
  /// skipped and logged rather than aborting the restore (see
  /// [BulwarkExport.fromJsonLenient]).
  @override
  Future<void> restoreAll(Uint8List data) async {
    final payload = _unwrap(data).payload;
    _requireExportShape(payload);

    final (export, skippedRows) =
        BulwarkExport.fromJsonLenient(jsonEncode(payload));
    if (skippedRows.isNotEmpty) {
      // Best-effort reporting: the restore stays atomic and only the rows
      // that parsed cleanly are written (skip-and-report, per
      // export_serializer.dart's fromJsonLenient — SANCTUARY-BRIEF §4.W2). A
      // user-facing summary is future work; this is a developer-visible
      // trail in the meantime.
      debugPrint(
        'Bulwark restore: skipped ${skippedRows.length} malformed row(s): '
        '${skippedRows.join('; ')}',
      );
    }

    await _db.transaction(() async {
      // Reuses the well-tested erase path; drift nests this as a savepoint
      // inside the outer transaction, so a later failure still rolls back
      // the wipe too.
      await _db.eraseUserData();

      if (export.profile != null) {
        await ProfileRepository(_db).save(export.profile!);
      }
      for (final habit in export.habits) {
        await HabitStateRepository(_db).upsert(habit);
      }
      for (final checkin in export.checkins) {
        await CheckinRepository(_db).upsert(checkin);
      }
      for (final pulse in export.pulses) {
        await PulseRepository(_db).upsert(pulse);
      }
      for (final item in export.shopping) {
        await ShoppingRepository(_db).setPurchased(
          item.interventionId,
          purchased: item.purchased,
          purchasedAt: item.purchasedAt,
        );
      }
    });
  }
}
