// Domain enums for the intervention library. Values are stored/shipped as
// their exact `.name` string in the content JSON; an unknown value is a
// content bug and must fail loudly rather than silently coerce, so every
// `fromJson` here throws instead of falling back to a default.

/// The body system an intervention primarily targets.
enum Category {
  sleep,
  nutrition,
  metabolic,
  dental,
  musculoskeletal,
  stress,
  environment,
  skin,
  hygiene;

  static Category fromJson(String value) => _parse(values, value, 'Category');
}

/// The daily/periodic moment a habit's trigger is anchored to.
///
/// Exactly these 16 values — the content wave's reconciled anchor taxonomy.
/// `asNeeded` marks reference-only items (see [Intervention.isActivatable]).
enum Anchor {
  wake,
  morning,
  breakfast,
  midday,
  lunch,
  dinner,
  postMeal,
  evening,
  bed,
  brushing,
  shower,
  stressMoment,
  hourly,
  weekly,
  asNeeded,
  custom;

  static Anchor fromJson(String value) => _parse(values, value, 'Anchor');
}

/// Strength-of-evidence tag. Ordered strongest-to-weakest via [strength] so
/// "at least this strength" thresholds (e.g. an evidence filter/settings
/// slider) are expressible as a simple integer comparison.
///
/// Use [strength], never `.index`: the enum is declared strongest-first, so
/// `.index` would give `rct` the *lowest* number (0) — the opposite of what
/// "at least this strong" needs. [strength] runs the other way (rct=3 down
/// to traditional=0) and lines up directly with the drift `Profile.
/// evidenceThreshold` column planned for the data-layer wave (`{0 all …
/// 3 rct-only}`) — a stored threshold int maps straight onto an [Evidence]
/// via that same 0..3 scale, no translation table needed.
enum Evidence {
  rct,
  observational,
  mechanistic,
  traditional;

  static Evidence fromJson(String value) => _parse(values, value, 'Evidence');

  /// Higher is stronger evidence. `rct` is strongest, `traditional` weakest.
  int get strength => switch (this) {
        Evidence.rct => 3,
        Evidence.observational => 2,
        Evidence.mechanistic => 1,
        Evidence.traditional => 0,
      };
}

/// Coarse cost bucket for an intervention (never a specific price/brand).
enum CostTier {
  free,
  oneTimeUnder50,
  oneTimeUnder200,
  recurring;

  static CostTier fromJson(String value) => _parse(values, value, 'CostTier');
}

/// Where a shopping item is generically sourced.
enum ShopWhere {
  grocery,
  pharmacy,
  online;

  static ShopWhere fromJson(String value) => _parse(values, value, 'ShopWhere');
}

/// Shared enum-parse helper: exact `.name` match or throw. Using
/// [Iterable.byName]'s own [ArgumentError] would work, but wrapping it names
/// the offending enum in the message, which matters when 88+ content items
/// funnel through the same parser.
T _parse<T extends Enum>(List<T> values, String value, String enumName) {
  for (final v in values) {
    if (v.name == value) return v;
  }
  throw FormatException('Unknown $enumName value “$value”');
}
