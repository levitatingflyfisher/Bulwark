# Bulwark

> **A wall between you and entropy.** The goal is not perfection. The goal is
> a floor that doesn't collapse.

Bulwark is a local-first health-habit operating system: an 89-item,
evidence-tagged library of interventions, introduced one to three at a time
onto anchors you already have (waking, meals, brushing, bed), a daily
check-in that takes under thirty seconds, and a maintenance floor — habits
you graduate become stones in a wall the app quietly watches for erosion. The
wall never shrinks on its own; stones weather, they don't vanish.

It runs entirely on your device. No account, no cloud, no ads, no tracking —
the Android build ships with **no `INTERNET` permission at all** (see the
[privacy model](docs/privacy-model.md)).

**Bulwark is not medical advice.** It is habit-tracking with health
education; for any specific condition, medication, or symptom, talk to a
clinician. See the disclaimer in onboarding and on every intervention card.

## What it does

- **An 89-item library**, each intervention tagged with its strength of
  evidence (RCT / observational / mechanistic / traditional), a time cost, a
  cost tier, and — where it requires a purchase — generic buying criteria
  only (never a brand or a link).
- **A starter pack, tonight.** Onboarding maps your day (wake, bed, optional
  meals), asks your goal and your pace, and hands you 1–3 free, low-friction
  habits picked to fit both.
- **A 30-second check-in.** One row per active habit — *did it / skipped /
  forgot* — plus a weekly solid/shaky pulse once a habit has graduated. Each
  answer is saved as you tap it, and a run of *forgot* offers to hang that
  habit off a different moment.
- **Nothing is one-way.** Activating, queueing, setting a habit aside,
  setting a stone and repointing all offer Undo, with no timer.
- **An advisory pacing engine, never a blocker.** A promotion gate can advise
  you to wait before taking on another habit; every verdict, kind or
  cautioning, ends in an "add anyway" button. Forgiveness over prevention.
- **The wall.** A hand-painted drystone wall on the Progress screen — one
  stone per graduated habit. Two shaky weekly pulses in a row weathers a
  stone (cracked, clay-tinted) and offers a gentle "repoint?"; the wall never
  loses a stone on its own.
- **A shopping list** of generic buying criteria for whatever your active and
  queued habits need — no brand names, no retailers, no affiliate links.
- **Local reminders only**, opt-in, batched morning/evening, silent between
  bed and wake, capped at five a day. The web build is a genuine no-op —
  in-app cues only.

## Try it

- **Web (PWA):** <https://levitatingflyfisher.github.io/Bulwark/> —
  installable, works offline.
- **Android (APK):** sideload the build attached to the repo's `v0-apk`
  release tag on GitHub.

## Quickstart (development)

Bulwark is built on four shared packages consumed by **sibling path
dependency**, the same pattern as `eloEngine`: the encrypted backup
(`sanctuary_auth_core`, `sanctuary_backup_ui`), the design package with the
fonts, type ladder and shared widgets (`ohStyle/openhearth_design`), and the
fleet conformance tests (`oh_fleet_conformance`, dev only). Clone them next to
Bulwark so the paths resolve:

```
ohStyle/                   # github: levitatingflyfisher/ohStyle
packages/
  sanctuary_auth_core/     # github: levitatingflyfisher/sanctuaryAuthCore
  sanctuary_backup_ui/     # github: levitatingflyfisher/sanctuaryBackupUi
  oh_fleet_conformance/    # github: levitatingflyfisher/ohFleetConformance
Bulwark/                   # this repo
```

```bash
git clone https://github.com/levitatingflyfisher/ohStyle ohStyle
git clone https://github.com/levitatingflyfisher/sanctuaryAuthCore packages/sanctuary_auth_core
git clone https://github.com/levitatingflyfisher/sanctuaryBackupUi packages/sanctuary_backup_ui
git clone https://github.com/levitatingflyfisher/ohFleetConformance packages/oh_fleet_conformance
git clone git@github.com:levitatingflyfisher/Bulwark.git
cd Bulwark
flutter pub get

# Drift + Riverpod generate *.g.dart files (gitignored) — run after every
# fresh checkout or dependency change, or the build fails on missing imports:
dart run build_runner build --delete-conflicting-outputs

flutter run           # launch on a device / emulator / web
flutter test          # unit, widget, and content-validation suites
flutter analyze       # static analysis — must be clean
```

## See the docs

Start with **[VISION.md](VISION.md)** — the one idea, the design
commitments, and an honest scorecard of what's built versus deferred. Then
the **[documentation index](docs/README.md)**, organized
[Diátaxis](https://diataxis.fr/)-style (tutorials · how-to · reference ·
explanation).

Working *in* the code (human or agent)? Read **[AGENTS.md](AGENTS.md)**
first.

## Stack

Flutter, Clean Architecture (domain / data / presentation per feature),
[Riverpod](https://riverpod.dev/) for state, [Drift](https://drift.simonbinder.eu/)
over SQLite for local storage, `go_router` for navigation. Content (the
intervention library and presets) ships as versioned JSON assets, not
database rows. Ships as both a PWA and an Android APK from one codebase. The
*why* behind each choice lives in [docs/adr/](docs/adr/).

Forked from [Furrow](https://github.com/levitatingflyfisher/Furrow), a
sibling OpenHearth app — see [ADR-0001](docs/adr/0001-fork-from-furrow.md).

## License

[MIT](LICENSE).
