#!/usr/bin/env bash
# Preflight for cluster work. Installs missing local tools and validates that
# everything needed to provision/deploy is in place — so deploys don't fail
# halfway. Safe to run repeatedly. Called automatically by `make cluster-up`
# and `make deploy`; you can also run it directly: `make preflight`.
#
# It NEVER prints your Hetzner token. If something is missing it tells you
# exactly what to do in plain language.
set -euo pipefail

BIN="$HOME/.local/bin"
KUBECONFIG_PATH="$HOME/.kube/handlingar-dev.yaml"
TOKEN_FILE=".local/.env"   # single local secrets file (template: .local/.env.example)
HELM_VERSION="v3.16.4"
ok()   { printf '  \033[32mOK\033[0m    %s\n' "$1"; }
add()  { printf '  \033[36mFIX\033[0m   %s\n' "$1"; }
warn() { printf '  \033[33mWARN\033[0m  %s\n' "$1"; }
die()  { printf '\n\033[31mPreflight stopped:\033[0m %s\n' "$1"; exit 1; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$1"; }

export PATH="$BIN:$PATH"
mkdir -p "$BIN" "$(dirname "$KUBECONFIG_PATH")"

hdr "Local tools"

# kubectl
if command -v kubectl >/dev/null 2>&1; then
  ok "kubectl present ($(kubectl version --client 2>/dev/null | head -1 | awk '{print $NF}'))"
else
  add "installing kubectl..."
  KV="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  curl -fsSL "https://dl.k8s.io/release/${KV}/bin/linux/amd64/kubectl" -o "$BIN/kubectl"
  chmod +x "$BIN/kubectl"
  ok "kubectl ${KV} installed"
fi

# helm
if command -v helm >/dev/null 2>&1; then
  ok "helm present"
else
  add "installing helm ${HELM_VERSION}..."
  tmp="$(mktemp -d)"
  curl -fsSL "https://get.helm.sh/helm-${HELM_VERSION}-linux-amd64.tar.gz" -o "$tmp/h.tgz"
  tar -xzf "$tmp/h.tgz" -C "$tmp"
  mv "$tmp/linux-amd64/helm" "$BIN/helm"
  rm -rf "$tmp"
  ok "helm ${HELM_VERSION} installed"
fi

# hetzner-k3s
if command -v hetzner-k3s >/dev/null 2>&1; then
  ok "hetzner-k3s present ($(hetzner-k3s --version 2>&1 | head -1))"
else
  add "installing hetzner-k3s..."
  LATEST="$(curl -fsSL https://api.github.com/repos/vitobotta/hetzner-k3s/releases/latest | grep -o '\"tag_name\": \"[^\"]*' | cut -d'\"' -f4)"
  curl -fsSL "https://github.com/vitobotta/hetzner-k3s/releases/download/${LATEST}/hetzner-k3s-linux-amd64" -o "$BIN/hetzner-k3s"
  chmod +x "$BIN/hetzner-k3s"
  ok "hetzner-k3s ${LATEST} installed"
fi

hdr "SSH key (for cluster nodes)"
if [[ -f "$HOME/.ssh/id_ed25519" && -f "$HOME/.ssh/id_ed25519.pub" ]]; then
  ok "ed25519 key present"
else
  add "generating ~/.ssh/id_ed25519 (no passphrase, for node access)..."
  ssh-keygen -t ed25519 -N "" -f "$HOME/.ssh/id_ed25519" >/dev/null
  ok "ed25519 key generated"
fi

hdr "Hetzner Cloud API token"
if [[ ! -f "$TOKEN_FILE" ]]; then
  die "$TOKEN_FILE not found — this is the single local secrets file.
  Create it from the tracked template, then fill in your values (it is NOT
  committed to git; see .local/.env.example for every value and where to get it):
      cp .local/.env.example $TOKEN_FILE
      \$EDITOR $TOKEN_FILE        # set HCLOUD_TOKEN (Hetzner Cloud -> Security -> API tokens)
  Then re-run this."
fi
# shellcheck disable=SC1090
set -a; . "$TOKEN_FILE"; set +a
[[ -n "${HCLOUD_TOKEN:-}" ]] || die "$TOKEN_FILE exists but HCLOUD_TOKEN is empty."
code="$(curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer $HCLOUD_TOKEN" https://api.hetzner.cloud/v1/server_types)"
case "$code" in
  200) ok "Hetzner token valid (API reachable)";;
  401|403) die "Hetzner token rejected (HTTP $code). Generate a fresh Read&Write *Cloud* API token (64 chars) and rewrite $TOKEN_FILE.";;
  000) die "No network route to api.hetzner.cloud — check connectivity.";;
  *) die "Unexpected Hetzner API status $code.";;
esac

hdr "Cloudflare API token (for ingress DNS + TLS)"
if [[ -z "${CLOUDFLARE_API_TOKEN:-}" ]]; then
  warn "CLOUDFLARE_API_TOKEN not set in $TOKEN_FILE.
  Not needed for 'make cluster-up', but REQUIRED by 'make ingress-up' / 'make bringup'
  (Traefik + cert-manager + external-dns). See .local/.env.example for how to create it
  (Cloudflare -> API Tokens -> Edit zone DNS, scoped to handlingar.se)."
else
  cf="$(curl -s -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" https://api.cloudflare.com/client/v4/user/tokens/verify)"
  if grep -q '"status":"active"' <<<"$cf"; then
    ok "Cloudflare token valid (active)"
  else
    die "Cloudflare token rejected. Recreate it (Edit zone DNS, zone handlingar.se) and rewrite $TOKEN_FILE."
  fi
fi

printf '\n\033[32mPreflight passed.\033[0m All prerequisites are in place.\n'
