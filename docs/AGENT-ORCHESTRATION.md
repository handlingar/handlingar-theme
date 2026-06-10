# AGENT-ORCHESTRATION — cost-efficient parallel AI agents on this repo

> Operating manual for running parallel Claude agents on this project without
> burning the token budget. Extends
> [WAYS-OF-WORKING § Parallel-agent protocol](WAYS-OF-WORKING.md#parallel-agent-protocol).
> Grounded in published practice from large-scale multi-agent systems
> (orchestrator-worker pattern; token cost scales linearly with agent count;
> the two levers that dominate cost are *scoping before spawning* and
> *model tiering per task*).

## The economics (why these rules exist)

1. **Every agent starts cold.** It re-reads CLAUDE.md, re-derives context, and
   its full report is re-read by the orchestrator. A spawned agent costs
   roughly (its own session) + (its report in the main context). Multiply
   expected solo cost by the parallelism factor, then add overhead — that's
   the bill.
2. **Parallelism buys wall-clock time, never tokens.** Spawn agents to get four
   streams done in one evening, not to "save" — it always costs more tokens
   than one focused session doing the work serially.
3. **The orchestrator's context is the scarcest resource.** Everything an agent
   returns lands there. Verbose agent reports kill the session that has to
   integrate them.

## The protocol (mandatory)

### Before spawning — the orchestrator's checklist

- **Scope first, spawn second.** The orchestrator does all discovery (which
  files, which make targets, what done-looks-like) BEFORE fan-out. An agent
  prompt that says "investigate and fix X" is a token bonfire; "edit files A,B
  to do Y, verify with Z" is a contract.
- **Write the handoff file** (`.local/SESSION-HANDOFF.md`): shared state every
  agent needs, ≤40 lines. Then `/clear` the main session.
- **One stream = one agent = one file-ownership set.** No two agents may touch
  the same file. If two streams need the same file, they are one stream.
- **3–4 agents max** per fan-out. More than that and integration cost
  dominates the savings.

### The agent prompt template

Every spawned agent gets exactly this shape (tight, self-contained):

```
CONTEXT: read CLAUDE.md + .local/SESSION-HANDOFF.md only. Do NOT read other
docs or explore beyond your file set.
TASK: <one task, concrete, with done-criteria>
OWNS (only files you may create/edit): <explicit list/globs>
VERIFY: <exact command(s) that must pass, e.g. make smoke, curl check>
REPORT (final message, machine-readable, ≤30 lines):
  STATUS: done|blocked
  CHANGED: <file: one-line summary, per file>
  VERIFIED: <command → result>
  BLOCKED-ON / ASSUMPTIONS: <only if any>
Do not commit. Do not run the quality gate. Do not update ROADMAP/BRIEFING.
```

### Model tiering

- Mechanical / well-specified streams (manifest edits, Helm chart wiring,
  Makefile targets, doc moves): run the agent on a **cheaper/faster tier**.
- Reasoning-heavy streams (debugging unknown failures, ADR drafting,
  architecture): **default tier**, or keep in the main session entirely.
- ADRs and anything needing user approval stay in the **main session** — they
  block on a human anyway, so a parallel agent just idles expensively.

### After fan-out — integration (main session only)

1. Read agent reports (not their diffs — trust VERIFY, spot-check one file per
   agent at most).
2. Run `bash scripts/quality-gate.sh` once, fix integration seams.
3. Run the cross-stream verify (`make smoke` / R10 checks) once.
4. **One commit** (or one commit per stream if they're separable), one
   BRIEFING/ROADMAP update, written by the orchestrator — never by agents.

### Kill criteria

Abort an agent (and do its task in the main session later) when:
- its report says `blocked` on anything another stream owns,
- it asks a question (the prompt was under-specified — that's an orchestrator
  bug, fix the prompt next time),
- it wants to expand its file ownership.

## When NOT to parallelize

- **Long-running infra commands** (`make bringup`, cluster-down): one session,
  command in the background, near-zero tokens while it runs. P2-T8 is this
  shape — it is a SOLO session, not a fan-out.
- Tasks under ~30 min of solo work — fan-out overhead exceeds the work.
- Anything touching DNS/base-infra or needing approval mid-flight
  (invariants.md): approvals serialize on the human, so parallel agents stall.

## Current stream map (after P2-T8 + P2-T9 land)

Pre-scoped fan-out, disjoint by construction — an orchestrator session can
lift this directly into agent prompts:

| Stream | Task | Owns | Tier |
| --- | --- | --- | --- |
| A | Observability stack (P6, new leaning: kube-prometheus-stack + Loki + Alloy via Helm) | `infra/k8s/observability/`, new `make obs-*` targets (Makefile section of its own) | cheap |
| B | Production-mode hardening (P2-T10) | `Dockerfile`, `infra/k8s/base/alaveteli.yaml`, `infra/k8s/base/configmap.yaml` | default |
| C | Scheduled jobs as k8s CronJobs (backlog → task) | `infra/k8s/jobs/` | cheap |
| D | CI/CD build+push+deploy (P4-T1/T2, needs P2-T9 registry first) | `.github/workflows/` | default |

Sequencing: A and C can run any time. B before D is merged (D deploys what B
defines). ADRs for A and D are written in the main session first.

## Next-session kickoff (P2-T8 — solo, do this before any fan-out)

Paste-ready plan; budget ≈ one short session, most of it waiting:

1. `make cluster-down` (destroys cluster — confirm billing stops via `make status` afterwards).
2. `make bringup` **in the background**, timed. Target: ~25 min cold. While it
   runs, do nothing token-heavy.
3. `make mock-data` → `make smoke` → RUNBOOK R10 checks → `make mail-ingest` loop check.
4. Verify: `https://dev.nonprod.handlingar.se` 200 + valid LE cert; `/body`
   lists 5 authorities in **both** sv and en; body search returns hits;
   Mailpit at `make mail-ui`.
5. Record: actual cold-bringup time + any manual step needed (each one is a
   defect — file it in ROADMAP).
6. Quality gate → commit → propose to close P2-T8 (and P2-T4 if /cost supplied).
