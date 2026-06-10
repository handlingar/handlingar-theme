# Ingress + automated DNS + TLS (P2-T4)

Everything here is applied by **`make ingress-up`** (idempotent) and is also run as
the final step of **`make bringup`**, so a from-zero rebuild reproduces the full
HTTPS stack with no manual steps. Governed by [ADR 0006](../../../docs/decisions/0006-ingress-dns-tls.md).

## What gets installed

| Component | Chart / kind | Role |
| --- | --- | --- |
| **Traefik** | Helm `traefik/traefik` | Ingress controller. Its `Service` is `type=LoadBalancer` with `load-balancer.hetzner.cloud/*` annotations → a managed **Hetzner Cloud LB** (stable public IPv4+IPv6, ~€5.4/mo). |
| **cert-manager** | Helm `jetstack/cert-manager` | Issues/renews TLS certs. |
| **external-dns** | Helm `external-dns/external-dns` | Publishes the `dev.nonprod.handlingar.se` A/AAAA records to Cloudflare, pointing at the LB. |
| ClusterIssuers | `clusterissuer-{staging,prod}.yaml` | Let's Encrypt via **DNS-01 / Cloudflare**. |
| Certificate | `certificate.yaml` | `alaveteli-tls` Secret for `dev.nonprod.handlingar.se`. |
| IngressRoute | `ingressroute.yaml` | Routes the host to the `alaveteli` Service; terminates TLS. |

## DNS safety (handlingar.se is the live production zone)

external-dns is locked down so it can never affect production DNS:

- `domainFilters: [nonprod.handlingar.se]` — only the non-prod subtree is visible to it.
- `registry: txt` + `txtOwnerId` + `txtPrefix: extdns-` — only manages records it owns; never
  adopts or deletes pre-existing (e.g. production) records.
- `policy: sync` — keeps records in lockstep with the cluster, INCLUDING removing its own stale
  records (each teardown/rebuild gives the LB a new IP; upsert-only would pile up stale A records).
  Deletes are confined to the nonprod subtree + this owner's records, so prod is never at risk.
- The parent zone `handlingar.se` is selected by `--zone-id-filter` (derived from the token at
  deploy time by `make ingress-up`); the LB's private IP is kept out of DNS via the Traefik
  Service annotation `load-balancer.hetzner.cloud/disable-private-ingress`.

Per [docs/invariants.md](../../../docs/invariants.md) (Change-control rules), the exact
record set external-dns / cert-manager will create is specified and approved before
first apply. For this host that set is:

```
A     dev.nonprod.handlingar.se          -> <Traefik LB IPv4>
AAAA  dev.nonprod.handlingar.se          -> <Traefik LB IPv6>
TXT   extdns-*.dev.nonprod.handlingar.se -> external-dns ownership metadata
TXT   _acme-challenge.dev.nonprod.handlingar.se -> transient, created+deleted by cert-manager
```

## Prerequisite

`CLOUDFLARE_API_TOKEN` in `.local/.env` (gitignored) — scoped to Zone:Read + DNS:Edit
on the `handlingar.se` zone. See `.local/.env.example`. `make ingress-secret` turns it
into the `cloudflare-api-token` Secret in both the `cert-manager` and `external-dns`
namespaces.

## Troubleshooting

```bash
make ingress-status                                   # LB IP, cert readiness, DNS resolution
kubectl -n external-dns logs deploy/external-dns -f   # every DNS record operation
kubectl -n handlingar describe certificate alaveteli-tls
kubectl -n handlingar get challenges,orders -A        # in-flight ACME challenges
kubectl -n traefik get svc traefik -o wide            # the LB's external IPs
```
