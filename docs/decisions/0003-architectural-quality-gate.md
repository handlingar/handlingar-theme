# ADR 0003 — Architectural quality gate

- **Status:** accepted
- **Date:** 2026-04-19
- **Supersedes:** —
- **Superseded by:** —

## Context

ADRs 0001–0002 and `docs/ARCHITECTURE.md` encode deliberate choices — hosting provider, IaC
tooling, no orchestrator, SOPS + age for secrets, and so on. Without mechanical enforcement,
these choices drift:

- a contributor unfamiliar with the history adds a dependency that contradicts an accepted ADR,
- a rushed PR renames a component without updating the design docs,
- secrets or personal details leak into commits,
- `[x]` closed tasks on the roadmap lose their audit trail.

We need a gate that runs at the cheapest-to-catch moments (session start, pre-push, PR check),
requires no one to remember anything, and provides an unambiguous remediation when it fails.

## Decision

We adopt `scripts/quality-gate.sh` as a single-entrypoint hygiene and drift checker, driven by
`docs/invariants.md` (machine-readable invariants derived from accepted ADRs). It runs in four
places:

| Trigger | Mode | Blocking? |
| --- | --- | --- |
| Session start (advisory instruction in `CLAUDE.md`) | `--session-start` | No |
| `git push` via `.githooks/pre-push` | `--pre-push` | Yes |
| Pull requests and pushes to `main` via `.github/workflows/quality-gate.yml` | `--ci` | Yes |
| Weekly scheduled sweep (same workflow) | `--ci` | Surfaces drift that predates the gate |

Version 1 checks:

1. **Privacy** — no real names; no email addresses in committed files outside specific allow-listed paths.
2. **Secrets** — no PEM private-key blocks, no basic-auth URLs with credentials, no token-shaped
   assignments to known secret config keys.
3. **Architectural drift** — every pattern in the `docs/invariants.md` "Forbidden outside ADRs"
   table must not appear outside the allow-list.
4. **ROADMAP integrity** — every `[x]` closed task is followed by a `> Closed YYYY-MM-DD` note.
5. **ADR integrity** — every ADR carries `Status:` and `Date:` fields.

Checks are intentionally narrow. New checks ship alongside the ADRs that introduce their need.

## Alternatives considered

- **Manual review only.** Rejected — it relies on memory and consistency across contributor
  churn; a check someone has to remember to run is a check that eventually gets skipped.
- **Heavy static-analysis framework (semgrep, gitleaks, etc.).** Deferred, not rejected outright:
  they offer more coverage but add build-time, configuration, and language-specific rules that
  dwarf the current surface area. Plain shell + grep is legible to any contributor and has zero
  runtime dependencies beyond what every Linux dev box already has. We can add a heavier tool
  later as a supplement, not a replacement.
- **Claude-only enforcement via agent hooks.** Rejected — drift detection must work for
  non-Claude contributors and for CI, and must not depend on permission prompts or agent-runtime
  quirks.

## Consequences

- **Positive:** drift is caught at the earliest, cheapest moment. The gate's own output points at
  the correct remediation (revert, or write a superseding ADR plus invariant update).
- **Positive:** `docs/invariants.md` is a single, versioned file that doubles as living
  documentation of the current architecture in machine-readable form.
- **Positive:** extending the gate is usually a one-row edit to `docs/invariants.md`. New script
  checks are only needed when a qualitatively new kind of invariant is introduced.
- **Negative:** the gate introduces a small procedural cost for genuine architectural pivots
  (new ADR + invariant update). This is exactly the paperwork we'd want anyway; the gate makes
  it non-skippable.
- **Negative:** regex-based drift detection has false-positive risk. The allow-list is the
  pressure-release valve; pattern tightening is expected as the tree grows.
- **Negative:** the pre-push hook lives under `.githooks/` and requires a one-time
  `git config core.hooksPath .githooks` during onboarding. The README bootstraps this.
