# ADR-0005: Local notifications only, no `INTERNET` permission

- **Status:** Accepted
- **Date:** 2026-07-11

## Context

Bulwark's per-habit anchor reminders and daily check-in reminder need *some*
notification mechanism to be useful — a habit anchored to a moment nobody
gets reminded about relies entirely on memory. But the OpenHearth fleet's
local-first stance (inherited from Furrow, see its
[ADR-0004](https://github.com/levitatingflyfisher/Furrow/blob/master/docs/adr/0004-local-first-ghost-mode.md))
requires the shipped Android build to declare **no `INTERNET` permission at
all** — a push-notification service (FCM or any equivalent) requires network
access and, typically, a server that knows the device exists, which is
exactly the kind of dependency this fleet avoids by construction, not by
policy.

## Decision

**Reminders are scheduled entirely on-device, and the web build gets a
genuine no-op.** `NotificationPlanner` (pure Dart, see
[engine-rules.md](../reference/engine-rules.md#notificationplanner)) decides
*what* to schedule and *when*, capped at 5/day, batched morning/evening,
silent between bed and wake. The platform layer applies that plan:

- **Android** (`AndroidNotificationService`) uses
  `flutter_local_notifications` with
  `AndroidScheduleMode.inexactAllowWhileIdle` — **not**
  `SCHEDULE_EXACT_ALARM`, keeping the permission footprint as small as the
  no-`INTERNET` ethos demands. The shipped manifest requests only
  `POST_NOTIFICATIONS`, `VIBRATE`, and `RECEIVE_BOOT_COMPLETED` (the last so
  scheduled reminders survive a reboot). The local time zone is resolved by
  matching the device's current UTC offset against the timezone database,
  rather than adding a `flutter_timezone` dependency to read it directly —
  correct for a daily wall-clock reminder, DST-imperfect at the edges (see
  [limitations.md](../limitations.md)).
- **Web** (`WebNotificationService`) is a real no-op — every method returns
  immediately without touching any plugin — because scheduling a background
  notification from a PWA isn't wired up in this codebase, and pretending to
  schedule one would be dishonest. In-app cues (the "Next up" hint on Home,
  the Check-in button) carry the same intent on that platform.

The right implementation is chosen by a conditional import
(`notification_service_factory.dart`), the same pattern Furrow uses for its
web/native splits.

## Consequences

- **Buys:** the no-`INTERNET` claim stays true even though the app has a
  genuine reminder feature — there is no tension between "useful reminders"
  and "the merged manifest declares no network permission," because nothing
  about local scheduling requires one. The permission footprint stays
  minimal (three permissions, all locally-scoped) rather than accumulating
  `SCHEDULE_EXACT_ALARM` or a network permission for a feature that doesn't
  strictly need either.
- **Costs:** reminders land a few minutes late under Doze/battery
  optimization (inexact scheduling, on purpose), and the DST-imperfect zone
  match can occasionally pick a same-offset sibling zone rather than the
  device's actual configured one. The web build has no real reminder
  mechanism at all — a PWA-only user gets in-app cues, not a notification
  that reaches them when the tab isn't open.
- **Forecloses:** any richer notification feature that would require exact
  alarms, a push-notification backend, or a companion server (e.g.
  server-driven reminder content, cross-device reminder sync) without first
  revisiting this ADR — those are all incompatible with "no `INTERNET`
  permission" as currently understood.

## Alternatives considered

- **Firebase Cloud Messaging (or any push service):** rejected outright —
  requires network access and a backend that knows the device exists,
  violating the no-`INTERNET` law categorically.
- **`SCHEDULE_EXACT_ALARM` for precise timing:** rejected — Android gates
  this behind a special permission with its own user-facing prompt and
  scrutiny; a habit nudge landing a few minutes late is an acceptable cost
  against expanding the permission footprint for a "gentle nudge," not a
  medical alert.
- **`flutter_timezone` for exact device-zone reads:** deferred, not
  rejected — would fix the DST-imperfect edge case cleanly, at the cost of
  one more native platform channel dependency. Revisit if the offset-match
  heuristic proves wrong often enough in practice to matter.
