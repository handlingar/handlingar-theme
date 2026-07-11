<!--
  Keep this checklist; remove the italic guidance after you've addressed each item.
  See docs/WAYS-OF-WORKING.md and docs/decisions/0003-architectural-quality-gate.md.
-->

## Task

_Link the `docs/ROADMAP.md` task id this PR closes or advances, e.g. `P0-T1`._

## Summary

_One paragraph on the user-visible behaviour change._

## Architectural impact

- [ ] No change to accepted ADRs or `docs/invariants.md`.
- [ ] **OR** this PR adds/supersedes an ADR (link it) AND updates `docs/invariants.md` in the
      same commit set.

## Assumptions

_New assumptions made while preparing this change are appended to `docs/assumptions.md`._

## Docs

- [ ] `docs/ROADMAP.md`, `docs/RUNBOOK.md`, `docs/ARCHITECTURE.md` updated where relevant.
- [ ] If a task is closed: the `[x]` line carries a `> Closed YYYY-MM-DD by @<gh-handle> — ...`
      note on the next non-blank line.

## Secrets & privacy

- [ ] No cleartext secrets in the diff (values live in `secrets/<env>.enc.yaml` only).
- [ ] No real names, no email addresses outside allow-listed paths.

## Quality gate

- [ ] `bash scripts/quality-gate.sh` passes locally.
