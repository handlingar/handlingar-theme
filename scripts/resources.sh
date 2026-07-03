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
#   scripts/resources.sh                 # list our resources (standardized table)
#   scripts/resources.sh --assert-empty  # exit non-zero if ANY remain — the
#                                         # final gate of `make cluster-down`.
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

# Hetzner JSON -> name/id/detail/cost. If NAME is set, keep only that exact name.
# Cost is the resource's own price from the API (server/LB types embed their
# price list; volumes are size × the per-GB price fetched once below). Resources
# Hetzner doesn't charge for (network, firewall, ssh-key) print "free".
py_hetzner() {
  python3 -c '
import sys, json, os
want=os.environ.get("NAME")
vol_gb=float(os.environ.get("VOL_GB_EUR") or 0)
def cost(x):
    prices, loc = None, None
    if x.get("server_type"):
        prices=x["server_type"].get("prices") or []
        loc=((x.get("datacenter") or {}).get("location") or {}).get("name")
    elif x.get("load_balancer_type"):
        prices=x["load_balancer_type"].get("prices") or []
        loc=(x.get("location") or {}).get("name")
    elif x.get("size"):
        return x["size"]*vol_gb
    if prices:
        for p in prices:
            if p.get("location")==loc:
                return float(p["price_monthly"]["gross"])
        return float(prices[0]["price_monthly"]["gross"])
    return 0.0
for x in json.load(sys.stdin):
    if want and x.get("name")!=want: continue
    d = x.get("status") \
        or x.get("public_net",{}).get("ipv4",{}).get("ip") \
        or ((str(x.get("size"))+"GB") if x.get("size") else "") \
        or "-"
    try: c=cost(x)
    except Exception: c=-1          # never lose a row to a pricing surprise
    label = "?" if c<0 else ("%.2f"%c if c else "free")
    print(x.get("name",""), x.get("id",""), d, label, sep="\t")'
}

# Cloudflare records whose name ends with the nonprod suffix (prod zone untouched).
cf_records() {
  local suffix="$1"
  [ -n "${CLOUDFLARE_API_TOKEN:-}" ] || { echo -e "(token unset)\t-\tDNS audit skipped\t-"; return; }
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
        print(r["name"], r["id"], r["type"], "free", sep="\t")'
}

# Per-GB volume price, fetched once from the pricing API (volumes don't embed
# their price). On any failure costs fall back to 0 — the audit still works.
VOL_GB_EUR="$(curl -sf -H "Authorization: Bearer $HCLOUD_TOKEN" \
  https://api.hetzner.cloud/v1/pricing 2>/dev/null \
  | python3 -c 'import sys,json; print(json.load(sys.stdin)["pricing"]["volume"]["price_per_gb_month"]["gross"])' \
  2>/dev/null || echo 0)"
export VOL_GB_EUR

printf '\n\033[1m%-14s %-38s %-34s %-12s %s\033[0m\n' "TYPE" "NAME" "ID" "DETAIL" "COST €/mo"
count=0
total=0
while IFS='|' read -r provider type match_by val _cleaned; do
  case "$provider" in ''|'#'*|provider) continue ;; esac   # skip comments/blank/header
  while IFS=$'\t' read -r name id detail cost || [ -n "$name" ]; do
    [ -n "$name" ] || continue
    printf '%-14s %-38s %-34s %-12s %s\n' "$type" "$name" "$id" "$detail" "${cost:-?}"
    case "$cost" in ''|free|-) ;; *) total="$(awk -v t="$total" -v c="$cost" 'BEGIN{printf "%.2f", t+c}')" ;; esac
    count=$((count+1))
  done < <(match_rows "$provider" "$type" "$match_by" "$val")
done < "$REGISTRY"

printf '\n%s resource(s) managed by this stack are currently deployed.\n' "$count"
if [ "$count" -gt 0 ]; then
  printf '\033[1mTotal: ≈ €%s/month while deployed\033[0m (prices incl. VAT, live from the provider API).\n' "$total"
fi
if [ "$ASSERT" = "1" ]; then
  if [ "$count" -eq 0 ]; then
    printf '\033[32mTEARDOWN VERIFIED CLEAN — no resources from this stack remain.\033[0m\n'
  else
    printf '\033[31mTEARDOWN INCOMPLETE — the resources above still exist (and may bill).\033[0m\n'
    printf 'Run \033[1mmake orphans-clean\033[0m, then re-run \033[1mmake resources\033[0m.\n'
    exit 1
  fi
fi
