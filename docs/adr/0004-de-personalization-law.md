# ADR-0004: De-personalization law + corpus quarantine

- **Status:** Accepted
- **Date:** 2026-07-11

## Context

Bulwark's 89-item intervention library was distilled from a private
research corpus: years of one household's actual health notes, protocols,
supplement stacks, and in places specific medical history (a birth protocol,
bloodwork, faith-based dietary practice). That corpus was the *source
material* for extracting generic, evidence-tagged interventions — it was
never meant to be the *shipped product*. This repository is a public,
open-source FLOSS project under the OpenHearth fleet's anonymized-identity
convention; a public repo that contains, in its shipped content or its git
history, personally identifying medical/religious/family detail would be a
serious privacy failure and would betray the trust of whoever's corpus this
was distilled from — including if that's the project's own author.

## Decision

**Two independent controls, and a manual pre-publish discipline as a third:**

1. **Corpus quarantine.** The private source documents (the PRD, the
   red-team errata, and the raw health-notes/protocol corpus files — named
   explicitly in `.gitignore`'s header comment) are `.gitignore`'d at the
   repo root and in a `corpus/` directory. They are never meant to be staged,
   committed, or force-added at any point — not "committed then scrubbed
   later," never committed at all.
2. **A de-personalization denylist test.** Every shipped content file is
   checked, on every `flutter test` run and in CI, against a denylist of
   sentinel strings (faith references, medical-history references, and a
   small brand-name list — see
   `test/content/content_validation_test.dart`), word-boundaried so it
   doesn't false-positive on ordinary English substrings.
3. **A manual git-history scan before this repo goes public.** If any
   corpus material or a denylisted term ever entered a commit before the
   controls above existed, a full-history scan (and, if needed, a
   history rewrite) for the sentinel strings is required before flipping
   this repository from private to public. **This is not currently automated
   anywhere in this repo** — there is no pre-push hook and no CI job that
   scans history; it's a deploy-time discipline the person or agent doing
   the publish step must run by hand.

## Consequences

- **Buys:** the shipped content is safe to read by strangers — generic
  health education, generic buying criteria, no identifying detail — and
  that claim is partially machine-checked (the denylist test catches a
  regression in future content edits) rather than resting entirely on
  discipline.
- **Costs:** the denylist is necessarily incomplete — it catches known
  sentinel strings, not every possible identifying detail, so a human
  editorial pass on new content is still required, not optional. The
  history-scan step being manual (not a gate) means it can be forgotten;
  this is a known gap, named here on purpose rather than glossed over.
- **Forecloses:** committing the raw corpus to this repo under any
  circumstances, including "just for one branch" or "we'll clean it up
  before merging" — the `.gitignore` list exists specifically to make that
  an active choice (removing a gitignore line) rather than an accident.

## Alternatives considered

- **Commit the corpus privately, scrub before going public:** rejected —
  "scrub git history before publishing" is exactly the failure mode this ADR
  exists to avoid; a corpus that was never committed can't leak via a
  forgotten `git filter-repo` step.
- **A pre-push hook that scans for the sentinel strings automatically:**
  the stronger version of control #3 above, and the honest gap this ADR
  names — not implemented yet. If you're adding one, wire it as a
  `pre-push` git hook or a CI step that runs against the full history (not
  just the diff), and update this ADR's Decision section rather than
  treating the addition as a new decision.
- **Rely on the denylist test alone, no manual scan:** rejected — the
  denylist only ever covers content *currently in the working tree*; it says
  nothing about whether an earlier, since-fixed commit still holds
  sensitive material in history.
