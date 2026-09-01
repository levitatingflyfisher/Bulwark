# Reference: data model

*Information-oriented — the drift/SQLite tables that hold everything about
*you*. Source of truth: `lib/core/storage/app_database.dart`. Content (the
intervention library) is **not** in here — see
[content-schema.md](content-schema.md); every table below references it
only by the intervention's shipped string `id`.*

Current `schemaVersion`: **2**. This is a fresh app (no public release
predates it), but the schema still moved once during development: a v1 dev
database had only `UserPrefs`; the `onUpgrade` path adds every adoption/state
table when it detects `from < 2`. There is no migration older than that.

## `UserPrefs`

Simple key→value store for shell preferences: `theme_mode` (`system`,
`light` or `dark`; missing or unknown means follow the phone),
`reminders` (`on`/`off`, missing means off), and `forgot_nudge:<id>` (the
ISO date the "keeps forgetting" offer was last answered for that habit; a
UI memory, not in exports or backups).

| Column | Type | Notes |
|---|---|---|
| `key` | TEXT | Primary key. |
| `value` | TEXT | |

## `HabitStates`

Per-intervention adoption state — where a habit sits in the
queued→active→graduated lifecycle, plus paused ("set aside": off Today,
every field kept, one Activate from active again). Generated row class is
`HabitStateRow` (to avoid colliding with the domain `HabitState`).

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | Autoincrement primary key. |
| `interventionId` | TEXT | **Unique.** The join key into the shipped content. |
| `status` | INTEGER | `HabitStatus` ordinal: `queued=0, active=1, graduated=2, paused=3`. **Load-bearing — do not reorder the enum.** (A never-written `retired=3` was removed before any install existed, which moved `paused` from 4.) |
| `queuePosition` | INTEGER? | Rank while queued; null once a habit leaves the queue. |
| `activatedAt` | DATETIME? | Set when a habit becomes active (including re-activation via "repoint"). |
| `graduatedAt` | DATETIME? | Set when a habit graduates. |
| `triggerAnchorOverride` | TEXT? | An `Anchor.name` string overriding the intervention's default trigger anchor; null keeps the content default. |
| `reminderEnabled` | BOOLEAN | Default `false`. Per-habit reminder opt-in. |
| `createdAt` | DATETIME | |

## `Checkins`

One daily self-report per (intervention, date). Row class `CheckinRow`.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | Autoincrement primary key. |
| `interventionId` | TEXT | |
| `date` | DATETIME | Date-only (midnight). |
| `result` | INTEGER | `CheckinResult` ordinal: `did=0, skipped=1, forgot=2`. |
| `note` | TEXT? | Optional, user-authored. |

**Unique key:** `(interventionId, date)` — re-checking a habit today updates
today's row in place rather than duplicating it.

## `Pulses`

One weekly maintenance pulse per (intervention, weekStart), for **graduated**
habits only. Row class `PulseRow`.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | Autoincrement primary key. |
| `interventionId` | TEXT | |
| `weekStart` | DATETIME | Date-only Monday of the pulse's week. |
| `result` | INTEGER | `PulseResult` ordinal: `solid=0, shaky=1`. |

**Unique key:** `(interventionId, weekStart)`.

## `ShoppingStates`

Whether a shoppable intervention's supply has been acquired. Row class
`ShoppingStateRow`.

| Column | Type | Notes |
|---|---|---|
| `interventionId` | TEXT | Primary key. |
| `purchased` | BOOLEAN | Default `false`. |
| `purchasedAt` | DATETIME? | Set when `purchased` flips true. |

## `Profiles`

The onboarding answers. A **single-row table**, pinned to `id = 1`. Row class
`ProfileRow`.

| Column | Type | Notes |
|---|---|---|
| `id` | INTEGER | Default `1` — there is exactly one row. |
| `wakeMinutes` | INTEGER | Minutes since midnight. |
| `bedMinutes` | INTEGER | Minutes since midnight. |
| `breakfastMinutes` | INTEGER? | Null = no breakfast anchor available. |
| `lunchMinutes` | INTEGER? | Null = no lunch anchor available. |
| `dinnerMinutes` | INTEGER? | Null = no dinner anchor available. |
| `goal` | TEXT | `Goal.name`: `sleep, energy, pain, longevity, immune, general`. |
| `pace` | INTEGER | `Pace` ordinal **+1**: `conservative=1, moderate=2, aggressive=3` (see `Pace` in `lib/features/adoption/domain/enums.dart` — `.index` alone would be off by one against this column; the domain layer handles the mapping). |
| `checkInMinutes` | INTEGER? | Minutes since midnight for the daily check-in reminder; null = opted out. |
| `evidenceThreshold` | INTEGER | Default `0`. `0..3` on the same scale as `Evidence.strength` (0 = show all, 3 = RCT-only). |
| `onboarded` | BOOLEAN | Default `false`. The router's redirect gate keys off this. |
| `newParentMode` | BOOLEAN | Default `false`. |

## Cross-cutting behavior

- **`AppDatabase.eraseUserData()`** wipes `habitStates`, `checkins`,
  `pulses`, `shoppingStates`, and `profiles` in one transaction — the
  "Erase all data" path in Settings. It deliberately leaves `UserPrefs`
  alone (theme, the reminders switch survive an erase); clearing the
  profile is what sends the app back to onboarding.
- **No DAO layer.** Every repository (`lib/features/adoption/data/*_repository.dart`)
  takes an `AppDatabase` directly rather than routing through a separate DAO
  class — a deliberate house-style simplification carried over from Furrow
  and Reckon.
- **`PRAGMA foreign_keys = ON`** is set in `beforeOpen`, though no table
  currently declares a foreign key — the tables are joined in application
  code via the shared `interventionId` string, not a SQL constraint.
