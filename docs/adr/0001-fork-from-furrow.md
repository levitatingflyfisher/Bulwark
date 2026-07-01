# ADR-0001: Fork from Furrow rather than build from scratch

- **Status:** Accepted
- **Date:** 2026-07-11

## Context

Bulwark needed a Clean Architecture Flutter skeleton — Riverpod, Drift over
SQLite, `go_router`, bundled fonts, a no-`INTERNET` Android manifest, PWA +
APK dual-target build — before any of its own domain logic could exist. The
OpenHearth fleet already had exactly this skeleton, proven in production, in
Furrow (a daily-virtue/habit tracker with its own no-dark-patterns,
local-first invariants already tested and documented). Building the same
skeleton again from an empty Flutter project would re-litigate a dozen
already-settled decisions (which Riverpod codegen pattern, how DAOs are or
aren't used, how the web/native split works for platform-specific code, how
the release workflow is shaped) for no benefit.

## Decision

**Fork Furrow's codebase** (copying the source tree minus `.git`/`build`/
`.dart_tool`), strip the virtue-tracking domain entirely, and reskin per
Bulwark's own identity (name, palette, icon) while keeping the architectural
shape: feature-first `lib/features/<feature>/{domain,data,presentation}`,
Riverpod for state (mixing hand-written providers and `@riverpod` codegen
exactly as Furrow does — codegen where a feature needs more than one
provider, hand-written otherwise), Drift over SQLite with repositories
talking to `AppDatabase` directly (no DAO layer), `go_router` with a
redirect-based onboarding gate, and the same conditional-import pattern for
web/native platform splits (seen here in
`notification_service_factory.dart`, mirroring Furrow's auth-tier stubs).

## Consequences

- **Buys:** a working, tested, no-`INTERNET` skeleton on day one — the first
  commits after the fork already had a clean `flutter analyze` and a passing
  generic test suite, before a single line of Bulwark-specific domain logic
  existed. It also buys consistency with the rest of the fleet: an agent or
  contributor who's worked on Furrow, Sundial, or Reckon recognizes this
  codebase's shape immediately.
- **Costs:** some Furrow-specific idioms travel along even where they're not
  ideal for Bulwark's very different domain (a habit-*sequencing* app is a
  meaningfully different problem than a habit-*logging* app) — the adoption
  engine, the content-as-assets model, and the wall are all Bulwark-native
  additions layered on top of a skeleton that wasn't designed with them in
  mind.
- **Forecloses:** nothing structurally — the fork point is a starting
  skeleton, not a shared dependency. Bulwark and Furrow can diverge freely
  from here with no coupling between the two repos' futures.

## Alternatives considered

- **A fresh Flutter project:** rejected — strictly more work to reach parity
  with an already-proven skeleton, with no offsetting benefit.
- **A shared package extracted from Furrow** (e.g. a `oh_flutter_core`
  library for the common skeleton pieces): deferred, not adopted — no third
  sibling app has needed this yet, and extracting a shared package before a
  second real consumer exists tends to guess the wrong seams. Revisit if a
  third app forks from either.
