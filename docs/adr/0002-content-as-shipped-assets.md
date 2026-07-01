# ADR-0002: Content ships as versioned JSON assets, not database rows

- **Status:** Accepted
- **Date:** 2026-07-11

## Context

The 89-item intervention library (title, action, category, trigger anchor,
mechanism, evidence tag, cost, optional shopping criteria, safety note,
details, tags) is authored content, not user data — it's identical for every
install of a given app version, it's produced by an editorial/curation
process (extraction and reconciliation from a private research corpus, then
red-team review, then the de-personalization pass), and it needs to be
validated as a whole document (unique ids, valid enums, every preset id
resolving, no denylisted strings) rather than row-by-row. Treating it as
seeded database rows would mean either re-seeding logic that has to detect
"is this a fresh install or an upgrade with new content," or a migration for
every content edit — neither of which content actually needs, since content
never depends on anything the user has done.

## Decision

**Content lives in `assets/content/interventions.json` and
`assets/content/presets.json`, loaded once at startup** by `ContentLoader`
into an immutable, indexed `ContentLibrary` (`byId` map, `all` stable-sorted
by `(defaultPhase, id)`, category and evidence indexes, case-insensitive
search). User state (`HabitStates`, `Checkins`, `Pulses`, `ShoppingStates`)
lives in Drift and references content only by its shipped, stable string
`id` — never a foreign key, never a copy of the content fields themselves.
**Content id stability is law**: an id must never be repurposed for a
different habit across releases, because every persisted row keyed by
`interventionId` depends on it still meaning the same thing.

## Consequences

- **Buys:** content changes (fixing a typo, adjusting a mechanism
  explanation, adding a 90th item) are pure data edits with no schema
  migration, and they're validated as a single document by
  `content_validation_test.dart` — a content bug (bad enum, duplicate id, an
  unresolved preset reference, a denylisted string) fails a `flutter test`
  loudly rather than silently shipping. It also keeps the database schema
  entirely about *the user*, which is the right thing to back up, export,
  and erase — content itself never needs any of those.
- **Costs:** updating content requires a new app release (there is no
  remote-content mechanism); a stale install can't pick up a corrected
  intervention without an update. Referential integrity between user state
  and content is enforced in application code (`byIdOrNull` returning null
  and callers skipping the row) rather than a SQL foreign key, so a
  retired-and-removed content id doesn't crash the app, but it does mean the
  database can hold "orphaned" rows referencing content that no longer
  exists — handled gracefully everywhere it's read, not prevented at write
  time.
- **Forecloses:** a server-driven content-update or A/B-tested content
  pipeline without a larger rework — this decision assumes content is a
  build-time artifact, not a runtime-fetched one, which is also required by
  the no-`INTERNET` law ([ADR-0005](0005-local-notifications-only.md)).

## Alternatives considered

- **Seed content into Drift on first launch:** rejected — needs a
  content-versioning/re-seed strategy for every future content edit, for no
  benefit over a static asset given content never depends on user state.
- **A remote content API:** rejected outright — violates the no-`INTERNET`
  law and the FLOSS/no-backend stance; also reintroduces exactly the kind of
  server-of-record dependency the whole OpenHearth fleet avoids.
- **Generate a Dart source file from the JSON at build time** (compile-time
  constants instead of a runtime-parsed asset): rejected — would make
  content changes require a full rebuild rather than a data edit, and loses
  the single validation entry point the shipped-JSON approach gives
  `content_validation_test.dart` (which reads the actual files that ride in
  the bundle, not a generated intermediate).
