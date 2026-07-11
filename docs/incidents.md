# Incidents

A log of process- or tooling-level failures in this repository, the root cause,
and the mitigation that now guards against recurrence. Kept so that lessons
survive past the session and developer that discovered them.

Format per entry:

```
## YYYY-MM-DD — <short title>

**What happened.** <1–3 sentences, no blame.>

**Root cause.** <the mechanical reason, not the human one.>

**Mitigation.** <concrete change(s) made to the code/docs/process.>

**How we'll know if it recurs.** <what check or signal would fire.>
```

---

## 2026-04-19 — Personal name embedded in public gate script

**What happened.** The first version of `scripts/quality-gate.sh` detected
developer names by hard-coding them as a literal pattern on line 49. The
script is committed to a public repository, so the detector leaked exactly
the information it was meant to protect. The gate self-tested clean because
the script was still untracked when the test ran, and the scan set was
sourced from `git ls-files` (tracked files only).

**Root cause.** Two compounding mistakes:

1. A detector for private literals was written with those literals inline.
2. The scan set excluded untracked files, so the gate could not self-flag a
   violation in the change that introduced it.

**Mitigation.**

- `scripts/quality-gate.sh` now derives personal-identifier tokens at runtime
  via `derive_personal_tokens()` — from `git config user.name`,
  `git config user.email`, commit-author history, and `$USER`. No name
  literals in the script.
- The scan set is now `git ls-files --cached --others --exclude-standard`,
  so staged and untracked-not-ignored files are in scope. The script can
  flag itself.
- `.github/workflows/quality-gate.yml` sets `fetch-depth: 0` so the CI run
  sees full history and can derive author tokens the same way.
- `docs/WAYS-OF-WORKING.md` now carries a "Writing gate checks safely"
  subsection codifying both rules.

**How we'll know if it recurs.** Any future gate check that embeds a private
literal will, on first commit, be scanned by the gate itself (via the
widened scan set) and — if the literal matches a derived personal token —
fail the privacy check before the change can land.
