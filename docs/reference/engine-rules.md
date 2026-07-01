# Reference: engine rules

*Information-oriented — the exact, numeric rules behind the adoption engine.
Every class here lives in `lib/features/adoption/domain/`, is pure Dart (no
DB, no widgets), and is unit-tested at every boundary named below. This is
the complete rule set — there is no hidden tuning elsewhere.*

## `StarterPackSelector`

Proposes the onboarding starter pack. Deterministic: the same
`(profile, library)` always yields the same ordered list.

- **Eligibility filter:** `isActivatable` (not `asNeeded`) **and**
  `cost.tier == free` **and** `timeCostMinutes <= 10` **and**
  `profile.hasAnchor(trigger.anchor)` (meal anchors require the matching
  `*Minutes` field to be set; every non-meal anchor always passes).
- **Scoring:** `affinity[goal][category] * 10 + (defaultPhase == 1 ? 1 : 0)`.
  The goal→category affinity table (`StarterPackSelector.affinity`) weights
  each goal toward a handful of categories — five goals (sleep, energy,
  pain, longevity, immune) weight three categories at 3/2/1 (e.g. `sleep` →
  sleep 3, stress 2, environment 1); `general` is the exception and spreads
  across four categories at 2/2/1/1 (sleep 2, nutrition 2, stress 1,
  musculoskeletal 1). A category absent from a goal's map scores 0 for that
  goal.
- **Ordering:** higher score first; ties broken by earlier `defaultPhase`;
  remaining ties broken by `id` (making the order total, hence
  deterministic).
- **Size:** `profile.pace.starterPackSize` — conservative 1, moderate 2,
  aggressive 3.

## `PromotionGate`

Advises — **never blocks** — on taking on another habit. `evaluate()`
returns a `PromotionVerdict { advisable, reasons[] }`; `advisable` is true
exactly when `reasons` is empty, and the UI always offers an "add anyway"
path regardless (see
[ADR-0003](../adr/0003-advisory-pacing-never-blocking.md)).

| Reason | Trigger condition |
|---|---|
| `tooSoon` | Fewer than `pace.minDaysBetween` days have elapsed since the most recent `activatedAt` across **any** habit state. `minDaysBetween`: conservative 7, moderate 5, aggressive 3. |
| `capReached` | `active.length >= activeCap` (`activeCap = 10`). |
| `unsteady` | **Any** active habit has ≥3 check-ins in the trailing 7 days (`now.subtract(7d)` through `now`, inclusive) with a did-rate `< 0.5`. Fewer than 3 check-ins in the window never triggers this — a single bad day can't flag a habit unsteady. |

## `GraduationDetector`

Suggests — never auto-applies — that an active habit has become automatic.
`detect()` returns `true` only when **all** of the following hold:

- `state.status == active` and `state.activatedAt` is set.
- `now.difference(activatedAt).inDays >= minActiveDays` (**21**).
- Within the trailing **14** days (`windowDays`) ending at `now`, there are
  **at least 7** check-ins for that intervention (`minSample`) — this
  guards against a one-off "did" graduating a habit that's barely been
  logged.
- Of those check-ins, the did-rate is **≥ 0.8** (`minDidRate`).

The user still confirms "this is automatic now" in the UI — `detect()` only
produces the suggestion.

## `ErosionCheck`

Finds graduated habits that have weathered. `erodedIds()` groups all
`Pulse`s by `interventionId`, sorts each group by `weekStart`, and flags an
id when it has **two *consecutive* shaky pulses** — meaning `b.weekStart -
a.weekStart == 7 days` exactly, so a gap (a week with no pulse recorded at
all) does **not** chain two distant shaky weeks together. Returns the
offending ids sorted, deterministic.

## `AdherenceStats`

Weekly aggregation **only** — there is no daily-streak computation anywhere
in this codebase, by design (see
[design-philosophy.md](../design-philosophy.md)). `weekly()` tallies
`did`/`skipped`/`forgot` per ISO week (keyed by that week's Monday, computed
from Dart's `weekday` where Monday = 1); `didRate = did / total`
(`0` when `total == 0`). `forgot` counts *against* the did-rate exactly like
`skipped` does, but is tracked as a separate tally so a repeated "forgot" can
be told apart from a deliberate "skipped" — a signal the trigger needs
changing, not that the user needs more willpower.

## `NotificationPlanner`

Plans (never applies) the day's local notifications. Pure: `plan()` returns
`List<PlannedNotification>` — the platform layer
(`notification_service_io.dart`/`_web.dart`) turns each into an actual
scheduled reminder or ignores it.

- **Clock-anchored habits** batch: every active habit anchored `wake` or
  `morning` folds into one **"Morning habits"** notification fired at
  `profile.wakeMinutes`; every habit anchored `evening` or `bed` folds into
  one **"Evening habits"** notification fired at `profile.bedMinutes - 60`
  (an hour before bed). Habits anchored `breakfast`/`lunch`/`dinner` each get
  their own individually-timed notification at the matching `*Minutes`
  field (skipped entirely if that field is null); `midday` falls back to
  `profile.lunchMinutes` if set, else a hardcoded 13:00.
- **Ambient anchors** (`brushing`, `hourly`, `stressMoment`, `weekly`,
  `asNeeded`, `custom`, `postMeal`, `shower`) schedule **nothing** — there is
  no clock moment to attach a notification to.
- **A per-habit anchor override** (`HabitState.triggerAnchorOverride`) is
  honored ahead of the intervention's own default anchor, if set.
- **The check-in reminder** (`profile.checkInMinutes`, if not null) is added
  as its own candidate.
- **Priority order:** the two batched cues and the check-in reminder are
  built as "candidates" ahead of the individually-timed habit notifications
  — if the day's cap trims the list, the batches and the check-in survive
  first.
- **Quiet window:** any candidate landing in `[bedMinutes, wakeMinutes)`
  (wrapping past midnight when bed is later in the clock than wake) is
  dropped entirely, not just delayed.
- **Cap:** at most `maxPerDay` (**5**) notifications survive per day, after
  quiet-window filtering, sorted by time-then-id for a stable final order.

On Android, the plan is applied via `flutter_local_notifications` using
`AndroidScheduleMode.inexactAllowWhileIdle` (not `SCHEDULE_EXACT_ALARM` —
see [ADR-0005](../adr/0005-local-notifications-only.md)) and a local time
zone resolved by matching the device's current UTC offset (DST-imperfect —
see [limitations.md](../limitations.md)). On web, every method on
`WebNotificationService` is a genuine no-op.

## `WallLayout`

Pure stone-packing for the Progress screen's signature wall. `pack()` lays
`graduatedCount` stones bottom-up into courses of `coursesWidth` stones each
(clamped to at least 1 column), marking the **last `erodedIds.length`**
graduated stones (clamped to `graduatedCount`) as `weathered` and the rest as
`set`; it then continues `activeCount` more stones on top as `forming`. The
wall's course/index math is entirely independent of on-screen geometry —
`WallGeometry` (in the presentation layer,
`lib/features/adoption/presentation/wall_painter.dart`) maps these abstract
placements to canvas rects and back for hit-testing, so drawing and taps can
never disagree about where a stone is. The wall never shrinks: nothing in
`WallLayout` or its caller ever removes a graduated stone once placed;
erosion can only change a stone's `kind`.
