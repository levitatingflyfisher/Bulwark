# ADR-0003: The pacing engine advises; it never blocks

- **Status:** Accepted
- **Date:** 2026-07-11

## Context

An app that introduces habits "one to three at a time" needs some opinion
about when a user is ready for another — otherwise the whole point of paced
introduction (letting each habit settle before adding load) is undermined
the first time someone queues ten habits and activates them all at once. The
naive way to enforce pacing is to make the gate a real gate: disable the
"activate" action until a cooldown passes, or until adherence on current
habits clears a bar. That is also the design that turns a helpful heuristic
into an authority the app hasn't earned — a hard-coded rule (days since last
activation, an active-habit cap, a did-rate threshold) can never account for
a user's actual circumstances, and Bulwark shares the OpenHearth
"forgiveness over prevention" value (from Sundial) which explicitly rejects
prevention-shaped UI.

## Decision

**`PromotionGate.evaluate()` returns an opinion, never a refusal.** It
computes up to three named reasons — `tooSoon`, `capReached`, `unsteady`
(see [engine-rules.md](../reference/engine-rules.md#promotiongate) for the
exact thresholds) — and packages them as a `PromotionVerdict{advisable,
reasons}`. Every screen that surfaces a verdict (the Queue screen's
"I'm ready for another" flow is the only current caller) must render **every**
reason as a short, kind, specific sentence, and must offer an "add anyway"
control in the same view, with equal or greater visual weight to the
caution — never a disabled button, never a forced wait. This is a contract
on every future caller of `PromotionGate`, not just the one screen that
exists today.

## Consequences

- **Buys:** the pacing heuristic can be as opinionated as it likes (three
  independent rules, tunable constants) without the app ever overriding a
  user's own judgment about their own life. It also keeps the gate testable
  in isolation — `PromotionGate` has no UI dependency, so its rules are
  unit-tested directly, and the *policy* of "always offer an override" lives
  in the presentation layer where a widget test can assert the button
  exists whenever a verdict is unadvisable.
- **Costs:** a user who dismisses every caution can genuinely take on more
  than they can sustain — there's no mechanism preventing that, by design.
  Measured "pacing adherence" (if anyone ever measured it) would likely be
  lower than a version of this app that enforced its own advice.
- **Forecloses:** any future feature that needs a genuine hard limit (a
  disabled button, a modal that can't be dismissed) on this specific
  interaction — that would require a new, explicitly-different mechanism,
  not a variant of `PromotionGate`, and should probably be its own ADR if it
  's ever proposed, because it would be reversing this one.

## Alternatives considered

- **A hard cooldown (disable Activate until N days pass):** rejected — the
  authority problem above; also brittle against the many good reasons a
  cooldown might be wrong for a specific week.
- **A soft warning with no override button** (a dismissible toast, no path
  forward from the caution screen itself): rejected — this still forces the
  user to back out and find another way to activate, which is blocking with
  extra steps, not advice.
- **No gate at all:** considered and rejected — the whole "adopt 1–3 at a
  time" thesis needs *some* signal about pacing, or "how much to take on" in
  onboarding becomes the only pacing mechanism the app has, which doesn't
  adapt to how habits are actually going.
