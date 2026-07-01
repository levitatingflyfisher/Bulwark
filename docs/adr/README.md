# Architecture Decision Records

An ADR captures **one architectural decision**: the context that forced it,
the choice made, and the consequences we accepted. They are immutable once
accepted — if a decision is revisited, add a *new* ADR that supersedes the
old one (and mark the old one `Superseded by ADR-NNNN`) rather than editing
history.

Read these when you're about to change something load-bearing and want to
know whether you're fixing a mistake or unknowingly reopening a settled
trade-off. The general Flutter/Riverpod/Drift/no-BaaS architecture decisions
are inherited from [Furrow](https://github.com/levitatingflyfisher/Furrow)'s
own ADR set (0001 below is the fork decision itself); this index only
records what's specific to Bulwark.

## Index

| # | Decision | Status |
|---|---|---|
| [0001](0001-fork-from-furrow.md) | Fork from Furrow rather than build from scratch | Accepted |
| [0002](0002-content-as-shipped-assets.md) | Content ships as versioned JSON assets, not database rows | Accepted |
| [0003](0003-advisory-pacing-never-blocking.md) | The pacing engine advises; it never blocks | Accepted |
| [0004](0004-de-personalization-law.md) | De-personalization law + corpus quarantine | Accepted |
| [0005](0005-local-notifications-only.md) | Local notifications only, no `INTERNET` permission | Accepted |

## Writing a new one

Copy [`0000-template.md`](0000-template.md) to the next number, fill it in,
add a row above. Keep it to ~one screen — an ADR that needs scrolling is two
ADRs.
