// lib/core/storage/app_database.dart
import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'app_database.g.dart';

// ─── Tables ───────────────────────────────────────────────────────────────────

/// Simple key→value store for shell preferences (theme, etc.).
class UserPrefs extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}

/// Per-intervention adoption state. Generated row is `HabitStateRow` so it
/// does not collide with the domain `HabitState`; the companion stays
/// `HabitStatesCompanion`.
@DataClassName('HabitStateRow')
class HabitStates extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get interventionId => text().unique()();
  IntColumn get status => integer()();
  IntColumn get queuePosition => integer().nullable()();
  DateTimeColumn get activatedAt => dateTime().nullable()();
  DateTimeColumn get graduatedAt => dateTime().nullable()();
  TextColumn get triggerAnchorOverride => text().nullable()();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
}

/// One daily self-report per (intervention, date).
@DataClassName('CheckinRow')
class Checkins extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get interventionId => text()();
  DateTimeColumn get date => dateTime()();
  IntColumn get result => integer()();
  TextColumn get note => text().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {interventionId, date}
      ];
}

/// One weekly maintenance pulse per (intervention, weekStart) for graduated
/// habits.
@DataClassName('PulseRow')
class Pulses extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get interventionId => text()();
  DateTimeColumn get weekStart => dateTime()();
  IntColumn get result => integer()();

  @override
  List<Set<Column>> get uniqueKeys => [
        {interventionId, weekStart}
      ];
}

/// Whether a shoppable intervention's supply has been acquired.
@DataClassName('ShoppingStateRow')
class ShoppingStates extends Table {
  TextColumn get interventionId => text()();
  BoolColumn get purchased => boolean().withDefault(const Constant(false))();
  DateTimeColumn get purchasedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {interventionId};
}

/// The user's onboarding answers. A single-row table pinned to id = 1.
@DataClassName('ProfileRow')
class Profiles extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();
  IntColumn get wakeMinutes => integer()();
  IntColumn get bedMinutes => integer()();
  IntColumn get breakfastMinutes => integer().nullable()();
  IntColumn get lunchMinutes => integer().nullable()();
  IntColumn get dinnerMinutes => integer().nullable()();
  TextColumn get goal => text()();
  IntColumn get pace => integer()();
  IntColumn get checkInMinutes => integer().nullable()();
  IntColumn get evidenceThreshold => integer().withDefault(const Constant(0))();
  BoolColumn get onboarded => boolean().withDefault(const Constant(false))();
  BoolColumn get newParentMode =>
      boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {id};
}

// ─── Database ─────────────────────────────────────────────────────────────────

@DriftDatabase(
  tables: [UserPrefs, HabitStates, Checkins, Pulses, ShoppingStates, Profiles],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ??
            driftDatabase(
              name: 'bulwark',
              // Web needs to know where the sqlite3 WASM engine + drift worker
              // live (both shipped in web/); without this drift_flutter throws
              // "the `web` parameter needs to be set" at startup.
              web: DriftWebOptions(
                sqlite3Wasm: Uri.parse('sqlite3.wasm'),
                driftWorker: Uri.parse('drift_worker.js'),
              ),
            ));

  @override
  int get schemaVersion => 2;

  /// Wipe every user-data table (habit states, check-ins, pulses, shopping
  /// states, profile) in one transaction — the "Erase all data" path. Leaves
  /// the key→value shell prefs (theme, reminders switch) in place; erasing the
  /// profile is what returns the app to onboarding.
  Future<void> eraseUserData() => transaction(() async {
        await delete(habitStates).go();
        await delete(checkins).go();
        await delete(pulses).go();
        await delete(shoppingStates).go();
        await delete(profiles).go();
      });

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          // Fresh app, never released: v2 adds the adoption/state tables. Any
          // dev DB still at v1 only has UserPrefs, so create the rest.
          if (from < 2) {
            await m.createTable(habitStates);
            await m.createTable(checkins);
            await m.createTable(pulses);
            await m.createTable(shoppingStates);
            await m.createTable(profiles);
          }
        },
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
