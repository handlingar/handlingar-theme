# BRIEFING — latest status

> Living "what are we doing right now" snapshot. Updated as work progresses so
> any contributor (or a cold Claude session) can see current state at a glance.
> Detailed task tracking lives in [ROADMAP.md](ROADMAP.md); this is the headline.

**Last updated:** 2026-06-09

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
- **NEXT SESSION — do this first:** full **cleanup and start from scratch** to prove the
  bring-up is truly reproducible from zero. Run `make cluster-down` (destroys cluster +
  postgres PVC), then `make bringup` (cluster + image build/import + app) and `make app-forward`
  to confirm a clean rebuild reaches a themed HTTP 200 with no manual steps. This is the
  one path not yet validated end-to-end (see "What I verified vs. didn't" history).
- **After that:** P2-T4 ingress (cert-manager + Traefik IngressRoute for `dev.handlingar.se`)
  so it's reachable without port-forward; then publish the image to a real registry and
  import to all workers (drop the worker1 pin).

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
