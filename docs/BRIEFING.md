# BRIEFING — latest status

> Living "what are we doing right now" snapshot. Updated as work progresses so
> any contributor (or a cold Claude session) can see current state at a glance.
> Detailed task tracking lives in [ROADMAP.md](ROADMAP.md); this is the headline.

**Last updated:** 2026-06-09

## Right now

- **Active work:** Phase 2 — IaC baseline (K3s on Hetzner).
- **Just finished:** P2-T2 — the **dev K3s cluster is live** on Hetzner Cloud.
- **Next up:** P2-T3 — base K8s manifests under `infra/k8s/base/` (blocked on the
  Phase 1 container image; will scaffold against a placeholder if we proceed first).

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

## Local tooling installed (this machine)

- `~/.local/bin/kubectl` v1.36.1
- `~/.local/bin/helm` v3.16.4
- `hetzner-k3s` v2.5.0 (on PATH)
- `HCLOUD_TOKEN` sourced from gitignored `.local/hcloud.env` (never committed)

## Known gotchas (captured during P2-T2 bring-up)

- hetzner-k3s does **not** evaluate ERB — token comes from `HCLOUD_TOKEN` env, not the config.
- Worker pools use `location:` (string); only masters use `locations:` (list).
- `cx22` is deprecated → use `cpx22`.
- `~/.kube/` must exist before provisioning or the kubeconfig write fails.
- hetzner-k3s v2.5.0 deploys a `cluster-autoscaler` even when disabled; it
  CrashLoopBackOffs and was deleted post-provision (harmless).

## Open decisions / waiting on

- Whether to build the Phase 1 Alaveteli container image before P2-T3, or
  scaffold manifests against a placeholder image first.
- P2-T2 close note in ROADMAP pending the session `/cost` figure.
