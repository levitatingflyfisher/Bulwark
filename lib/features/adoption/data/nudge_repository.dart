import 'package:drift/drift.dart';

import 'package:bulwark/core/storage/app_database.dart';

/// Remembers, per habit, when the "you've been forgetting this one" offer was
/// answered (a new moment chosen, or "Not now"), so answers from before then
/// don't bring the offer straight back. Kept in the shell key→value table:
/// it is a UI memory, not part of the household's data, so it is not in the
/// export or the backup.
class NudgeRepository {
  NudgeRepository(this._db);
  final AppDatabase _db;

  static const _prefix = 'forgot_nudge:';

  Future<Map<String, DateTime>> forgotAcks() async {
    final rows = await (_db.select(_db.userPrefs)
          ..where((t) => t.key.like('$_prefix%')))
        .get();
    return {
      for (final r in rows)
        if (DateTime.tryParse(r.value) case final at?)
          r.key.substring(_prefix.length): at,
    };
  }

  Future<void> ackForgot(String interventionId, DateTime at) =>
      _db.into(_db.userPrefs).insertOnConflictUpdate(UserPrefsCompanion.insert(
          key: '$_prefix$interventionId', value: at.toIso8601String()));
}
