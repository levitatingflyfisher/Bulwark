# Explanation: design philosophy

*Understanding-oriented — the reasoning behind three choices that show up
throughout the app, gathered in one place because they're really one
argument told three ways. The formal decision records are
[ADR-0003](adr/0003-advisory-pacing-never-blocking.md) and
[ADR-0004](adr/0004-de-personalization-law.md); this page is the why in
prose.*

## Why advisory, not blocking

A pacing engine that *enforces* a rule — "you may not activate another habit
for 5 more days" — sounds responsible. It also assumes the engine knows more
about a person's life than the person does, and it hands the app a kind of
authority it hasn't earned. Real life doesn't wait for a cooldown timer: a
new diagnosis, a trip, a hard week, a sudden burst of motivation — any of
these can be an excellent reason to take on a habit "too soon" by
`PromotionGate`'s clock.

So the gate only ever *advises*. `PromotionGate.evaluate()` returns a list
of reasons, never a refusal, and the UI's contract with that verdict is
fixed: every reason gets a plain-language, kind sentence, and the same
screen always offers **"Add anyway"** in the same breath as the caution.
This is the OpenHearth "forgiveness over prevention" value applied to habit
formation specifically — the same instinct that keeps a missed check-in from
turning into a guilt notification keeps a "not now" from turning into a
"not allowed."

The cost of this is real: a user who ignores every caution can genuinely
overload themselves with habits that never settle. Bulwark accepts that cost
on purpose. An app that can't be talked out of its own good advice by the
person using it has stopped being a tool and started being a warden, and
that's a worse failure mode than an occasional bad call by the user.

## Why a wall, not a streak

A streak is a single number that goes up every day you comply and collapses
to zero the moment you don't. It is an extremely effective engagement
mechanic — and it is effective *because* it manufactures loss aversion: the
fear of "breaking" something you built is what brings people back, not the
value of the habit itself. Bulwark's whole thesis is that health habits
should survive contact with an ordinary human life (illness, travel,
a rough week, a newborn) without the tracker punishing the interruption. A
number that resets to zero is structurally the wrong shape for that.

A **wall** is the opposite shape. A stone, once set, is set — the wall can
gain stones (graduation) and a stone can weather (two shaky weekly pulses
crack it and tint it clay), but nothing in `WallLayout` or its caller ever
removes a stone once placed. This isn't just UI dressing: there is no
daily-streak computation anywhere in the codebase, on purpose — see
[`AdherenceStats`](reference/engine-rules.md#adherencestats), which
aggregates weekly only. Missing a day is a data point that can inform a
"repoint?" suggestion later; it is never itself an alarm.

The honest cost, matching Furrow's: a tool that never nags is a tool easy to
forget, and a wall that can't collapse also can't manufacture the urgency
that keeps some people coming back. Bulwark accepts that trade. Local
reminders (opt-in, capped, quiet-hours-respecting — see
[ADR-0005](adr/0005-local-notifications-only.md)) are the honest,
non-manipulative answer this codebase currently has to "how do you stay
present without pressure"; it is not a solved problem, and the
[Vision](../VISION.md#horizons-problems-not-a-feature-list) horizons say so.

## The de-personalization stance

Bulwark's 89-item content library was distilled from a private research
corpus — years of one household's actual health notes, protocols, and
bloodwork. None of that source material, or anything that would identify
the household it came from, is meant to exist in this public repository or
its git history. Concretely:

- The shipped content contains **zero** references to any author's family,
  faith, personal medical history, or specific personal protocol. A caffeine
  item, for instance, says "if you don't consume caffeine at all, this one
  is already handled" — generic guidance, not a note about anyone's specific
  beliefs or habits.
- Shopping criteria are **generic buying guidance only** — "magnesium
  glycinate or malate, 200–400 mg elemental; avoid oxide," never a brand
  name, retailer, or affiliate link.
- The private source corpus itself lives outside version control entirely
  (see `.gitignore`'s header and
  [ADR-0004](adr/0004-de-personalization-law.md)) and is never meant to enter
  git history at all — not "committed then scrubbed," never committed.

This isn't a cosmetic privacy gesture. It's the difference between "a health
app someone built" and "a searchable public record of one specific family's
medical history," and only one of those is a tool worth sharing. A
`flutter test` (`content_validation_test.dart`) checks a denylist of
sentinel strings against the shipped content on every run, as a tripwire —
but that test only covers content that's already in the repo; the
history-scan step described in ADR-0004 is a manual pre-publish discipline,
not (yet) an automated gate.
