// Pure filtering for the Library screen — no Flutter, so it is unit-tested
// directly. Search runs through ContentLibrary.search (all when the query is
// blank); the remaining predicates narrow that result set.
import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';

/// The Library's active filter selections. An empty [categories]/[costTiers]
/// set means "no restriction". [evidenceThreshold] is on Evidence.strength's
/// 0..3 scale (0 = show all, 3 = RCT-only). [maxMinutes] null means "any time".
class LibraryFilters {
  final String query;
  final Set<Category> categories;
  final int evidenceThreshold;
  final Set<CostTier> costTiers;
  final int? maxMinutes;

  const LibraryFilters({
    this.query = '',
    this.categories = const {},
    this.evidenceThreshold = 0,
    this.costTiers = const {},
    this.maxMinutes,
  });

  /// Whether any *non-search* filter is narrowing the list — drives the filter
  /// button's "active" dot.
  bool get hasFacets =>
      categories.isNotEmpty ||
      evidenceThreshold > 0 ||
      costTiers.isNotEmpty ||
      maxMinutes != null;

  /// Whether a filter from the facet sheet (evidence, cost, time) is on.
  bool get hasSheetFacets =>
      evidenceThreshold > 0 || costTiers.isNotEmpty || maxMinutes != null;

  LibraryFilters copyWith({
    String? query,
    Set<Category>? categories,
    int? evidenceThreshold,
    Set<CostTier>? costTiers,
    Object? maxMinutes = _unset,
  }) =>
      LibraryFilters(
        query: query ?? this.query,
        categories: categories ?? this.categories,
        evidenceThreshold: evidenceThreshold ?? this.evidenceThreshold,
        costTiers: costTiers ?? this.costTiers,
        maxMinutes:
            maxMinutes == _unset ? this.maxMinutes : maxMinutes as int?,
      );

  static const _unset = Object();
}

/// Applies [filters] to [library], returning the surviving interventions in the
/// library's stable (phase, id) order.
List<Intervention> filterInterventions(
  ContentLibrary library,
  LibraryFilters filters,
) {
  final base = library.search(filters.query);
  return base.where((i) {
    if (filters.categories.isNotEmpty &&
        !filters.categories.contains(i.category)) {
      return false;
    }
    if (i.evidence.strength < filters.evidenceThreshold) return false;
    if (filters.costTiers.isNotEmpty && !filters.costTiers.contains(i.cost.tier)) {
      return false;
    }
    if (filters.maxMinutes != null && i.timeCostMinutes > filters.maxMinutes!) {
      return false;
    }
    return true;
  }).toList();
}
