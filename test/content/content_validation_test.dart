// Validates the SHIPPED content assets (assets/content/*.json) — the actual
// files that ride in the app bundle, read directly off disk here, not via
// rootBundle and not mocked. Content bugs are supposed to fail loudly (see
// domain/enums.dart); this test is the tripwire that catches them in CI.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';

void main() {
  late List<dynamic> interventionsJson;
  late Map<String, dynamic> presetsJson;
  late ContentLibrary library;

  setUpAll(() {
    interventionsJson = jsonDecode(
      File('assets/content/interventions.json').readAsStringSync(),
    ) as List<dynamic>;
    presetsJson = jsonDecode(
      File('assets/content/presets.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    // If any item carries an invalid enum value, this throws here and every
    // test below fails with the FormatException naming the offending value.
    library = ContentLibrary.fromJson(
      interventionsJson: interventionsJson,
      presetsJson: presetsJson,
    );
  });

  group('shipped content schema', () {
    test('89 items ship (88 base + nap-when-baby-naps merged in)', () {
      expect(library.all.length, 89);
    });

    test('ids are unique', () {
      final ids = library.all.map((i) => i.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every category/anchor/evidence/costTier/shopWhere value parses', () {
      for (final raw in interventionsJson) {
        final map = raw as Map<String, dynamic>;
        final id = map['id'];
        try {
          Category.fromJson(map['category'] as String);
          final trigger = map['trigger'] as Map<String, dynamic>;
          Anchor.fromJson(trigger['anchor'] as String);
          Evidence.fromJson(map['evidence'] as String);
          final cost = map['cost'] as Map<String, dynamic>;
          CostTier.fromJson(cost['tier'] as String);
          final shopping = map['shopping'];
          if (shopping != null) {
            ShopWhere.fromJson((shopping as Map<String, dynamic>)['where'] as String);
          }
        } on FormatException catch (e) {
          fail('$id: $e');
        }
      }
    });

    test('the enums cover exactly the spec\'d value sets', () {
      expect(Category.values, hasLength(9));
      expect(Anchor.values, hasLength(16));
      expect(Evidence.values, hasLength(4));
      expect(CostTier.values, hasLength(4));
      expect(ShopWhere.values, hasLength(3));
    });

    test('fromJson throws loudly on an unknown value (content bugs must not coerce)', () {
      expect(() => Category.fromJson('not-a-category'), throwsFormatException);
      expect(() => Anchor.fromJson('not-an-anchor'), throwsFormatException);
      expect(() => Evidence.fromJson('not-evidence'), throwsFormatException);
      expect(() => CostTier.fromJson('not-a-tier'), throwsFormatException);
      expect(() => ShopWhere.fromJson('not-a-where'), throwsFormatException);
    });

    test('defaultPhase is within 1..8', () {
      for (final i in library.all) {
        expect(i.defaultPhase, inInclusiveRange(1, 8), reason: i.id);
      }
    });

    test('title/action/mechanism/details are non-empty', () {
      for (final i in library.all) {
        expect(i.title.trim(), isNotEmpty, reason: '${i.id}.title');
        expect(i.action.trim(), isNotEmpty, reason: '${i.id}.action');
        expect(i.mechanism.trim(), isNotEmpty, reason: '${i.id}.mechanism');
        expect(i.details.trim(), isNotEmpty, reason: '${i.id}.details');
      }
    });

    test('recurring shopping implies a recurring cost tier', () {
      for (final i in library.all) {
        final shopping = i.shopping;
        if (shopping != null && shopping.recurring) {
          expect(i.cost.tier, CostTier.recurring, reason: i.id);
        }
      }
    });

    test('every preset interventionId resolves in the shipped library', () {
      expect(library.presets, isNotEmpty);
      for (final preset in library.presets) {
        for (final id in preset.interventionIds) {
          expect(library.byIdOrNull(id), isNotNull, reason: '${preset.id} -> $id');
        }
      }
    });

    test('asNeeded items are not activatable; everything else is', () {
      final asNeeded = library.all.where((i) => i.trigger.anchor == Anchor.asNeeded);
      expect(asNeeded, isNotEmpty);
      for (final i in library.all) {
        expect(
          i.isActivatable,
          i.trigger.anchor != Anchor.asNeeded,
          reason: i.id,
        );
      }
    });
  });

  group('banned strings (case-sensitive, word-boundary)', () {
    // Faith references, medical-history references, and brand names — none may
    // ship in a public repo (de-personalization law). Word-boundaried so
    // substrings like "toward"/"builds" don't false-positive on "ward"/"ORB".
    // NB: "baby"/"newborn" are deliberately NOT here — they are legitimate in
    // the newParent preset copy.
    const denylist = <String>[
      // Faith
      'Word of Wisdom',
      'Sabbath',
      'LDS',
      'ward',
      'bishop',
      'Mormon',
      'priesthood',
      // Medical history
      'VBAC',
      'Olympian',
      'Mom',
      // Brands a future content regen could reintroduce
      'Oral-B',
      'CeraVe',
      'Waterpik',
      'GORUCK',
      'Squatty',
      'Creapure',
      'ChiliPad',
      'SleepMe',
      'Nordic',
      'Kirkland',
      'Brita',
    ];

    late String allText;

    setUpAll(() {
      final buffer = StringBuffer()
        ..writeln(jsonEncode(interventionsJson))
        ..writeln(jsonEncode(presetsJson));
      allText = buffer.toString();
    });

    for (final term in denylist) {
      test('does not contain "$term"', () {
        final pattern = RegExp(r'\b' + RegExp.escape(term) + r'\b');
        expect(pattern.hasMatch(allText), isFalse, reason: 'found "$term"');
      });
    }

    test('word-boundary avoids false positives inside longer words', () {
      const sample = 'This builds toward a stronger habit. Momentum keeps '
          'oral hygiene on track better than a moment of willpower.';
      // "toward" contains "ward"; "builds" contains "build"; "Momentum" and
      // "moment" contain "Mom"/"mom" — none of these should trip a denylist
      // entry for the standalone word.
      expect(RegExp(r'\bward\b').hasMatch(sample), isFalse);
      expect(RegExp(r'\bbuild\b').hasMatch(sample), isFalse);
      expect(RegExp(r'\bMom\b').hasMatch(sample), isFalse);
    });
  });

  group('ContentLibrary', () {
    test('byId resolves a known item', () {
      final item = library.byIdOrNull('consistent-sleep-schedule');
      expect(item, isNotNull);
      expect(item!.category, Category.sleep);
    });

    test('byIdOrNull returns null for an unknown id', () {
      expect(library.byIdOrNull('does-not-exist'), isNull);
    });

    test('all is stable-ordered by (defaultPhase, id)', () {
      for (var i = 1; i < library.all.length; i++) {
        final prev = library.all[i - 1];
        final curr = library.all[i];
        final inOrder = prev.defaultPhase < curr.defaultPhase ||
            (prev.defaultPhase == curr.defaultPhase && prev.id.compareTo(curr.id) <= 0);
        expect(inOrder, isTrue, reason: '${prev.id} before ${curr.id}');
      }
    });

    test('byCategory only returns items in that category', () {
      final results = library.byCategory(Category.dental);
      expect(results, isNotEmpty);
      for (final i in results) {
        expect(i.category, Category.dental);
      }
    });

    test('search finds items by title substring, case-insensitively', () {
      final results = library.search('SLEEP schedule');
      expect(results.map((i) => i.id), contains('consistent-sleep-schedule'));
    });

    test('search finds items by tag', () {
      final results = library.search('new-parent');
      expect(results.map((i) => i.id), contains('nap-when-baby-naps'));
    });

    test('search returns everything for an empty (or whitespace) query', () {
      expect(library.search('').length, library.all.length);
      expect(library.search('   ').length, library.all.length);
    });

    test('byEvidenceAtLeast(rct) only returns rct items', () {
      final results = library.byEvidenceAtLeast(Evidence.rct);
      expect(results, isNotEmpty);
      for (final i in results) {
        expect(i.evidence, Evidence.rct);
      }
    });

    test('byEvidenceAtLeast(observational) includes rct and observational only', () {
      final results = library.byEvidenceAtLeast(Evidence.observational);
      final evidences = results.map((i) => i.evidence).toSet();
      expect(evidences, containsAll(<Evidence>[Evidence.rct, Evidence.observational]));
      expect(evidences, isNot(contains(Evidence.mechanistic)));
      expect(evidences, isNot(contains(Evidence.traditional)));
    });

    test('byEvidenceAtLeast(traditional) returns everything', () {
      expect(library.byEvidenceAtLeast(Evidence.traditional).length, library.all.length);
    });

    test('presetById resolves the new-parent bundle to its 8 original ids', () {
      final preset = library.presetById('newParent');
      expect(preset, isNotNull);
      expect(preset!.interventionIds, hasLength(8));
      // nap-when-baby-naps was merged into the library, not appended to the
      // preset's own id list — it carries the new-parent tag instead.
      expect(preset.interventionIds, isNot(contains('nap-when-baby-naps')));
    });

    test('presetById returns null for an unknown id', () {
      expect(library.presetById('does-not-exist'), isNull);
    });
  });
}
