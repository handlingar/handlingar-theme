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

## Session bootstrap — read first

**Current repo state (2026-04-19).** Foundation scaffolding lives on branch `feat/local-dev`:
this ROADMAP, ADRs 0001-0003, `scripts/quality-gate.sh`, pre-push hook, CI workflow, usage
statusline (`.claude/settings.json`), docs for ways-of-working / architecture / runbook /
inventory / assumptions / incidents / invariants. Three commits, not pushed, not yet merged
to `main`. No P0 task is claimed yet.

**Next session's first decision.** Before starting any P0 task, resolve the scaffold:

1. Open a PR from `feat/local-dev` to `main` (recommended — CI runs the gate as a required
   check), OR
2. Merge `feat/local-dev` into `main` locally and push `main`, OR
3. Branch P0-T1 off `feat/local-dev` directly if there's a reason not to merge yet.

Option 1 is the default unless the developer says otherwise. After that, create
`feat/p0-t1-<slug>` off the updated `main` and claim P0-T1 inline below.

**Environment prerequisites (one-time).** `git config core.hooksPath .githooks` and
`npm i -g ccusage` (for the Pro-usage statusline) — see [README.md](../README.md#first-time-setup-any-contributor).

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
  > Claimed: branch `feat/local-dev` since 2026-06-09 by @erikjaderberg — DONE in substance,
  > pending /cost + formal close. `ALAVETELI_VERSION` file created (`0.46.7.0`); `Dockerfile`
  > pins the clone to that tag via `ARG ALAVETELI_VERSION` and uses `ruby:3.3-bookworm`
  > (Ruby 3.3 for `dalli`; bookworm/GCC-12 so the old C gems `statistics2`/`syck` compile;
  > `npm i -g corepack` since bookworm node lacks it). Added `.dockerignore` (keeps
  > `.local/`, `.git` out of the image). NOT yet consumed by prod deploy — that's later.
- [ ] **P1-T5** — `make dev` / `make dev-reset` / `make dev-logs` convenience targets with brief docs
  in README.
- [ ] **P1-T6** — Smoke-test checklist in `docs/RUNBOOK.md` (browse site, submit request, receive
  outbound email in smtp4dev, background job runs).

_Exit criteria: fresh clone → `make dev` → working local Alaveteli in one command, confirmed on a
second machine._

---

## Phase 2 — IaC baseline (K8s via hetzner-k3s)

Goal: one codepath provisions any environment (dev, tst, prod) as a K3s cluster on Hetzner Cloud.
Provisioning is a single command; teardown equally simple. See ADR 0004.

- [x] **P2-T1** — ADR: tooling choice — hetzner-k3s + K3s instead of Terraform + Ansible single-box.
> Closed 2026-06-09 by @erikjaderberg — ADR 0004 written; infra/hetzner-k3s/dev-cluster.yaml created; ARCHITECTURE.md and invariants.md updated.
- [x] **P2-T2** — Install hetzner-k3s locally and provision the dev cluster from
  `infra/hetzner-k3s/dev-cluster.yaml`. Record kubeconfig path. Verify `kubectl get nodes` shows
  1 master + 2 workers.
> Closed 2026-06-09 by @erikjaderberg — dev cluster live (1 master + 2 workers, cpx22/fsn1, k3s v1.32.4+k3s1); kubeconfig at ~/.kube/handlingar-dev.yaml; config corrected (cpx22, location:, HCLOUD_TOKEN, autoscaler cleanup). See docs/BRIEFING.md. /cost: pending.
- [ ] **P2-T3** — Base K8s manifests (`infra/k8s/base/`): Namespace, Deployments for alaveteli,
  sidekiq, redis, memcached; StatefulSet + PVC for postgres. ConfigMaps for non-secret config.
  Use the same container image built in Phase 1.
  > Claimed: branch `feat/local-dev` since 2026-06-09 by @erikjaderberg — DONE in substance,
  > pending /cost + formal close. App is **live and themed** in the `handlingar` ns:
  > `alaveteli-web` + `alaveteli-sidekiq` (1/1 each) on the Phase 1 image
  > `alaveteli-handlingar:0.46.7.0`, plus postgres 14 / redis 7 / memcached 1.6. Frontpage
  > returns HTTP 200 (sv locale, "Handlingar" branding). Full state, access steps, and
  > caveats are in **docs/BRIEFING.md** — read it first next session. Key handoff facts:
  >  - Image is imported into **worker1's containerd only** (no registry yet); both app
  >    pods are pinned to worker1 via nodeSelector. To rebuild/re-import:
  >    `docker build -t alaveteli-handlingar:0.46.7.0 .` then
  >    `docker save … | gzip | ssh root@<worker1-ip> 'gunzip | k3s ctr -n k8s.io images import -'`.
  >  - Boot runs `db:migrate` (NOT `db:prepare`) + `rake themes:install`; general.yml comes
  >    from the baked `config/general-handlingar-theme.yml`. RAILS_ENV=development for now.
  >  - The `alaveteli_dev` PVC had to be dropped & recreated clean (leftover inconsistent
  >    schema). A stray `alaveteli_test` DB also exists.
  >  - Remaining for full close: P2-T4 ingress (so it's reachable at dev.handlingar.se
  >    without port-forward; Rails 8 host-auth 403s non-localhost hosts), real registry,
  >    production-mode hardening.
- [ ] **P2-T4** — cert-manager + ClusterIssuer (Let's Encrypt) and Traefik IngressRoute for
  `dev.handlingar.se`. TLS cert issued automatically.
- [ ] **P2-T5** — Hetzner CSI driver persistent volumes: verify postgres PVC survives a pod
  restart; snapshot/restore test.
- [ ] **P2-T6** — ADR: secret-less bootstrap — how do SOPS-encrypted secrets reach the K8s cluster
  on first deploy (options: External Secrets Operator, SOPS + Helm secrets plugin, manual
  `kubectl create secret` from decrypted local file).
- [ ] **P2-T7** — Parity check: cluster running dev.handlingar.se with all Phase 1 services green;
  smoke test passes; no manual steps required beyond `hetzner-k3s create` + `kubectl apply`.

_Exit criteria: `hetzner-k3s create --config infra/hetzner-k3s/dev-cluster.yaml` + `make deploy ENV=dev`
yields a running Alaveteli instance at dev.handlingar.se, confirmed by smoke test._

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
