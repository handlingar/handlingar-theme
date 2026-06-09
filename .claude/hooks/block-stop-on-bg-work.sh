#!/usr/bin/env bash
# Stop hook — status-visibility guardrail (repo-contained).
#
# Purpose: stop Claude from ending a turn SILENTLY while long-running work it
# started (image builds, image transfers to cluster nodes, cluster provisioning,
# rollout waits) is still in flight. If such work is running, this blocks the
# stop (exit 2) and feeds a reminder back to Claude to report status + ETA or
# actively poll to completion before yielding.
#
# Wired via .claude/settings.json (project scope) so it applies to every
# contributor working in this repo. Self-contained: process patterns are matched
# at runtime via pgrep. No secrets, hostnames, or project literals are baked in.
#
# Disable anytime via /hooks, or settings `disableAllHooks: true`.

set -euo pipefail

# Long-running operations whose completion the user must not be left waiting on
# in silence. Extend this list as new long ops appear.
PATTERN='(docker[[:space:]]+(build|buildx|save|load))'
PATTERN+='|(kubectl[[:space:]].*(rollout[[:space:]]+status|wait))'
PATTERN+='|(hetzner-k3s[[:space:]]+(create|delete))'
PATTERN+='|(ssh[[:space:]].*((k3s[[:space:]]+)?ctr|images)[[:space:]].*import)'

# Match running processes, excluding this hook itself.
matches=$(pgrep -af "$PATTERN" 2>/dev/null | grep -v 'block-stop-on-bg-work' || true)

# Nothing in flight → allow the stop.
[ -z "$matches" ] && exit 0

# Something is running → block and tell Claude to keep the user in the loop.
summary=$(printf '%s\n' "$matches" | sed 's/[[:space:]]\{2,\}/ /g' | cut -c1-110 | head -4)
{
  echo "STATUS-VISIBILITY GUARDRAIL — long-running background work you started is still in flight:"
  echo "$summary"
  echo
  echo "Do NOT end the turn in silence. Before yielding, either:"
  echo "  (a) give the user a concrete status update WITH an ETA, or"
  echo "  (b) actively poll the work to completion and report progress as it lands."
  echo "Then it is fine to stop once the work is done or the user has a clear picture."
} >&2
exit 2