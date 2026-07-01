# Reference: content schema

*Information-oriented — the exact shape of the shipped content and the
enums it's built from. Source of truth: `lib/features/library/domain/{intervention,preset,enums}.dart`
and the two files under `assets/content/`. Enforced by
`test/content/content_validation_test.dart`.*

Content ships as versioned JSON **assets**, not database rows — see
[ADR-0002](../adr/0002-content-as-shipped-assets.md) for why. The app loads
`assets/content/interventions.json` and `assets/content/presets.json` once
at startup (`ContentLoader`) into an immutable, indexed `ContentLibrary`.
User state never touches this data directly; it references an intervention
only by its `id` string.

## `interventions.json`

A JSON array. As of this writing it ships **89 items** (88 authored plus
`nap-when-baby-naps`, which was merged into the main library — tagged
`new-parent` — rather than left only inside the New Parent preset). Each
item:

| Field | Type | Notes |
|---|---|---|
| `id` | string | Stable across releases — this is the join key to every drift row. Never repurpose an existing id for a different habit. |
| `title` | string | Non-empty. |
| `action` | string | The one-line instruction ("Wake at the same time every day…"). Non-empty. |
| `category` | string | One of the 9 [`Category`](#category) values. |
| `trigger` | object | `{ "anchor": string, "note": string }` — `anchor` is one of the 16 [`Anchor`](#anchor) values; `note` is the human trigger description shown on Home/Detail. |
| `mechanism` | string | The one-line "why it works" shown on Home cards. Non-empty. |
| `evidence` | string | One of the 4 [`Evidence`](#evidence) values. |
| `timeCostMinutes` | int | Daily time cost; `0` renders as "No extra time". |
| `cost` | object | `{ "tier": string, "note": string? }` — `tier` is one of the 4 [`CostTier`](#costtier) values. |
| `shopping` | object? | `null`, or `{ "item": string, "criteria": string, "recurring": bool, "where": string }`. `criteria` is **generic buying guidance only** — never a brand, retailer, or link (the de-personalization law, [ADR-0004](../adr/0004-de-personalization-law.md)). `recurring: true` **must** pair with `cost.tier == "recurring"` — enforced by the validation test. `where` is one of the 3 [`ShopWhere`](#shopwhere) values. |
| `safety` | string? | An optional caution, rendered as a calm "Good to know" note (clay, never red) — not a contraindication database. |
| `details` | string | The longer explanation shown on the Detail screen. Non-empty. |
| `defaultPhase` | int | `1..8` inclusive. Used as the primary sort key for the library's stable order and as a mild bias in starter-pack scoring (phase 1 gets a small bonus). Not a strict rollout gate — nothing in the app currently blocks a later-phase item from being activated directly. |
| `tags` | string[] | Free-form; searched alongside title/action/mechanism/details. `new-parent` is the one tag the app currently reads structurally (see [presets](#presetsjson) below). |

### `isActivatable`

Computed, not stored: `trigger.anchor != asNeeded`. See
[activatable vs. reference-only](#activatable-vs-reference-only).

## Enums

Every enum parses via a strict `fromJson` that **throws a `FormatException`**
on an unrecognized value rather than silently coercing — a content typo is a
build-breaking bug, not a quiet default (`lib/features/library/domain/enums.dart`).

### `Category`
9 values: `sleep`, `nutrition`, `metabolic`, `dental`, `musculoskeletal`,
`stress`, `environment`, `skin`, `hygiene`.

### `Anchor`
16 values: `wake`, `morning`, `breakfast`, `midday`, `lunch`, `dinner`,
`postMeal`, `evening`, `bed`, `brushing`, `shower`, `stressMoment`, `hourly`,
`weekly`, `asNeeded`, `custom`.

Of these, only `wake`/`morning`/`breakfast`/`midday`/`lunch`/`dinner`/
`evening`/`bed` are clock-anchored moments the `NotificationPlanner` can
schedule against; the rest are ambient (see
[engine-rules.md](engine-rules.md#notificationplanner)). `custom` is, in
practice, the most common anchor in the shipped content — most habits carry
a specific `trigger.note` cue rather than a clock moment. `lunch` is declared
and fully supported (`Profile.hasAnchor`, the planner) but no shipped item
currently uses it.

### `Evidence`
4 values, strongest to weakest: `rct`, `observational`, `mechanistic`,
`traditional`. Use `.strength` (not `.index`) for "at least this strong"
comparisons — `rct.strength == 3` down to `traditional.strength == 0` — this
is what `evidenceThreshold` (0..3) in the `Profile` and the Library's
evidence filter compare against.

### `CostTier`
4 values: `free`, `oneTimeUnder50`, `oneTimeUnder200`, `recurring`. Coarse
buckets only — never a specific price.

### `ShopWhere`
3 values: `grocery`, `pharmacy`, `online`.

## Activatable vs. reference-only

Items anchored `asNeeded` (9 of the 89 as shipped — symptom-triggered things
like zinc lozenges, or periodic things like an annual bloodwork panel or a
filter swap) are **reference-only in this version**: they ship in the
library, are fully searchable and pinnable, but their detail card shows
"Reference only for now" instead of Activate/Queue buttons, and they can
never enter a check-in or contribute to adherence stats. This was a
deliberate content-integration decision — honest about what the app can
track daily, rather than forcing a symptom-triggered item into a daily
check-in row it doesn't belong in.

## `presets.json`

A JSON **object** keyed by preset id (not an array) — `{ "newParent": {...}
}`. Each value:

| Field | Type | Notes |
|---|---|---|
| `title` | string | |
| `description` | string | |
| `interventionIds` | string[] | Every id **must** resolve in `interventions.json` — enforced by the validation test. |
| `bundleNotes` | string? | Free-text guidance for taking the bundle as a whole (timing, sequencing). |

### The shipped `newParent` preset

Offered during onboarding when a user flips "Caring for a newborn?". It
carries **8** `interventionIds` (creatine, vitamin-d3-k2, omega-3,
phosphatidylserine, magnesium-glycinate, glycine-before-bed,
caffeine-cutoff, morning-sunlight) — note that `nap-when-baby-naps` is
**not** in this list even though it's part of the "survival stack" idea; it
was merged into the main library with a `new-parent` tag instead of being
appended to the preset, so it's discoverable by tag/search but not
double-counted against the preset's own id list.

## Validating a content change

Any edit to either JSON file should leave
`test/content/content_validation_test.dart` green. It checks (among other
things): ids are unique; every enum value parses; `defaultPhase` is
`1..8`; `title`/`action`/`mechanism`/`details` are non-empty; a
`recurring: true` shopping item has `cost.tier == recurring`; every preset's
`interventionIds` resolve; `asNeeded` items are exactly the non-activatable
ones; and the de-personalization denylist (`Word of Wisdom`, `VBAC`,
`Olympian`, `Mom`, plus a small brand-name list) matches nothing, anywhere in
either file, word-boundaried so it doesn't false-positive on substrings like
"toward" or "momentum". If you change the total item count, update the
test's `89` assertion deliberately — it's meant to catch an *accidental*
count drift, not to be edited reflexively.
