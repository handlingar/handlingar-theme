# ADR 0006 — Ingress, automated DNS, and TLS (Traefik + Hetzner LB + cert-manager + external-dns)

- **Status:** accepted
- **Date:** 2026-06-10
- **Supersedes:** —
- **Superseded by:** —

## Context

P2-T4 requires the dev cluster's Alaveteli app to be reachable over HTTPS at a stable
hostname, with the certificate issued and renewed automatically and DNS managed
reproducibly from this repo (no manual record edits). Constraints:

- `hetzner-k3s` did **not** bundle an ingress controller, so there is none yet — only
  `kubectl port-forward` worked previously.
- `handlingar.se` is the **live production DNS zone** (managed in Cloudflare). Any
  automation that can write to it is high-blast-radius and must be provably unable to
  affect production records.
- The setup must be reproducible from zero (`make bringup`) and operable without tribal
  knowledge, per ADR 0004/0005.

## Decision

Expose the app via the following stack, all installed by `make ingress-up` (run as the
final step of `make bringup`) from committed manifests under `infra/k8s/ingress/`:

| Concern | Choice |
| --- | --- |
| Ingress controller | **Traefik** (Helm chart, pinned). Provides IngressRoute CRD + standard Ingress. |
| External entry point | Traefik `Service type=LoadBalancer` with `load-balancer.hetzner.cloud/*` annotations → a **managed Hetzner Cloud LB** (lb11, stable IPv4+IPv6, ~€5.4/mo). |
| Certificates | **cert-manager** with Let's Encrypt, **DNS-01 challenge via Cloudflare**. |
| DNS records | **external-dns** (Cloudflare provider) publishes the app host's A/AAAA records to the LB automatically. |
| Hostname convention | Non-prod environments live under **`*.nonprod.handlingar.se`**; this cluster is `dev.nonprod.handlingar.se`. |

### Why DNS-01 (not HTTP-01)

A Cloudflare API token is needed for external-dns anyway, so DNS-01 reuses it. DNS-01
works regardless of Cloudflare proxy status, does not depend on the LB being reachable on
:80 at challenge time, supports wildcards, and is the easiest to troubleshoot (inspect one
TXT record).

### Production-DNS safety (non-negotiable)

`handlingar.se` is shared with production, so external-dns is constrained so it **cannot**
touch prod records:

- `domainFilters: [nonprod.handlingar.se]` — only the non-prod subtree is visible to it.
- `registry: txt` + `txtOwnerId: handlingar-dev-k8s` + `txtPrefix: extdns-` — only manages
  records it owns; never adopts or deletes pre-existing (production) records.
- `policy: sync` — required so external-dns removes its own stale records (each rebuild gives the
  LB a fresh IP; `upsert-only` would accumulate stale A records and break resolution). Deletes are
  confined to the nonprod subtree + this owner's records, so production is never touched.
- The parent zone is selected explicitly via `--zone-id-filter` (the `handlingar.se` zone id,
  derived from the token at deploy time — there is no separate `nonprod.handlingar.se` zone, so a
  domain filter alone would match no zone). The LB's private IP is kept out of DNS via the Traefik
  `load-balancer.hetzner.cloud/disable-private-ingress` annotation.
- The Cloudflare token is scoped to Zone:Read + DNS:Edit on the `handlingar.se` zone only.

This is backed by the **change-control rule in `docs/invariants.md`**: the exact DNS record
set must be specified and approved before first apply, including records created indirectly
by controllers.

## Alternatives considered

- **k3s servicelb / klipper on a node's public IP** — free, but the IP is pinned to a node;
  if the worker is replaced the IP changes and DNS breaks. Rejected for fragility.
- **HTTP-01 challenge** — simpler conceptually but couples cert issuance to LB/:80
  reachability and Cloudflare proxy state. Rejected in favour of DNS-01 (token already present).
- **Manual / declarative-only DNS records** (no external-dns) — contradicts the "DNS managed
  reproducibly from the repo, no manual edits" requirement.
- **nginx-ingress** — viable, but Traefik is the K3s-native default and the task specified
  IngressRoute.

## Consequences

- A Hetzner LB now bills (~€5.4/mo) on top of the cluster while it exists; `make cluster-down`
  removes it with the cluster.
- `make bringup` / `make ingress-up` now require `CLOUDFLARE_API_TOKEN` in `.local/.env`
  (validated by `make preflight`).
- A new orphan-cleanup gap: as with the postgres CSI volume, verify the LB is removed on
  teardown (it is owned by the Service, so it is deleted when the cluster/Service is).
- Chart versions are pinned (`CERTMGR_VER`/`TRAEFIK_VER`/`EXTDNS_VER` in the Makefile);
  bumping them is a deliberate, reviewable change.
