/// A curated bundle of interventions offered as a unit during onboarding
/// (e.g. "New parent survival stack"). Ships as shipped-asset content,
/// keyed by id in [ContentLibrary] just like interventions.
class Preset {
  final String id;
  final String title;
  final String description;
  final List<String> interventionIds;
  final String? bundleNotes;

  const Preset({
    required this.id,
    required this.title,
    required this.description,
    required this.interventionIds,
    this.bundleNotes,
  });

  /// [id] is supplied separately because presets.json keys each preset by id
  /// rather than carrying it as a field (`{"newParent": {...}}`).
  factory Preset.fromJson(String id, Map<String, dynamic> json) => Preset(
        id: id,
        title: json['title'] as String,
        description: json['description'] as String,
        interventionIds:
            (json['interventionIds'] as List<dynamic>).cast<String>(),
        bundleNotes: json['bundleNotes'] as String?,
      );
}
