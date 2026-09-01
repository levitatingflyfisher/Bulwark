# Changelog

All notable changes to Bulwark will be documented in this file.

## [Unreleased]

### Changed (fleet rollout, 2026-09)
- Adopts openhearth_design 0.7.2, sanctuary_backup_ui 0.3.0 and
  oh_fleet_conformance 0.8.1. The type ladder is the fleet one (body 16,
  no Lora w600). Lora and Nunito now come from the design package's
  fonts; the app's own copies and the unused `AppTextStyles` are gone.
- Colour goes through roles. Secondary text was 2.31:1 on the light card
  and dark mode printed light-mode ink at 1.10:1; every text colour now
  clears 4.5:1 on both grounds of both themes (`BulwarkPalette`,
  `contrast_test`). The error role is clay, never red.
- A screen that fails to load shows one plain sentence and Try again, with
  the technical error only behind Details (`OhErrorState`). Six screens
  used to print "Something went wrong." followed by the raw exception.
- Theme: light, dark, or follow the phone (the new default), from an icon
  plus a word in the app bar of every top-level screen. The icon-only
  sun/moon pill and the Settings "Dark mode" switch are gone; the choice
  is stored under `theme_mode` (no migration, no users yet).
- On a tablet or in the browser every screen keeps a 640 dp column
  (`OhPage`) instead of stretching the phone layout edge to edge.
- Top-bar actions are an icon plus a word: Home's hamburger reads "Menu"
  and Library's Filters says "Filters". Bar words stop growing at 2x text
  so the title keeps room at 320 dp.
- Erase all data asks "Erase all data?" with Erase everything / Keep my
  data. With backup set up it first puts a verified safety copy in
  Previous backups and erases nothing if that fails. The local
  confirm_dialog is retired for ohStyle's `showOhConfirm`.
- Home shows the dismissible "Backup isn't set up" line until backup is
  finished. On the web, Bulwark's recovery words get their own storage
  names instead of sharing the origin's with other fleet apps.
- Copy: no spaced em dashes and no typewriter apostrophes in on-screen
  text (`copy_typography_test` scans `lib/`).
- Check-in saves each answer, pulse and note as it is given. Leaving by
  back no longer loses the day's answers; Save is now Done, which only
  goes back. A write that fails puts the chip back and says so.
- Every habit change (activate, queue, set aside, set into the wall,
  repoint) offers Undo in a bar under every screen, with no timer. An
  active habit can be **set aside** from its detail page (the `paused`
  state, finally written); the never-used `retired` state is gone.
  Set-aside habits are listed on Queue under "Set aside", each with
  Activate.
- Graduation says what it frees: one fewer daily check-in, a weekly check
  instead, and room for the next habit. The sparkles badge icon is gone.
- The wall's caption counts what is drawn ("2 outlined stones: the habits
  you are working on now…") instead of saying "None yet" over two
  outlines, and an outlined stone answers a tap with its habit.
- "Forgot" now buys something: three forgets in two weeks (a third of the
  answers) make Home offer to hang that habit off a different moment, with
  Undo, or "Not now". The chosen moment drives reminders, the card and the
  detail page.
- Onboarding's first screen states the not-medical-advice disclaimer as
  text; Continue no longer waits on an unlabelled tick.
- Library and Queue rows set the habit's action (what you actually do) as
  body text in full, instead of a grey two-line footnote cut off with "…".
- Day one: until the first check-in, Home says what the daily job is (do
  each habit at its moment, then Check in tonight).
- Fix: setting a habit aside, graduating or queueing it kept its daily
  reminder, and activating one did not add it; every habit change (and
  its Undo) now re-plans the day's reminders.
- Fix: an Undo tapped after the screen that made the change had closed
  (a graduated card, a popped detail page) threw; habit changes now run on
  an app-lived service.

### Fixed
- `startOfWeek` now uses calendar arithmetic (`DateTime(y, m, d - n)`)
  instead of Duration subtraction from local midnight. In a timezone
  whose DST transition falls at midnight mid-week (e.g. America/Santiago,
  where Sat 2026-04-04 has 25 hours), the old 24h-per-day walk landed on
  Monday 01:00/23:00 instead of Monday midnight, skewing every weekly
  aggregate (check-in pulses, adherence) keyed on the week start —
  exactly the class of bug the same file's `daysBetweenDates` was already
  rewritten to avoid.

### Added
- Fleet conformance suite (`oh_fleet_conformance` dev dep +
  `test/fleet_conformance_test.dart`): the fleet's standards — canonical
  design package, shared backup envelope, size budgets, the exact
  no-INTERNET permission surface, harness canon — now fail tests instead
  of drifting. `budgets.json` records the size ratchet (gzipped
  `main.dart.js` + arm64 APK baselines +5%).
- Push CI (`.github/workflows/ci.yml`): analyze + tests now run on every
  push/PR, not only on release tags (corpus-guard already ran on push;
  this closes the test gap). Pinned to the fleet Flutter 3.38.7.
- Snapshot vault ("Previous backups" on the Backup & Restore section):
  every encrypted export and every restore leaves a stamped on-device
  snapshot (keep-N, pinnable) you can restore, pin or delete.
- Mandatory pre-restore snapshot: a restore refuses to run unless the
  current data was snapshotted (and the snapshot verified) first —
  restoring is now reversible.
- Preview before restore: the confirm dialog shows the backup's age and
  per-section row counts, validated by the same gate the restore itself
  uses (wrong-app, future-schema and malformed-shape files are rejected
  at preview time, not mid-restore).
- Backups now carry a `createdAt` stamp (plus the fleet-legacy
  `exportedAt` twin), so the restore preview shows the backup's real age
  instead of "unknown". Older stamp-less backups still restore and
  preview; older app versions still restore new backups — the keys are
  additive, never breaking.
- Silent freshness snapshot on app start when the newest vault snapshot
  is older than 7 days (post-frame, fire-and-forget — never blocks boot).
- Plain-JSON export tile from the shared backup section.

### Changed
- `test/flutter_test_config.dart` re-synced to the fleet-canonical
  FontManifest-aware variant: goldens now load the app's bundled
  Lora/Nunito in addition to SDK Roboto/Material Icons (no goldens exist
  in-repo yet, so no pixels changed). Re-synced again to the per-family
  font-load isolation revision: one family's failure to load logs and
  continues instead of aborting the families after it (the success path
  is byte-identical, so nothing renders differently).
- `release.yml` now clones the `ohStyle` and `ohFleetConformance`
  siblings alongside the sanctuary packages, matching the pubspec's full
  path-dep surface.
- Adopted the shared `openhearth_design` package (path dep): the Material
  TextTheme ladder in `app_theme.dart` now comes from
  `OhTypography.materialTextTheme`, which is byte-identical to the block
  Bulwark hand-rolled — zero visual change, locked by a whole-TextStyle
  (letterSpacing/height included) equivalence test across all 15 roles;
  Bulwark has no goldens yet, so that strict-equality test is the lock,
  not a golden suite. Bulwark's basalt/mortar/lichen
  identity (surfaces, ramp, AppBarTheme) stays app-local by design.
- Upgraded `sanctuary_backup_ui` to 0.2.0; envelope validation now goes
  through the shared `BackupEnvelope.unwrap` helper instead of
  hand-rolled checks. Bulwark's wire `schemaVersion` stays a hardcoded 1,
  deliberately decoupled from the drift database version.
