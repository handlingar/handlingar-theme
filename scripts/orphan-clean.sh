#!/usr/bin/env bash
# Clean up the cloud resources that `hetzner-k3s delete` leaves behind.
#
# A cluster teardown removes servers, the private network, the firewall and the
# SSH key — but NOT the resources created from *inside* the cluster by the
# hcloud cloud-controller-manager and external-dns:
#
#   - the managed Hetzner Load Balancer (named $LB_NAME) that fronts Traefik, and
#   - the Cloudflare DNS records external-dns published for $APP_HOST
#     (the A + AAAA records, plus its "extdns-*" TXT ownership records).
#
# Both keep costing money / pointing at dead IPs after a teardown. This script
# finds and removes exactly those, and nothing else. It is idempotent: a clean
# account is a no-op, and it never touches a record outside the nonprod subtree.
#
# Usage:
#   scripts/orphan-clean.sh            # LIST what would be cleaned (default, read-only)
#   scripts/orphan-clean.sh --clean    # actually delete the orphans
#   scripts/orphan-clean.sh --clean --force   # delete even if a cluster is live
#
# SAFETY: by default it REFUSES to clean while a cluster is up (servers named
# "$LB_NAME-*" exist), because deleting the LB/DNS of a running cluster would
# break ingress. `make cluster-down` calls it after the servers are gone, so the
# guard is transparent there. Tokens are read from the environment and NEVER
# printed (HCLOUD_TOKEN for Hetzner, CLOUDFLARE_API_TOKEN for Cloudflare).
set -euo pipefail

MODE="list"        # list | clean
FORCE=0
for arg in "$@"; do
  case "$arg" in
    --clean) MODE="clean" ;;
    --list)  MODE="list" ;;
    --force) FORCE=1 ;;
    *) echo "unknown arg: $arg" >&2; exit 2 ;;
  esac
done

# Inputs (with the same defaults the Makefile uses, so the script also runs
# stand-alone). The cluster/LB name comes from the Traefik LB annotation and the
# hetzner-k3s server-name prefix — both are "$LB_NAME".
LB_NAME="${LB_NAME:-handlingar-dev}"
APP_HOST="${APP_HOST:-dev.nonprod.handlingar.se}"
NONPROD_SUFFIX="nonprod.handlingar.se"   # hard safety boundary — never delete outside this

ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
act()  { printf '  \033[36m%s\033[0m %s\n' "$2" "$1"; }   # $2 = verb (FOUND/DELETED)
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; }
die()  { printf '\n\033[31morphan-clean stopped:\033[0m %s\n' "$1"; exit 1; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

command -v hcloud >/dev/null 2>&1 || die "hcloud CLI not found — run 'make preflight' to install it."
[ -n "${HCLOUD_TOKEN:-}" ] || die "HCLOUD_TOKEN not set — fill in .local/.env (see .local/.env.example)."
export HCLOUD_TOKEN   # hcloud reads this natively; we never pass it on the command line

# --- Safety guard: is a cluster live? --------------------------------------
live_servers="$(hcloud server list -o noheader -o columns=name 2>/dev/null | grep -c "^${LB_NAME}-" || true)"
if [ "${live_servers:-0}" -gt 0 ]; then
  if [ "$MODE" = "clean" ] && [ "$FORCE" -eq 0 ]; then
    die "$live_servers server(s) named '${LB_NAME}-*' are still up — a cluster is live.
  Refusing to delete its LB/DNS (that would break ingress). Run 'make cluster-down'
  first, or pass --force if you really mean it."
  fi
  [ "$MODE" = "list" ] && warn "$live_servers '${LB_NAME}-*' server(s) live — a cluster appears to be up."
fi

# --- 1) Orphaned Hetzner Load Balancer -------------------------------------
hdr "Hetzner Load Balancer ($LB_NAME)"
lb_id="$(hcloud load-balancer list -o noheader -o columns=id,name 2>/dev/null | awk -v n="$LB_NAME" '$2==n {print $1}')"
if [ -z "$lb_id" ]; then
  ok "no load balancer named '$LB_NAME' — nothing to clean."
else
  if [ "$MODE" = "clean" ]; then
    hcloud load-balancer delete "$lb_id" >/dev/null && act "$LB_NAME (id $lb_id)" "DELETED"
  else
    act "$LB_NAME (id $lb_id)" "FOUND  "
  fi
fi

# --- 2) Orphaned Cloudflare DNS records ------------------------------------
# external-dns publishes: A + AAAA at $APP_HOST, and TXT ownership records named
# "extdns-*$APP_HOST". We list every record in the zone whose name is $APP_HOST
# (A/AAAA) or an "extdns-" prefixed TXT for it, restricted to the nonprod subtree.
hdr "Cloudflare DNS records ($APP_HOST)"
if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
  warn "CLOUDFLARE_API_TOKEN not set — skipping DNS cleanup (set it in .local/.env to enable)."
else
  cf() { curl -sf -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" -H "Content-Type: application/json" "$@"; }
  zone_id="$(cf "https://api.cloudflare.com/client/v4/zones?name=handlingar.se" \
    | python3 -c 'import sys,json; z=json.load(sys.stdin).get("result",[]); print(z[0]["id"] if z else "")')"
  [ -n "$zone_id" ] || die "could not resolve the handlingar.se zone id from Cloudflare (token scope?)."

  # Pull all records, filter in python to exactly our names, inside the nonprod subtree.
  recs="$(cf "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records?per_page=200" \
    | APP_HOST="$APP_HOST" SUFFIX="$NONPROD_SUFFIX" python3 -c '
import sys, json, os
host=os.environ["APP_HOST"]; suffix=os.environ["SUFFIX"]
for r in json.load(sys.stdin).get("result",[]):
    name=r["name"]; t=r["type"]
    if not name.endswith(suffix):      # hard boundary: never outside nonprod subtree
        continue
    is_app_addr = (name==host and t in ("A","AAAA"))
    is_extdns_txt = (t=="TXT" and name.startswith("extdns-") and name.endswith(host))
    if is_app_addr or is_extdns_txt:
        print(r["id"], t, name)
')"
  if [ -z "$recs" ]; then
    ok "no managed records for '$APP_HOST' — nothing to clean."
  else
    while read -r id type name; do
      [ -n "$id" ] || continue
      if [ "$MODE" = "clean" ]; then
        cf -X DELETE "https://api.cloudflare.com/client/v4/zones/$zone_id/dns_records/$id" >/dev/null \
          && act "$type $name" "DELETED" \
          || warn "delete failed for $type $name (id $id) — check the Cloudflare dashboard."
      else
        act "$type $name" "FOUND  "
      fi
    done <<< "$recs"
  fi
fi

if [ "$MODE" = "list" ]; then
  printf '\nThis was a read-only listing. Re-run with --clean to delete the items above.\n'
else
  printf '\n\033[32mOrphan cleanup complete.\033[0m\n'
fi
