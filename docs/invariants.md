# Architectural invariants

Machine-readable invariants enforced by [`scripts/quality-gate.sh`](../scripts/quality-gate.sh).

Each row in the **Forbidden outside ADRs** table is a regex (ERE syntax, case-insensitive) that
must NOT appear anywhere in tracked files except the allow-listed paths below. The rationale and
governing ADR document why the pattern is forbidden.

**Changing an invariant requires two artifacts in the same PR:**
1. A new ADR in `docs/decisions/` (status `accepted`) that records the change.
2. The corresponding edit to this file.

This two-step rule is why editing-around-the-gate is not an easier path than doing it right.

## Forbidden outside ADRs

| Pattern | Rationale | Governing ADR |
| --- | --- | --- |
| `\baws\b` | Hosting is Hetzner; AWS explicitly rejected | 0002 |
| `\bamazon[[:space:]]+web[[:space:]]+services\b` | As above | 0002 |
| `\bazure\b` | Hosting is Hetzner | 0002 |
| `\bgcp\b` | Hosting is Hetzner | 0002 |
| `\bgoogle[[:space:]]+cloud\b` | Hosting is Hetzner | 0002 |
| `\bnomad\b` | No orchestrator other than K3s | 0004 |
| `\bdocker[[:space:]]+swarm\b` | No orchestrator other than K3s | 0004 |
| `\bpulumi\b` | IaC tooling is Terraform + Ansible (pending ADR 0004) | assumption 2026-04-19 |
| `/home/[a-z]` | No hardcoded absolute home paths — use `$HOME`/`~` so setup is non-person/machine-dependent | 0005 |

## Allow-list (patterns may appear here without counting as drift)

These files may reference rejected technologies (in "alternatives considered" sections, decision
rationale, historical context, or the quality-gate implementation itself).

- `docs/decisions/**`
- `docs/assumptions.md`
- `docs/invariants.md`
- `docs/ARCHITECTURE.md`
- `docs/ROADMAP.md`
- `docs/WAYS-OF-WORKING.md`
- `docs/RUNBOOK.md`
- `CLAUDE.md`
- `README.md`
- `.github/pull_request_template.md`
- `scripts/quality-gate.sh`

## Required-artifact rules (not yet auto-enforced)

When a PR modifies any of these paths, a corresponding ADR must exist in `docs/decisions/` or
land in the same PR:

- `infra/**`
- `Dockerfile`
- `docker-compose.yml`
- `ALAVETELI_VERSION`
- `.github/workflows/deploy*.yml`

Current enforcement: human checklist via `.github/pull_request_template.md`. Upgrading this to
automatic diff-based enforcement is a later task (tracked when Phase 2 introduces `infra/`).

## Change-control rules (process)

These govern *how* a change is made, not what patterns are forbidden.

- **DNS and base-infrastructure changes must be pre-specified and approved.** Before applying any
  change to DNS records, cloud DNS zones, load balancers, networks, firewalls, or other base
  infrastructure, state **exactly** what will change — for DNS: each record's name, type, and
  old → new value; for other infra: the resource and the precise mutation — and get explicit
  approval first. This applies to changes made *indirectly* by automation too: e.g. before
  deploying external-dns or requesting a cert (cert-manager DNS-01), enumerate the exact records
  the controller will create/modify/delete. Rationale: `handlingar.se` is the live production zone
  and infra changes are high-blast-radius; "the controller manages it" is not a substitute for
  knowing the exact record set. Governed by ADR 0006.

## Evolving this file

- **Adding a pattern:** accompanies an ADR that newly rejects a technology. Add one row; add the
  ADR number in the "Governing ADR" column.
- **Removing / relaxing a pattern:** requires a superseding ADR (new number, sets the old ADR's
  status to `superseded by <new>`). Then remove / edit the row.
- **Adding an allow-list entry:** rare. Each entry is a partial defeat of the gate; prefer
  rewriting the file to comply.
- **Syntax notes:** patterns use POSIX ERE with `[[:space:]]` rather than `\s`. Test new patterns
  against the current tree with `scripts/quality-gate.sh` before committing.
