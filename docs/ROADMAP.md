# Roadmap — Handlingar.se platform

**North star:** an efficient, well-maintained, reproducible hosting platform for handlingar.se
(Alaveteli) on Hetzner, fully defined in this repository, operable by any contributor with
minimal tribal knowledge.

**Active phase:** Phase 0 — Inventory & baseline.

Task ids are `P<phase>-T<task>`. Tasks marked `[ ]` are open, `[x]` closed.

**Task notes live inline** under each task. A task may carry at most one of:
- `> Claimed: branch \`feat/<id>-<slug>\` since YYYY-MM-DD by @<gh-handle> — <status>` (while in progress; can carry a handoff paragraph)
- `> Closed YYYY-MM-DD by @<gh-handle> — <1 sentence outcome + PR/SHA>` (after merge)

See [WAYS-OF-WORKING.md](WAYS-OF-WORKING.md) for claim, handoff, and close protocols.

---

## Phase 0 — Inventory & baseline  ← active

Goal: know what's actually running in production, documented in the repo, before changing anything.
No prod mutations in this phase.

- [ ] **P0-T1** — Inventory installed OS packages, versions, and systemd units on the prod server.
  Record in `docs/INVENTORY.md` (section: "OS & services").
- [ ] **P0-T2** — Record configured apache2 vhosts, ports, TLS cert source (Let's Encrypt? manual?),
  and firewall/crowdsec rules.
- [ ] **P0-T3** — Capture Alaveteli deployment specifics: install path, Ruby version (via rbenv),
  passenger config, sidekiq systemd unit, theme branch currently pinned, `general.yml` drift vs. the
  example `general.yml` in this repo.
- [ ] **P0-T4** — Record postgresql version, DB name(s), size, backup mechanism (if any), and the
  exact `schema_migrations` max version so we can pin for reproducible installs.
- [ ] **P0-T5** — Record postfix + dovecot role (incoming-mail pipeline for Alaveteli), aliases /
  virtual maps, and the integration with Alaveteli's `MTA_LOG_PATH` / `MTA_LOG_TYPE`.
- [ ] **P0-T6** — Record redis + memcached roles and current memory limits.
- [ ] **P0-T7** — Record cronjobs for the alaveteli user (xapian rebuild, alert emails, etc.).
- [ ] **P0-T8** — Document backup and restore story (what exists today, what's missing).
- [ ] **P0-T9** — Catalogue this repo's runtime patches (`lib/model_patches.rb`,
  `lib/controller_patches.rb`, `lib/patch_mailer_paths.rb`, `lib/customstates.rb`,
  `lib/config/custom-routes.rb`, `lib/config/user_spam_scorer.rb`): which Alaveteli classes they
  hook, what behaviour they change, whether they're tied to a specific upstream version.
  Outcome feeds ARCHITECTURE.md "runtime patches" section and pinning decisions in Phase 1.
- [ ] **P0-T10** — Design the read-only inventory collector script with built-in **secret
  masking** (see WAYS-OF-WORKING → "Secret masking"). Must produce output the developer can paste
  back into a Claude session without leaking PEM blocks, API keys, passwords, or basic-auth URLs.
  Do **not** run it against prod in this task — design + dry-run on local dev only. Running
  against prod is a separate gated step.
- [ ] **P0-T11** — Write ADR `0003-inventory-findings.md` summarising risks and quick wins.

_Exit criteria: `docs/INVENTORY.md` is filled out end-to-end; ADR 0003 is `accepted`; any
contributor can hand the inventory to another and they understand how prod is put together._

---

## Phase 1 — Local dev that actually works

Goal: `make dev` (or equivalent) → full Alaveteli stack running locally, no manual fiddling, with
mocked SMTP via smtp4dev. Onboard new devs in <30 minutes.

- [ ] **P1-T1** — Add `smtp4dev` service to `docker-compose.yml` and wire Alaveteli SMTP settings.
- [ ] **P1-T2** — Add `sidekiq` + `memcached` services mirroring prod (matching versions).
- [ ] **P1-T3** — Address the "Alaveteli install requires online DB connection" pain point.
  Exact failure mode to be confirmed in P0 (pending clarification: does it fail at gem install,
  asset precompile, `rake` loading, seed-data fetch, or xapian? each has a different fix).
  Likely solutions: ship a pre-seeded schema dump and/or bypass DB-requiring rake tasks via a
  `SKIP_DB` env flag. Make `setup.sh` fully idempotent (safe to re-run). Document "reset to
  clean state" procedure.
- [ ] **P1-T4** — Pin Alaveteli upstream to a specific tag (not `master --depth=1`) and record it
  in a top-level `ALAVETELI_VERSION` file consumed by both dev and prod.
- [ ] **P1-T5** — `make dev` / `make dev-reset` / `make dev-logs` convenience targets with brief docs
  in README.
- [ ] **P1-T6** — Smoke-test checklist in `docs/RUNBOOK.md` (browse site, submit request, receive
  outbound email in smtp4dev, background job runs).

_Exit criteria: fresh clone → `make dev` → working local Alaveteli in one command, confirmed on a
second machine._

---

## Phase 2 — IaC baseline

Goal: one codepath provisions any environment (dev-box, tst, prod replacement). Reproducible.

- [ ] **P2-T1** — ADR: tooling choice (default assumption: Terraform for Hetzner Cloud + DNS +
  firewall; Ansible for in-OS config). Ratify or replace.
- [ ] **P2-T2** — `infra/terraform/` — Hetzner project, server resource, floating IP, firewall,
  DNS records. Per-env tfvars files (`tst.tfvars`, `prod.tfvars`).
- [ ] **P2-T3** — `infra/ansible/` — role per stack component (postgres, postfix, dovecot, apache2,
  passenger/rbenv, redis, memcached, crowdsec, alaveteli-app). Idempotent.
- [ ] **P2-T4** — Parity check: apply to a throwaway Hetzner box, compare to prod inventory from
  Phase 0, close gaps.
- [ ] **P2-T5** — ADR: secret-less bootstrap strategy (how does the Ansible run get secrets the
  first time?).

_Exit criteria: a fresh Hetzner box provisioned from scratch via `make provision ENV=tst` matches
the prod inventory._

---

## Phase 3 — Secrets management

Goal: secrets live encrypted in this repo, decrypted only at deploy time.

- [ ] **P3-T1** — ADR: SOPS + age (default assumption). Keys per env + per developer.
- [ ] **P3-T2** — `secrets/<env>.enc.yaml` structure; wire into Ansible + GH Actions.
- [ ] **P3-T3** — Key rotation runbook.
- [ ] **P3-T4** — Migrate existing prod secrets (manually captured) into `secrets/prod.enc.yaml`.
  **Do not paste cleartext secret values into a Claude session during this task** — the
  maintainer captures them offline from prod, encrypts locally with the team's age recipients,
  commits the encrypted blob. Claude's role is limited to structuring the schema.

_Exit criteria: no secret exists only on the server. Rotation procedure tested on tst._

---

## Phase 4 — CI/CD

Goal: PR checks that matter; deploys that are boring.

- [ ] **P4-T1** — PR workflow: lint (rubocop / shellcheck / terraform fmt), theme spec tests,
  docker-compose build sanity.
- [ ] **P4-T2** — Env deploy workflow: merge to `main` → deploy to `tst` automatically; manual
  approval to deploy to `prod`.
- [ ] **P4-T3** — Manual workflow: "upgrade Alaveteli to \<tag\>" — bumps `ALAVETELI_VERSION`,
  opens PR, restores a recent prod DB snapshot into a scratch tst DB, runs upstream migrations
  against it end-to-end (Rails has no true dry-run), and reports duration + any errors. Also
  diffs `config/general.yml-example` against our `general.yml` and posts drift in the PR.
- [ ] **P4-T4** — Rollback workflow (redeploy previous git SHA).

_Exit criteria: a theme change ships via PR → auto-tst → approved prod deploy, no SSH required._

---

## Phase 5 — Staging (tst) environment

Goal: a second Hetzner box, provisioned from the same IaC, with anonymised prod-like data.

- [ ] **P5-T1** — Provision `tst.handlingar.se` via Phase 2 IaC.
- [ ] **P5-T2** — DB snapshot + anonymisation pipeline (strip PII) for importing into tst.
- [ ] **P5-T3** — Document refresh cadence (weekly? on-demand?).

_Exit criteria: tst refresh is a single command, runs in <15 min, preserves no PII._

---

## Phase 6 — Observability

Goal: know what's broken without logging into the box. Minimal external infra.

- [ ] **P6-T1** — ADR: observability stack. Candidates: Loki+Prometheus+Grafana (self-host),
  Metabase (BI, not ops), HolmesGPT (AI triage, k8s-centric — may not fit). **My leaning:**
  Prometheus + Loki + Grafana, all self-hosted on the same box via Podman.
- [ ] **P6-T2** — Deploy the chosen stack via Ansible role. Off-site backup of metrics/logs (S3-
  compatible like Hetzner Object Storage).
- [ ] **P6-T3** — Dashboards: request rate, error rate, sidekiq queue depth, postgres stats,
  postfix queue, disk/mem, TLS cert expiry.
- [ ] **P6-T4** — Alerts: page on real breakages (site down, sidekiq stalled, cert <7 days, disk
  >85%). Send to email initially.
- [ ] **P6-T5** — "Troubleshooting with Claude" runbook: how a developer pastes Grafana/Loki
  snippets into a Claude session for contextual triage (replaces HolmesGPT-style integration for
  our scale). Pastes must go through the secret-masking tooling (see WAYS-OF-WORKING).

_Exit criteria: an outage is visible in Grafana before a developer notices it by other means._

---

## Phase 7 — Alaveteli upgrades & DB migrations

Goal: upstream version bumps are low-risk and routine.

- [ ] **P7-T1** — Document Alaveteli's migration model (Rails `db:migrate`, their seed data,
  xapian reindex triggers, config drift points).
- [ ] **P7-T2** — Runbook: upgrade procedure. Dry-run on tst, observe migration time, apply to
  prod in maintenance window.
- [ ] **P7-T3** — Automate the "diff our `general.yml` against upstream example on each upgrade"
  check in the upgrade workflow.

_Exit criteria: one team member can upgrade Alaveteli end-to-end by following the runbook._

---

## Backlog (not yet scheduled)

- Metabase for business reporting on FOI-request data (distinct from observability).
- Public status page.
- k6 / locust load test suite runnable against tst.
- Postgres logical-backup to external S3.
- Multi-region DR story.

---

## Completed phases

_(none yet)_
