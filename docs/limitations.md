# Limitations

An honest list of what Bulwark does not do, cannot do today, or does
imprecisely on purpose. Read this before adopting — the goal is to save you
an afternoon of discovery. For the shape of what's built vs. deferred, see
the [Vision scorecard](../VISION.md#honest-scorecard-built-vs-deferred).

## Not medical advice

- Bulwark is habit-tracking with health education, not medical advice,
  diagnosis, or treatment. Nothing in `assets/content/` has been reviewed by
  a clinician for any individual's situation. Evidence tags
  (`rct`/`observational`/`mechanistic`/`traditional`) are conservative,
  hand-assigned buckets, not the product of a systematic review or
  meta-analysis.
- Safety notes on individual intervention cards are calm cautions, not a
  contraindication database — they don't know your medications, conditions,
  or pregnancy status. For any of those, talk to a clinician.

## No sync, no cloud, no multi-device

- **Local-only.** There is no cloud, no sync, and no server-side backup by
  design (see [privacy-model.md](privacy-model.md)). There is no "log in on
  your new phone and it's all there" — restoring on a new device means
  moving a file yourself. Settings offers two file formats: a plaintext JSON
  export (portability, no restore path) and an encrypted `.ohbk` backup
  (restores, but the recovery phrase is the only key — lose both the phrase
  and the device and that backup is gone for good). If you make neither
  before you lose or wipe the device, the data is gone.
- **Single-user.** There are no profiles. A shared household device shares
  one dataset; Bulwark can't tell family members apart.

## Notifications are approximate

- **Inexact scheduling on Android.** `NotificationPlanner`'s output is
  applied via `AndroidScheduleMode.inexactAllowWhileIdle`, not
  `SCHEDULE_EXACT_ALARM` — a habit nudge can land a few minutes late,
  especially under Doze. This is a deliberate trade against requesting a
  broader permission footprint, not an oversight.
- **DST-imperfect time zone resolution.** The Android implementation
  resolves the device's local time zone by matching the *current* UTC
  offset against the timezone database, rather than reading the device's
  actual configured zone (avoiding an extra `flutter_timezone` dependency).
  This is correct for a same-offset zone in the common case, but it can pick
  a same-offset sibling zone, and it does not itself detect or re-resolve
  mid-flight across a daylight-saving transition.
- **Web is a genuine no-op.** There is no way to schedule a background
  notification from the installed PWA today; reminders exist only as
  in-app cues (the "Next up" hint, the Check-in button) on that platform.
- **No engagement-style notifications, ever, by design.** The only
  notifications Bulwark can post are the opt-in daily reminders it plans
  itself — see [ADR-0005](adr/0005-local-notifications-only.md).

## The adoption engine is fixed, not adaptive

- **No adaptive sequencing.** The starter pack's affinity table, the
  promotion gate's thresholds, the graduation and erosion rules are all
  fixed constants in `lib/features/adoption/domain/` (see
  [engine-rules.md](reference/engine-rules.md)) — nothing learns from a
  user's outcomes or adjusts its own numbers. Tuning them today is a code
  change.
- **No correlation engine, no LLM.** Bulwark surfaces the evidence tag
  shipped with a piece of content; it does not analyze check-in history for
  correlations, and there is no on-device or cloud model anywhere in this
  app.
- **No health-data platform integration.** Apple Health / Google Fit are not
  read from or written to.

## Content model

- **`asNeeded` items (9 of 89) are reference-only.** They're searchable and
  pinnable but never activatable, and never enter a check-in or adherence
  stats — a deliberate v0 scope decision (see
  [content-schema.md](reference/content-schema.md#activatable-vs-reference-only)),
  not a bug.
- **`defaultPhase` is a sort/scoring hint, not a rollout gate.** Nothing
  currently prevents a user from activating a phase-6 item on day one if
  they find it in the Library and it otherwise qualifies.
- **Content ships with the app, not from a server.** There is no
  remote-content-update mechanism; a new intervention or a corrected safety
  note requires a new app release.

## Undo

- **Undo lasts until you act, not until a timer.** Activating, queueing,
  setting aside, setting a stone into the wall and repointing each happen
  at once and offer Undo in a bar under every screen. The offer stays until
  you tap Undo, dismiss it, or make another change; after that the change
  stands (make the opposite change to reverse it). Only the most recent
  change can be undone.
- **Erase all data is the exception.** It asks first; with backup set up,
  its way back is the safety copy in Previous backups.

## Platform notes

- **Golden tests are environment-sensitive.** Font rasterization differs
  across machines, so the golden suite is tagged (`dart_test.yaml`) and
  **excluded from CI** (`flutter test --exclude-tags golden`, per
  `.github/workflows/release.yml`); regenerate locally with
  `flutter test --update-goldens` when you deliberately change a screen's
  look.
- **Web storage is evictable**, same as the rest of the OpenHearth PWA
  fleet — browser storage can be reclaimed under pressure. The installed
  APK does not have this caveat.
- **iOS is not built.** Flutter could target it; Bulwark ships Android + web
  today.

If any of the above is a hard requirement for you, Bulwark may not fit yet —
and that's the point of listing it here.
