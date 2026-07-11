# Ways of working — Human ↔ Claude protocol

This document defines how developers on the Handlingar.se platform collaborate with Claude Code
in this repository. Goal: predictable, token-efficient, resumable work across sessions,
developers, and parallel branches — without relying on Claude's conversation history.

## Source of truth

- **Permanent state** lives in `docs/` (roadmap, architecture, ADRs, runbook, assumptions) and in
  the code itself.
- **Conversation state** is volatile. A new session must be able to continue the work with only
  `CLAUDE.md` + `docs/ROADMAP.md` in context.

If a fact matters tomorrow, it belongs in a doc or an ADR, not in a chat reply.

## Parallel developer model

Multiple contributors work on this repo concurrently, each potentially running their own Claude
Code session. Coordination happens through git and `docs/ROADMAP.md`, not through a live channel.

- **Feature branches** are named `feat/<phase-task-id>-<slug>`, e.g. `feat/p0-t1-os-inventory`.
- **Task claim** is an inline note under the task in `ROADMAP.md` on the claiming branch, of the form:
  ```
  > Claimed: branch `feat/p0-t1-os-inventory` since 2026-04-19 by @<gh-handle> — <status>
  ```
  Use GitHub handles (already public via commit history), not real names.
- **Different tasks → different paragraphs → clean merges.** Each task's notes are self-contained,
  so two developers working on different tasks won't conflict on `ROADMAP.md`.
- **Same-task collaboration** (rare) happens on the same feature branch — not by both creating
  parallel branches against the same task.
- **Stale claims:** if a claim is >14 days old with no commits, any developer may take over the
  task. Update the inline note with the new claimant and rebase the branch or start fresh.

## Session lifecycle

### Start of session

1. Claude loads `CLAUDE.md` (automatic) and reads `docs/ROADMAP.md`.
2. Claude checks the current git branch. If it's `main`, ask the developer which task they want
   to work on before doing anything — they likely want to branch.
3. On a feature branch, Claude identifies the corresponding task id from the branch name, and
   reads its inline notes.
4. If the task is ambiguous or the branch doesn't map to a task, Claude asks before acting.
5. Claude does **not** pre-load `ARCHITECTURE.md`, `RUNBOOK.md`, etc. unless the task requires it.

### During work

- Make small, reviewable changes. Prefer one concern per commit.
- If Claude needs to make an assumption to proceed, state it plainly and append one line to
  `docs/assumptions.md` with today's date. Assumptions are reviewed periodically by the team.
- If a decision affects architecture, secrets, infra topology, env layout, or tooling choice:
  write or update an ADR in `docs/decisions/` *before* the code change lands.
- Never push to `main`. Work on a feature branch and open a PR.
- Never run commands on the production server without explicit per-session approval. Even
  read-only inventory scripts require go-ahead.

### Feedback from the developer mid-task (authoritative)

Developers do NOT pre-review large scaffolding up front. Feedback arrives *during* task work:
corrections, preferences, clarifications. When this happens:

1. Treat the correction as authoritative for this task and all future work.
2. If the guidance is likely to recur across tasks/sessions (e.g. "redact secrets in any prod
   tooling"), propose saving it to Claude memory on the spot: *"Save this as feedback memory so
   future sessions apply it?"*
3. If the guidance invalidates earlier scope in the current task, update the inline task notes
   and the PR description rather than silently adjusting.
4. Never argue a correction down to save work already done. Undo and redo if needed.

### Task closure

1. Claude says: **"Propose to close task `<id>` — summary: \<one sentence\>. Please share
   `/cost` output so I can log session usage."**
2. The developer replies yes/no (or asks for adjustments), and pastes the `/cost` line.
3. On approval, in the same response, Claude:
   - marks the task `[x]` in `ROADMAP.md`
   - replaces the inline `> Claimed:` line with
     `> Closed YYYY-MM-DD by @<gh-handle> — <1 sentence outcome + PR or commit SHA> (usage: <N msgs / $X>)`
   - announces the next candidate task if the developer wants to continue.

The `(usage: ...)` line lets the team see per-task cost over time in git history, which is
our mechanical backstop against silent overruns (see § Resource discipline and the statusline
setup in the README).

### End of session / handoff

When a developer is about to stop mid-task, Claude updates the **inline note** under that task
with a handoff paragraph. No global "In progress" section exists — handoff stays scoped to its
task, which avoids cross-branch merge conflicts.

Example inline handoff:

```
> Claimed: branch `feat/p0-t1-os-inventory` since 2026-04-19 by @<gh-handle> — in progress
> Handoff 2026-04-21: OS package list captured; apt-mark holds next. Blocker: need confirmation
> that `systemd-timers` replaced `cron` on the box. Next step: re-run collector with --systemd
> flag. Files touched: scripts/inventory/os.sh, docs/INVENTORY.md §A.
```

This replaces the need to read Claude's conversation history next time.

## Decision-making — ADRs

We use lightweight Architecture Decision Records. One file per decision, under `docs/decisions/`.

- Filename: `NNNN-short-slug.md` (zero-padded, monotonic).
- Status field: `proposed | accepted | superseded by NNNN | deprecated`.
- Draft ADRs are allowed — mark as `proposed` and link from the relevant roadmap task.
- Never silently change an accepted ADR. Supersede it with a new one.

See `docs/decisions/0001-record-architecture-decisions.md` for the template.

## Roadmap discipline

- `docs/ROADMAP.md` has **phases** (large chunks) and **tasks** (atomic units).
- Each task has an id like `P2-T3` (Phase 2, Task 3).
- Tasks fit in one working session (≤3h) where possible. If larger, split.
- Only one phase is "active" at a time. Future phases are sketches and may be reordered.
- New ideas go under the `## Backlog` heading in `ROADMAP.md`, not in random files.
- Inline task notes (claim / handoff / closed) live directly under the task line. Nothing global.

## Secret masking (hard rule)

Any script, tool, or command we design for inspecting the production server **must mask secrets
programmatically** before output can reach a Claude session. Developers will paste inventory and
log output into Claude for analysis; unredacted pastes leak into transcript + telemetry.

- Redaction is a mandatory component of any prod-facing tool, not an afterthought.
- Target patterns: PEM blocks, tokens, API keys, passwords, basic-auth URLs, known-secret config
  keys (e.g. Alaveteli `INCOMING_EMAIL_SECRET`, reCAPTCHA keys, mail creds).
- Replace matches with a stable placeholder (hash-derived) so same-value-twice is still
  detectable without leaking the value.
- The tool prints a redaction summary (counts by pattern) for sanity-checking.
- Never propose "grep it yourself and paste clean" — the tool does the redaction.

## Resource discipline

Claude usage on this project is cost-capped. `CLAUDE.md § Resource discipline` carries the
per-session rules (tight replies, `/clear` between tasks, `/fast` for mechanical edits, narrow
reads, subagents only when genuinely parallel). What follows is the shared responsibility model
and the provider-choice guidance that Claude Code alone can't encode.

### Responsibility model

- **Claude** manages per-session spend by default. It applies the rules above, calibrates tool
  calls to the task, and keeps replies short.
- **Developers** flag when usage feels excessive — *"that cost too much", "slow down on reads",
  "use fast for this"*. Flagging is expected and not a complaint. Claude recalibrates
  immediately.
- **Neither side pre-negotiates every turn.** If something gets out of hand, the developer says
  so; Claude adjusts. That loop is the control system.

### Parallel-agent protocol

When a task genuinely splits into independent streams (proven on 2026-06-11: four parallel
streams in commit `9cffa97`), use subagents — but keep them token-cheap:

1. Write a short handoff file with the shared state agents need, then `/clear` the main session.
2. Fan out with **tight prompts** and **disjoint file ownership** — no two agents may touch the
   same file.
3. Agents return **machine-readable reports** (what changed, what was verified), not prose.
4. The **main session alone** integrates the results, runs the quality gate, and commits once.

Keep agents few and cheap; every delegation starts cold and re-derives context.

The full operating manual — economics, prompt template, model tiering, kill criteria, and the
current pre-scoped stream map — lives in [AGENT-ORCHESTRATION.md](AGENT-ORCHESTRATION.md).

### Provider division of labour

Claude Code is the only AI that touches this repository directly — it has the `CLAUDE.md` entry
brief, the private memory system, the skills, and the quality-gate integration. Other providers
(Gemini, ChatGPT, local models) feed it context but do not modify files.

| Task | Best tool | Why |
| --- | --- | --- |
| Code changes, commits, ADRs in this repo | Claude Code | In-context memory, gate, repo knowledge. |
| Reading long upstream Alaveteli source / vendor docs | Gemini | Large context window, cheap. |
| Brainstorming / drafting before bringing a plan in | Whatever's fastest | No repo state needed. |
| Swedish ↔ English translation for locale work | Any general LLM | No repo state needed. |
| Ops reasoning on already-masked inventory output | Claude Code | Session continuity. |

Rule of thumb: **Claude Code touches this repo; other tools feed it context.** Switching
providers mid-edit costs more context than it saves.

### Intensity-variable days

- **Short day (≤2h):** one focused task end-to-end, commit, done.
- **Long day (up to ~10h):** multiple tasks, each on its own feature branch + ROADMAP claim,
  with `/clear` between them. Continuity comes from the repo, not from a conversation history
  that grew for hours.

## Privacy (public-repository hygiene)

This repository is public. Committed files must not contain:

- Real names or email addresses of contributors (use GitHub handles instead).
- Internal team size, roles, or organisational detail.
- Pasted output from production unless secret-masked per the rule above.
- Domain-internal hostnames, IPs, or paths beyond what is already in the deploy workflow.

Private context (identities, team dynamics, subscription specifics) lives in Claude's private
memory directory, which is not part of this repo.

## Quality gate (automated drift detection)

`scripts/quality-gate.sh` is the mechanical backstop for the conventions in this document. It
enforces hygiene and architectural invariants so nothing relies on contributor vigilance alone.

### When it runs

| Trigger | Mode | Blocking? |
| --- | --- | --- |
| Session start (instruction in `CLAUDE.md`) | `--session-start` | No — advisory. |
| `git push` (via `.githooks/pre-push`) | `--pre-push` | Yes. |
| Pull request + push to `main` (via `.github/workflows/quality-gate.yml`) | `--ci` | Yes, required check. |
| Weekly sweep at 06:27 UTC Mondays (same workflow) | `--ci` | Surfaces drift that predates the gate. |

### What it checks

1. **Privacy** — no real names (detected via tokens *derived at runtime* from `git config`
   identity, commit-author history, and `$USER` — never embedded in the script); no email
   addresses in committed files outside allow-listed paths.
2. **Secrets** — no PEM private-key blocks, no basic-auth URLs with credentials, no token-shaped
   assignments to known secret config keys.
3. **Architectural drift** — every pattern in `docs/invariants.md` (Forbidden outside ADRs table)
   must not appear outside the allow-list in the same file.
4. **ROADMAP integrity** — every `[x]` closed task carries a `> Closed YYYY-MM-DD ...` note.
5. **ADR integrity** — every ADR has `Status:` and `Date:` fields.

### What to do when the gate fails

Do not edit around the gate. Pick one:

- **Revert** the change that tripped the check, or
- **Supersede** the architectural decision properly: write a new ADR under `docs/decisions/`,
  update `docs/invariants.md`, and include both in the same PR.

### One-time local install

```bash
git config core.hooksPath .githooks
```

### Before proposing to close a task

Claude runs the full gate in addition to these content checks:

1. **Scoped changes only** — no drive-by refactors, no unrelated cleanup.
2. **No production reach-outs** — no SSH commands to prod, no live DB migrations, unless the
   task explicitly authorised it for this session.
3. **Docs updated** — any behaviour-visible change has a corresponding ROADMAP / RUNBOOK / ADR
   edit.
4. **Idempotence** — if the change is a deploy/provisioning step, running it twice must be safe.
5. **Assumptions logged** — anything assumed is in `docs/assumptions.md`.
6. **`scripts/quality-gate.sh` passes** — it subsumes privacy, secrets, drift, and roadmap/ADR
   integrity mechanically.

If any check fails, Claude says so and does not propose closure.

### Evolving the gate

- **New invariant** → add a row to `docs/invariants.md` when the ADR that rejects it is accepted.
- **Relaxing an invariant** → write a superseding ADR, then edit the row.
- **New check in the script itself** → accompanies an ADR that establishes a new kind of
  invariant. Rare.
- **Allow-list entries** are conservative defeats of the gate; prefer rewriting the offending
  file to comply.

### Writing gate checks safely

Two rules — both motivated by concrete failures logged in `docs/incidents.md`:

1. **Never embed a private literal inside a public detector.** If the gate scans for a name,
   host, key fingerprint, or similar, the literal must come from an *external* runtime source
   (git identity, environment, file outside the repo) — never from a string in
   `scripts/quality-gate.sh`. Writing the literal into the detector leaks it into the public
   repo, defeating the purpose of the check.
2. **Scan what will be committed, not just what was.** Use `git ls-files --cached --others
   --exclude-standard` so newly-added files are in scope. A tracked-only scan is blind to the
   diff that first introduces a violation.

## Onboarding another developer

A new developer with their own Claude Pro subscription should be able to:

1. Clone the repo, read `README.md` and `CLAUDE.md`.
2. Open a Claude Code session. Claude reads `CLAUDE.md` + `ROADMAP.md` automatically.
3. Run the local dev quickstart from `README.md`.
4. Pick the next `[ ]` task under the active phase (one not already `Claimed:`) and continue.

No Claude conversation history, no Slack archaeology, no tribal knowledge required.

New to infrastructure as code specifically (not just this repo)? Work through
[docs/ONBOARDING-IAC.md](ONBOARDING-IAC.md) first — it's a guided path through steps 1-3 above
plus the ADRs, aimed at building understanding rather than just getting unblocked.
