SHELL := /usr/bin/env bash
.SHELLFLAGS := -euo pipefail -c
.DEFAULT_GOAL := help
PYTHON ?= python3
export PATH := $(CURDIR)/.tools/venv/bin:$(PATH)
MISE_EXEC := $(shell if command -v mise >/dev/null 2>&1; then printf 'mise exec --'; fi)

TERRAFORM_DIRS := $(shell find infrastructure/terraform -type f -name '*.tf' -not -path '*/.terraform/*' -exec dirname {} \; 2>/dev/null | sort -u)
HELM_CHART_DIRS := $(shell find . -type f -name 'Chart.yaml' -not -path './.git/*' -exec dirname {} \; 2>/dev/null | sort -u)
K8S_MANIFESTS := $(shell find platform-gitops templates -type f \( -name '*.yaml' -o -name '*.yml' \) 2>/dev/null | sort)

.PHONY: help bootstrap lint pre-commit validate terraform-fmt terraform-validate tflint checkov kubeconform helm-lint policy-test-rego policy-test-kyverno plan apply docs

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

validate: terraform-validate checkov kubeconform helm-lint ## Run validation checks that do not deploy resources.

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
	  for dir in $(TERRAFORM_DIRS); do \
	    echo "Validating Terraform in $$dir"; \
	    (cd "$$dir" && $(MISE_EXEC) terraform init -backend=false -input=false && $(MISE_EXEC) terraform validate); \
	  done; \
	fi

tflint: ## Run TFLint with the Azure ruleset for Terraform directories.
	@if [ -z "$(TERRAFORM_DIRS)" ]; then \
	  echo "No Terraform files found; skipping tflint."; \
	else \
	  $(MISE_EXEC) tflint --init --config="$(CURDIR)/.tflint.hcl"; \
	  for dir in $(TERRAFORM_DIRS); do \
	    echo "Running tflint in $$dir"; \
	    (cd "$$dir" && $(MISE_EXEC) tflint --config="$(CURDIR)/.tflint.hcl"); \
	  done; \
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

plan: ## Run Terraform plan for directories with .tf files; Stage 00 has none.
	@if [ -z "$(TERRAFORM_DIRS)" ]; then \
	  echo "No Terraform files found; Stage 01 introduces planable bootstrap stacks."; \
	else \
	  for dir in $(TERRAFORM_DIRS); do \
	    echo "Planning Terraform in $$dir"; \
	    (cd "$$dir" && $(MISE_EXEC) terraform init -input=false && $(MISE_EXEC) terraform plan -input=false); \
	  done; \
	fi

apply: ## Deployment is intentionally blocked until deployable stacks exist.
	@echo "Terraform apply is out of scope for Stage 00 and requires explicit stage-specific implementation."
	@exit 1

docs: ## List Markdown documentation included in the current stage.
	@find README.md CONTRIBUTING.md docs plan -type f -name '*.md' | sort
