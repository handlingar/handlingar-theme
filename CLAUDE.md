# CLAUDE.md — Entry brief for Claude Code

This repository is the Swedish theme overlay for [Alaveteli](https://github.com/mysociety/alaveteli),
powering [handlingar.se](https://handlingar.se). We are evolving it into the full IaC + deployment
home for the platform (Hetzner, GH Actions CI/CD, dev/tst/prod envs).

**Read this file first. Then read [docs/ROADMAP.md](docs/ROADMAP.md) to know what we're working on
right now.** Open other docs only when the task calls for them.

## Session start (run every time)

Before touching any file, run the advisory quality gate:

```
bash scripts/quality-gate.sh --session-start
```

It prints the current branch, the active phase, any `Claimed:` tasks, open-assumption count,
assumptions older than 45 days, and an overall PASS/FAIL line. If the gate reports a FAIL, stop
and investigate before layering new work on top of pre-existing drift.

## How this documentation is organised

| File | When to open |
| --- | --- |
| [docs/ROADMAP.md](docs/ROADMAP.md) | Every session. Current phase, task list, handoff notes. |
| [docs/WAYS-OF-WORKING.md](docs/WAYS-OF-WORKING.md) | First session on this repo, or when the human↔Claude protocol is unclear. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | When touching deploy, infra, env topology, or tooling choice. |
| [docs/RUNBOOK.md](docs/RUNBOOK.md) | When executing or writing operational procedures (deploy, rollback, rebuild). |
| [docs/INVENTORY.md](docs/INVENTORY.md) | When Phase 0 work requires facts about the live prod server. |
| [docs/decisions/](docs/decisions/) | When considering or recording an architectural decision (ADR). |
| [docs/assumptions.md](docs/assumptions.md) | Whenever you're about to make an assumption — read first, then append. |
| [docs/invariants.md](docs/invariants.md) | When touching anything near tooling / hosting / infra; or when the quality gate flags drift. |

## Working protocol (short form)

1. **Session start**: read this file + `docs/ROADMAP.md`, then run the session-start quality gate
   above. Don't pre-load the rest.
2. **One task at a time**: pick the next `[ ]` task under the active phase in `ROADMAP.md`. If unclear,
   ask the developer which.
3. **Task close**: when you believe a task is done, say *"Propose to close task `<id>`"* and
   ask the developer to run `/cost` so the session usage can be captured in the close note.
   On approval, edit `ROADMAP.md` to mark `[x]` and add a one-line completion note with the
   date + the `/cost` figure (format in WAYS-OF-WORKING).
4. **New decision?** Write a new ADR under `docs/decisions/NNNN-title.md` before/alongside the code change.
5. **Making an assumption?** Append one line to `docs/assumptions.md` with today's date.
6. **Stopping mid-task**: offer to write a short handoff paragraph into `ROADMAP.md`'s "In progress" section
   so the next session (possibly a different developer) can resume cold.

Full protocol + rationale lives in [docs/WAYS-OF-WORKING.md](docs/WAYS-OF-WORKING.md).

## Resource discipline

Claude usage on this project is cost-capped. Responsibility is split:

- **Claude self-manages** per-session spend by default: tight replies, narrow reads, aggressive
  `/clear` between tasks.
- **Developers flag** when usage feels excessive ("that cost too much", "slow down on reads").
  Claude recalibrates immediately — no argument.

Working rules (non-negotiable):

- **`/clear` between tasks.** State persists in `docs/ROADMAP.md` + branch, not in chat history.
  One task → one session → commit → clear. Don't continue a long session into a new task.
- **`/fast` (Opus 4.6) for routine mechanical edits.** Save default Opus for architecture,
  tricky debugging, unfamiliar code paths.
- **Narrow reads.** `offset`/`limit` on `Read`, specific `Grep` patterns. Never read a whole
  file when a region suffices.
- **No re-reads** of files already loaded this session — Edit/Write track state.
- **Subagents only** for genuinely parallel work or open-ended research (>3 search rounds).
  They start cold and re-derive context; every delegation has a real cost.
- **Terse replies.** One-sentence end-of-turn. No diff recap. Structure only when the task
  needs it.

See [docs/WAYS-OF-WORKING.md § Provider division of labour](docs/WAYS-OF-WORKING.md#provider-division-of-labour)
for when other LLMs beat Claude Code for a given sub-task.

## Repo layout (current)

```
.github/workflows/deploy.yaml   # SSH-based theme deploy (to be replaced with proper CI/CD)
docker-compose.yml              # Local dev stack (postgres + redis + app) — incomplete
Dockerfile                      # App image for local dev
setup.sh, run.sh                # Local dev bootstrap + run
themes/                         # Populated at dev-setup time from alaveteli repo
lib/, app/, locale-theme/       # Theme source (views, locale overrides, etc.)
general.yml, database.yml       # Example Alaveteli configs (reference, not deployed as-is)
docs/                           # This project's design, roadmap, runbooks, ADRs
```

Infra-as-code (`infra/`, `ansible/`, etc.) will appear in Phase 2.

## Before proposing to close a task

Run `bash scripts/quality-gate.sh` (full mode) and confirm it passes. If it fails, resolve
before closing — either revert the offending change, or add a superseding ADR under
`docs/decisions/` and update `docs/invariants.md` in the same PR. See
[docs/WAYS-OF-WORKING.md](docs/WAYS-OF-WORKING.md#quality-gate-automated-drift-detection).

## Don't do without asking

- Don't SSH to the production server or run commands there.
- Don't modify secrets or GH Actions variables.
- Don't push to `main`. Open a PR from the current feature branch.
- Don't delete `themes/` or anything under `.local/` — they're gitignored dev state.
- Don't add dependencies, CI jobs, or tooling not already in the active phase of the roadmap.
