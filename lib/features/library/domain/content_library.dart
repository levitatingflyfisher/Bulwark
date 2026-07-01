import 'enums.dart';
import 'intervention.dart';
import 'preset.dart';

/// The whole shipped content set, indexed for fast lookup. Pure, no I/O —
/// building one from raw JSON is the data layer's job (see
/// `content_loader.dart`); this class only organizes already-parsed content.
class ContentLibrary {
  /// All interventions keyed by id.
  final Map<String, Intervention> byId;

  /// Every intervention, stable-ordered by (defaultPhase, id).
  final List<Intervention> all;

  /// All presets, in the order they appeared in the source JSON.
  final List<Preset> presets;

  final Map<Category, List<Intervention>> _byCategory;
  final Map<String, Preset> _presetsById;

  ContentLibrary._({
    required this.byId,
    required this.all,
    required this.presets,
    required Map<Category, List<Intervention>> byCategory,
    required Map<String, Preset> presetsById,
  })  : _byCategory = byCategory,
        _presetsById = presetsById;

  /// Builds the indexed library from already-parsed content.
  factory ContentLibrary.build({
    required List<Intervention> interventions,
    required List<Preset> presets,
  }) {
    final sorted = List<Intervention>.of(interventions)
      ..sort((a, b) {
        final byPhase = a.defaultPhase.compareTo(b.defaultPhase);
        return byPhase != 0 ? byPhase : a.id.compareTo(b.id);
      });

    final byId = <String, Intervention>{};
    final byCategory = <Category, List<Intervention>>{};
    for (final intervention in sorted) {
      byId[intervention.id] = intervention;
      byCategory
          .putIfAbsent(intervention.category, () => <Intervention>[])
          .add(intervention);
    }

    return ContentLibrary._(
      byId: Map.unmodifiable(byId),
      all: List.unmodifiable(sorted),
      presets: List.unmodifiable(presets),
      byCategory: {
        for (final entry in byCategory.entries)
          entry.key: List.unmodifiable(entry.value),
      },
      presetsById: Map.unmodifiable({
        for (final preset in presets) preset.id: preset,
      }),
    );
  }

  /// Parses the two content JSON documents (interventions array, presets
  /// object keyed by preset id) into an indexed [ContentLibrary].
  factory ContentLibrary.fromJson({
    required List<dynamic> interventionsJson,
    required Map<String, dynamic> presetsJson,
  }) {
    final interventions = interventionsJson
        .map((e) => Intervention.fromJson(e as Map<String, dynamic>))
        .toList();
    final presets = presetsJson.entries
        .map((e) => Preset.fromJson(e.key, e.value as Map<String, dynamic>))
        .toList();
    return ContentLibrary.build(interventions: interventions, presets: presets);
  }

  Intervention? byIdOrNull(String id) => byId[id];

  List<Intervention> byCategory(Category category) =>
      _byCategory[category] ?? const [];

  /// Interventions whose evidence is at least as strong as [threshold]
  /// (e.g. `byEvidenceAtLeast(Evidence.observational)` includes rct too).
  List<Intervention> byEvidenceAtLeast(Evidence threshold) => all
      .where((intervention) => intervention.evidence.strength >= threshold.strength)
      .toList();

  /// Case-insensitive substring search over title, action, mechanism,
  /// details, and tags.
  List<Intervention> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((intervention) {
      if (intervention.title.toLowerCase().contains(q)) return true;
      if (intervention.action.toLowerCase().contains(q)) return true;
      if (intervention.mechanism.toLowerCase().contains(q)) return true;
      if (intervention.details.toLowerCase().contains(q)) return true;
      return intervention.tags.any((tag) => tag.toLowerCase().contains(q));
    }).toList();
  }

  Preset? presetById(String id) => _presetsById[id];
}
