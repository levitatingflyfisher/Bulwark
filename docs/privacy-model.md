# Privacy model

The short version: **nothing leaves your device.** Bulwark has no accounts,
no network layer, no analytics, and no cloud. This page says exactly what
that means and — more importantly — how you can *check* it rather than take
it on faith.

## What Bulwark stores, and where

| Data | Where it lives |
|---|---|
| Habit adoption state, check-ins, weekly pulses, shopping/purchase state, your onboarding profile | On-device SQLite database (via Drift), in the app's private storage — see [data-model.md](reference/data-model.md) |
| Theme, the reminders master switch | `UserPrefs` (the same on-device database) |
| The 89-item intervention library and presets | Shipped **with the app** as a JSON asset — it never comes from a server, is never fetched, and is identical for every install |
| Your 12-word recovery phrase and the encryption keys derived from it (only if you set up encrypted backup) | OS secure storage (Android Keystore / iOS Keychain) — a separate, hardware-backed store from the SQLite database above, never written to a file, never leaves the device |

That is the entire footprint. There is no server-side copy because there is
no server.

## What leaves the device

**Nothing, automatically.** There is no telemetry, no crash reporting to a
third party, no ad SDK, no sync, and no health-data platform integration.
The only way any data moves off the device is one *you* explicitly trigger:

- **Export → system share sheet.** Settings → "Export my data" serializes
  your whole dataset to a JSON file and hands it to the OS share sheet.
  Where it goes from there — a file, an email, another app — is your
  choice, not a Bulwark backend (see
  [everyday-tasks.md](how-to/everyday-tasks.md#export-your-data)). This copy
  is **unencrypted** — anyone who gets the file can read it.
- **Encrypted backup → system share sheet.** Settings → "Encrypted Backup"
  does the same thing but the file (`.ohbk`) is ChaCha20-Poly1305-encrypted
  under a key derived from a 12-word recovery phrase generated and shown to
  you once, on-device — Bulwark never transmits it anywhere (see
  [everyday-tasks.md](how-to/everyday-tasks.md#encrypted-backup--restore)).
  Unlike the plaintext export, this one restores.

The only notifications Bulwark can post are the local, opt-in daily
reminders planned by `NotificationPlanner` (see
[engine-rules.md](reference/engine-rules.md#notificationplanner)) — never an
engagement nudge, never anything that reports back anywhere.

## How to verify it yourself

These claims are meant to be checkable, not trusted:

1. **No network code.** Grep the app source for any egress and find none:
   ```bash
   grep -rniE 'http[s]?://|HttpClient|package:http|dio|socket|firebase|supabase|analytics' lib/
   ```
   (Matches, if any, are limited to doc/comment URLs — e.g. this docs tree —
   not calls.)
2. **No `INTERNET` permission in the shipped app.** Bulwark's own release
   source manifest (`android/app/src/main/AndroidManifest.xml`) requests
   only `POST_NOTIFICATIONS`, `VIBRATE`, and `RECEIVE_BOOT_COMPLETED` — the
   last two for local notification scheduling and reboot re-registration.
   What actually ships, though, is the *merged* manifest (Bulwark's plus its
   plugins'), so check that one — it is the source of truth:
   ```bash
   flutter build apk --release
   grep -i INTERNET build/app/intermediates/packaged_manifests/release/*/*/AndroidManifest.xml
   # or, on the built APK:
   aapt dump permissions build/app/outputs/flutter-apk/app-release.apk
   ```
   The merged manifest declares **no `INTERNET` permission** — so the app
   cannot open a socket or transmit anything, full stop. (An `INTERNET` line
   exists only in the *debug*/*profile* source manifests, which Flutter
   merges in for local development and hot reload, and which never ship.)
3. **Content is a static asset, not a fetch.** `assets/content/*.json` ships
   inside the app bundle (`pubspec.yaml`'s `flutter.assets`); it's loaded via
   `rootBundle`, which reads packaged assets, not the network. There is no
   remote-config or content-update mechanism.
4. **Fonts are bundled, not fetched.** Lora and Nunito ship in
   `assets/fonts/` and are declared in `pubspec.yaml`, so even the web build
   makes no runtime request to a font CDN.
5. **Airplane mode.** Turn off all connectivity; every feature still works,
   because offline *is* the mode.

## Threat model (what this does and doesn't protect against)

- **Protects against:** operator data access (there is no operator), account
  compromise (there is no account), tracking/profiling/data sale
  (architecturally impossible without egress).
- **Does not protect against:** anyone with access to the unlocked device —
  the database is app-private but not separately encrypted at rest;
  device-level lock/encryption is your protection. Nor does it protect data
  you *choose* to export and send somewhere.
- **Backup is your responsibility.** Because there is no cloud copy, losing
  or wiping the device loses the data unless you made a copy yourself —
  either the plaintext JSON export, or (recommended) an encrypted `.ohbk`
  backup, which is also the only one of the two that restores. Either way,
  the copy is *yours to keep*: nothing is retained anywhere else. This is
  the honest cost of local-only — see [limitations.md](limitations.md).

## If sync is ever added

It must be **opt-in** and travel as **encrypted blobs through a dumb relay**
the operator cannot read — never a backend-as-a-service, never plaintext.
Local-only must remain complete and default. This is a hard invariant, not a
preference — see [VISION.md](../VISION.md#design-commitments-the-invariants).
