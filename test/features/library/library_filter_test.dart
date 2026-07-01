import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/presentation/library_filter.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/content_builders.dart';

void main() {
  final library = libraryOf([
    intervention(
        id: 'sleep-window',
        category: Category.sleep,
        evidence: Evidence.rct,
        timeCostMinutes: 5,
        costTier: CostTier.free),
    intervention(
        id: 'eat-protein',
        category: Category.nutrition,
        evidence: Evidence.observational,
        timeCostMinutes: 10,
        costTier: CostTier.oneTimeUnder50),
    intervention(
        id: 'box-breathing',
        category: Category.stress,
        evidence: Evidence.mechanistic,
        timeCostMinutes: 2,
        costTier: CostTier.free),
    intervention(
        id: 'cold-shower',
        category: Category.skin,
        evidence: Evidence.traditional,
        timeCostMinutes: 3,
        costTier: CostTier.recurring),
  ]);

  List<String> ids(LibraryFilters f) =>
      filterInterventions(library, f).map((i) => i.id).toList();

  test('no filters returns the whole library in stable order', () {
    expect(ids(const LibraryFilters()),
        ['box-breathing', 'cold-shower', 'eat-protein', 'sleep-window']);
  });

  test('search narrows to matching items', () {
    expect(ids(const LibraryFilters(query: 'sleep')), ['sleep-window']);
  });

  test('category filter narrows to the selected categories', () {
    expect(ids(const LibraryFilters(categories: {Category.nutrition})),
        ['eat-protein']);
  });

  test('evidence threshold keeps only items at least that strong', () {
    // 2 = observational-or-stronger drops mechanistic + traditional.
    expect(ids(const LibraryFilters(evidenceThreshold: 2)),
        ['eat-protein', 'sleep-window']);
  });

  test('cost-tier filter narrows to the selected tiers', () {
    expect(ids(const LibraryFilters(costTiers: {CostTier.free})),
        ['box-breathing', 'sleep-window']);
  });

  test('max-time filter drops slower habits', () {
    expect(ids(const LibraryFilters(maxMinutes: 3)),
        ['box-breathing', 'cold-shower']);
  });

  test('filters compose', () {
    const f = LibraryFilters(
      categories: {Category.sleep, Category.nutrition},
      evidenceThreshold: 3,
    );
    expect(ids(f), ['sleep-window']);
  });
}
