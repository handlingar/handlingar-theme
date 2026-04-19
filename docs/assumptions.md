# Assumptions log

Append-only. Every time Claude (or a contributor) makes an assumption that future work depends
on, add one line here with today's date. The maintainer reviews the list periodically and
either **ratifies** (upgrades to an ADR or hard fact in a doc) or **challenges** (removes +
adjusts the affected work).

Format: `- YYYY-MM-DD — <assumption> — <context / task id> — [open|ratified|challenged]`

Ratified assumptions should be struck through and linked to the ADR or doc that now owns the fact.

---

## Open

- 2026-04-19 — IaC tooling will be **Terraform (Hetzner Cloud + DNS + firewall) + Ansible (in-OS config)** rather than Pulumi, Nix, or container-orchestrator alternatives. — project kickoff — [open]
- 2026-04-19 — Observability stack will be **self-hosted on the prod box** (Prometheus + Loki + Grafana) initially, with off-site backup only — minimising external infra per kickoff constraints. — project kickoff — [open]
- 2026-04-19 — Alaveteli upstream is pulled as a pinned clone or submodule (NOT forked). All customisation flows through this theme — including non-trivial runtime patches in `lib/` that we now know bind us to specific upstream internals. — project kickoff — [open]
- 2026-04-19 — Tooling choices favour readability over cleverness across all phases. — project kickoff — [open]
- 2026-04-19 — Secrets management will be **SOPS + age** (encrypted in repo, decrypted at deploy). — project kickoff — [open]
- 2026-04-19 — One production box continues to host everything (app + DB + mail + observability). Split out only when a measured bottleneck justifies it. — project kickoff — [open]
- 2026-04-19 — `main` is the default branch; feature branches merge via PR. `feat/local-dev` is the branch where the foundation scaffolding is being built before merging to `main`. — project kickoff — [open]
- 2026-04-19 — 2-3 contributors may work on the repo concurrently via separate feature branches; task claims are tracked inline under each task in `ROADMAP.md`. — project kickoff — [open]
- 2026-04-19 — GitHub handles are the identifier used in repo-visible contributor notes (claim / close / handoff lines) — no real names. — project kickoff — [open]
- 2026-04-19 — Any production inventory/log/config tooling must redact secrets programmatically before output can reach a Claude session. — project kickoff — [open]

## Ratified

_(none yet)_

## Challenged / reversed

_(none yet)_
