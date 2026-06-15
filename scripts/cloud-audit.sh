#!/usr/bin/env bash
# Inventory + teardown gate for the cloud resources THIS STACK deploys.
#
# Discovery is driven entirely by the registry in infra/resources.tsv (the single
# source of truth for what we deploy). Each row says how to identify OUR resources
# — by Hetzner label selector, exact name, or Cloudflare nonprod-suffix. Resources
# NOT in the registry (e.g. the production server that shares this Hetzner project)
# are never queried and never appear. Add a registry line to manage something new.
#
# Why this exists: `hetzner-k3s delete` only removes what it created; the
# in-cluster cloud-controller-manager (Load Balancer) and external-dns (DNS) leave
# resources behind that kept billing while a teardown reported "nothing to clean".
#
# Usage:
#   scripts/cloud-audit.sh                 # list our resources (standardized table)
#   scripts/cloud-audit.sh --assert-empty  # exit non-zero if ANY remain — the
#                                           # final gate of `make cluster-down`.
#
# Tokens are read from the environment and NEVER printed.
set -euo pipefail

ASSERT=0
[ "${1:-}" = "--assert-empty" ] && ASSERT=1
REGISTRY="${REGISTRY:-infra/resources.tsv}"
[ -f "$REGISTRY" ] || { echo "registry not found: $REGISTRY" >&2; exit 2; }

command -v hcloud >/dev/null 2>&1 || { echo "hcloud not found — run 'make preflight'." >&2; exit 2; }
[ -n "${HCLOUD_TOKEN:-}" ] || { echo "HCLOUD_TOKEN not set — fill in .local/.env." >&2; exit 2; }
export HCLOUD_TOKEN

# Print rows "name<TAB>id<TAB>detail" for the resources a registry line matches.
# Foreign resources are excluded at the source (label selector / exact name /
# nonprod suffix), so nothing outside this stack is ever emitted.
match_rows() {
  local provider="$1" type="$2" match_by="$3" val="$4"
  case "$provider:$match_by" in
    hetzner:label)
      hcloud "$type" list -l "$val" -o json 2>/dev/null | py_hetzner ;;
    hetzner:name)
      hcloud "$type" list -o json 2>/dev/null | NAME="$val" py_hetzner ;;
    cloudflare:suffix)
      cf_records "$val" ;;
    *) echo "unknown match rule: $provider:$match_by" >&2; return 1 ;;
  esac
}

# Hetzner JSON -> name/id/detail. If NAME is set, keep only that exact name.
py_hetzner() {
  python3 -c '
import sys, json, os
want=os.environ.get("NAME")
for x in json.load(sys.stdin):
    if want and x.get("name")!=want: continue
    d = x.get("status") \
        or x.get("public_net",{}).get("ipv4",{}).get("ip") \
        or ((str(x.get("size"))+"GB") if x.get("size") else "")
    print(x.get("name",""), x.get("id",""), d, sep="\t")'
}

# Cloudflare records whose name ends with the nonprod suffix (prod zone untouched).
cf_records() {
  local suffix="$1"
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo -e "(token unset)\t-\tDNS audit skipped"; return; }
  local cf zid
  cf() { curl -sf -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "$@"; }
  zid="$(cf "https://api.cloudflare.com/client/v4/zones?name=handlingar.se" \
    | python3 -c 'import sys,json; z=json.load(sys.stdin).get("result",[]); print(z[0]["id"] if z else "")')"
  [ -n "$zid" ] || { echo "could not resolve handlingar.se zone id" >&2; return 1; }
  cf "https://api.cloudflare.com/client/v4/zones/$zid/dns_records?per_page=200" \
    | SUFFIX="$suffix" python3 -c '
import sys, json, os
suffix=os.environ["SUFFIX"]
for r in json.load(sys.stdin).get("result",[]):
    if r["name"].endswith(suffix):
        print(r["name"], r["id"], r["type"], sep="\t")'
}

printf '\n\033[1m%-14s %-38s %-12s %s\033[0m\n' "TYPE" "NAME" "ID" "DETAIL"
count=0
while IFS='|' read -r provider type match_by val _cleaned; do
  case "$provider" in ''|'#'*|provider) continue ;; esac   # skip comments/blank/header
  while IFS=$'\t' read -r name id detail || [ -n "$name" ]; do
    [ -n "$name" ] || continue
    printf '%-14s %-38s %-12s %s\n' "$type" "$name" "$id" "$detail"
    count=$((count+1))
  done < <(match_rows "$provider" "$type" "$match_by" "$val")
done < "$REGISTRY"

printf '\n%s resource(s) managed by this stack are currently deployed.\n' "$count"
if [ "$ASSERT" = "1" ]; then
  if [ "$count" -eq 0 ]; then
    printf '\033[32mTEARDOWN VERIFIED CLEAN — no resources from this stack remain.\033[0m\n'
  else
    printf '\033[31mTEARDOWN INCOMPLETE — the resources above still exist (and may bill).\033[0m\n'
    printf 'Run \033[1mmake orphans-clean\033[0m, then re-run \033[1mmake cloud-audit\033[0m.\n'
    exit 1
  fi
fi
