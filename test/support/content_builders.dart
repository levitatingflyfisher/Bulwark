import 'package:bulwark/features/library/domain/content_library.dart';
import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/features/library/domain/intervention.dart';

/// Terse [Intervention] factory for engine tests — every field defaulted so a
/// test only states the axis it cares about.
Intervention intervention({
  required String id,
  Category category = Category.sleep,
  Anchor anchor = Anchor.wake,
  Evidence evidence = Evidence.rct,
  int timeCostMinutes = 5,
  CostTier costTier = CostTier.free,
  int defaultPhase = 1,
  List<String> tags = const [],
  Shopping? shopping,
  String? safety,
  String details = 'details',
}) =>
    Intervention(
      id: id,
      title: id,
      action: 'do $id',
      category: category,
      trigger: Trigger(anchor: anchor, note: 'when'),
      mechanism: 'because',
      evidence: evidence,
      timeCostMinutes: timeCostMinutes,
      cost: Cost(tier: costTier),
      shopping: shopping,
      safety: safety,
      details: details,
      defaultPhase: defaultPhase,
      tags: tags,
    );

ContentLibrary libraryOf(List<Intervention> interventions) =>
    ContentLibrary.build(interventions: interventions, presets: const []);
