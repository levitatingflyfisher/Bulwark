# How-to: everyday tasks

*Task-oriented — four specific things people ask how to do, assuming you
already know the basics from [your first week](../tutorials/your-first-week.md).*

## Add a habit from the Library

1. Open **Library** from the Home menu.
2. Search by name, or tap the filter icon to narrow by minimum evidence
   (Any / Mechanistic+ / Observational+ / Trials only), cost, or daily time.
   Tap a category chip in the strip below the search box to narrow further.
3. Tap any result to open its detail card — the full action, when and why
   it's anchored where it is, the mechanism, the evidence tag explained in
   plain language, a safety note if there is one, and generic buying
   criteria if it requires a purchase.
4. At the bottom of the card:
   - **Activate** puts it straight onto your Today list and starts today's
     check-in tracking it.
   - **Add to queue** puts it in your backlog instead — see it any time on
     the **Queue** screen, in the order you added things.
   - On a habit that is already active, **Set aside** takes it off Today
     and out of the check-in without losing anything. It is then listed on
     the **Queue** screen under **Set aside**, with **Activate** to take it
     up again. Every one of these changes offers **Undo** in a bar at the
     bottom of the screen until you act on it or make another change.
   - If the card instead says **"Reference only for now"**, the item is
     symptom- or period-triggered (like zinc lozenges or an annual
     bloodwork panel) rather than a daily habit — it's there to read and
     pin, not to activate or check in on. See
     [content-schema.md](../reference/content-schema.md#activatable-vs-reference-only)
     for the full list of anchors this applies to.

You don't have to go through the Queue → gate flow to add a habit this way —
the promotion gate only runs when you explicitly ask "I'm ready for another"
from the Queue screen. Activating straight from a detail card is always
available.

## Turn on reminders

Reminders are **off by default and fully opt-in** — nothing schedules until
you turn something on.

1. Open **Settings**.
2. Flip the **Reminders** switch under the "Reminders" section. On Android,
   this is the moment Bulwark asks the OS for notification permission (never
   before, and never inside a background reschedule) — if you decline, the
   switch stays on in Bulwark's own settings but Android will silently drop
   the notifications; flip it off and back on to re-prompt.
3. Optionally set a **Daily check-in reminder** time on the same screen (or
   during onboarding). Leaving it blank keeps the master switch's effect to
   your per-habit anchor reminders only.
4. Per-habit reminders follow from a habit's anchor once the master switch is
   on: habits anchored to a clock moment (wake, morning, breakfast, midday,
   lunch, dinner, evening, bed) get batched into at most one morning cue and
   one evening cue, or one exact-time cue for a meal anchor. Habits anchored
   to something ambient (brushing, hourly, a stress moment, weekly, as
   needed, or a custom cue) never get a notification — there's no clock
   moment to attach one to.

However many habits you have active, you will never get more than five
notifications in a day, and nothing fires between your bed time and your
wake time. See [engine-rules.md](../reference/engine-rules.md#notificationplanner)
for the exact batching and cap rules, and
[limitations.md](../limitations.md) for why the timing is approximate rather
than to-the-minute.

**On the web**, reminders are a no-op by design — turning the switch on
changes nothing observable, because scheduling a background notification
from a PWA isn't wired up. In-app cues (the "Next up" hint on Home, the
Check-in button itself) carry the same intent without a platform
notification.

## Export your data

1. Open **Settings → Export my data** (under "Your data").
2. Bulwark serializes your whole on-device dataset — profile, every habit's
   state, every check-in, every weekly pulse, and shopping/purchase state —
   into one pretty-printed JSON file, and hands it to your device's share
   sheet.
3. Send it wherever you like (save it, email it to yourself, back it up) —
   this is the only way any of your data ever leaves the device, and it only
   happens when you take this action.

The file is named `bulwark-export-YYYY-MM-DD.json` and carries a
`schemaVersion` field, so a future Bulwark version can tell an old export
apart from a new one if the format ever needs to change. It's a durability
and portability tool — readable, greppable, yours — but it is
**unencrypted**, and there is no *import* path for it. For an actual
backup-and-restore feature, see the next section.

**Erase all data**, right below Export on the same screen, is the reverse:
it asks you to confirm, then wipes every habit, check-in, pulse, and
shopping state in one transaction and returns you to onboarding. If you have
set up backup (you have recovery words), it first puts a verified safety
copy in **Previous backups**, and restoring that copy brings everything
back; if that copy can't be made, nothing is erased. Without backup there is
no copy, and the dialog says so.

## Encrypted backup & restore

Right below Export my data is a second, separate **Backup**
section — this one *does* restore, and the file it produces (`.ohbk`) is
useless to anyone but you.

1. **Set up encrypted backup.** Tap it once to see a 12-word recovery
   phrase, then write the words down on paper. Nothing is stored until you
   tap "I've written this down". You'll then re-enter them word by word —
   this isn't busywork, it's the only way the app can confirm your paper
   copy is actually correct before it's the only copy that matters. Until
   setup is finished, Home shows a dismissible "Backup isn't set up" line.
2. **Export backup.** Once your phrase is confirmed, this encrypts your
   whole dataset (profile, habits, check-ins, pulses, shopping state — the
   same scope as the plaintext export, minus the app-shell theme/reminder
   switches) under a key derived from your recovery phrase, and hands the
   `.ohbk` file to your device's share sheet. Save it anywhere; without the
   phrase, the file is unreadable ciphertext.
3. **Restore from backup**, on this device or a new install, picks an
   `.ohbk` file and — after you confirm a plain warning that this **replaces
   everything currently on the device** — decrypts and loads it in one
   all-or-nothing step. A wrong phrase or a backup from a different app is
   rejected with a calm, specific message; nothing is ever partially
   restored.

**The recovery phrase *is* your data's only key.** Bulwark has no account
and no server, so there is no "forgot your password?" — if you lose both the
phrase and the device, that backup is gone for good, by design (see
[privacy-model.md](../privacy-model.md)). Treat the 12 words like you'd
treat a house key, not like a password you can reset.
