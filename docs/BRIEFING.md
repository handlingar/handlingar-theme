# BRIEFING — latest status

> Living "what are we doing right now" snapshot. Updated as work progresses so
> any contributor (or a cold Claude session) can see current state at a glance.
> Detailed task tracking lives in [ROADMAP.md](ROADMAP.md); this is the headline.

**Last updated:** 2026-06-10

## Operating this — no commands to memorize

Everything runs through `make`. Run it with no arguments to see every command:

```bash
make                 # list all commands with descriptions
make preflight       # install/verify tools + validate the Hetzner token
make bringup         # FULL zero-to-running: cluster + build image + import + deploy app
make cluster-up      # create the dev cluster (auto-fixes prerequisites)
make image-build     # docker build the pinned Alaveteli image locally
make image-import    # import the image into worker1 containerd (idempotent, no registry)
make app-up          # apply manifests + wait for the app to roll out
make app-forward     # port-forward the app to http://localhost:3000
make deploy          # deploy backing services (auto-creates namespace + dev secret)
make status          # cluster + app health + the billing reminder
make smoke           # re-runnable cluster health test
make cluster-down    # destroy the cluster (STOPS billing)
```

### Replicate everything from zero (e.g. after `make cluster-down`)
The whole platform is reproducible from this repo with **one command** (each step is
idempotent and self-fixing):
```bash
make preflight       # one-time: installs kubectl/helm/hetzner-k3s; tells you where
                     #   to paste the Hetzner token (.local/.env, gitignored)
make bringup         # cluster-up → image-build → image-import → app-up
make app-forward     # → http://localhost:3000
```
Prerequisites NOT in the repo (by design): the **Hetzner API token** in
`.local/.env` (a secret; `make preflight` prompts) and your SSH key
`~/.ssh/id_ed25519` (used by the cluster config + the image import). Everything else —
image build, registry-less import, DB migrate, theme install, dev secret — is
automated. `make bringup` from a fresh cluster takes ~25-40 min (mostly the image
build + the slow image upload to the node).

Each target sets `KUBECONFIG`/`PATH` and fixes its own prerequisites, so commands
don't fail halfway and you never need to remember flags or environment variables.
The only manual, one-time step is pasting a Hetzner Cloud API token into
`.local/.env` (kept out of git) — `make preflight` tells you exactly how if
it's missing.

## Right now

- **Active work:** Phase 2 — IaC baseline (K3s on Hetzner).
- **Just finished (2026-06-09):** **Alaveteli is running in the cluster, themed.**
  Built the Phase 1 image (pinned Alaveteli `0.46.7.0`, Ruby 3.3, `ruby:3.3-bookworm`
  base), imported it into worker1's containerd (registry-less), deployed web + sidekiq,
  migrated a clean DB, and installed the **handlingar theme** (sv locale, "Handlingar"
  branding). Frontpage returns **HTTP 200** via port-forward.
- **Just validated (2026-06-10): reproducibility from zero PASSES.** Ran `make cluster-down`
  then `make bringup` + port-forward on a fully fresh cluster — themed **HTTP 200** (sv locale,
  "Handlingar" branding), **no manual steps**. Total ~18 min (cluster ready) + slow image
  upload + first-boot migrate. Three defects surfaced and were handled (see below).
- **Just finished (2026-06-11): P2-T4 — public HTTPS is LIVE.** The app is reachable at
  **https://dev.nonprod.handlingar.se** with a real Let's Encrypt cert, behind a Hetzner LB.
  Full stack codified in `infra/k8s/ingress/` + `make ingress-up` (wired into `make bringup`):
  Traefik (LB), cert-manager (DNS-01/Cloudflare), external-dns (auto-publishes the record). See
  ADR 0006 + `infra/k8s/ingress/README.md`. Non-prod now lives under `*.nonprod.handlingar.se`.
- **Just finished (2026-06-11, four parallel work streams): functional dev environment.**
  (1) **Xapian fixed** — /list/* and search 500'd (index never built); boot now builds the index
  if missing + runs a 60s background incremental updater. All main pages verified 200.
  (2) **Mock mail loop** — Mailpit deployed (`infra/k8s/base/mailpit.yaml`); all outgoing app
  mail lands there (`SMTP_URL: smtp://mailpit:1025` in the ConfigMap; Alaveteli's
  USE_MAILCATCHER_IN_DEVELOPMENT path). Web UI: **`make mail-ui`** → http://localhost:8025.
  Incoming replies: **`make mail-ingest`** pipes Mailpit messages into `script/mailin`.
  (3) **Mock data** — **`make mock-data`** seeds 5 fake Swedish authorities + a test user
  (idempotent; `scripts/mock-data/`); **`make mock-request`** files a real FOI request through
  the normal code path (verified: request live on site, email in Mailpit, searchable via Xapian).
  (4) **Bringup speed** — image-build now runs in parallel with cluster-up; zstd image transfer
  (−25% bytes); Dockerfile slimmed ~340MB; ssh known-hosts noise fixed; `cluster-down` now also
  deletes orphaned detached CSI volumes. Est. cold bringup ~40 → ~25 min. Registry evaluation:
  **ghcr.io recommended** (kills the 12-16 min import entirely) — not yet implemented.
- **NEXT SESSION — do this first:** re-validate full reproducibility — `make cluster-down`
  then `make bringup` on a fresh cluster should reach **https://dev.nonprod.handlingar.se**
  (themed 200, valid cert) with no manual steps, then `make mock-data` for test content (the
  whole chain was built incrementally, never proven in one clean from-zero run). Then: ghcr.io
  registry (drop the worker1 pin); production-mode hardening.

### Ingress / DNS / TLS (P2-T4, 2026-06-11)
- **Reachable at https://dev.nonprod.handlingar.se** — Hetzner LB IPv4 `91.98.218.67` (+ IPv6).
- **Prerequisite:** `CLOUDFLARE_API_TOKEN` in `.local/.env` (Edit zone DNS, scoped to
  `handlingar.se`); validated by `make preflight`.
- **DNS safety:** external-dns is locked to `nonprod.handlingar.se` (domain-filter) + TXT
  ownership registry, so it can NEVER touch production records. Recorded as a project rule in
  `docs/invariants.md` (Change-control rules): exact DNS changes are specified before applying.
- **Three sub-issues hit + fixed while wiring it (all codified):** (1) Traefik chart v40 nests
  redirect under `ports.web.http.redirections`; (2) external-dns needs `--zone-id-filter` for the
  parent zone (domain-filter alone matched no zone) — derived from the token at deploy time;
  (3) the LB's private IP leaked into DNS — fixed with `disable-private-ingress` + `policy: sync`
  (so stale records self-clean on rebuild, since the LB IP changes each time).
- **`make ingress-status`** shows LB IP, cert readiness, and DNS resolution for troubleshooting.

### Reproducibility-validation findings (2026-06-10)
- **FIXED — `make cluster-down` hung forever non-interactively.** `hetzner-k3s delete` v2.5.0
  prompts "type the cluster name to confirm"; with no TTY it looped on the empty-input error
  at 100% CPU and deleted nothing (burned ~25 min before I killed it). Added `--force` to the
  target ([Makefile](../Makefile) `cluster-down`). Re-run deleted the cluster in ~20s.
- **GAP — `cluster-down` orphans the postgres CSI volume.** `hetzner-k3s delete` removes
  servers/network/firewall/SSH key but NOT dynamically-provisioned `pvc-*` volumes; one was
  left `available` (detached, still billing). Removed it manually via the Hetzner API. The
  target's doc-string claims it "destroys the postgres PVC" — it does not. **Follow-up:** have
  `cluster-down` delete orphaned dev CSI volumes too (query API by name/label, delete detached).
- **COSMETIC — image-import prints SSH "REMOTE HOST IDENTIFICATION HAS CHANGED" on recycled
  IPs.** A fresh cluster can reuse a prior node's public IP with a new host key, conflicting
  with `~/.ssh/known_hosts`. Import still succeeds (pubkey auth via `-i`, `StrictHostKeyChecking=no`
  proceeds and only disables password auth), but the warning is alarming and would become fatal
  if SSH config ever hardened. **Follow-up:** add `-o UserKnownHostsFile=/dev/null` (or
  `ssh-keygen -R` the node IPs) to the import target's ssh calls.
- **NOTE — `alaveteli-web` restarted 3× during first boot** before going 1/1 Running (probe
  timing while the first-boot migrate + theme install run). Self-healed; worth a readiness/boot
  review later, not blocking.

### How to reach the running app (no ingress yet)
```bash
export PATH="$HOME/.local/bin:$PATH"; export KUBECONFIG=~/.kube/handlingar-dev.yaml
kubectl -n handlingar port-forward deploy/alaveteli-web 3000:3000
# then open http://localhost:3000  (Host must be localhost — see caveat below)
```

### Caveats / known follow-ups (dev cluster)
- **RAILS_ENV=development** for now (matches the proven docker-compose bring-up:
  on-the-fly assets, dev secret_key_base). Production hardening (precompiled assets,
  SECRET_KEY_BASE, xapian index, FORCE_SSL) is later Phase 1 work.
- **Image only on worker1**; both app pods are pinned there via nodeSelector
  (single registry-less import over a slow uplink, ~16 min). A real registry removes this.
- **`db:migrate`, not `db:prepare`** on boot: `db:prepare` also prepares the test DB
  in-process, where `acts_as_versioned.create_versioned_table` reads a stale column
  cache and skips `public_bodies.version`, breaking migration 026. (The `alaveteli_dev`
  PVC also carried inconsistent leftover schema from earlier P2-T3 work — dropped &
  recreated clean; a stray `alaveteli_test` DB also exists on the server.)
- **Host authorization:** Rails 8 returns 403 for non-localhost Host headers. Access via
  port-forward (Host `localhost`) works; P2-T4 ingress for `dev.handlingar.se` will need
  that host added to `config.hosts` / Alaveteli `DOMAIN`.
- **Theme is cloned at pod boot** via `rake themes:install` (handlingar-theme `dev`
  branch). Fine for dev; bake into the image once stable.

## Dev cluster — handlingar-dev (LIVE)

| Item | Value |
| --- | --- |
| Topology | 1 master + 2 workers, all `Ready` |
| K3s | `v1.32.4+k3s1` |
| Instances | 3 × `cpx22` (2 vCPU / 4 GB, shared x86) in `fsn1` |
| Cost | ~€20/mo **while running** — `hetzner-k3s delete --config infra/hetzner-k3s/dev-cluster.yaml` to stop billing |
| Kubeconfig | `~/.kube/handlingar-dev.yaml` |
| System pods | Hetzner CCM, CSI (5/5), CoreDNS, Traefik — Running |

**Connect:**
```bash
export PATH="$HOME/.local/bin:$PATH"   # kubectl 1.36.1, helm 3.16.4 live here
export KUBECONFIG=~/.kube/handlingar-dev.yaml
kubectl get nodes
```

## Deployed services — `handlingar` namespace

| Service | Image | State | Verified |
| --- | --- | --- | --- |
| postgres | postgres:14 | Running, 10Gi CSI PVC | `alaveteli_dev` reachable (v14.23) |
| redis | redis:7-alpine | Running | `PONG` |
| memcached | memcached:1.6-alpine | Running | `VERSION 1.6.42` |
| alaveteli-web | alaveteli-handlingar:0.46.7.0 | Running (1/1), themed | HTTP 200 via port-forward |
| alaveteli-sidekiq | alaveteli-handlingar:0.46.7.0 | Running (1/1) | boots after schema ready |

Manifests: `infra/k8s/base/` (see its README). Dev DB password is a throwaway
Secret created out-of-band (`alaveteli-secrets`, not in git). Apply/teardown:
```bash
kubectl apply -f infra/k8s/base/
kubectl -n handlingar get pods
kubectl delete -f infra/k8s/base/      # also removes the postgres volume
```

## Validation — cluster smoke test

Re-runnable test at `infra/k8s/smoke-test/` proves the cluster works end-to-end
without the app image. **Run it after any cluster change:**

```bash
export PATH="$HOME/.local/bin:$PATH"
export KUBECONFIG=~/.kube/handlingar-dev.yaml
infra/k8s/smoke-test/run.sh          # all checks should PASS
infra/k8s/smoke-test/run.sh --clean  # release the test volume when done
```

Checks: (1) pod scheduling, (2) CSI volume survives a pod restart, (3) Service /
in-cluster DNS, (4) real HTTP GET from the host via port-forward, (5) ingress —
SKIPPED until P2-T4 installs a controller (auto-runs once one exists). Last run:
all PASS, 2026-06-09. Teardown leaves no billed volume behind.

## Local tooling installed (this machine)

- `~/.local/bin/kubectl` v1.36.1
- `~/.local/bin/helm` v3.16.4
- `hetzner-k3s` v2.5.0 (on PATH)
- `HCLOUD_TOKEN` sourced from gitignored `.local/.env` (never committed)

## Known gotchas (captured during P2-T2 bring-up)

- hetzner-k3s does **not** evaluate ERB — token comes from `HCLOUD_TOKEN` env, not the config.
- Worker pools use `location:` (string); only masters use `locations:` (list).
- `cx22` is deprecated → use `cpx22`.
- `~/.kube/` must exist before provisioning or the kubeconfig write fails.
- hetzner-k3s v2.5.0 deploys a `cluster-autoscaler` even when disabled; it
  CrashLoopBackOffs and was deleted post-provision (harmless).
- **No ingress controller installed.** hetzner-k3s did not bundle Traefik, so
  there is no ingress / LoadBalancer yet — external HTTP is only reachable via
  `kubectl port-forward`. Installing an ingress controller is P2-T4.

## Open decisions / waiting on

- Whether to build the Phase 1 Alaveteli container image before P2-T3, or
  scaffold manifests against a placeholder image first.
- P2-T2 close note in ROADMAP pending the session `/cost` figure.
