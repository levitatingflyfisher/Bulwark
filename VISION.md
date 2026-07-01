# Vision

> The north star for Bulwark. If you (person or agent) are about to change
> something load-bearing, read this first — it says what must stay true and
> why. For *how it's built*, see [AGENTS.md](AGENTS.md); for *why each
> decision was made*, [docs/adr/](docs/adr/).

## The one idea

**A knowledge→behavior bridge; a floor that doesn't collapse.** Most health
information is a firehose: an ever-growing pile of things you *should* be
doing, with no mechanism for turning any one of them into something you
*actually* do, and no way to keep it once you have. Bulwark is built on the
conviction that the missing piece is not more knowledge — it's *pacing* and
*maintenance*. It introduces evidence-tagged habits a few at a time, hangs
each one off a moment you already live through (waking, a meal, brushing,
bed), and once a habit is automatic, stops asking about it daily and starts
quietly watching that it holds. The goal is not perfection. The goal is a
floor that doesn't collapse.

The metaphor is a **wall**: not a scoreboard, not a chain you can break. A
habit graduates into a stone; the wall accumulates one course at a time and
never demolishes itself. A stone can weather — two shaky weeks in a row
crack it and offer a "repoint?" — but it does not vanish. Nothing you have
built is ever taken away by the app; at worst, it's flagged as needing
attention.

## What this is

A single-user, **local-first** Flutter app holding three things:

- An **89-item intervention library**, shipped as a versioned JSON asset
  (not database rows), each item carrying a category, an anchor (when it
  fires), an evidence tag, a time and cost, and — where relevant — generic
  buying criteria and a safety note.
- An **adoption engine** (pure Dart, unit-tested): a starter-pack selector
  for onboarding, a promotion gate that *advises* (never blocks) on taking on
  another habit, a graduation detector, an erosion check for graduated
  habits, weekly adherence aggregation, a notification planner, and the wall
  layout itself.
- A **drift/SQLite** store for everything about *you* — which habits you've
  queued, activated, graduated, or paused; your daily check-ins; your weekly
  maintenance pulses; your shopping list — keyed to the shipped content by a
  stable string id.

It ships as an Android APK and an installable web PWA from one codebase, both
fully offline: the Android build declares no `INTERNET` permission at all.

It is **not** a medical device, a coach, a correlation engine, or a
subscription product. It does not try to keep your attention for its own
sake, and it does not gamify adherence with streaks, red marks, or guilt
copy.

## Design commitments (the invariants)

These are the load-bearing beliefs Bulwark shares with the rest of the
OpenHearth family, plus two specific to this app's content. Breaking one is a
design regression, not a feature. Each is recorded as an ADR and, where it's
checkable, enforced in tests.

1. **Local-first, and here, local-only.** Everything lives in an on-device
   SQLite database via Drift. There is no account, no cloud, no telemetry,
   and no subscription — the business-model half of the source PRD is void
   for this app. If sync is ever added it must be encrypted blobs through a
   dumb relay, never a backend that can read the data.
2. **No `INTERNET` permission, structurally.** The shipped Android manifest
   requests only `POST_NOTIFICATIONS`, `VIBRATE`, and
   `RECEIVE_BOOT_COMPLETED` — nothing that can open a socket. Local
   reminders schedule via `flutter_local_notifications`; the web build's
   notification service is a genuine no-op. See
   [ADR-0005](docs/adr/0005-local-notifications-only.md) and the
   [privacy model](docs/privacy-model.md).
3. **Advisory pacing, never blocking.** The promotion gate can say "you added
   one recently" or "a couple of habits are still finding their footing" —
   and every one of those verdicts ships with an "add anyway" button in the
   same breath. No gate in this app can stop a user from doing what they
   want. See [ADR-0003](docs/adr/0003-advisory-pacing-never-blocking.md).
4. **A wall, not a streak.** There is no daily-streak computation anywhere in
   the codebase. Adherence is aggregated *weekly* only, a `forgot` is tracked
   separately from a `skipped` (so a weak trigger can be told apart from a
   deliberate pass), and a graduated habit's stone weathers on two
   consecutive shaky weekly pulses — it never disappears. Copy stays
   matter-of-fact; clay (never red) is the only "attention" color in the
   palette.
5. **De-personalized, quarantined content.** The shipped content is generic
   health education: no references to any author's family, faith, medical
   history, or specific protocols, and no brand names, retailers, or
   affiliate links in shopping criteria. The private source corpus this
   content was distilled from lives outside version control entirely and is
   never meant to enter git history. See
   [ADR-0004](docs/adr/0004-de-personalization-law.md).
6. **Not medical advice, said out loud.** A disclaimer is acknowledged once
   during onboarding, repeated as a footer line on every intervention card
   and the Home check-in bar, and stated in full on the About screen.
7. **FLOSS / open by default.** MIT-licensed. The code is a recipe worth
   sharing.
8. **Genuine craft.** Clean Architecture on Flutter (domain / data /
   presentation per feature), the whole adoption engine is pure Dart covered
   by unit tests, and the shipped content JSON is itself validated by a
   `flutter test` (unique ids, valid enums, non-empty text, presets that
   resolve, the de-personalization denylist).

## Honest scorecard — built vs. deferred

A guiding light has to tell the truth about where the light reaches. Every
line of this code and every comment in it was written by an AI assistant;
treat them as **an accurate record of what currently exists, offered with
gratitude and a grain of salt** — not as a specification, and not as
guaranteed-correct. Verify a claim (read the code, run the test) before you
rely on it. As of v0.1.0, 227 tests, `flutter analyze` clean:

**Real, tested, load-bearing:**
- The full core loop: onboard (disclaimer → day map → goal/pace → starter
  pack) → the starter pack goes active → daily check-in → the promotion gate
  advises on taking on another → graduation is suggested and confirmed → the
  habit becomes a stone on the wall.
- The **89-item content library** (88 base items plus `nap-when-baby-naps`,
  merged in with a `new-parent` tag), loaded once from shipped JSON into an
  immutable, indexed `ContentLibrary` — searchable by title/action/
  mechanism/details/tags, filterable by category and a minimum evidence
  threshold. A dedicated `flutter test` fails loudly on any content schema
  bug (bad enum value, duplicate id, an unresolved preset reference, a
  denylisted string).
- The **adoption engine**: `StarterPackSelector` (deterministic, goal-scored,
  phase-biased), `PromotionGate` (tooSoon / capReached / unsteady — advisory
  only), `GraduationDetector` (≥21 days active, ≥7 check-ins and ≥80% did-rate
  over the trailing 14 days), `ErosionCheck` (two *consecutive* shaky weekly
  pulses, exactly 7 days apart), `AdherenceStats` (weekly aggregation, no
  daily streak), `NotificationPlanner` (≤5/day, morning/evening batching,
  quiet window), and `WallLayout` (pure stone packing) — every rule and
  boundary condition unit-tested.
- **The wall**, hand-painted (`WallPainter`/`WallGeometry`): set / forming /
  weathered stones, a running-bond course offset, deterministic per-stone
  jitter so it reads as masonry rather than a grid, and a tap-to-reveal sheet
  naming the habit and its graduation date.
- **The New Parent Mode preset**: a pre-configured "survival stack" bundle
  offered during onboarding, reconciled against the live content library so
  every id in it is guaranteed to resolve.
- **Local reminders on Android** via `flutter_local_notifications`
  (`inexactAllowWhileIdle`, DST-imperfect same-offset zone matching — see
  [limitations](docs/limitations.md)) and a genuine no-op on web.
- **Data export**, two ways: a plaintext JSON dump (profile/habits/check-ins/
  pulses/shopping state, share-sheeted, never uploaded — portability, no
  restore path) and an **encrypted `.ohbk` backup** (same scope, ChaCha20-
  Poly1305-sealed under a key derived from a 12-word recovery phrase
  generated on-device — Ghost-tier `sanctuary_auth_core`, the same primitives
  as the rest of the OpenHearth fleet). The backup *does* restore:
  destructive-replace inside one transaction, behind an explicit "this
  replaces everything" confirmation. Plus **erase-all-data** (wipes every
  user table in one transaction, returns to onboarding).
- Fully offline on Android and web; bundled fonts (Lora/Nunito), no
  `google_fonts` egress.

**Deferred — documented, not shipped:**
- **Health-data integration** (Apple Health / Google Fit) — no reads or
  writes to any platform health store.
- **A correlation engine or LLM Q&A.** Bulwark surfaces evidence tags on
  content it ships; it does not analyze your check-in history for
  correlations, and there is no on-device or cloud model anywhere in the
  app.
- **Adaptive sequencing.** The starter pack and the promotion gate use fixed,
  hand-written rules (affinity tables, day/rate thresholds) — nothing learns
  from your outcomes or adjusts its own thresholds.
- **A seasonal engine.** Content and pacing do not vary by time of year.
- **iOS.** The Flutter project could target it; only Android + web ship
  today.
- **Sync / multi-device / multi-user.** There is no account and no server;
  an export (plaintext or encrypted) is the only way data leaves a device,
  and only when you explicitly trigger it — moving to a new device is a
  manual restore, not a login.

**Known limits, honestly:**
- **Content is education, not medical advice** — said in onboarding, on
  every card, and on the About screen, but it bears repeating here: nothing
  shipped in `assets/content/` has been reviewed by a clinician for any
  individual's situation.
- **Evidence tags are conservative and hand-assigned**, not the product of a
  systematic review; `rct`/`observational`/`mechanistic`/`traditional` are a
  coarse, four-level bucket, not a meta-analysis.
- **Notifications are inexact and DST-imperfect on Android.** Scheduling
  deliberately uses `AndroidScheduleMode.inexactAllowWhileIdle` rather than
  requesting `SCHEDULE_EXACT_ALARM` (keeping the permission footprint
  minimal), and the local time zone is resolved by matching the current UTC
  offset rather than a device timezone lookup — correct for a daily
  wall-clock reminder, but it can pick a same-offset sibling zone and will
  not self-correct mid-flight across a DST transition.
- **No cloud sync, by design** — losing the device loses the data unless you
  made a copy yourself. The encrypted backup is the only one that restores,
  and its recovery phrase is the only key — lose both the phrase and the
  device and that backup is gone for good, the same honest cost as any
  local-only, no-account design.
- **`asNeeded` items are reference-only** (9 of the 89) — searchable and
  pinnable, but never activatable, and they never enter check-in or
  adherence stats. Honest > clever, per the content-integration decision
  log.
- **Single-user.** There are no profiles; a shared household device shares
  one dataset.

## Horizons (problems, not a feature list)

Framed as problems on purpose — a dated feature list self-destructs.

- **Near** — Health-data integration as a *read-only signal*, not a write
  target: could a sleep or step count from the OS health store refine the
  starter pack or the promotion gate's "unsteady" check, without Bulwark
  ever writing back? The privacy cost of that read needs to be worth the
  gain before it's built.
- **Mid** — A general erosion/graduation criterion engine, so tuning the
  thresholds (21 days, 80% did-rate, two shaky weeks) is a content change,
  not a code change — today they're hand-written constants in the domain
  layer.
- **Far** — The honest hard one, shared with Furrow: **presence without
  pressure.** A reminder system that never nags is a reminder system easy to
  forget; the unsolved problem is a genuinely adaptive nudge that respects a
  person rather than a growth metric. Nobody in this category has solved it
  well; we would rather ship inexact, capped, quiet-hours reminders than a
  dark pattern.

## The name

**Bulwark** — a defensive wall, literally "bole-work," a structure built from
tree trunks or masonry to hold a line. It carries the right connotation
without romanticizing the fight: a bulwark does not defeat entropy, it holds
a floor against it, one course at a time. Forked from
[Furrow](https://github.com/levitatingflyfisher/Furrow) — a good fork should
not be mistaken for its parent, and a wall is visually and thematically
nothing like a plough-line. See
[ADR-0001](docs/adr/0001-fork-from-furrow.md).
