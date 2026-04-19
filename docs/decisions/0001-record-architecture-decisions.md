# ADR 0001 — Record architecture decisions

- **Status:** accepted
- **Date:** 2026-04-19
- **Supersedes:** —
- **Superseded by:** —

## Context

We are evolving `handlingar-theme` from a theme-only repository into the full
deployment/IaC/docs home for the Handlingar.se platform. Across Phase 0–7 work we will make
architecturally significant decisions (tooling, hosting, secrets, observability, upgrade
strategy). Without a consistent record of *why* we chose each approach, a future developer (or
future us) will re-litigate the same debates.

## Decision

We will record every architecturally significant decision as an **Architecture Decision Record
(ADR)** in `docs/decisions/NNNN-slug.md`, using the template below. Michael Nygard-style:
short, in repo, versioned via git.

"Architecturally significant" means: affects environment topology, runtime components, tooling
choice, data model, security posture, deployment flow, or observability. It does NOT include
routine code changes.

## Consequences

- **Positive:** future developers can read `docs/decisions/` in chronological order and
  understand how the current architecture came to be. Claude sessions can reference decisions
  by number without re-deriving them.
- **Positive:** decisions have a clear status; superseding is explicit, not silent.
- **Negative:** small overhead (~10 min per ADR). Mitigated by keeping ADRs short.
- **Neutral:** drafts are allowed (`status: proposed`) so ADRs can be authored alongside a
  feature branch rather than gating it.

## Template for new ADRs

```markdown
# ADR NNNN — <short title>

- **Status:** proposed | accepted | superseded by NNNN | deprecated
- **Date:** YYYY-MM-DD
- **Supersedes:** NNNN or —
- **Superseded by:** NNNN or —

## Context

What is the problem? What forces are at play? Keep it concrete.

## Decision

What did we decide? State it as a single sentence first, then elaborate.

## Alternatives considered

- **X** — why not.
- **Y** — why not.

## Consequences

What becomes easier? What becomes harder? Any ongoing cost or risk introduced?
```

## Numbering & conventions

- Zero-padded 4-digit numbers (`0001`, `0002`, …). Monotonic.
- Slug is kebab-case.
- Once an ADR is `accepted`, edit it only for typos. To change the substance, write a new ADR
  that supersedes it and update both `Superseded by` / `Supersedes` fields.
