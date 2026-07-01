# Changelog

All notable changes to Bulwark will be documented in this file.

## [Unreleased]

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
