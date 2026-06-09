# Assumptions log

Append-only. Every time Claude (or a contributor) makes an assumption that future work depends
on, add one line here with today's date. The maintainer reviews the list periodically and
either **ratifies** (upgrades to an ADR or hard fact in a doc) or **challenges** (removes +
adjusts the affected work).

Format: `- YYYY-MM-DD — <assumption> — <context / task id> — [open|ratified|challenged]`

Ratified assumptions should be struck through and linked to the ADR or doc that now owns the fact.

---

## Open

- ~~2026-04-19 — IaC tooling will be **Terraform (Hetzner Cloud + DNS + firewall) + Ansible (in-OS config)** rather than Pulumi, Nix, or container-orchestrator alternatives. — project kickoff — [challenged → ratified as ADR 0004: hetzner-k3s + K3s]~~
- 2026-04-19 — Observability stack will be **self-hosted on the prod box** (Prometheus + Loki + Grafana) initially, with off-site backup only — minimising external infra per kickoff constraints. — project kickoff — [open]
- 2026-04-19 — Alaveteli upstream is pulled as a pinned clone or submodule (NOT forked). All customisation flows through this theme — including non-trivial runtime patches in `lib/` that we now know bind us to specific upstream internals. — project kickoff — [open]
- 2026-04-19 — Tooling choices favour readability over cleverness across all phases. — project kickoff — [open]
- 2026-04-19 — Secrets management will be **SOPS + age** (encrypted in repo, decrypted at deploy). — project kickoff — [open]
- ~~2026-04-19 — One production box continues to host everything (app + DB + mail + observability). Split out only when a measured bottleneck justifies it. — project kickoff — [challenged → superseded by ADR 0004 K3s cluster model]~~
- 2026-06-09 — Inbound mail (postfix + dovecot) in K3s will run as a DaemonSet with hostNetwork on a dedicated node, or be replaced by an external relay. Exact approach TBD. — P2 kickoff — [open]
- 2026-06-09 — Observability (Prometheus + Loki + Grafana) will run as in-cluster workloads on the K3s cluster rather than on a single box. Self-hosted still; container-based. — P2 kickoff — [open]
- 2026-04-19 — `main` is the default branch; feature branches merge via PR. `feat/local-dev` is the branch where the foundation scaffolding is being built before merging to `main`. — project kickoff — [open]
- 2026-04-19 — 2-3 contributors may work on the repo concurrently via separate feature branches; task claims are tracked inline under each task in `ROADMAP.md`. — project kickoff — [open]
- 2026-04-19 — GitHub handles are the identifier used in repo-visible contributor notes (claim / close / handoff lines) — no real names. — project kickoff — [open]
- 2026-04-19 — Any production inventory/log/config tooling must redact secrets programmatically before output can reach a Claude session. — project kickoff — [open]
- 2026-06-09 — Dev cluster uses `cpx22` (2 vCPU / 4 GB shared-x86) in `fsn1`; the original `cx22` is deprecated by Hetzner and not provisionable. Implies app container images must be x86 (not ARM `cax11`). — P2-T2 — [open]
- 2026-06-09 — `HCLOUD_TOKEN` is provided to local tooling via a gitignored `.local/hcloud.env` sourced at provision time; never committed, never pasted into a Claude session. Kubeconfig lands at `~/.kube/handlingar-dev.yaml`. — P2-T2 — [open]

## Ratified

_(none yet)_

## Challenged / reversed

_(none yet)_
