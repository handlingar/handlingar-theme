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
-include .local/hcloud.env
export HCLOUD_TOKEN

CLUSTER_CFG := infra/hetzner-k3s/dev-cluster.yaml
NS := handlingar

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
	hetzner-k3s delete --config $(CLUSTER_CFG)

.PHONY: deploy
deploy: ## Deploy backing services (postgres/redis/memcached) to the cluster
	@kubectl get ns $(NS) >/dev/null 2>&1 || kubectl create namespace $(NS)
	@# Create a throwaway dev DB secret once if missing (never printed, not in git).
	@kubectl -n $(NS) get secret alaveteli-secrets >/dev/null 2>&1 || { \
	  kubectl -n $(NS) create secret generic alaveteli-secrets \
	    --from-literal=db-password="dev-$$(head -c8 /dev/urandom | od -An -tx1 | tr -d ' \n')" >/dev/null; \
	  echo "Created dev DB secret 'alaveteli-secrets' (value not shown)."; }
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
