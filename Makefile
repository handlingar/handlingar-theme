# Handlingar platform — one place for every operational command.
#
# You do NOT need to remember kubectl/hetzner-k3s flags or set environment
# variables. Just run `make` to see what's available, then run a target.
# Each target fixes its own prerequisites (installs tools, validates the
# token, creates the kubeconfig dir) so commands don't fail halfway.
#
#   make                 # show this help
#   make cluster-up      # create the dev cluster (spends money — see status)
#   make deploy          # deploy the app's backing services to the cluster
#   make status          # show cluster + app health + the billing reminder
#   make cluster-down    # destroy the cluster (STOPS billing)

SHELL := /bin/bash
# Make tools, kubeconfig, and the Hetzner token available to every target
# automatically — no manual `export` needed.
export PATH := $(HOME)/.local/bin:$(PATH)
export KUBECONFIG := $(HOME)/.kube/handlingar-dev.yaml
# All local secrets live in ONE gitignored file: .local/.env
# (template + docs: .local/.env.example). Sourced into every target.
-include .local/.env
export HCLOUD_TOKEN
export DB_PASSWORD
export CLOUDFLARE_API_TOKEN

CLUSTER_CFG := infra/hetzner-k3s/dev-cluster.yaml
NS := handlingar

# Ingress / DNS / TLS (P2-T4). Chart versions pinned for reproducibility.
INGRESS_DIR := infra/k8s/ingress
CERTMGR_VER := v1.20.2
TRAEFIK_VER := 40.3.0
EXTDNS_VER  := 1.21.1
APP_HOST    := dev.nonprod.handlingar.se
DNS_ZONE    := handlingar.se
# The managed Hetzner LB (Traefik svc annotation) AND the hetzner-k3s server-name
# prefix are both this. Used by orphan cleanup to find the LB and detect live nodes.
LB_NAME     := handlingar-dev

# App image (registry-less for now: built locally, imported into the worker
# node's containerd over SSH). TAG tracks the pinned Alaveteli version.
IMAGE   := alaveteli-handlingar
TAG     := $(shell cat ALAVETELI_VERSION 2>/dev/null || echo dev)
WORKER  := handlingar-dev-pool-workers-worker1
SSH_KEY := $(HOME)/.ssh/id_ed25519
# Node IPs are recycled across cluster rebuilds, so never trust/record host keys:
# UserKnownHostsFile=/dev/null avoids stale-key failures and known_hosts spam;
# LogLevel=ERROR silences the per-connection "Permanently added" warning.
SSH_OPTS := -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR -i $(SSH_KEY)

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show this help (default)
	@printf '\nHandlingar — available commands:\n\n'
	@grep -hE '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
	  | sort | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n",$$1,$$2}'
	@printf '\nTip: first run "make preflight", then "make cluster-up".\n\n'

.PHONY: preflight
preflight: ## Install/verify local tools + validate the Hetzner token
	@bash scripts/preflight.sh

.PHONY: cluster-up
cluster-up: preflight ## Create the dev K3s cluster on Hetzner (spends ~€20/mo)
	@mkdir -p $(HOME)/.kube
	@echo "Provisioning cluster (this takes a few minutes; progress streams below)..."
	hetzner-k3s create --config $(CLUSTER_CFG)
	@# hetzner-k3s deploys an autoscaler even when disabled; it crash-loops. Remove it.
	@kubectl -n kube-system delete deploy cluster-autoscaler --ignore-not-found >/dev/null 2>&1 || true
	@$(MAKE) --no-print-directory status

.PHONY: cluster-down
cluster-down: ## Destroy the dev cluster (STOPS billing)
	@echo "Destroying cluster — this stops Hetzner billing."
	# --force: delete without the interactive "type the cluster name" prompt.
	# Without it, a non-TTY run (CI, make in background) loops forever at 100% CPU
	# on the empty-input error and deletes nothing. Must stay non-interactive.
	hetzner-k3s delete --config $(CLUSTER_CFG) --force
	@# Volume detach + LB/DNS deletion are ASYNC and lag the cluster delete, so a
	@# single reap pass can miss a still-detaching volume. Reap + verify in a loop
	@# until the registry audit (the hard gate) confirms nothing remains — a
	@# teardown can never finish quietly with a resource still billing.
	@for i in 1 2 3 4 5; do \
	  $(MAKE) --no-print-directory volumes-clean; \
	  $(MAKE) --no-print-directory orphans-clean; \
	  if bash scripts/cloud-audit.sh --assert-empty; then break; fi; \
	  if [ $$i -eq 5 ]; then echo "TEARDOWN VERIFICATION FAILED after 5 attempts."; exit 1; fi; \
	  echo "Resources still settling — retry $$i/5 in 15s..."; sleep 15; \
	done

# hetzner-k3s delete leaves the in-cluster-provisioned LB + DNS behind (the
# cloud-controller-manager and external-dns are gone, so nobody reaps them).
# These two targets find and remove exactly those orphans. `orphans` is
# read-only (safe to run anytime); `orphans-clean` deletes and is folded into
# `cluster-down` so a teardown is actually complete. See scripts/orphan-clean.sh.
.PHONY: orphans
orphans: ## List orphaned cloud resources (LB + DNS) a teardown would leave behind (read-only)
	@LB_NAME=$(LB_NAME) APP_HOST=$(APP_HOST) bash scripts/orphan-clean.sh --list

.PHONY: orphans-clean
orphans-clean: ## Delete the orphaned LB + DNS records left by a cluster teardown (idempotent)
	@LB_NAME=$(LB_NAME) APP_HOST=$(APP_HOST) bash scripts/orphan-clean.sh --clean

# Enumerates EVERY billable Hetzner resource + all nonprod DNS by discovery
# (not by guessing names), so nothing is ever left running silently. `cloud-audit`
# is read-only; `cloud-audit-assert` exits non-zero if anything remains and runs
# as the final gate of `cluster-down`.
.PHONY: cloud-audit resources
resources: cloud-audit ## Alias for cloud-audit — list every resource this stack deploys
cloud-audit: ## List the cloud resources this stack deploys (registry-driven; foreign resources never shown)
	@bash scripts/cloud-audit.sh

.PHONY: cloud-audit-assert
cloud-audit-assert: ## Fail if ANY billable resource / stale nonprod DNS remains (teardown gate)
	@bash scripts/cloud-audit.sh --assert-empty

# hetzner-k3s delete removes servers but NOT volumes created by the in-cluster
# CSI driver (e.g. the postgres PVC) — they keep billing. This deletes a volume
# only when ALL THREE hold: it is detached (server=null — an attached volume
# belongs to a live server and is never touched), its name starts with "pvc-"
# (the CSI naming scheme), and it carries the CSI driver's own label
# (managed-by=csi-driver — confirmed against the live API JSON). Manually
# created volumes are therefore never deleted. Zero matches is a normal no-op.
.PHONY: volumes-clean
volumes-clean: ## Delete orphaned (detached) CSI-created Hetzner volumes (stops their billing)
	@[ -n "$$HCLOUD_TOKEN" ] || { echo "ERROR: HCLOUD_TOKEN not set — fill in .local/.env (see .local/.env.example)"; exit 1; }
	@vols=$$(curl -sf -H "Authorization: Bearer $$HCLOUD_TOKEN" "https://api.hetzner.cloud/v1/volumes?per_page=50" \
	  | python3 -c 'import sys,json; [print(v["id"], v["name"]) for v in json.load(sys.stdin).get("volumes",[]) if v.get("server") is None and v.get("name","").startswith("pvc-") and v.get("labels",{}).get("managed-by")=="csi-driver"]'); \
	if [ -z "$$vols" ]; then \
	  echo "No orphaned CSI volumes — nothing to clean up."; \
	else \
	  echo "$$vols" | while read -r id name; do \
	    echo "Deleting orphaned CSI volume $$name (id $$id)..."; \
	    curl -sf -X DELETE -H "Authorization: Bearer $$HCLOUD_TOKEN" \
	      "https://api.hetzner.cloud/v1/volumes/$$id" >/dev/null \
	      && echo "  deleted." || echo "  WARNING: delete failed for $$name (id $$id) — check the Hetzner console."; \
	  done; \
	fi

.PHONY: deploy
deploy: ## Deploy backing services (postgres/redis/memcached) to the cluster
	@kubectl get ns $(NS) >/dev/null 2>&1 || kubectl create namespace $(NS)
	@# Create a throwaway dev DB secret once if missing (never printed, not in git).
	@kubectl -n $(NS) get secret alaveteli-secrets >/dev/null 2>&1 || { \
	  pw="$(DB_PASSWORD)"; [ -n "$$pw" ] || pw="dev-$$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')"; \
	  kubectl -n $(NS) create secret generic alaveteli-secrets \
	    --from-literal=db-password="$$pw" >/dev/null; \
	  echo "Created DB secret 'alaveteli-secrets' (value not shown; from .local/.env DB_PASSWORD or auto-generated)."; }
	kubectl apply -f infra/k8s/base/
	@$(MAKE) --no-print-directory status

.PHONY: smoke
smoke: ## Run the re-runnable cluster smoke test (scheduling/storage/HTTP)
	@bash infra/k8s/smoke-test/run.sh

.PHONY: smoke-clean
smoke-clean: ## Tear down the smoke-test workload (release its volume)
	@bash infra/k8s/smoke-test/run.sh --clean

.PHONY: status
status: ## Show cluster nodes, app pods, and the billing reminder
	@printf '\n\033[1mCluster nodes\033[0m\n'
	@kubectl get nodes 2>/dev/null || echo "  (cluster not reachable — run 'make cluster-up')"
	@printf '\n\033[1mApp services (%s namespace)\033[0m\n' "$(NS)"
	@kubectl -n $(NS) get pods 2>/dev/null || echo "  (nothing deployed yet — run 'make deploy')"
	@printf '\n\033[33mBilling:\033[0m the cluster bills continuously (~€20/mo) while it exists.\n'
	@printf "   Run \033[36mmake cluster-down\033[0m when you are done to stop billing.\n\n"

.PHONY: gate
gate: ## Run the full quality gate (drift/secret/privacy checks)
	@bash scripts/quality-gate.sh

# ---------------------------------------------------------------------------
# App image + bring-up (registry-less: build locally, import into the worker
# node's containerd over SSH, then deploy). `make bringup` does the whole thing
# from a fresh cluster; each target is idempotent and self-fixing.
# ---------------------------------------------------------------------------

.PHONY: image-build
image-build: ## Build the pinned Alaveteli app image locally (docker build)
	@echo "Building $(IMAGE):$(TAG) (Alaveteli pinned via ALAVETELI_VERSION)..."
	docker build -t $(IMAGE):$(TAG) .

# Compression choice: zstd -12 -T0 measured 25% smaller than gzip -1 on this
# image (711MB vs 950MB) while compressing at ~20MB/s — far above the ~1MB/s
# uplink, so the smaller stream cuts upload time proportionally (~16min → ~12min,
# less again as the image shrinks). Self-fixing: installs zstd on the node (Ubuntu)
# if missing; falls back to gzip -1 when zstd is unavailable on either end.
.PHONY: image-import
image-import: ## Import the local image into worker1's containerd (no registry needed)
	@set -o pipefail; \
	ip=$$(kubectl get node $(WORKER) -o jsonpath='{.status.addresses[?(@.type=="ExternalIP")].address}' 2>/dev/null); \
	if [ -z "$$ip" ]; then echo "ERROR: $(WORKER) not found — is the cluster up? (make cluster-up)"; exit 1; fi; \
	if ! docker image inspect $(IMAGE):$(TAG) >/dev/null 2>&1; then \
	  echo "Image $(IMAGE):$(TAG) not built locally — run 'make image-build' first."; exit 1; fi; \
	if ssh $(SSH_OPTS) -o ConnectTimeout=10 root@$$ip \
	     "k3s ctr -n k8s.io images ls 2>/dev/null | grep -q $(IMAGE):$(TAG)"; then \
	  echo "Image already present on $(WORKER) — nothing to do."; \
	elif command -v zstd >/dev/null 2>&1 && ssh $(SSH_OPTS) root@$$ip \
	     "command -v zstd >/dev/null 2>&1 || (apt-get update -qq && apt-get install -y -qq zstd) >/dev/null 2>&1; command -v zstd >/dev/null 2>&1"; then \
	  echo "Streaming $(IMAGE):$(TAG) to $(WORKER) ($$ip) via zstd — limited by uplink, be patient..."; \
	  docker save $(IMAGE):$(TAG) | zstd -12 -T0 -q | ssh $(SSH_OPTS) \
	    root@$$ip "zstd -d | k3s ctr -n k8s.io images import -"; \
	  echo "Imported."; \
	else \
	  echo "zstd unavailable locally or on the node — falling back to gzip -1 (slower)."; \
	  docker save $(IMAGE):$(TAG) | gzip -1 | ssh $(SSH_OPTS) \
	    root@$$ip "gunzip | k3s ctr -n k8s.io images import -"; \
	  echo "Imported."; \
	fi

.PHONY: app-up
app-up: ## Deploy the app (apply manifests, wait for web to roll out, show status)
	@kubectl get ns $(NS) >/dev/null 2>&1 || kubectl create namespace $(NS)
	@kubectl -n $(NS) get secret alaveteli-secrets >/dev/null 2>&1 || { \
	  pw="$(DB_PASSWORD)"; [ -n "$$pw" ] || pw="dev-$$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')"; \
	  kubectl -n $(NS) create secret generic alaveteli-secrets \
	    --from-literal=db-password="$$pw" >/dev/null; \
	  echo "Created DB secret 'alaveteli-secrets' (value not shown; from .local/.env DB_PASSWORD or auto-generated)."; }
	kubectl apply -f infra/k8s/base/
	@echo "Waiting for alaveteli-web to roll out (first boot migrates + installs theme)..."
	kubectl -n $(NS) rollout status deploy/alaveteli-web --timeout=420s
	@$(MAKE) --no-print-directory status

# cluster-up (~10-15 min, mostly waiting on Hetzner) and image-build (~10 min
# cold, seconds when cached) are independent, so bringup runs them in parallel:
# the build streams in the background with an [image-build] prefix while
# cluster-up streams in the foreground. We always wait for BOTH and fail hard
# (loudly) if either failed — never proceeding to import/deploy on a half-result.
.PHONY: bringup
bringup: ## FULL zero-to-running: cluster + image build/import + app + ingress (idempotent)
	@echo "Running cluster-up and image-build in parallel (build lines are prefixed [image-build])..."
	@( set -o pipefail; $(MAKE) --no-print-directory image-build 2>&1 | sed -u 's/^/[image-build] /' ) & build_pid=$$!; \
	$(MAKE) --no-print-directory cluster-up; cluster_rc=$$?; \
	wait $$build_pid; build_rc=$$?; \
	if [ $$cluster_rc -ne 0 ]; then echo "ERROR: cluster-up FAILED (rc=$$cluster_rc) — aborting bringup."; exit $$cluster_rc; fi; \
	if [ $$build_rc -ne 0 ]; then echo "ERROR: image-build FAILED (rc=$$build_rc) — see [image-build] lines above. Aborting bringup."; exit $$build_rc; fi; \
	echo "cluster-up and image-build both succeeded."
	@$(MAKE) --no-print-directory image-import
	@$(MAKE) --no-print-directory app-up
	@$(MAKE) --no-print-directory ingress-up
	@echo ""
	@echo "App is up at https://$(APP_HOST) (TLS via Let's Encrypt; DNS via external-dns)."
	@echo "  Local fallback: kubectl -n $(NS) port-forward deploy/alaveteli-web 3000:3000  # http://localhost:3000"

# ---------------------------------------------------------------------------
# Ingress + automated DNS + TLS (P2-T4). Installs Traefik (behind a Hetzner LB),
# cert-manager, and external-dns, then applies the Let's Encrypt issuers, the
# Certificate, and the app IngressRoute. All committed under infra/k8s/ingress/.
# external-dns is locked to the nonprod.handlingar.se subtree + upsert-only, so
# it can never touch production DNS. See ADR 0006 and infra/k8s/ingress/README.md.
# ---------------------------------------------------------------------------

.PHONY: ingress-secret
ingress-secret: ## Create the Cloudflare API-token Secret (cert-manager + external-dns ns)
	@[ -n "$(CLOUDFLARE_API_TOKEN)" ] || { echo "ERROR: CLOUDFLARE_API_TOKEN not set in .local/.env (see .local/.env.example)"; exit 1; }
	@for ns in cert-manager external-dns; do \
	  kubectl get ns $$ns >/dev/null 2>&1 || kubectl create namespace $$ns >/dev/null; \
	  kubectl -n $$ns create secret generic cloudflare-api-token \
	    --from-literal=api-token="$(CLOUDFLARE_API_TOKEN)" \
	    --dry-run=client -o yaml | kubectl apply -f - >/dev/null; \
	done
	@echo "Cloudflare API-token Secret present in cert-manager + external-dns namespaces (value not shown)."

.PHONY: ingress-up
ingress-up: ## Install ingress + automated DNS + TLS (Traefik LB, cert-manager, external-dns)
	@command -v helm >/dev/null || { echo "helm not found — run 'make preflight'"; exit 1; }
	@echo "[1/6] helm repos..."
	@helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1; \
	 helm repo add traefik https://traefik.github.io/charts >/dev/null 2>&1; \
	 helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ >/dev/null 2>&1; \
	 helm repo update >/dev/null 2>&1
	@echo "[2/6] cert-manager $(CERTMGR_VER)..."
	@helm upgrade --install cert-manager jetstack/cert-manager -n cert-manager --create-namespace \
	  --version $(CERTMGR_VER) --set crds.enabled=true --wait --timeout 5m
	@echo "[3/6] Cloudflare API-token secret..."
	@$(MAKE) --no-print-directory ingress-secret
	@echo "[4/6] Traefik $(TRAEFIK_VER) (provisions the Hetzner LB — this bills ~€5.4/mo)..."
	@helm upgrade --install traefik traefik/traefik -n traefik --create-namespace \
	  --version $(TRAEFIK_VER) -f $(INGRESS_DIR)/values-traefik.yaml --wait --timeout 5m
	@echo "[5/6] external-dns $(EXTDNS_VER) (publishes $(APP_HOST) to Cloudflare)..."
	@# dev.nonprod.handlingar.se lives INSIDE the handlingar.se Cloudflare zone (no
	@# separate sub-zone). domainFilters alone would exclude the parent zone, so we
	@# pin the zone by id (derived from the token at deploy time — nothing secret in
	@# git) while domainFilters keeps record management restricted to the nonprod subtree.
	@zid=$$(curl -s -H "Authorization: Bearer $(CLOUDFLARE_API_TOKEN)" \
	   'https://api.cloudflare.com/client/v4/zones?name=$(DNS_ZONE)' \
	   | python3 -c 'import sys,json;z=json.load(sys.stdin).get("result",[]);print(z[0]["id"] if z else "")'); \
	 [ -n "$$zid" ] || { echo "ERROR: could not resolve Cloudflare zone id for $(DNS_ZONE) (check CLOUDFLARE_API_TOKEN scope)"; exit 1; }; \
	 helm upgrade --install external-dns external-dns/external-dns -n external-dns --create-namespace \
	   --version $(EXTDNS_VER) -f $(INGRESS_DIR)/values-external-dns.yaml \
	   --set "extraArgs[0]=--zone-id-filter=$$zid" --wait --timeout 5m
	@echo "[6/6] Let's Encrypt issuers + certificate + IngressRoute..."
	@kubectl apply -f $(INGRESS_DIR)/clusterissuer-staging.yaml -f $(INGRESS_DIR)/clusterissuer-prod.yaml
	@kubectl apply -f $(INGRESS_DIR)/certificate.yaml -f $(INGRESS_DIR)/ingressroute.yaml
	@$(MAKE) --no-print-directory ingress-status

.PHONY: ingress-status
ingress-status: ## Show LB IP, TLS cert readiness, and DNS resolution for the app host
	@printf '\n\033[1mTraefik LoadBalancer (Hetzner LB)\033[0m\n'
	@kubectl -n traefik get svc traefik -o wide 2>/dev/null || echo "  (traefik not installed — run 'make ingress-up')"
	@printf '\n\033[1mTLS certificate\033[0m\n'
	@kubectl -n $(NS) get certificate alaveteli-tls 2>/dev/null || echo "  (no certificate yet)"
	@printf '\n\033[1mDNS — %s\033[0m\n' "$(APP_HOST)"
	@getent hosts $(APP_HOST) || echo "  (not resolving yet — external-dns may still be publishing)"
	@printf '\n'

.PHONY: app-forward
app-forward: ## Port-forward the app to http://localhost:3000 (Ctrl-C to stop)
	@echo "Open http://localhost:3000 (use Host localhost — Rails blocks other hosts in dev)"
	kubectl -n $(NS) port-forward deploy/alaveteli-web 3000:3000

# ---------------------------------------------------------------------------
# Theme development helpers (diff/copy theme views against upstream Alaveteli)
# ---------------------------------------------------------------------------

DIFF_FILE_HSE = general/_before_body_end.html.erb
DIFF_FILE_HSE = general/_before_head_end.html.erb
DIFF_FILE_HSE = general/_credits.html.erb
DIFF_FILE_HSE = general/_credits.sv.html.erb
DIFF_FILE_HSE = general/_orglink.html.erb
DIFF_FILE_HSE = general/_popup_banner.html.erb
DIFF_FILE_HSE = general/exception_caught.html.erb
DIFF_FILE_HSE = general/mycontroller.html.erb


DIFF_FILE_HSE = help/_sidebar.html.erb
DIFF_FILE_HSE = help/_why_they_should_reply_by_email.html.erb
DIFF_FILE_HSE = help/about.html.erb
DIFF_FILE_HSE = help/alaveteli.html.erb
DIFF_FILE_HSE = help/api.html.erb
DIFF_FILE_HSE = help/contact.html.erb
DIFF_FILE_HSE = help/credits.html.erb
DIFF_FILE_HSE = help/officers.html.erb
DIFF_FILE_HSE = help/privacy.html.erb
DIFF_FILE_HSE = help/pro.html.erb
DIFF_FILE_HSE = help/requesting.html.erb
DIFF_FILE_HSE = help/unhappy.html.erb


diff-theme: ## (theme) diff a theme view against the upstream copy
	#git diff --no-index -w ./lib/views/$(DIFF_FILE_HSE) ../alaveteli/app/views/$(DIFF_FILE_HSE)
	git diff --no-index ./lib/views/$(DIFF_FILE_HSE) ../alavetelitheme/lib/views/$(DIFF_FILE_HSE)


copy-a: ## (theme) copy an upstream view into the theme
	 cp ../alaveteli/app/views/$(DIFF_FILE_HSE) ./lib/views/$(DIFF_FILE_HSE)

# ---------------------------------------------------------------------------
# Mock data (dev cluster) — scripts/mock-data/
# ---------------------------------------------------------------------------

.PHONY: mock-data
mock-data: ## Seed mock authorities + a test user into the dev cluster
	@cat scripts/mock-data/seed.rb | kubectl -n $(NS) exec -i deploy/alaveteli-web -- bash -c 'cat > /tmp/mock-seed.rb'
	kubectl -n $(NS) exec deploy/alaveteli-web -- bundle exec rails runner /tmp/mock-seed.rb

.PHONY: mock-request
mock-request: ## File a mock FOI request (generates a real outgoing email)
	@cat scripts/mock-data/send-request.rb | kubectl -n $(NS) exec -i deploy/alaveteli-web -- bash -c 'cat > /tmp/mock-send-request.rb'
	kubectl -n $(NS) exec deploy/alaveteli-web -- bundle exec rails runner /tmp/mock-send-request.rb

.PHONY: mock-reply
mock-reply: ## Simulate an authority replying (delivers an answer into Mailpit via SMTP) [REQ=<id>]
	@cat scripts/mock-data/send-reply.rb | kubectl -n $(NS) exec -i deploy/alaveteli-web -- bash -c 'cat > /tmp/mock-send-reply.rb'
	kubectl -n $(NS) exec deploy/alaveteli-web -- bundle exec rails runner /tmp/mock-send-reply.rb $(REQ)

# ---------------------------------------------------------------------------
# Mock mail loop (dev) — Mailpit catches all outgoing mail; see
# infra/k8s/base/mailpit.yaml for the design notes.
# ---------------------------------------------------------------------------

.PHONY: mail-poll
mail-poll: ## Pull incoming mail from Mailpit over POP3 into Alaveteli (native AlaveteliMailPoller)
	@# The real incoming path: Alaveteli's POP3 poller fetches from Mailpit's POP3
	@# (:1110, dev fixtures alaveteli:alaveteli per mailpit.yaml), routes each
	@# message via RequestMailer.receive, and deletes it from the mailbox. One pass
	@# drains the mailbox (each_mail iterates all messages).
	kubectl -n $(NS) exec deploy/alaveteli-web -- bundle exec rails runner \
	  "found = AlaveteliMailPoller.new(address: 'mailpit', port: 1110, user_name: 'alaveteli', password: 'alaveteli', enable_ssl: false).poll_for_incoming; puts(found ? 'POP3 poll: incoming mail retrieved and processed.' : 'POP3 poll: mailbox empty — nothing to retrieve.')"

.PHONY: mail-ui
mail-ui: ## Port-forward the Mailpit web UI to http://localhost:8025
	@echo "Open http://localhost:8025 — all outgoing app mail lands here (Ctrl-C to stop)"
	kubectl -n $(NS) port-forward svc/mailpit 8025:8025

.PHONY: mail-ingest
mail-ingest: ## Feed every message in Mailpit into Alaveteli as incoming mail (then delete it from Mailpit)
	@echo "Ingesting Mailpit messages into Alaveteli via script/mailin..."
	@kubectl -n $(NS) port-forward svc/mailpit 18025:8025 >/dev/null 2>&1 & \
	PF_PID=$$!; trap 'kill $$PF_PID 2>/dev/null' EXIT; \
	for i in 1 2 3 4 5 6 7 8 9 10; do \
	  curl -sf http://localhost:18025/api/v1/messages?limit=1 >/dev/null && break; sleep 1; \
	done; \
	IDS=$$(curl -sf 'http://localhost:18025/api/v1/messages?limit=500' \
	  | python3 -c 'import sys,json; print("\n".join(m["ID"] for m in json.load(sys.stdin)["messages"]))'); \
	[ -n "$$IDS" ] || { echo "Mailpit is empty — nothing to ingest."; exit 0; }; \
	for id in $$IDS; do \
	  echo "  -> $$id"; \
	  if curl -sf "http://localhost:18025/api/v1/message/$$id/raw" \
	    | kubectl -n $(NS) exec -i deploy/alaveteli-web -- ./script/mailin; then \
	    curl -sf -X DELETE http://localhost:18025/api/v1/messages \
	      -H 'Content-Type: application/json' -d "{\"IDs\":[\"$$id\"]}" >/dev/null; \
	  else \
	    echo "     mailin failed for $$id (left in Mailpit)"; \
	  fi; \
	done; \
	echo "Done. Replies to request addresses now appear on the request page."
