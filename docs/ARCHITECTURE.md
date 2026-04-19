# Architecture — Handlingar.se platform

> Target-state design. This is aspirational for everything past Phase 0. Current prod is a single
> hand-built Hetzner box (see [INVENTORY.md](INVENTORY.md) once populated).

## Principles

1. **One codepath per environment.** Local, dev, tst, prod are the same recipe with different inputs.
2. **Idempotent everything.** Any provisioning or deploy step must be safe to run twice.
3. **Repo is the source of truth.** If it's not in the repo, it isn't real. No state lives only on
   the server.
4. **Minimum external infra.** Prefer a thing we host on our own box over a SaaS subscription,
   unless hosting it ourselves costs more than the subscription in effort.
5. **Small-team ergonomics over clever abstractions.** Readable beats clever. Any contributor
   should be able to onboard and run a procedure from the docs alone.
6. **Secrets never leave encryption-at-rest.** Encrypted in repo, decrypted in-memory at deploy.

## High-level topology (target)

```
                         ┌─────────────────────┐
                         │   GitHub Actions    │
                         │  (CI/CD, scheduled) │
                         └──────────┬──────────┘
                                    │ Terraform + Ansible + SOPS
                                    ▼
  Hetzner Cloud project ─── provisioned from infra/
    ┌───────────────────────────────────────────────────────────────┐
    │  prod.handlingar.se      tst.handlingar.se   dev.handlingar.se │
    │  (production box)        (staging box)       (optional)        │
    └───────────────────────────────────────────────────────────────┘

  Each box (identical recipe):
    ┌──────────────────────────────────────────────────────────────┐
    │  apache2  ──►  passenger  ──►  alaveteli (Rails, rbenv)      │
    │                                  │                           │
    │                                  ├──► postgresql             │
    │                                  ├──► redis   (cache/sidekiq)│
    │                                  ├──► memcached              │
    │                                  └──► sidekiq (background)   │
    │                                                              │
    │  postfix + dovecot ◄───── inbound mail ────── MX             │
    │                           (Alaveteli mail handling)          │
    │                                                              │
    │  crowdsec       (intrusion detection)                         │
    │  prometheus + loki + grafana (self-host observability, P6)   │
    │  node_exporter + alloy agent                                 │
    └──────────────────────────────────────────────────────────────┘

  Off-box:
    ┌──────────────────────────────────────────────────────────────┐
    │  Hetzner DNS       (managed by Terraform)                    │
    │  Hetzner Object    (encrypted DB + metric/log backups)       │
    │   Storage (S3)                                               │
    │  Let's Encrypt     (TLS, via acme.sh or certbot)             │
    └──────────────────────────────────────────────────────────────┘
```

## Components & responsibilities

| Component | Purpose | Notes |
| --- | --- | --- |
| `apache2` + `mod_passenger` | HTTP(S) front end + Rails app server | Matches upstream Alaveteli docs. |
| `alaveteli` (Rails, Ruby 3.2 via rbenv) | The FOI platform | Pinned by `ALAVETELI_VERSION`. |
| `handlingar-theme` | Swedish overlay (views, locale, config) **and runtime patches** into Alaveteli core via `lib/*_patches.rb` and friends | This repo. Upgrade-risk surface — see INVENTORY §M. |
| `sidekiq` | Background jobs (mail, xapian, alerts) | systemd unit. |
| `postgresql` | Main data store | Version pinned; encrypted backups to S3-compatible object storage (provider decided in a later ADR — Hetzner Object Storage is the likely default). |
| `redis` | Sidekiq queue + Rails cache | Single-instance, on-box. |
| `memcached` | Fragment cache | Small footprint. |
| `postfix` (+ possibly `dovecot`) | Inbound mail pipeline for Alaveteli request replies | Critical. Alaveteli typically ingests via postfix pipe to a parsing script. Dovecot's role on the current prod box is TBC in Phase 0 (may be legacy / unneeded). |
| `crowdsec` | Intrusion detection + rate-limiting | Keep; integrate logs into Loki (P6). |
| `prometheus` + `loki` + `grafana` | Observability (Phase 6) | Self-hosted, podman. |

## Environment model

| Env | Purpose | Hosting | Data |
| --- | --- | --- | --- |
| `local` | Dev loop | `docker-compose` on dev laptop | Seeded sample data + smtp4dev |
| `dev` | Optional shared long-running dev box | Hetzner (smallest instance) | Sample data |
| `tst` | Pre-prod verification | Hetzner (sized like prod) | Anonymised prod snapshot |
| `prod` | `handlingar.se` | Hetzner (production box) | Live data, backups to Object Storage |

Provisioned from the same Terraform root with per-env tfvars. Ansible inventory has one group per env.

## Deployment flow (target)

1. Developer opens PR against `main` with theme or config changes.
2. GH Actions PR workflow: lint, rubocop, theme specs, terraform fmt/validate, docker-compose build.
3. Merge to `main` → GH Actions deploy workflow:
   a. Decrypt `secrets/tst.enc.yaml` (SOPS + age; key in repo secret).
   b. Run Ansible playbook against `tst` inventory (idempotent; unchanged nodes no-op).
   c. Run smoke test against `tst.handlingar.se`.
4. Human approval → same workflow runs against `prod`.
5. On failure, `rollback` workflow redeploys the previous SHA.

## Alaveteli upgrade flow (target, Phase 7)

1. Manual workflow "Upgrade Alaveteli" takes a target tag (e.g. `0.48.0.0`) as input.
2. Bumps `ALAVETELI_VERSION`, opens a PR.
3. CI clones the new Alaveteli tag, diffs `config/general.yml-example` against our `general.yml`,
   reports drift in the PR description.
4. CI restores a recent prod DB snapshot into an ephemeral tst DB, runs `db:migrate` on it, reports
   migration duration and any errors.
5. On approval + merge, normal deploy flow runs (tst → prod).
6. Post-deploy: trigger xapian reindex if migration notes say so.

## Secrets model

- Source of truth: `secrets/<env>.enc.yaml`, encrypted with SOPS + age.
- Per-env age recipient key (stored in GH repo env secrets, named `SOPS_AGE_KEY_<ENV>`).
- Per-developer age keys (local, never committed). Team-rotatable via `secrets/.sops.yaml` recipients.
- Ansible decrypts at deploy time; secrets land in `/etc/alaveteli/env` (root:alaveteli 0640) and
  similar locations. Never written to disk encrypted-less outside that path.
- No secret sits only on the server. Rotation = edit encrypted file → PR → deploy.

## Observability (Phase 6, target)

- Metrics: `prometheus` scrapes `node_exporter` + passenger exporter + postgres exporter + sidekiq
  exporter. 30-day retention on-box. Long-term remote storage is out of scope unless a real need
  emerges.
- Logs: `grafana alloy` tails `/var/log/` + apache + syslog + sidekiq → `loki` on the same box.
- Dashboards: checked into `observability/grafana/dashboards/*.json`, provisioned by Ansible.
- Alerts: `grafana alerting` → email for now; SMS via external service later if pager is needed.
- Claude-in-the-loop troubleshooting: a developer pastes a Grafana snapshot or Loki query result
  into a Claude session (via the secret-masking tooling) and Claude correlates with the code. No
  HolmesGPT integration planned — k8s-centric, overkill at this scale.

## What is explicitly NOT in scope

- Kubernetes / Nomad / any container orchestrator. Single-box deploy.
- Multi-region / HA database. A nightly restore drill is good enough for our SLA.
- Cloud-managed Postgres / Redis. We stay on-box.
- A forked Alaveteli. Upstream is consumed unchanged at a pinned tag; all customisation flows
  through this theme — including runtime monkey-patches (they still run inside Alaveteli's
  process, but the upstream source tree isn't modified).
- Public status page (nice-to-have backlog item).

## Compatibility note — theme runtime patches

This repo is technically a theme, but it carries non-trivial runtime patches into Alaveteli core
(see `lib/model_patches.rb`, `lib/controller_patches.rb`, `lib/patch_mailer_paths.rb`,
`lib/customstates.rb`, `lib/config/custom-routes.rb`, `lib/config/user_spam_scorer.rb`). Those
patches bind us to specific upstream internals. The upgrade playbook (Phase 7) must include a
step to re-validate every patch against the new Alaveteli tag before cutting a release. See
INVENTORY §M for the patch catalogue (populated in P0-T9).

## Open questions (tracked in ADRs)

See `docs/decisions/`:
- `0002` — Hetzner Cloud as sole hosting provider (draft).
- (Future) `0003` — Phase 0 inventory findings summary.
- (Future) `0004` — IaC tooling (Terraform + Ansible vs. alternatives).
- (Future) `0005` — Secrets encryption (SOPS + age vs. alternatives).
- (Future) `0006` — Observability stack choice.
