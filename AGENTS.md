# AGENTS.md

Guidance for AI coding agents (and humans) working in this repo. This is the
top-level map; when in doubt, the file closest to what you're editing wins.

**Read these, in order, before non-trivial work:**
1. [VISION.md](VISION.md) — what must stay true and why (the invariants).
2. [docs/adr/](docs/adr/) — the load-bearing decisions, so you don't
   re-litigate a settled trade-off.
3. [docs/reference/](docs/reference/) — the exact content schema, data
   model, and engine rules, if you're touching any of those.

## Take the code as current-state, not gospel

Every line of source and every comment here was written by an AI assistant.
Treat it as **an accurate record of what currently exists, offered with
gratitude and a grain of salt** — not as a specification and not as
guaranteed-correct. A comment claiming an invariant is a *hypothesis to
verify*, not a proof. If a comment and the tests disagree, the tests win; if
the tests and reality disagree, reality wins. When you rely on a claim,
confirm it (read the code, run the test) first.

## What this is

A single-user, **local-first** Flutter health-habit app. An 89-item
evidence-tagged intervention library ships as a versioned JSON asset; a pure
Dart adoption engine (starter pack, promotion gate, graduation, erosion,
adherence, notification planning, wall layout) governs how habits move
queued → active → graduated; a Drift/SQLite store holds only user state,
keyed to content by a stable string id. Ships as an Android APK (no
`INTERNET` permission) and an installable web PWA from one codebase, fully
offline. Clean Architecture (domain / data / presentation per feature),
Riverpod for state, Drift over SQLite for storage, `go_router` for
navigation. Forked from [Furrow](https://github.com/levitatingflyfisher/Furrow)
— see [ADR-0001](docs/adr/0001-fork-from-furrow.md).

## Non-negotiables (breaking one is a regression, not a feature)

- **No `INTERNET` permission, ever, in the shipped Android build.** The
  release manifest (`android/app/src/main/AndroidManifest.xml`) requests
  only `POST_NOTIFICATIONS`, `VIBRATE`, and `RECEIVE_BOOT_COMPLETED`. (The
  *debug*/*profile* manifests do request `INTERNET` — Flutter needs it for
  hot reload — but those never ship. Grep the *merged* manifest of a release
  build before trusting this claim, per the
  [privacy model](docs/privacy-model.md).) No network package, no BaaS, no
  analytics, anywhere in `lib/`.
- **Advisory, never blocking.** `PromotionGate.evaluate` returns reasons, not
  a refusal. Any UI that consumes a verdict must offer a way to proceed
  regardless. See [ADR-0003](docs/adr/0003-advisory-pacing-never-blocking.md).
- **No streaks, no red, no guilt copy.** There is no daily-streak computation
  anywhere in the codebase — `AdherenceStats` is weekly-only by design. The
  palette's only "attention" color is clay (`#A66A4A`); nothing in this app
  is red. A `forgot` check-in is a data point, not a shame trigger.
- **De-personalization law + corpus quarantine.** Shipped content
  (`assets/content/*.json`) must never reference any author's family, faith,
  medical history, or specific personal protocol, and shopping criteria must
  never name a brand, retailer, or link. The private source material this
  content was distilled from lives at the repo root and in `corpus/`,
  **entirely `.gitignore`'d** — never stage or force-add anything on that
  list (see `.gitignore`'s header comment for the exact file names). The
  `content_validation_test.dart` denylist (`Word of Wisdom`, `VBAC`,
  `Olympian`, `Mom`, plus brand names) is the automated check; it runs in
  `flutter test` and in CI. See
  [ADR-0004](docs/adr/0004-de-personalization-law.md) — and if you're about
  to take this repo public, **run a full git-history scan for those
  sentinel strings first**; nothing in this repo currently automates that
  scan (no pre-push hook, no CI step does it) — it is a manual pre-publish
  step, not an enforced gate.
- **Content ids never change meaning.** `Intervention.id` is the join key
  between the shipped JSON and every drift row keyed by `interventionId`. A
  release must never repurpose an existing id for a different habit.
- **Not medical advice, said everywhere it matters.** The onboarding
  welcome, the Home check-in bar footer, every intervention detail card, and
  the About screen all repeat this. Don't remove any of them. It is standing
  text, not a gate: the onboarding tick that held Continue was removed under
  the fleet first-run ruling (open into the task; no control that must
  always be operated), so don't bring a checkbox back.
- **TDD, always.** Reproduce → failing test → fix → `flutter test` green →
  commit. Every bugfix ships with a regression test. The engine
  (`lib/features/adoption/domain/`) is pure — no DB, no widgets — so it stays
  unit-testable; keep new domain logic that way.
- **Atomic commits, one concern each.** Commit messages state the *why* and
  the failure mode fixed. **No AI attribution** (`Co-Authored-By` /
  "Generated with" lines) — deliberate project policy. Keep the git history
  a single neutral persona.
- **Never commit** `corpus/`, the root-level private source `.md`/`.txt`
  files already listed in `.gitignore` (the PRD, the red-team errata, the
  health-notes corpus docs), `CLAUDE.md`, or `GEMINI.md`. This repo *ships*
  `AGENTS.md`.

## Where things are (progressive disclosure)

| You're touching… | Go to |
|---|---|
| **The content library** (89 interventions + presets) | `assets/content/interventions.json`, `assets/content/presets.json` — schema in [docs/reference/content-schema.md](docs/reference/content-schema.md); loaded by `lib/features/library/data/content_loader.dart` into `lib/features/library/domain/content_library.dart` |
| **Content enums** (Category/Anchor/Evidence/CostTier/ShopWhere) | `lib/features/library/domain/enums.dart` — every `fromJson` throws loudly on an unknown value, on purpose |
| **The adoption engine** (pure Dart, the tested core) | `lib/features/adoption/domain/` — `starter_pack_selector.dart`, `promotion_gate.dart`, `graduation_detector.dart`, `erosion_check.dart`, `adherence_stats.dart`, `notification_planner.dart`, `wall_layout.dart`. Exact rules/constants in [docs/reference/engine-rules.md](docs/reference/engine-rules.md) |
| **User-state enums** (HabitStatus/CheckinResult/PulseResult/Goal/Pace) | `lib/features/adoption/domain/enums.dart` — stored as ordinals/text in drift; **the stored values are load-bearing, don't reorder** |
| **The database / schema** | `lib/core/storage/app_database.dart` (drift tables + migration) — schema in [docs/reference/data-model.md](docs/reference/data-model.md). Currently `schemaVersion = 2` with a real `onUpgrade` path (a v1 dev DB only had `UserPrefs`) |
| **Reading/writing habit state, check-ins, pulses, shopping** | `lib/features/adoption/data/*_repository.dart` — each takes `AppDatabase` directly, no DAO layer (Reckon/Furrow house style) |
| **Derived read models** (joins state + content for screens) | `lib/features/adoption/presentation/providers.dart` — `ActiveHabit`, `activeHabitsProvider`, `queuedHabitsProvider`, `graduatedHabitsProvider`, `pulseDueProvider`, etc. All one-shot `Future`s, refreshed explicitly after a write — not drift `.watch()` streams (avoids a pending-timer teardown trap in widget tests) |
| **The wall** (signature Progress screen) | `lib/features/adoption/presentation/wall_painter.dart` (`WallGeometry` — pure, unit-tested; `WallPainter` — the `CustomPainter`), fed by `lib/features/adoption/domain/wall_layout.dart` |
| **Notifications** | `lib/features/notifications/notification_service.dart` (the interface) → `notification_service_io.dart` (Android, `flutter_local_notifications`) / `notification_service_web.dart` (genuine no-op), chosen by `notification_service_factory.dart`'s conditional import. Planning is pure: `notification_planner.dart` |
| **Onboarding / Home / Check-in / Queue / Library / Detail / Shopping / Progress / Settings / About** | `lib/features/<feature>/presentation/` |
| **Navigation / redirect gate** | `lib/core/router/app_router.dart` — every route redirects to `/onboarding` until `Profile.onboarded` is true |
| **Theme / palette** | `lib/shared/theme/app_colors.dart` (basalt/mortar/lichen/clay/ink/stone tokens — never red) and `app_palette.dart` (`BulwarkPalette`, the per-brightness text-grade roles). Feature code reads `BulwarkPalette.of(context)` or the `ColorScheme`, never an `AppColors` constant; `test/shared/theme/contrast_test.dart` enforces that and the 4.5:1 floor in both themes |
| **Data export / erase** | `lib/features/settings/data/export_serializer.dart` (`BulwarkExport`, schema-versioned JSON), `export_share*.dart` (io/web share-sheet), `lib/features/settings/presentation/settings_actions.dart` (`eraseAllData`) |
| **Encrypted backup / restore** | `lib/features/sanctuary_backup/data/backup_serializer.dart` (`BulwarkBackupSerializer`, wraps `BulwarkExport`) + `lib/features/sanctuary_backup/backup_config.dart` (`bulwarkBackupConfig` — appId/AAD context/restore-consequence copy), overridden at the root `ProviderScope` in `lib/main.dart`; UI is the sibling-package `BackupSettingsSection` dropped into `settings_screen.dart`; `afterBackupRestore` (post-restore invalidation + reminder replan) lives in `settings_actions.dart`. Built on the sibling packages `../packages/sanctuary_auth_core` + `../packages/sanctuary_backup_ui` — see the README's sibling-clone note |
| **Web shell / PWA** | `web/index.html`, `web/manifest.json` |

Docs are organized [Diátaxis](https://diataxis.fr/)-style — see
[docs/README.md](docs/README.md) for the full tutorials / how-to / reference
/ explanation split.

## How to work here

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # regen *.g.dart (drift + riverpod)
flutter test         # unit, widget, and content-validation suites — green before you commit
flutter analyze      # static analysis — must be clean (package:flutter_lints, no overrides)
flutter run          # launch on a device / emulator / web
```

- `*.g.dart` files (drift + `@riverpod` codegen) are **gitignored**. Run
  `build_runner` after every fresh checkout or dependency change, or the
  build fails on missing `*.g.dart` imports.
- **`flutter test test/ --exclude-tags golden`** is what CI actually runs
  (`.github/workflows/release.yml`) — pixel golden tests are environment-
  sensitive (font rasterization differs by machine) and tagged accordingly
  in `dart_test.yaml`.
- **The a11y-sweep pattern**: every screen's widget test includes a pass at
  320dp width and `textScale` 1.0 *and* 3.0 (Home, Check-in, Library rows,
  Queue, Onboarding, Settings, About, Detail, Shopping all have this). The
  fleet's known overflow class is a rigid `Row` starving at large text
  scale — the fix is `Flexible`/`Wrap`/`SizedBox` + ellipsis, not a hard-
  coded width. If you add a screen or a row, add the 320dp/3× pass before
  calling it done.
- **Content changes need the validation test.** Any edit to
  `assets/content/interventions.json` or `presets.json` should leave
  `test/content/content_validation_test.dart` green — it's the tripwire for
  a bad enum value, a duplicate id, an unresolved preset reference, a
  missing `recurring` cost tier, or a de-personalization denylist hit.
  Update the item-count assertion (`89`) if you deliberately add or remove
  content.
- Adding a feature? Follow the existing shape: `domain/` (entities + pure
  logic) → `data/` (repository over `AppDatabase`) → `presentation/`
  (screens, widgets, hand-written or `@riverpod`-codegen'd providers). New
  tables go in `app_database.dart`; bump `schemaVersion` and add an
  `onUpgrade` branch if you change an existing table (the current bump from
  1→2 added every adoption/state table in one step — a template for the
  next one).

## Gotchas for the next agent

- **The release workflow's tag pattern doesn't match the fleet's sideload
  convention.** `.github/workflows/release.yml` (carried over from the fork)
  triggers on semver tags (`v*.*.*`) and creates a **draft** GitHub release.
  The rest of the OpenHearth fleet (Furrow, WeatherGlass, …) instead
  publishes its sideload APK under a single, repeatedly-updated `v0-apk` tag
  — this README and the landing-site convention assume that pattern. Someone
  doing the deploy wave needs to reconcile these: either move `v0-apk`
  forward after each semver release, or change the workflow trigger.
- **`Anchor.lunch` is declared but currently unused by any shipped content
  item** (content uses `breakfast`/`dinner`/`midday`/`custom` instead) — the
  `StarterPackSelector`'s `Profile.hasAnchor` gating for it is still correct
  and tested, there's just no live item to exercise it against today. Don't
  "clean up" the enum value on that basis.
- **`custom` is the dominant anchor** (37 of 89 items) — most habits don't
  hang off a clock-anchored moment, they hang off a `trigger.note` describing
  a specific cue. The notification planner treats `custom` (like `brushing`,
  `hourly`, `stressMoment`, `weekly`, `asNeeded`) as ambient: it schedules
  nothing for these anchors.
- **Read models are one-shot `Future`s, not `.watch()` streams**, deliberately
  — a drift query stream leaves a pending timer that trips widget-test
  teardown. Every write path calls `ref.invalidate(...)` on the relevant
  provider(s) and awaits the reload; if you add a new mutation, follow the
  same pattern (see `checkin_screen.dart`'s `_refreshReadModels` for the
  fullest example — it invalidates four providers because Progress's
  erosion/adherence read models are `keepAlive` and outlive the write).
- **Check-in writes on every tap.** There is no Save: each answer, pulse
  and note upserts as it is given, a failed write puts the chip back and
  says so, and Done only navigates. Don't reintroduce a commit step.
- **`test(` alone undercounts the suite** — widget tests use `testWidgets(`,
  so grep both if you need a real test count.
