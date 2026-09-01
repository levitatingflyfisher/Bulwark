// Plain-language labels for shipped content enums, shared by the Library rows
// and the Intervention Detail card. Kept matter-of-fact — no hype, no ranking
// of one habit above another.
import 'package:bulwark/features/library/domain/enums.dart';

/// A short, human name for the body system a habit targets.
String categoryLabel(Category category) => switch (category) {
      Category.sleep => 'Sleep',
      Category.nutrition => 'Nutrition',
      Category.metabolic => 'Metabolic',
      Category.dental => 'Dental',
      Category.musculoskeletal => 'Movement',
      Category.stress => 'Stress',
      Category.environment => 'Environment',
      Category.skin => 'Skin',
      Category.hygiene => 'Hygiene',
    };

/// A short, human name for the daily/periodic moment a habit is anchored to.
String anchorLabel(Anchor anchor) => switch (anchor) {
      Anchor.wake => 'On waking',
      Anchor.morning => 'In the morning',
      Anchor.breakfast => 'At breakfast',
      Anchor.midday => 'Around midday',
      Anchor.lunch => 'At lunch',
      Anchor.dinner => 'At dinner',
      Anchor.postMeal => 'After a meal',
      Anchor.evening => 'In the evening',
      Anchor.bed => 'At bedtime',
      Anchor.brushing => 'When brushing',
      Anchor.shower => 'In the shower',
      Anchor.stressMoment => 'In a stressful moment',
      Anchor.hourly => 'Through the day',
      Anchor.weekly => 'Once a week',
      Anchor.asNeeded => 'As needed',
      Anchor.custom => 'At its own time',
    };

/// A short cost hint. Never a price or brand — a coarse bucket only.
String costLabel(CostTier tier) => switch (tier) {
      CostTier.free => 'Free',
      CostTier.oneTimeUnder50 => 'One-time, under \$50',
      CostTier.oneTimeUnder200 => 'One-time, under \$200',
      CostTier.recurring => 'Ongoing',
    };

/// A short time hint for a habit's daily cost.
String timeLabel(int minutes) =>
    minutes <= 0 ? 'No extra time' : '$minutes min';

/// A short, human name for where a shopping item is generically sourced.
String shopWhereLabel(ShopWhere where) => switch (where) {
      ShopWhere.grocery => 'Grocery',
      ShopWhere.pharmacy => 'Pharmacy',
      ShopWhere.online => 'Online',
    };

/// One calm sentence explaining what an evidence tier means, for the Detail
/// card — so the tag informs rather than just labels.
String evidenceGloss(Evidence evidence) => switch (evidence) {
      Evidence.rct =>
        'Tested in randomized controlled trials, the most direct kind of '
            'human evidence.',
      Evidence.observational =>
        'Backed by observational studies that follow outcomes over time, but '
            'cannot prove cause on their own.',
      Evidence.mechanistic =>
        'Supported by a plausible biological mechanism, with less direct '
            'outcome data in people.',
      Evidence.traditional =>
        'A long-standing traditional practice with limited formal study.',
    };
