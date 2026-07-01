import 'enums.dart';

/// When and by what cue an intervention fires.
class Trigger {
  final Anchor anchor;
  final String note;

  const Trigger({required this.anchor, required this.note});

  factory Trigger.fromJson(Map<String, dynamic> json) => Trigger(
        anchor: Anchor.fromJson(json['anchor'] as String),
        note: json['note'] as String,
      );
}

/// Coarse cost bucket plus an optional human-readable qualifier.
class Cost {
  final CostTier tier;
  final String? note;

  const Cost({required this.tier, this.note});

  factory Cost.fromJson(Map<String, dynamic> json) => Cost(
        tier: CostTier.fromJson(json['tier'] as String),
        note: json['note'] as String?,
      );
}

/// Generic buying criteria for an intervention that requires a purchase.
/// Never a brand name, retailer, or link — see the de-personalization law.
class Shopping {
  final String item;
  final String criteria;
  final bool recurring;
  final ShopWhere where;

  const Shopping({
    required this.item,
    required this.criteria,
    required this.recurring,
    required this.where,
  });

  factory Shopping.fromJson(Map<String, dynamic> json) => Shopping(
        item: json['item'] as String,
        criteria: json['criteria'] as String,
        recurring: json['recurring'] as bool,
        where: ShopWhere.fromJson(json['where'] as String),
      );
}

/// A single library item: one evidence-tagged habit a user can queue,
/// activate, or (if [isActivatable] is false) only reference.
///
/// Immutable, content-shipped — this is not a DB row. User state (queued,
/// active, graduated, ...) lives in a later wave's drift tables, keyed by
/// [id].
class Intervention {
  final String id;
  final String title;
  final String action;
  final Category category;
  final Trigger trigger;
  final String mechanism;
  final Evidence evidence;
  final int timeCostMinutes;
  final Cost cost;
  final Shopping? shopping;
  final String? safety;
  final String details;
  final int defaultPhase;
  final List<String> tags;

  const Intervention({
    required this.id,
    required this.title,
    required this.action,
    required this.category,
    required this.trigger,
    required this.mechanism,
    required this.evidence,
    required this.timeCostMinutes,
    required this.cost,
    this.shopping,
    this.safety,
    required this.details,
    required this.defaultPhase,
    required this.tags,
  });

  /// `asNeeded`-anchored items are symptom/periodic reference material only
  /// in v0 — never activatable, never entering check-in or adherence stats.
  bool get isActivatable => trigger.anchor != Anchor.asNeeded;

  factory Intervention.fromJson(Map<String, dynamic> json) => Intervention(
        id: json['id'] as String,
        title: json['title'] as String,
        action: json['action'] as String,
        category: Category.fromJson(json['category'] as String),
        trigger: Trigger.fromJson(json['trigger'] as Map<String, dynamic>),
        mechanism: json['mechanism'] as String,
        evidence: Evidence.fromJson(json['evidence'] as String),
        timeCostMinutes: json['timeCostMinutes'] as int,
        cost: Cost.fromJson(json['cost'] as Map<String, dynamic>),
        shopping: json['shopping'] == null
            ? null
            : Shopping.fromJson(json['shopping'] as Map<String, dynamic>),
        safety: json['safety'] as String?,
        details: json['details'] as String,
        defaultPhase: json['defaultPhase'] as int,
        tags: (json['tags'] as List<dynamic>).cast<String>(),
      );
}
