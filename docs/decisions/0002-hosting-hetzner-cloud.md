# ADR 0002 — Host on Hetzner Cloud

- **Status:** proposed
- **Date:** 2026-04-19
- **Supersedes:** —
- **Superseded by:** —

## Context

Handlingar.se currently runs on a Hetzner server (exact product and sizing to be confirmed in
Phase 0 inventory). We need to pick a hosting strategy for the IaC rebuild — same provider, or
migrate. Constraints:

- Small contributor base. Low tolerance for platform complexity.
- Small budget. Hetzner offers the lowest €/GB RAM / €/vCPU in the European VPS market.
- EU data residency is a plus for a Swedish FOI platform handling personal data.
- No need for managed services — we already run our own postgres, mail, cache on a box.
- Must support provisioning via well-supported Terraform provider.

## Decision

We will continue to host on **Hetzner Cloud** (or Hetzner Dedicated if inventory in Phase 0
reveals the current prod is dedicated and the workload justifies it — this ADR will be amended
or superseded once that fact is known).

Terraform provider: `hetznercloud/hcloud`.
Resources we'll manage in Terraform: servers, floating IPs, firewalls, DNS zones + records,
object storage buckets for backup.

## Alternatives considered

- **Status quo (manual, no IaC)** — rejected; the whole point of this project is to fix that.
- **OVH / Scaleway** — comparable EU pricing, but no existing operator familiarity; migration
  risk not worth marginal savings.
- **AWS / GCP / Azure** — rejected; cost and complexity are wrong for a small team running a
  single-box workload. Managed services we don't need. Vendor lock-in not desirable.
- **Self-hosted on-prem** — rejected; no existing infrastructure or ops capacity.
- **Kubernetes on Hetzner (k3s or Hetzner-managed k8s)** — rejected; adds an operational
  dimension (cluster ops) that dwarfs the workload. Single-box Ansible is simpler and covers
  current needs.

## Consequences

- **Positive:** minimal change from status quo; contributors already have Hetzner access.
- **Positive:** Terraform provider is mature and well-documented.
- **Positive:** low ongoing cost; tst and prod boxes together likely <€50/month.
- **Negative:** Hetzner outage is a single point of failure. Mitigation: off-site encrypted
  backups (Hetzner Object Storage or an alternative provider — TBD in a future ADR).
- **Negative:** Hetzner's managed DNS zone product is less featured than e.g. Cloudflare. If
  DNS features become a gap, we can split DNS off to a separate provider without affecting the
  server provisioning path.
- **Open:** Phase 0 inventory must confirm whether the current prod server is Cloud or
  Dedicated. If Dedicated, this ADR gets amended (same provider, different Terraform resource).
