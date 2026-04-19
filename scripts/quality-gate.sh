#!/usr/bin/env bash
# handlingar-theme — architectural quality gate.
#
# Usage:
#   scripts/quality-gate.sh                  # full, human-friendly; exit 1 on failure
#   scripts/quality-gate.sh --pre-push       # same strict behaviour, invoked by git hook
#   scripts/quality-gate.sh --ci             # strict, CI-friendly (no color unless forced)
#   scripts/quality-gate.sh --session-start  # informational; always exit 0
#
# See docs/decisions/0003-architectural-quality-gate.md for design and
# docs/invariants.md for the enforced invariants.

set -o pipefail
IFS=$'\n\t'

MODE=${1:-full}
ROOT=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
cd "$ROOT"

FAIL=0
WARN=0

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  R=$'\033[31m'; Y=$'\033[33m'; G=$'\033[32m'; B=$'\033[1m'; N=$'\033[0m'
else
  R=''; Y=''; G=''; B=''; N=''
fi

hdr()  { printf '\n%s%s%s\n' "$B" "$*" "$N"; }
pass() { printf '  %sOK%s   %s\n' "$G" "$N" "$*"; }
warn() { printf '  %sWARN%s %s\n' "$Y" "$N" "$*"; WARN=$((WARN + 1)); }
fail() { printf '  %sFAIL%s %s\n' "$R" "$N" "$*"; FAIL=$((FAIL + 1)); }

# Scan set = tracked + staged + untracked-not-ignored. Untracked files must be
# in scope so the gate catches violations in the commit that introduces them;
# a tracked-only scan couldn't self-flag a newly added script, which is how
# incident 2026-04-19 (personal name embedded in this script) slipped through.
FILES=$( { git ls-files --cached --others --exclude-standard 2>/dev/null; } \
  | grep -Ev '(^\.local/|^themes/|^rdbg/|^logs\.txt$|\.(png|jpe?g|gif|ico|pdf|mo|woff2?|ttf|eot|lock)$)' \
  | sort -u \
  || true)

scan() {
  [[ -z "$FILES" ]] && return 0
  printf '%s\n' "$FILES" | xargs -d '\n' -r grep "$@" 2>/dev/null || true
}

# Personal-identifier tokens are derived at runtime from local signals — never
# hard-coded in this script, which is public. Sources: current git identity,
# the system login, and authors of commits unique to this branch (commits
# between merge-base with main and HEAD). Full-history authors are NOT used —
# upstream contributors are legitimately credited in theme content and would
# cause false positives. Tokens <4 chars and common service/bot words are
# filtered out to keep false-positive rate low.
derive_personal_tokens() {
  local stop
  stop='^(claude|github|noreply|users|action|actions|bot|bots|dependabot|renovate'
  stop+='|handlingar|alaveteli|mysociety|example|gmail|outlook|hotmail|yahoo|icloud'
  stop+='|mail|info|admin|root|user|null|none|main|test|prod'
  stop+='|mark|make|made|this|that|with|from|have|were|will|your|into|when|then|than)$'
  local base
  base=$(git merge-base HEAD origin/main 2>/dev/null \
         || git merge-base HEAD main 2>/dev/null \
         || printf '')
  {
    git config user.name 2>/dev/null
    git config user.email 2>/dev/null
    if [[ -n "$base" ]]; then
      git log "${base}..HEAD" --format='%an%n%ae' 2>/dev/null
    fi
    printf '%s\n' "${USER:-$(id -un 2>/dev/null)}"
  } \
    | LC_ALL=C tr -cs 'A-Za-z0-9' '\n' \
    | tr '[:upper:]' '[:lower:]' \
    | awk 'length($0) >= 4' \
    | grep -Ev "$stop" \
    | sort -u
}

# ---------------------------------------------------------------- 1. Privacy
check_privacy() {
  hdr "[1/5] Privacy"
  local before_fail=$FAIL

  local tokens
  tokens=$(derive_personal_tokens)
  if [[ -n "$tokens" ]]; then
    local pat
    pat=$(printf '%s' "$tokens" | paste -sd'|' -)
    local names
    names=$(scan -HniE "\\b(${pat})\\b" || true)
    if [[ -n "$names" ]]; then
      fail "personal-identifier token(s) derived from git/env appear in committed or staged files (use GitHub handles)"
      printf '%s\n' "$names" | head -10 | sed 's/^/      /'
    fi
  else
    warn "no personal-identifier tokens could be derived (git identity + \$USER unavailable) — name check inert on this run"
  fi

  local emails
  emails=$(scan -HnE '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}' \
    | grep -vE '^(docs/decisions/|docs/assumptions\.md|docs/incidents\.md|\.github/|CLAUDE\.md|README\.md|docs/WAYS-OF-WORKING\.md|docs/RUNBOOK\.md)' \
    | grep -vE '(noreply@|@example\.(com|org)|@handlingar\.se|@mysociety\.|@alaveteli(theme)?\.org)' \
    | grep -vE '@[0-9]+x?\.(png|jpe?g|gif|webp|svg|ico)' \
    | grep -vE ':[0-9]+:[^@]*\bgit@github\.com:')
  if [[ -n "$emails" ]]; then
    fail "email addresses in committed files"
    printf '%s\n' "$emails" | head -10 | sed 's/^/      /'
  fi

  [[ $FAIL -eq $before_fail ]] && pass "no personal identifiers detected"
}

# ---------------------------------------------------------------- 2. Secrets
check_secrets() {
  hdr "[2/5] Secrets"
  local before_fail=$FAIL

  # This script is a detector and legitimately mentions what it detects
  # (PEM markers, token-shaped key names). Exempt it from the secrets scan;
  # normal code review is the compensating control for changes to the gate.
  local self='^scripts/quality-gate\.sh(:|$)'

  local pem
  pem=$( { scan -l -F 'BEGIN OPENSSH PRIVATE KEY'
           scan -l -F 'BEGIN RSA PRIVATE KEY'
           scan -l -F 'BEGIN EC PRIVATE KEY'
           scan -l -F 'BEGIN PRIVATE KEY'; } \
         | sort -u \
         | grep -Ev "$self" || true)
  if [[ -n "$pem" ]]; then
    fail "PEM private key block(s) in committed files"
    printf '%s\n' "$pem" | sed 's/^/      /'
  fi

  local ba
  ba=$(scan -HnE '://[^/[:space:]:]+:[^/@[:space:]]{6,}@' \
    | grep -vE '(postgres:password@|user:pass@|example\.(com|org))' \
    | grep -Ev "$self")
  if [[ -n "$ba" ]]; then
    fail "basic-auth URL(s) with embedded credentials"
    printf '%s\n' "$ba" | head -10 | sed 's/^/      /'
  fi

  local sk
  sk=$(scan -HnEi '(api[_-]?key|api[_-]?token|access[_-]?token|secret[_-]?key|incoming[_-]email[_-]secret|recaptcha[_-](private|secret)[_-]key|aws[_-](access|secret)[_-]key)[[:space:]]*[:=][[:space:]]*["'"'"'][A-Za-z0-9_/+.-]{16,}["'"'"']' \
    | grep -vE '(<redacted|<your|placeholder|example|\.sops\.yaml|changeme|x{8,})' \
    | grep -Ev "$self")
  if [[ -n "$sk" ]]; then
    fail "token-shaped secret assignment(s)"
    printf '%s\n' "$sk" | head -10 | sed 's/^/      /'
  fi

  [[ $FAIL -eq $before_fail ]] && pass "no plaintext secrets detected"
}

# -------------------------------------------------- 3. Architectural invariants
check_invariants() {
  hdr "[3/5] Architectural invariants"
  local inv=docs/invariants.md
  if [[ ! -f "$inv" ]]; then
    warn "docs/invariants.md missing — drift detection skipped"
    return
  fi

  local rows
  rows=$(awk '
    /^## Forbidden outside ADRs/ { flag = 1; next }
    /^## / { flag = 0 }
    flag && /^\| `/
  ' "$inv")

  if [[ -z "$rows" ]]; then
    warn "no forbidden patterns declared in $inv"
    return
  fi

  local allow_re
  allow_re=$(awk '
    /^## Allow-list/ { flag = 1; next }
    /^## / { flag = 0 }
    flag && /^- `/ {
      # strip only the leading "- " list marker and backticks; preserve
      # hyphens inside filenames (e.g. scripts/quality-gate.sh).
      sub(/^- /, "", $0)
      gsub(/`/, "", $0)
      sub(/^[[:space:]]+/, "")
      sub(/[[:space:]]+$/, "")
      if (length($0) > 0) {
        gsub(/\./, "\\.")
        gsub(/\*\*/, ".*")
        if (patterns) patterns = patterns "|" $0
        else patterns = $0
      }
    }
    END { print patterns }
  ' "$inv")
  [[ -z "$allow_re" ]] && allow_re='^$'

  local scan_set
  scan_set=$(printf '%s\n' "$FILES" | grep -Ev "^($allow_re)$" || true)
  if [[ -z "$scan_set" ]]; then
    pass "no files outside allow-list to scan"
    return
  fi

  local any=0
  while IFS='|' read -r _ pat_col _ gov_col _; do
    local pat
    pat=$(printf '%s' "$pat_col" | sed -E 's/^[[:space:]]*`([^`]+)`[[:space:]]*$/\1/')
    local gov
    gov=$(printf '%s' "$gov_col" | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
    [[ -z "$pat" ]] && continue
    local hits
    hits=$(printf '%s\n' "$scan_set" | xargs -d '\n' -r grep -HniE -- "$pat" 2>/dev/null || true)
    if [[ -n "$hits" ]]; then
      any=1
      fail "drift: /$pat/ (governed by $gov) appears outside allow-list"
      printf '%s\n' "$hits" | head -5 | sed 's/^/      /'
    fi
  done <<< "$rows"

  [[ $any -eq 0 ]] && pass "no drift from docs/invariants.md"
}

# -------------------------------------------------- 4. ROADMAP closed-note form
check_roadmap() {
  hdr "[4/5] ROADMAP integrity"
  local r=docs/ROADMAP.md
  if [[ ! -f "$r" ]]; then
    warn "docs/ROADMAP.md missing"
    return
  fi

  local bad
  bad=$(awk '
    /^- \[x\] \*\*P[0-9]+-T[0-9]+/ {
      task = $0; tn = NR; found = 0
      while ((getline nxt) > 0) {
        if (nxt ~ /^[[:space:]]*$/) continue
        if (nxt ~ /^> Closed [0-9]{4}-[0-9]{2}-[0-9]{2}/) { found = 1 }
        break
      }
      if (!found) print tn ": " task
    }
  ' "$r")

  if [[ -n "$bad" ]]; then
    fail "[x] tasks missing '> Closed YYYY-MM-DD ...' note on the next non-blank line"
    printf '%s\n' "$bad" | sed 's/^/      /'
  else
    pass "closed tasks are properly noted (or none yet)"
  fi
}

# -------------------------------------------------- 5. ADR integrity
check_adrs() {
  hdr "[5/5] ADR integrity"
  local before_fail=$FAIL
  shopt -s nullglob
  for adr in docs/decisions/*.md; do
    local miss=()
    grep -q '^- \*\*Status:\*\*' "$adr" || miss+=("Status")
    grep -q '^- \*\*Date:\*\*'   "$adr" || miss+=("Date")
    if (( ${#miss[@]} > 0 )); then
      fail "$adr missing fields: ${miss[*]}"
    fi
  done
  shopt -u nullglob
  [[ $FAIL -eq $before_fail ]] && pass "all ADRs carry Status and Date"
}

# -------------------------------------------------- session-start summary
session_summary() {
  hdr "handlingar-theme session state"
  printf '  branch:  %s\n' "$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo '?')"

  local phase
  phase=$(grep -m1 '^\*\*Active phase:\*\*' docs/ROADMAP.md 2>/dev/null | sed 's/\*\*//g')
  printf '  %s\n' "${phase:-Active phase: (unknown)}"

  local claims
  claims=$(grep -n '^> Claimed:' docs/ROADMAP.md 2>/dev/null || true)
  if [[ -n "$claims" ]]; then
    printf '  claimed tasks:\n'
    printf '%s\n' "$claims" | sed 's/^/    /'
  else
    printf '  claimed tasks: none\n'
  fi

  local aopen
  aopen=$(awk '/^## Open/{f=1;next} /^## /{f=0} f && /^- [0-9]{4}-[0-9]{2}-[0-9]{2}/' \
          docs/assumptions.md 2>/dev/null | wc -l | tr -d ' ')
  printf '  open assumptions: %s\n' "${aopen:-0}"

  local cutoff
  cutoff=$(date -d '45 days ago' +%Y-%m-%d 2>/dev/null \
           || date -v-45d +%Y-%m-%d 2>/dev/null \
           || echo '')
  if [[ -n "$cutoff" && -f docs/assumptions.md ]]; then
    local old
    old=$(awk -v c="$cutoff" '
      /^## Open/{f=1;next} /^## /{f=0}
      f && match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
        d = substr($0, RSTART, RLENGTH)
        if (d < c) print $0
      }' docs/assumptions.md)
    if [[ -n "$old" ]]; then
      printf '  %sassumptions older than 45 days (ratify or challenge):%s\n' "$Y" "$N"
      printf '%s\n' "$old" | sed 's/^/    /'
    fi
  fi

  # ---- Claude usage spend (requires ccusage; skipped if not installed)
  printf '\n'
  hdr "Claude usage (today)"
  if command -v ccusage >/dev/null 2>&1; then
    local usage_json
    usage_json=$(ccusage blocks --json 2>/dev/null)
    if [[ -n "$usage_json" ]]; then
      local total_cost active_pct burn_usd_hr
      total_cost=$(printf '%s' "$usage_json" | python3 -c "
import json,sys
blocks=json.load(sys.stdin).get('blocks',[])
total=sum(b.get('costUSD',0) for b in blocks)
print(f'\${total:.2f}')
" 2>/dev/null || echo '?')
      active_pct=$(printf '%s' "$usage_json" | python3 -c "
import json,sys
blocks=json.load(sys.stdin).get('blocks',[])
ab=next((b for b in blocks if b.get('isActive')),None)
if ab:
    limit=blocks[0].get('totalTokens',1) if blocks else 1
    pct=ab.get('totalTokens',0)/limit*100
    print(f'{pct:.0f}%')
" 2>/dev/null || echo '')
      burn_usd_hr=$(printf '%s' "$usage_json" | python3 -c "
import json,sys
blocks=json.load(sys.stdin).get('blocks',[])
ab=next((b for b in blocks if b.get('isActive')),None)
if ab and ab.get('burnRate'):
    print(f'\${ab[\"burnRate\"][\"costPerHour\"]:.2f}/hr')
" 2>/dev/null || echo '')

      printf '  spend today: %s' "$total_cost"
      [[ -n "$active_pct" ]] && printf '  |  active block: %s of limit' "$active_pct"
      [[ -n "$burn_usd_hr" ]] && printf '  |  burn rate: %s' "$burn_usd_hr"
      printf '\n'

      # Warn if today's spend already looks high for typical doc/config work
      local cost_num
      cost_num=$(printf '%s' "$total_cost" | tr -d '$')
      if awk "BEGIN{exit !($cost_num > 10)}"; then
        printf '  %sWARN%s spend >$10 today — check resource discipline before continuing:\n' "$Y" "$N"
        printf '       /fast for mechanical edits  |  /clear after each commit  |  narrow reads\n'
        printf '       (2026-04-19: $15.85 spent on 4 doc commits — do not repeat)\n'
      fi
    else
      printf '  ccusage available but returned no data\n'
    fi
  else
    printf '  %sccusage not installed%s — install with: npm i -g ccusage\n' "$Y" "$N"
  fi
}

# -------------------------------------------------- runner
case "$MODE" in
  --session-start)
    session_summary
    check_privacy
    check_secrets
    check_invariants
    check_roadmap
    check_adrs
    echo
    if (( FAIL > 0 )); then
      printf '  %squality gate would FAIL in strict mode%s — resolve before pushing.\n' "$R" "$N"
    else
      printf '  %squality gate OK%s (%d warnings)\n' "$G" "$N" "$WARN"
    fi
    exit 0
    ;;
  --pre-push | --ci | full | '')
    hdr "handlingar-theme quality gate"
    check_privacy
    check_secrets
    check_invariants
    check_roadmap
    check_adrs
    echo
    if (( FAIL > 0 )); then
      printf '%s%d check(s) failed%s, %d warning(s).\n' "$R" "$FAIL" "$N" "$WARN"
      echo "Resolve by (a) reverting the offending change, or (b) writing a superseding ADR"
      echo "under docs/decisions/ AND updating docs/invariants.md in the same PR."
      exit 1
    fi
    printf '%sAll checks passed%s (%d warnings).\n' "$G" "$N" "$WARN"
    exit 0
    ;;
  *)
    echo "Usage: $0 [--session-start|--pre-push|--ci]" >&2
    exit 2
    ;;
esac
