# ADR 0004 — Use hetzner-k3s + K3s for cluster provisioning

- **Status:** accepted
- **Date:** 2026-06-09
- **Supersedes:** ADR 0002 (overrides the K8s-rejected alternative; Hetzner Cloud as provider remains)
- **Superseded by:** —

## Context

ADR 0002 rejected Kubernetes on the grounds that "it adds an operational dimension that dwarfs the
workload" and that single-box Ansible is simpler. That was a reasonable position for an unknown
workload on an unknown box.

After Phase 0 scoping we have a clearer picture:

- The platform needs reproducible dev, tst, and prod environments that are cheap to spin up and
  tear down.
- A dedicated K3s cluster tool ([hetzner-k3s](https://github.com/vitobotta/hetzner-k3s)) reduces
  the operational burden of running K8s on Hetzner Cloud to a single YAML config + one CLI
  command — it handles node provisioning, K3s install, CCM, CSI driver, and kubeconfig in one
  shot.
- The "Development" cluster type (1 master + 2 workers on `cx22` instances) costs roughly
  €17–22/month including the load balancer — comparable to or cheaper than the equivalent Ansible
  target for a dev box.
- Containerising the Alaveteli stack removes the rbenv/passenger/OS-level dependency tangle that
  makes Ansible roles brittle across OS upgrades.
- The local dev target (Phase 1) already uses Docker Compose; Kubernetes manifests share the same
  image artefacts, reducing divergence between local and deployed environments.

## Decision

We will provision all non-production environments using **hetzner-k3s** and **K3s** (lightweight
Kubernetes). Production will follow the same path once the dev cluster is validated, replacing the
original Terraform + Ansible plan.

Cluster types:

| Env | hetzner-k3s type | Masters | Workers | Est. cost |
| --- | --- | --- | --- | --- |
| `dev` | Development | 1 × cx23 | 2 × cx23 | ~€21/mo |
| `tst` | Development | 1 × cx23 | 2 × cx23 | ~€21/mo |
| `prod` | Small HA (future) | 3 × cx23 | 3 × cpx32 | TBD |

(`cx22` is deprecated; `cpx22` was used until 2026-07-03 but costs €19.49/mo —
3.5× more than `cx23` (€5.49/mo, same 2 vCPU / 4 GB x86 spec). Switched to
`cx23` to bring dev/tst cost back to ~€21/mo.)

Cluster configs live in `infra/hetzner-k3s/<env>-cluster.yaml`. The Hetzner API token is
injected at runtime via `HCLOUD_TOKEN`; no token is committed to the repo.

Application workloads will be deployed via Kubernetes manifests under `infra/k8s/` (initially
plain YAML; Helm or Kustomize if complexity warrants it).

K3s default ingress (Traefik) will be used initially. cert-manager handles Let's Encrypt TLS.
Hetzner CSI driver (bundled by hetzner-k3s) provides persistent volumes.

## Alternatives considered

- **Terraform + Ansible (original plan)** — rejected for dev cluster; the single-box Ansible
  approach requires maintaining OS-level dependency chains (rbenv, passenger, postfix) that
  containerisation removes. May still be used for any non-K8s ancillary resource (DNS, object
  storage).
- **Hetzner Managed Kubernetes (HKE)** — more expensive, less control over K3s version, and
  hetzner-k3s gives equivalent UX at lower cost.
- **k3d / kind locally, hetzner-k3s remotely** — viable for local dev but adds a second
  abstraction layer; Docker Compose (Phase 1) already covers the local case.
- **Stay single-box Ansible** — still valid for prod as a fallback if K8s operational overhead
  proves too high; this ADR is revisited after the dev cluster is running for 30 days.

## Consequences

- **Positive:** one-command cluster provision and teardown; easy to blow away and rebuild.
- **Positive:** environment parity: same container images run locally (Compose), on dev K8s, and
  on prod K8s.
- **Positive:** built-in HA path: upgrade dev → tst → prod cluster types without topology
  redesign.
- **Positive:** Hetzner CSI driver gives first-class persistent volumes; no manual disk
  management.
- **Negative:** K8s adds operational concepts (namespaces, services, ingress, PVCs) that
  contributors must understand. Mitigated by keeping manifests simple and well-documented.
- **Negative:** postfix + dovecot for inbound mail handling is awkward in K8s. Mitigation:
  inbound mail will run as a DaemonSet with `hostNetwork: true` on a dedicated node pool, or
  outsourced to an external relay (TBD in a follow-up ADR).
- **Negative:** K3s single master (Development type) is not HA. Acceptable for dev/tst; prod
  will use a 3-master cluster once validated.
- **Resolved (2026-06-09):** hetzner-k3s v2.5.0 (latest) uses the v2 config schema, which our
  `dev-cluster.yaml` now matches (masters use `locations:` list, workers use `location:` string;
  token via `HCLOUD_TOKEN` env, no ERB). `k3s_version` is pinned to `v1.32.4+k3s1`; confirm it
  still appears in `hetzner-k3s releases` at provision time and bump if not.
- **Open:** decide whether Terraform is still needed for DNS + object storage, or whether
  hetzner-k3s + manual Hetzner console covers those for now.