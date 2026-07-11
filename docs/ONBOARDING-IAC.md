# Onboarding — learning infrastructure as code on this repo

Audience: a developer on this project who wants to actually understand the IaC (not just run
`make bringup` and trust it). Read this after the [README.md](../README.md) first-time setup
and [CLAUDE.md](../CLAUDE.md) — this is the "go one level deeper" doc.

It does not replace [ARCHITECTURE.md](ARCHITECTURE.md), [WAYS-OF-WORKING.md](WAYS-OF-WORKING.md),
or the ADRs under [decisions/](decisions/) — it's a guided path *through* them, in an order that
builds understanding instead of dumping everything at once.

## Why this repo is a decent place to learn IaC

Everything that defines the platform is checked into git and applied by explicit commands —
nothing is hand-configured on a server. That's the core IaC idea: **if it's not in the repo, it
isn't real** (see ARCHITECTURE.md principle 3). You can read the whole system by reading files,
and you can safely experiment because every environment can be torn down and rebuilt from the
same recipe.

## Step 0 — vocabulary you'll hit immediately

You don't need to know these deeply yet, just recognise them:

- **Hetzner Cloud** — the cloud provider hosting everything (like AWS/GCP, smaller/cheaper).
- **hetzner-k3s** — a CLI that provisions a Kubernetes cluster on Hetzner from one YAML file.
- **K3s** — a lightweight Kubernetes distribution (same concepts as full K8s, smaller footprint).
- **Kubernetes (K8s)** — orchestrates containers: you describe *desired state* (e.g. "run 1 copy
  of this container"), and the cluster continuously makes reality match it.
- **kubectl** — the CLI for talking to a running K8s cluster.
- **Manifest** — a YAML file describing a K8s object (Deployment, Service, etc).
- **ADR (Architecture Decision Record)** — a short document under `docs/decisions/` explaining a
  decision, why it was made, and what alternatives were rejected. Read these instead of asking
  "why is it built this way?" — the answer is usually already written down.

## Step 1 — run it before you read it

Don't start by reading Kubernetes manifests cold. Start by running the thing and watching what
happens:

```bash
cp .local/.env.example .local/.env   # fill in HCLOUD_TOKEN — ask a teammate for a project invite
make preflight                       # installs/verifies tools, validates the token
make bringup                         # full zero-to-running build — take ~15-20 min, watch the output
make status                          # see what's running and what it costs
```

While `make bringup` runs, open [README.md](../README.md) and match each `make` target it prints
to the step happening in your terminal. Then:

```bash
make cluster-down                    # tear it all down — confirm nothing is left billing
make orphans                         # should be empty after cluster-down
```

Doing a full up → down cycle once is worth more than reading ten pages of docs. It also proves
the core IaC promise to yourself: the environment is disposable and reproducible.

## Step 2 — read the docs in this order

1. [ARCHITECTURE.md](ARCHITECTURE.md) — the target-state picture. Skim the topology diagram
   first; don't try to memorise it.
2. [ADR 0004](decisions/0004-kubernetes-hetzner-k3s.md) — why Kubernetes/hetzner-k3s was chosen
   over Terraform+Ansible. This is the most important ADR to understand — it's the foundation
   everything else sits on.
3. [ADR 0005](decisions/0005-reproducible-non-person-dependent-setup.md) — why the repo insists
   nothing depends on a specific person's laptop state.
4. [ADR 0006](decisions/0006-ingress-dns-tls.md) — how a request reaches the app (DNS → Traefik →
   TLS → Rails).
5. [RUNBOOK.md](RUNBOOK.md) — operational procedures. Skim, don't memorise; come back when you
   need to actually do one of these.
6. [WAYS-OF-WORKING.md](WAYS-OF-WORKING.md) — the human↔Claude collaboration protocol. Relevant
   even if you're not driving Claude yourself, since task claims / ADRs / the quality gate shape
   how changes land in this repo.

## Step 3 — trace one real change end-to-end

Pick something small and concrete and follow it through every layer:

- `infra/hetzner-k3s/dev-cluster.yaml` — defines the cluster shape (node count, size, region).
  This is the *only* file `hetzner-k3s create` reads.
- `infra/k8s/base/` — the Kubernetes manifests for the app itself (Deployments, Services,
  ConfigMaps). This is what `kubectl apply -k` reads.
- `infra/k8s/ingress/` — how traffic gets routed in from the internet (Traefik, cert-manager).
- `infra/resources.tsv` — the declarative registry of *every* cloud resource this stack is
  allowed to know about. If a resource isn't listed here, the tooling is provably blind to it
  (this is also what keeps `make` commands from ever touching the prod server — see the
  Phase 2 P2-T8 note in [ROADMAP.md](ROADMAP.md) for why that mattered).
- `Makefile` — the glue. Every `make <target>` is a short, readable recipe over the above. Read
  `make bringup`'s recipe line by line; it's intentionally kept simple.

Good exercise: change one value in `infra/k8s/base/` (e.g. a resource limit), run
`make deploy`, and watch `kubectl get pods -n handlingar` show the rollout. Then revert it.

## Step 4 — how work actually lands here (process, not just tech)

- [ROADMAP.md](ROADMAP.md) is the single source of truth for "what are we doing right now."
  Tasks are `P<phase>-T<n>`; pick an open `[ ]` one under the *active* phase.
- Claim a task by adding a `> Claimed: branch \`feat/<id>-<slug>\` ...` line under it (see
  WAYS-OF-WORKING.md § Roadmap discipline) before you start — this is how two people avoid
  colliding on the same task.
- Any non-trivial decision gets an ADR *before or alongside* the code change, not after.
- `bash scripts/quality-gate.sh` is the automated check for drift (privacy, secrets,
  architectural invariants, ADR hygiene). Run it before you consider a task done.
- Don't push to `main` directly — open a PR from your feature branch.

## Step 5 — where to go deeper

- Kubernetes concepts in general (not this repo): the [official K8s concepts
  docs](https://kubernetes.io/docs/concepts/) are the standard reference — read "Pods",
  "Deployments", "Services", and "ConfigMaps and Secrets" first; skip the rest until you need it.
- hetzner-k3s specifics: its own [GitHub README](https://github.com/vitobotta/hetzner-k3s) covers
  the config schema this repo's `infra/hetzner-k3s/*.yaml` files use.
- Ask in the repo, not in your own head: if something in the manifests looks arbitrary, check
  `docs/decisions/` and `docs/assumptions.md` first — there's a good chance it's already answered
  and dated.

## What "done learning" looks like

You can pick an open `[ ]` task from the active ROADMAP.md phase, claim it, make the change,
run the quality gate, and open a PR — without needing to ask "how does this repo work?" first.
You'll still ask *what's the right design here* sometimes, same as anyone; that's normal and
what ADRs + PR review are for.
