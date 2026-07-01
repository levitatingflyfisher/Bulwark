import 'dart:convert';

import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/domain/shopping_state.dart';
import 'package:bulwark/shared/extensions/datetime_ext.dart';

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// The date-stamped filename for a data export, e.g.
/// `bulwark-export-2026-07-11.json`. Takes the date explicitly (not
/// `DateTime.now`) so tests are deterministic; the UI passes `DateTime.now()`.
String exportFileName(DateTime date) => 'bulwark-export-${date.toDateDay()}.json';

/// The whole on-device dataset, ready to serialize to a portable JSON document
/// the user can keep or move. Pure: it holds domain objects and knows how to
/// (de)serialize itself, with value equality so an encode→decode round-trip is
/// testable. Enums serialize as their `.name`; dates as ISO-8601 strings.
class BulwarkExport {
  /// Bulwark's WIRE schema counter — deliberately a hardcoded 1, NOT
  /// `AppDatabase.schemaVersion`. The drift version counts on-device
  /// migrations (column adds, index tweaks) that don't change this JSON
  /// shape; tying the wire counter to it would make every routine DB
  /// migration reject older installs from restoring newer backups for no
  /// reason. Bump this only when the exported JSON itself changes
  /// incompatibly (SANCTUARY-BRIEF §2.8 — additive keys never require a
  /// bump).
  static const schemaVersion = 1;

  final Profile? profile;
  final List<HabitState> habits;
  final List<Checkin> checkins;
  final List<Pulse> pulses;
  final List<ShoppingState> shopping;

  /// When this export was produced, or null for the shipped v1 shape that
  /// never stamped one (preview shows "unknown age", never an error).
  final DateTime? createdAt;

  const BulwarkExport({
    required this.profile,
    required this.habits,
    required this.checkins,
    required this.pulses,
    required this.shopping,
    this.createdAt,
  });

  String toPrettyJson() =>
      const JsonEncoder.withIndent('  ').convert(_toMap());

  Map<String, dynamic> _toMap() => {
        // Lowercase: matches the app id used everywhere else in the
        // encrypted-backup wiring (config appId, AAD context, appDomain are
        // all 'bulwark' — SANCTUARY-BRIEF §2.8), so
        // BulwarkBackupSerializer's wrong-app envelope check has one
        // canonical value to compare against.
        'app': 'bulwark',
        'schemaVersion': schemaVersion,
        // ADDITIVE stamps (wire-compat law): the shipped restore path reads
        // only the keys it knows, so old installs restore new backups
        // unchanged. `createdAt` is the fleet-canonical spelling the
        // preview manifest reads; `exportedAt` is the fleet-legacy twin so
        // any tables-era reader finds a stamp under its own name too.
        if (createdAt != null) ...{
          'createdAt': createdAt!.toUtc().toIso8601String(),
          'exportedAt': createdAt!.toUtc().toIso8601String(),
        },
        'profile': profile == null ? null : _profileToJson(profile!),
        'habits': habits.map(_habitToJson).toList(),
        'checkins': checkins.map(_checkinToJson).toList(),
        'pulses': pulses.map(_pulseToJson).toList(),
        'shopping': shopping.map(_shoppingToJson).toList(),
      };

  // A hand-edited export with an unknown enum name or malformed date makes
  // the `.byName`/`DateTime.parse` calls below throw — left unguarded here
  // on purpose: fromJson is the strict path, still exercised only by the
  // round-trip test with self-produced JSON. The encrypted-backup restore
  // feature (SANCTUARY-BRIEF §4.W2) is the "import feature" the old comment
  // deferred hardening to; it uses [fromJsonLenient] below instead, which
  // skips and reports malformed individual rows rather than throwing.
  factory BulwarkExport.fromJson(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final profileJson = map['profile'] as Map<String, dynamic>?;
    return BulwarkExport(
      profile: profileJson == null ? null : _profileFromJson(profileJson),
      habits: (map['habits'] as List)
          .map((e) => _habitFromJson(e as Map<String, dynamic>))
          .toList(),
      checkins: (map['checkins'] as List)
          .map((e) => _checkinFromJson(e as Map<String, dynamic>))
          .toList(),
      pulses: (map['pulses'] as List)
          .map((e) => _pulseFromJson(e as Map<String, dynamic>))
          .toList(),
      shopping: (map['shopping'] as List)
          .map((e) => _shoppingFromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt: _stampOrNull(map['createdAt']),
    );
  }

  /// Age is information, never an obstacle (mirrors the package's
  /// BackupEnvelope): an absent or unparseable stamp reads as null, not a
  /// rejected export — even on the otherwise-strict [fromJson] path.
  static DateTime? _stampOrNull(Object? raw) =>
      raw is String ? DateTime.tryParse(raw)?.toUtc() : null;

  /// Lenient counterpart to [fromJson] for the encrypted-backup restore path
  /// (SANCTUARY-BRIEF §4.W2): a hand-edited or partially-corrupted payload
  /// skips the offending row instead of aborting the whole restore, and
  /// reports what it skipped (as `"<section>[<index>]: <error>"` strings, or
  /// `"profile: <error>"`) so the caller can log or surface it. The
  /// top-level shape — a JSON object, with `habits`/`checkins`/`pulses`/
  /// `shopping` as lists when present — must still hold; this only tolerates
  /// malformed *rows* within those lists, not a wholesale different shape.
  static (BulwarkExport, List<String> skippedRows) fromJsonLenient(
    String source,
  ) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final skipped = <String>[];

    Profile? profile;
    final profileJson = map['profile'] as Map<String, dynamic>?;
    if (profileJson != null) {
      try {
        profile = _profileFromJson(profileJson);
      } catch (e) {
        skipped.add('profile: $e');
      }
    }

    List<T> parseList<T>(
      String key,
      T Function(Map<String, dynamic>) parseRow,
    ) {
      final raw = map[key] as List? ?? const [];
      final out = <T>[];
      for (var i = 0; i < raw.length; i++) {
        try {
          out.add(parseRow(raw[i] as Map<String, dynamic>));
        } catch (e) {
          skipped.add('$key[$i]: $e');
        }
      }
      return out;
    }

    final export = BulwarkExport(
      profile: profile,
      habits: parseList('habits', _habitFromJson),
      checkins: parseList('checkins', _checkinFromJson),
      pulses: parseList('pulses', _pulseFromJson),
      shopping: parseList('shopping', _shoppingFromJson),
      createdAt: _stampOrNull(map['createdAt']),
    );
    return (export, skipped);
  }

  @override
  bool operator ==(Object other) =>
      other is BulwarkExport &&
      other.createdAt == createdAt &&
      other.profile == profile &&
      _listEq(other.habits, habits) &&
      _listEq(other.checkins, checkins) &&
      _listEq(other.pulses, pulses) &&
      _listEq(other.shopping, shopping);

  @override
  int get hashCode => Object.hash(
        createdAt,
        profile,
        Object.hashAll(habits),
        Object.hashAll(checkins),
        Object.hashAll(pulses),
        Object.hashAll(shopping),
      );
}

// ─── Field-level (de)serializers ────────────────────────────────────────────

Map<String, dynamic> _profileToJson(Profile p) => {
      'wakeMinutes': p.wakeMinutes,
      'bedMinutes': p.bedMinutes,
      'breakfastMinutes': p.breakfastMinutes,
      'lunchMinutes': p.lunchMinutes,
      'dinnerMinutes': p.dinnerMinutes,
      'goal': p.goal.name,
      'pace': p.pace.name,
      'checkInMinutes': p.checkInMinutes,
      'evidenceThreshold': p.evidenceThreshold,
      'onboarded': p.onboarded,
      'newParentMode': p.newParentMode,
    };

Profile _profileFromJson(Map<String, dynamic> m) => Profile(
      wakeMinutes: m['wakeMinutes'] as int,
      bedMinutes: m['bedMinutes'] as int,
      breakfastMinutes: m['breakfastMinutes'] as int?,
      lunchMinutes: m['lunchMinutes'] as int?,
      dinnerMinutes: m['dinnerMinutes'] as int?,
      goal: Goal.values.byName(m['goal'] as String),
      pace: Pace.values.byName(m['pace'] as String),
      checkInMinutes: m['checkInMinutes'] as int?,
      evidenceThreshold: m['evidenceThreshold'] as int,
      onboarded: m['onboarded'] as bool,
      newParentMode: m['newParentMode'] as bool,
    );

Map<String, dynamic> _habitToJson(HabitState s) => {
      'interventionId': s.interventionId,
      'status': s.status.name,
      'queuePosition': s.queuePosition,
      'activatedAt': s.activatedAt?.toIso8601String(),
      'graduatedAt': s.graduatedAt?.toIso8601String(),
      'triggerAnchorOverride': s.triggerAnchorOverride,
      'reminderEnabled': s.reminderEnabled,
      'createdAt': s.createdAt.toIso8601String(),
    };

HabitState _habitFromJson(Map<String, dynamic> m) => HabitState(
      interventionId: m['interventionId'] as String,
      status: HabitStatus.values.byName(m['status'] as String),
      queuePosition: m['queuePosition'] as int?,
      activatedAt: _dateOrNull(m['activatedAt']),
      graduatedAt: _dateOrNull(m['graduatedAt']),
      triggerAnchorOverride: m['triggerAnchorOverride'] as String?,
      reminderEnabled: m['reminderEnabled'] as bool,
      createdAt: DateTime.parse(m['createdAt'] as String),
    );

Map<String, dynamic> _checkinToJson(Checkin c) => {
      'interventionId': c.interventionId,
      'date': c.date.toIso8601String(),
      'result': c.result.name,
      'note': c.note,
    };

Checkin _checkinFromJson(Map<String, dynamic> m) => Checkin(
      interventionId: m['interventionId'] as String,
      date: DateTime.parse(m['date'] as String),
      result: CheckinResult.values.byName(m['result'] as String),
      note: m['note'] as String?,
    );

Map<String, dynamic> _pulseToJson(Pulse p) => {
      'interventionId': p.interventionId,
      'weekStart': p.weekStart.toIso8601String(),
      'result': p.result.name,
    };

Pulse _pulseFromJson(Map<String, dynamic> m) => Pulse(
      interventionId: m['interventionId'] as String,
      weekStart: DateTime.parse(m['weekStart'] as String),
      result: PulseResult.values.byName(m['result'] as String),
    );

Map<String, dynamic> _shoppingToJson(ShoppingState s) => {
      'interventionId': s.interventionId,
      'purchased': s.purchased,
      'purchasedAt': s.purchasedAt?.toIso8601String(),
    };

ShoppingState _shoppingFromJson(Map<String, dynamic> m) => ShoppingState(
      interventionId: m['interventionId'] as String,
      purchased: m['purchased'] as bool,
      purchasedAt: _dateOrNull(m['purchasedAt']),
    );

DateTime? _dateOrNull(Object? iso) =>
    iso == null ? null : DateTime.parse(iso as String);
