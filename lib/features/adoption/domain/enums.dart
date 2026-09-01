// User-state enums for the adoption feature. Unlike the library enums these
// are never parsed from shipped JSON — they are persisted as ints/text in the
// drift tables, so the stored ordinals below are load-bearing and must not be
// reordered (see the data layer's row↔domain mapping).

/// Lifecycle of a habit as the user adopts, sustains, or sets it aside.
/// Stored as its `.index` (queued 0, active 1, graduated 2, paused 3).
/// `paused` is "set aside": off Today, kept with all its fields, one tap from
/// active again. (A `retired` state was declared and never written; it was
/// removed before any install existed, which is why paused moved from 4.)
enum HabitStatus { queued, active, graduated, paused }

/// A single day's self-report for an active habit. Stored as its `.index`
/// (did 0, skipped 1, forgot 2). `forgot` is a miss that also signals a weak
/// trigger — it counts against adherence but is queried separately.
enum CheckinResult { did, skipped, forgot }

/// A graduated habit's weekly maintenance pulse. Stored as `.index`
/// (solid 0, shaky 1).
enum PulseResult { solid, shaky }

/// The user's headline reason for using Bulwark; steers starter-pack scoring.
/// Stored as its `.name`.
enum Goal { sleep, energy, pain, longevity, immune, general }

/// How fast the user wants to take on new habits. Stored as `.index + 1`
/// (conservative 1, moderate 2, aggressive 3) per the drift schema.
enum Pace {
  conservative,
  moderate,
  aggressive;

  /// Minimum days since the last activation the promotion gate advises before
  /// suggesting another habit.
  int get minDaysBetween => switch (this) {
        Pace.conservative => 7,
        Pace.moderate => 5,
        Pace.aggressive => 3,
      };

  /// How many interventions the starter pack proposes at once.
  int get starterPackSize => switch (this) {
        Pace.conservative => 1,
        Pace.moderate => 2,
        Pace.aggressive => 3,
      };
}
