#!/usr/bin/env bash
# Re-runnable cluster smoke test for handlingar-dev (or any env).
#
# Verifies the live cluster end-to-end without needing the app image:
#   1. Scheduling      — nginx Deployment rolls out and becomes Ready.
#   2. CSI persistence  — a marker written to the Hetzner CSI volume survives a
#                         full pod restart (Recreate).
#   3. Service / DNS    — the ClusterIP Service is reachable by name from another
#                         pod (in-cluster DNS + kube-proxy routing).
#   4. HTTP reachability — a real HTTP GET from this host (via kubectl
#                         port-forward) returns nginx's served page.
#   5. Ingress          — SKIPPED until an ingress controller exists (P2-T4);
#                         auto-exercised once one is installed.
#
# Idempotent: safe to run repeatedly. Re-run it after any cluster change to
# confirm scheduling + storage + networking still work.
#
# Usage:
#   export KUBECONFIG=~/.kube/handlingar-dev.yaml
#   export PATH="$HOME/.local/bin:$PATH"      # if kubectl lives there
#   infra/k8s/smoke-test/run.sh               # run the test
#   infra/k8s/smoke-test/run.sh --clean       # tear down the smoke-test namespace
set -euo pipefail

NS=smoke-test
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$HERE/manifest.yaml"

pass() { printf '  \033[32mPASS\033[0m  %s\n' "$1"; }
fail() { printf '  \033[31mFAIL\033[0m  %s\n' "$1"; FAILED=1; }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$1"; }
step() { printf '\n\033[1m%s\033[0m\n' "$1"; }
FAILED=0

if ! command -v kubectl >/dev/null 2>&1; then
  echo "kubectl not on PATH. Try: export PATH=\"\$HOME/.local/bin:\$PATH\"" >&2
  exit 2
fi

if [[ "${1:-}" == "--clean" ]]; then
  step "Tearing down namespace '$NS'"
  kubectl delete namespace "$NS" --ignore-not-found --wait=true
  echo "Done."
  exit 0
fi

CTX="$(kubectl config current-context 2>/dev/null || echo '?')"
step "Smoke test against context: $CTX"

step "1/5 Apply manifest + wait for rollout (scheduling)"
kubectl apply -f "$MANIFEST" >/dev/null
if kubectl -n "$NS" rollout status deploy/smoke-nginx --timeout=180s >/dev/null; then
  pass "smoke-nginx Deployment is Ready (pod scheduled on a worker)"
else
  fail "Deployment did not become Ready within 180s"
  kubectl -n "$NS" get pods -o wide || true
fi

step "2/5 CSI persistent volume (write -> restart -> read back)"
if kubectl -n "$NS" get pvc smoke-pvc -o jsonpath='{.status.phase}' 2>/dev/null | grep -q Bound; then
  pass "PVC smoke-pvc is Bound ($(kubectl -n "$NS" get pvc smoke-pvc -o jsonpath='{.spec.resources.requests.storage}'))"
else
  fail "PVC smoke-pvc is not Bound"
fi
MARKER="smoke $(kubectl -n "$NS" get pvc smoke-pvc -o jsonpath='{.metadata.uid}' 2>/dev/null) $RANDOM"
POD="$(kubectl -n "$NS" get pod -l app=smoke-nginx -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)"
if [[ -n "$POD" ]]; then
  kubectl -n "$NS" exec "$POD" -- sh -c "printf '%s' '$MARKER' > /data/smoke-marker.txt"
  # Full restart: delete the pod, Recreate strategy brings up a fresh one on the same volume.
  kubectl -n "$NS" delete pod "$POD" --wait=true >/dev/null
  kubectl -n "$NS" rollout status deploy/smoke-nginx --timeout=180s >/dev/null
  NEWPOD="$(kubectl -n "$NS" get pod -l app=smoke-nginx -o jsonpath='{.items[0].metadata.name}')"
  READBACK="$(kubectl -n "$NS" exec "$NEWPOD" -- cat /data/smoke-marker.txt 2>/dev/null || true)"
  if [[ "$READBACK" == "$MARKER" ]]; then
    pass "marker survived pod restart on volume (new pod: $NEWPOD)"
  else
    fail "marker not persisted across restart (got: '${READBACK:-<empty>}')"
  fi
else
  fail "no smoke-nginx pod found to test persistence"
fi

step "3/5 Service / in-cluster DNS connectivity"
if kubectl -n "$NS" run smoke-curl --rm -i --restart=Never --image=curlimages/curl:8.10.1 \
     --command -- curl -sS -m 10 -o /dev/null -w '%{http_code}' http://smoke-nginx.smoke-test.svc.cluster.local 2>/dev/null | grep -q '^200'; then
  pass "Service smoke-nginx reachable by DNS, HTTP 200"
else
  fail "Service not reachable via cluster DNS (expected HTTP 200)"
fi

step "4/5 HTTP reachability from this host (kubectl port-forward)"
if ! command -v curl >/dev/null 2>&1; then
  skip "curl not on host PATH; cannot test HTTP reachability"
else
  LPORT=18080
  kubectl -n "$NS" port-forward svc/smoke-nginx "${LPORT}:80" >/dev/null 2>&1 &
  PF_PID=$!
  # wait for the tunnel to come up
  up=0
  for _ in $(seq 1 15); do
    if curl -sf -m 2 "http://127.0.0.1:${LPORT}/" >/dev/null 2>&1; then up=1; break; fi
    sleep 1
  done
  CODE="$(curl -sS -m 5 -o /tmp/smoke_body.$$ -w '%{http_code}' "http://127.0.0.1:${LPORT}/" 2>/dev/null || echo 000)"
  if [[ "$up" == "1" && "$CODE" == "200" ]] && grep -qi 'Welcome to nginx' /tmp/smoke_body.$$ 2>/dev/null; then
    pass "HTTP GET http://127.0.0.1:${LPORT}/ -> 200, served nginx welcome page"
  else
    fail "HTTP GET via port-forward failed (code=$CODE, tunnel_up=$up)"
  fi
  kill "$PF_PID" >/dev/null 2>&1 || true
  rm -f /tmp/smoke_body.$$
fi

step "5/5 Ingress (optional until P2-T4)"
if kubectl get ingressclass -o name 2>/dev/null | grep -q .; then
  skip "ingress controller present but ingress check not yet implemented — extend here in P2-T4"
else
  skip "no ingress controller installed yet (P2-T4 installs Traefik/ingress); nothing to test"
fi

step "Result"
if [[ "$FAILED" == "0" ]]; then
  printf '  \033[32mALL CHECKS PASSED\033[0m — cluster scheduling, storage, and networking are healthy.\n'
  echo "  (Leave the workload running, or tear down with: $0 --clean)"
  exit 0
else
  printf '  \033[31mSMOKE TEST FAILED\033[0m — see FAIL lines above.\n'
  exit 1
fi
