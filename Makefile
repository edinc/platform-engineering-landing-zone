SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
PYTHON ?= python3
export PATH := $(CURDIR)/.tools/venv/bin:$(PATH)
MISE_EXEC := $(shell if command -v mise >/dev/null 2>&1; then printf 'mise exec --'; fi)

TERRAFORM_DIRS := $(shell find infrastructure/terraform -type f -name '*.tf' -not -path '*/.terraform/*' -exec dirname {} \; 2>/dev/null | sort -u)
BOOTSTRAP_DIR := infrastructure/terraform/_bootstrap
# The _bootstrap stack uses a remote backend and import-based adoption, so it is
# driven by the dedicated bootstrap-* targets rather than the generic plan/apply.
PLANNABLE_TERRAFORM_DIRS := $(filter-out $(BOOTSTRAP_DIR) infrastructure/terraform/_modules/%,$(TERRAFORM_DIRS))
HELM_CHART_DIRS := $(shell find . -type f -name 'Chart.yaml' -not -path './.git/*' -exec dirname {} \; 2>/dev/null | sort -u)
K8S_MANIFESTS := $(shell find platform-gitops templates -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort)
STAGE08_ALERT_RULES := $(shell { find platform-gitops/clusters/_base/addon-config/observability -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null; printf '%s\n' infrastructure/terraform/platform/monitoring.tf; } | sort)
CONTRACT_REQUESTS := $(shell find docs/contracts -type f \( -path '*/examples/*.yaml' -o -name 'vending-request.yaml' \) 2>/dev/null | sort)
CONTRACT_NEGATIVE_REQUESTS := $(shell find docs/contracts/tests -type f -name '*.yaml' 2>/dev/null | sort)

.PHONY: help bootstrap lint pre-commit validate terraform-fmt terraform-validate tflint checkov kubeconform helm-lint contract-test workflow-contracts stage07-contracts stage08-contracts alert-runbook-lint finops-cost-test azure-test-stage08 policy-test-rego policy-test-kyverno policy-test-azure policy-test-firewall plan apply docs bootstrap-init bootstrap-tf-init bootstrap-import bootstrap-plan bootstrap-apply

help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "Available targets:\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-24s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

bootstrap: ## Install local developer hooks.
	@if command -v mise >/dev/null 2>&1; then \
	  mise install; \
	else \
	  echo "mise not found; install mise or open the devcontainer before running bootstrap."; \
	  exit 1; \
	fi
	rm -rf .tools/venv
	mise exec -- python -m venv .tools/venv
	.tools/venv/bin/python -m pip install --upgrade pip
	.tools/venv/bin/python -m pip install pre-commit==4.0.1 checkov==3.2.287
	$(MISE_EXEC) pre-commit install

lint: pre-commit terraform-fmt tflint ## Run local linting checks.

pre-commit: ## Run pre-commit hooks across tracked files.
	$(MISE_EXEC) pre-commit run --all-files

validate: terraform-validate checkov kubeconform helm-lint contract-test workflow-contracts stage07-contracts stage08-contracts ## Run validation checks that do not deploy resources.

terraform-fmt: ## Check Terraform formatting.
	@if [ -z "$(TERRAFORM_DIRS)" ]; then \
	  echo "No Terraform files found; skipping terraform fmt."; \
	else \
	  $(MISE_EXEC) terraform fmt -recursive -check infrastructure/terraform; \
	fi

terraform-validate: ## Validate each Terraform directory that contains .tf files.
	@if [ -z "$(TERRAFORM_DIRS)" ]; then \
	  echo "No Terraform files found; skipping terraform validate."; \
	else \
	  status=0; \
	  for dir in $(TERRAFORM_DIRS); do \
	    echo "Validating Terraform in $$dir"; \
	    (cd "$$dir" && $(MISE_EXEC) terraform init -backend=false -input=false && $(MISE_EXEC) terraform validate) || status=$$?; \
	  done; \
	  exit $$status; \
	fi

tflint: ## Run TFLint with the Azure ruleset for Terraform directories.
	@if [ -z "$(TERRAFORM_DIRS)" ]; then \
	  echo "No Terraform files found; skipping tflint."; \
	else \
	  $(MISE_EXEC) tflint --init --config="$(CURDIR)/.tflint.hcl"; \
	  status=0; \
	  for dir in $(TERRAFORM_DIRS); do \
	    echo "Running tflint in $$dir"; \
	    (cd "$$dir" && $(MISE_EXEC) tflint --config="$(CURDIR)/.tflint.hcl") || status=$$?; \
	  done; \
	  exit $$status; \
	fi

checkov: ## Run Checkov against Terraform code.
	@if [ -z "$(TERRAFORM_DIRS)" ]; then \
	  echo "No Terraform files found; skipping checkov."; \
	else \
	  $(MISE_EXEC) checkov --config-file .checkov.yaml -d infrastructure/terraform; \
	fi

kubeconform: ## Validate Kubernetes manifests outside policy test fixtures.
	@if [ -z "$(K8S_MANIFESTS)" ]; then \
	  echo "No Kubernetes manifests found; skipping kubeconform."; \
	else \
	  $(MISE_EXEC) kubeconform -strict -summary -ignore-missing-schemas $(K8S_MANIFESTS); \
	fi

helm-lint: ## Lint Helm charts when chart directories exist.
	@if [ -z "$(HELM_CHART_DIRS)" ]; then \
	  echo "No Helm charts found; skipping helm lint."; \
	else \
	  for chart in $(HELM_CHART_DIRS); do \
	    echo "Linting Helm chart $$chart"; \
	    $(MISE_EXEC) helm lint "$$chart"; \
	  done; \
	fi

contract-test: ## Validate public request contracts and negative fixtures.
	@if [ -z "$(CONTRACT_REQUESTS)" ]; then \
	  echo "No contract request examples found; skipping contract validation."; \
	else \
	  mkdir -p .tools/tmp/contracts; \
	  for request in $(CONTRACT_REQUESTS); do \
	    json_file=".tools/tmp/contracts/$$(basename "$$request").json"; \
	    echo "Validating contract $$request"; \
	    $(MISE_EXEC) npx --yes js-yaml@4.1.0 "$$request" > "$$json_file"; \
	    $(MISE_EXEC) npx --yes ajv-cli@5.0.0 validate --strict=true -s docs/contracts/vending-request.schema.json -d "$$json_file"; \
	  done; \
	fi
	@if [ -n "$(CONTRACT_NEGATIVE_REQUESTS)" ]; then \
	  mkdir -p .tools/tmp/contracts; \
	  for request in $(CONTRACT_NEGATIVE_REQUESTS); do \
	    json_file=".tools/tmp/contracts/$$(basename "$$request").json"; \
	    echo "Validating negative contract fixture $$request"; \
	    $(MISE_EXEC) npx --yes js-yaml@4.1.0 "$$request" > "$$json_file"; \
	    if $(MISE_EXEC) npx --yes ajv-cli@5.0.0 validate --strict=true -s docs/contracts/vending-request.schema.json -d "$$json_file"; then \
	      echo "Expected $$request to fail vending-request.schema.json validation."; \
	      exit 1; \
	    else \
	      echo "Schema rejected $$request as expected."; \
	    fi; \
	  done; \
	fi

workflow-contracts: ## Validate Stage 06 reusable workflow contracts.
	$(PYTHON) scripts/workflows/validate_stage06_workflows.py

stage07-contracts: ## Validate Stage 07 GitOps, Flux, and Kyverno contracts.
	$(PYTHON) scripts/gitops/validate_stage07_gitops.py

stage08-contracts: alert-runbook-lint finops-cost-test ## Validate Stage 08 observability, SRE, and FinOps contracts.
	$(PYTHON) scripts/observability/validate_stage08_observability.py

alert-runbook-lint: ## Ensure Prometheus alert rules carry runbook_url annotations.
	$(PYTHON) scripts/observability/lint_alert_runbooks.py $(STAGE08_ALERT_RULES)

finops-cost-test: ## Test Stage 08 cost showback allocation logic.
	$(PYTHON) scripts/finops/test_cost_showback.py

azure-test-stage08: ## Run Azure CLI read-only validation for deployed Stage 08 resources.
	bash scripts/azure/validate_stage08_azure.sh

policy-test-rego: ## Test OPA/Rego policies with conftest fixtures.
	$(MISE_EXEC) conftest test --namespace terraform.tags --policy policies/rego policies/rego/fixtures/compliant-terraform-plan.json
	@mkdir -p .tools/tmp; \
	tmp_file=".tools/tmp/conftest-missing-tags.out"; \
	if $(MISE_EXEC) conftest test --namespace terraform.tags --policy policies/rego policies/rego/fixtures/missing-tags-terraform-plan.json > "$$tmp_file" 2>&1; then \
	  cat "$$tmp_file"; \
	  rm -f "$$tmp_file"; \
	  echo "Expected missing-tags Terraform plan fixture to fail Rego policy."; \
	  exit 1; \
	else \
	  cat "$$tmp_file"; \
	  rm -f "$$tmp_file"; \
	  echo "Rego policy rejected missing-tags Terraform plan fixture as expected."; \
	fi

policy-test-kyverno: ## Test Kyverno policies with kyverno test.
	$(MISE_EXEC) kyverno test policies/kyverno/tests

policy-test-azure: policy-test-firewall ## Validate custom Azure Policy initiatives and Stage 03 Firewall allowlist.
	$(PYTHON) scripts/policy/validate_azure_initiatives.py policies/azure/initiatives

policy-test-firewall: ## Validate Stage 03 Azure Firewall egress allowlist.
	$(PYTHON) scripts/policy/validate_firewall_allowlist.py policies/azure/firewall/allowlist.json

plan: ## Run Terraform plan for planable stacks (excludes the _bootstrap stack).
	@if [ -z "$(PLANNABLE_TERRAFORM_DIRS)" ]; then \
	  echo "No planable Terraform stacks found; use 'make bootstrap-plan' for the _bootstrap stack."; \
	else \
	  status=0; \
	  for dir in $(PLANNABLE_TERRAFORM_DIRS); do \
	    echo "Planning Terraform in $$dir"; \
	    (cd "$$dir" && $(MISE_EXEC) terraform init -input=false && $(MISE_EXEC) terraform plan -input=false) || status=$$?; \
	  done; \
	  exit $$status; \
	fi

apply: ## Deployment is intentionally blocked until deployable stacks exist.
	@echo "Terraform apply is out of scope for the generic target; use 'make bootstrap-apply' for the _bootstrap stack."
	@exit 1

bootstrap-init: ## Secret zero: one-off az-CLI script (Global Admin) — state SA, seed KV, OIDC app. Pass flags via ARGS="--subscription-id ... --tenant-id ... --name-suffix ...".
	bash scripts/bootstrap/bootstrap-init.sh $(ARGS)

bootstrap-tf-init: ## Initialize the _bootstrap Terraform backend (needs backend.hcl).
	@if [ ! -f "$(BOOTSTRAP_DIR)/backend.hcl" ]; then \
	  echo "Create $(BOOTSTRAP_DIR)/backend.hcl from backend.hcl.example (or run scripts/bootstrap/bootstrap-init.sh) first."; \
	  exit 1; \
	fi
	cd $(BOOTSTRAP_DIR) && $(MISE_EXEC) terraform init -input=false -backend-config=backend.hcl

bootstrap-import: ## Adopt bootstrap-init.sh resources into Terraform state (first apply only).
	$(MISE_EXEC) bash scripts/bootstrap/bootstrap-import.sh

bootstrap-plan: ## Terraform plan for the _bootstrap stack.
	cd $(BOOTSTRAP_DIR) && $(MISE_EXEC) terraform plan -input=false -lock-timeout=120s

bootstrap-apply: ## Terraform apply for the _bootstrap stack.
	cd $(BOOTSTRAP_DIR) && $(MISE_EXEC) terraform apply -input=false -lock-timeout=120s

docs: ## List Markdown documentation included in the current stage.
	@find README.md CONTRIBUTING.md docs plan -type f -name '*.md' | sort
