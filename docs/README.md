# Documentation

Organized on the [Diátaxis](https://diataxis.fr/) model — four kinds of docs
for four different needs. Find what you need by *what you're trying to do*,
not by guessing a filename.

| I want to… | I need | Go to |
|---|---|---|
| **learn by doing** | a Tutorial | [Tutorials](#tutorials) |
| **accomplish a specific task** | a How-to guide | [How-to guides](#how-to-guides) |
| **look up exact details** | Reference | [Reference](#reference) |
| **understand why** | Explanation | [Explanation](#explanation) |

New here? Start with the [README quickstart](../README.md), then
[Vision](../VISION.md), then the tutorial below.

---

## Tutorials
*Learning-oriented — take me by the hand through my first success.*

- **[Your first week](tutorials/your-first-week.md)** — install, onboard,
  meet your starter pack, check in every day, and see the promotion gate and
  the wall for the first time.
- The **[README quickstart](../README.md#quickstart-development)** — clone,
  generate code, run the app, for development.

## How-to guides
*Task-oriented — how do I accomplish X (assumes you know the basics)?*

- **[Everyday tasks](how-to/everyday-tasks.md)** — add a habit straight from
  the Library, turn on reminders (and understand what "opt-in" actually
  means here), and export your data.
- Working *in* the repo (human or agent): **[AGENTS.md](../AGENTS.md)**.

## Reference
*Information-oriented — tell me exactly, precisely, completely.*

- **[Content schema](reference/content-schema.md)** — the shipped
  intervention JSON's exact fields, and the Category / Anchor / Evidence /
  CostTier / ShopWhere enums.
- **[Data model](reference/data-model.md)** — the drift tables, columns,
  keys, and what each one stores.
- **[Engine rules](reference/engine-rules.md)** — the exact, numeric rules
  behind the starter pack, the promotion gate, graduation, erosion,
  adherence, notification planning, and the wall layout.

## Explanation
*Understanding-oriented — help me understand the ideas and the why.*

- **[Vision](../VISION.md)** — the one idea, the invariants, the honest
  scorecard.
- **[Design philosophy](design-philosophy.md)** — why the pacing engine only
  ever advises, why the signature is a wall and not a streak, and the
  de-personalization stance behind the shipped content.
- **[Architecture Decision Records](adr/)** — why each load-bearing choice
  was made.
- **[Privacy model](privacy-model.md)** — exactly what leaves the device
  (nothing, automatically), and how to check that claim yourself.
- **[Limitations](limitations.md)** — read before adopting. What it does
  *not* do, and where it's imprecise on purpose.

---

*(There is no white paper or yellow paper for Bulwark. Its algorithmic core —
the adoption engine — is small enough that [reference/engine-rules.md](reference/engine-rules.md)
is the complete, precise account; a separate formal spec would only restate
it.)*
