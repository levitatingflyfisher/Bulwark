import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bulwark/features/library/domain/content_library.dart';

/// Loads the shipped content assets (interventions + presets JSON) into an
/// indexed [ContentLibrary]. Assets only, via `rootBundle` — no dart:io, so
/// this stays web-safe.
class ContentLoader {
  const ContentLoader();

  static const _interventionsAsset = 'assets/content/interventions.json';
  static const _presetsAsset = 'assets/content/presets.json';

  Future<ContentLibrary> load() async {
    final interventionsRaw = await rootBundle.loadString(_interventionsAsset);
    final presetsRaw = await rootBundle.loadString(_presetsAsset);
    final interventionsJson = jsonDecode(interventionsRaw) as List<dynamic>;
    final presetsJson = jsonDecode(presetsRaw) as Map<String, dynamic>;
    return ContentLibrary.fromJson(
      interventionsJson: interventionsJson,
      presetsJson: presetsJson,
    );
  }
}

/// The whole content library, loaded once from shipped assets. A plain
/// `FutureProvider` is keepAlive by default (only `.autoDispose` opts out),
/// so this stays resident for the app's lifetime without extra ceremony.
/// Hand-written rather than `@riverpod`-codegen'd — this feature has no
/// other provider needs that would justify the riverpod_generator/
/// build_runner machinery.
final contentLibraryProvider = FutureProvider<ContentLibrary>((ref) {
  return const ContentLoader().load();
});
