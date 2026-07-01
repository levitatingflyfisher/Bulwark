import 'dart:convert';

import 'package:bulwark/features/adoption/domain/checkin.dart';
import 'package:bulwark/features/adoption/domain/enums.dart';
import 'package:bulwark/features/adoption/domain/habit_state.dart';
import 'package:bulwark/features/adoption/domain/profile.dart';
import 'package:bulwark/features/adoption/domain/pulse.dart';
import 'package:bulwark/features/adoption/domain/shopping_state.dart';
import 'package:bulwark/features/settings/data/export_serializer.dart';
import 'package:flutter_test/flutter_test.dart';

BulwarkExport _sample() => BulwarkExport(
      profile: const Profile(
        wakeMinutes: 7 * 60,
        bedMinutes: 22 * 60,
        breakfastMinutes: 8 * 60,
        lunchMinutes: null,
        dinnerMinutes: 18 * 60,
        goal: Goal.sleep,
        pace: Pace.moderate,
        checkInMinutes: 20 * 60,
        evidenceThreshold: 2,
        onboarded: true,
        newParentMode: true,
      ),
      habits: [
        HabitState(
          interventionId: 'morning-sunlight',
          status: HabitStatus.active,
          activatedAt: DateTime(2026, 3, 2, 6, 30),
          createdAt: DateTime(2026, 3, 1, 9),
          reminderEnabled: true,
          triggerAnchorOverride: 'wake',
        ),
        HabitState(
          interventionId: 'magnesium',
          status: HabitStatus.graduated,
          graduatedAt: DateTime(2026, 4, 1),
          createdAt: DateTime(2026, 2, 1),
        ),
      ],
      checkins: [
        Checkin(
          interventionId: 'morning-sunlight',
          date: DateTime(2026, 3, 3),
          result: CheckinResult.did,
          note: 'felt good',
        ),
        Checkin(
          interventionId: 'morning-sunlight',
          date: DateTime(2026, 3, 4),
          result: CheckinResult.forgot,
        ),
      ],
      pulses: [
        Pulse(
          interventionId: 'magnesium',
          weekStart: DateTime(2026, 4, 6),
          result: PulseResult.shaky,
        ),
      ],
      shopping: [
        ShoppingState(
          interventionId: 'magnesium',
          purchased: true,
          purchasedAt: DateTime(2026, 1, 20, 14, 5),
        ),
        const ShoppingState(interventionId: 'omega-3', purchased: false),
      ],
    );

void main() {
  test('encode → decode round-trips to an equal export', () {
    final original = _sample();
    final decoded = BulwarkExport.fromJson(original.toPrettyJson());
    expect(decoded, original);
  });

  test('round-trips an empty/fresh dataset (null profile, no rows)', () {
    const empty = BulwarkExport(
      profile: null,
      habits: [],
      checkins: [],
      pulses: [],
      shopping: [],
    );
    final decoded = BulwarkExport.fromJson(empty.toPrettyJson());
    expect(decoded, empty);
  });

  test('output is pretty-printed and carries a schema version', () {
    final json = _sample().toPrettyJson();
    expect(json, contains('\n')); // indented, not a single line
    expect(json, contains('"schemaVersion": 1'));
    // Lowercase — matches the app id used everywhere else in the encrypted
    // backup wiring (config appId, AAD context, appDomain all 'bulwark'), so
    // BulwarkBackupSerializer's wrong-app envelope check has one canonical
    // value to compare against (SANCTUARY-BRIEF §2.8).
    expect(json, contains('"app": "bulwark"'));
  });

  group('createdAt stamp', () {
    test('a stamped export emits createdAt AND legacy exportedAt (additive)',
        () {
      final export = BulwarkExport(
        profile: null,
        habits: const [],
        checkins: const [],
        pulses: const [],
        shopping: const [],
        createdAt: DateTime.utc(2026, 7, 1, 12),
      );
      final map =
          jsonDecode(export.toPrettyJson()) as Map<String, dynamic>;
      expect(map['createdAt'], '2026-07-01T12:00:00.000Z');
      // Additive twin key: fleet-legacy readers look for exportedAt, so a
      // new backup carries both spellings of the same stamp.
      expect(map['exportedAt'], map['createdAt']);
    });

    test('an unstamped export emits neither key (the shipped v1 shape)', () {
      final map =
          jsonDecode(_sample().toPrettyJson()) as Map<String, dynamic>;
      expect(map.containsKey('createdAt'), isFalse);
      expect(map.containsKey('exportedAt'), isFalse);
    });

    test('round-trips through fromJson', () {
      final export = BulwarkExport(
        profile: null,
        habits: const [],
        checkins: const [],
        pulses: const [],
        shopping: const [],
        createdAt: DateTime.utc(2026, 7, 1, 12),
      );
      final decoded = BulwarkExport.fromJson(export.toPrettyJson());
      expect(decoded.createdAt, DateTime.utc(2026, 7, 1, 12));
      expect(decoded, export);
    });

    test('a malformed stamp is dropped by fromJsonLenient, not fatal', () {
      final (export, skipped) = BulwarkExport.fromJsonLenient(jsonEncode({
        'app': 'bulwark',
        'schemaVersion': 1,
        'createdAt': 'not-a-date',
        'profile': null,
        'habits': <dynamic>[],
        'checkins': <dynamic>[],
        'pulses': <dynamic>[],
        'shopping': <dynamic>[],
      }));
      expect(export.createdAt, isNull);
      expect(skipped, isEmpty);
    });
  });

  test('exportFileName stamps the given date (not now)', () {
    expect(
      exportFileName(DateTime(2026, 7, 11)),
      'bulwark-export-2026-07-11.json',
    );
  });

  group('fromJsonLenient', () {
    test('round-trips a well-formed export with no skipped rows', () {
      final original = _sample();
      final (decoded, skipped) =
          BulwarkExport.fromJsonLenient(original.toPrettyJson());
      expect(decoded, original);
      expect(skipped, isEmpty);
    });

    test('skips a malformed habit row and keeps the rest', () {
      final good = _sample();
      final map = jsonDecode(good.toPrettyJson()) as Map<String, dynamic>;
      final habits = List<Map<String, dynamic>>.from(
        (map['habits'] as List).cast<Map<String, dynamic>>(),
      );
      habits.add({'interventionId': 'broken', 'status': 'not-a-real-status'});
      map['habits'] = habits;

      final (decoded, skipped) =
          BulwarkExport.fromJsonLenient(jsonEncode(map));

      // The two good habits survive; the malformed third is skipped and
      // reported, not thrown.
      expect(decoded.habits, hasLength(good.habits.length));
      expect(decoded.checkins, good.checkins);
      expect(skipped, hasLength(1));
      expect(skipped.single, contains('habits[2]'));
    });

    test('skips a malformed profile and continues with a null profile', () {
      final good = _sample();
      final map = jsonDecode(good.toPrettyJson()) as Map<String, dynamic>;
      map['profile'] = {'goal': 'not-a-real-goal'};

      final (decoded, skipped) =
          BulwarkExport.fromJsonLenient(jsonEncode(map));

      expect(decoded.profile, isNull);
      expect(decoded.habits, good.habits);
      expect(skipped, hasLength(1));
      expect(skipped.single, contains('profile'));
    });

    test('a null profile in a well-formed payload stays null (not skipped)',
        () {
      final map = jsonDecode(_sample().toPrettyJson()) as Map<String, dynamic>;
      map['profile'] = null;

      final (decoded, skipped) =
          BulwarkExport.fromJsonLenient(jsonEncode(map));

      expect(decoded.profile, isNull);
      expect(skipped, isEmpty);
    });

    test('missing list keys are treated as empty, not skipped', () {
      final bytes = jsonEncode({'schemaVersion': 1, 'app': 'bulwark'});
      final (decoded, skipped) = BulwarkExport.fromJsonLenient(bytes);
      expect(decoded.habits, isEmpty);
      expect(decoded.checkins, isEmpty);
      expect(decoded.pulses, isEmpty);
      expect(decoded.shopping, isEmpty);
      expect(skipped, isEmpty);
    });
  });
}
