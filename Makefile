# Task runner for terraform-aws-odcr-unused-alarm.
#
# Targets that act on a root configuration use TF_DIR, which defaults to the example. Point it
# at your own:
#
#   make plan TF_DIR=../my-infra

TF        ?= terraform
TFLINT    ?= tflint
TF_DIR    ?= examples/targeted-odcrs

EXAMPLES  := $(wildcard examples/*)

.DEFAULT_GOAL := help
.PHONY: help fmt fmt-check validate validate-examples test-tf lint docs docs-check \
        scan scan-report init plan apply output destroy clean

help: ## Show this help
	@grep -hE '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  TF_DIR is currently '$(TF_DIR)'."

# --- Gates. Every target in this section runs with no AWS credentials. --------

fmt: ## Rewrite all Terraform files in canonical format
	$(TF) fmt -recursive .

fmt-check: ## Fail if any Terraform file is not canonically formatted
	$(TF) fmt -check -recursive .

validate: ## Validate the module itself
	TF_DATA_DIR=.terraform/validate $(TF) init -backend=false -input=false >/dev/null
	TF_DATA_DIR=.terraform/validate $(TF) validate

validate-examples: ## Validate every root configuration under examples/
	@for d in $(EXAMPLES); do \
	  echo "== $$d"; \
	  ( cd $$d && TF_DATA_DIR=.terraform/validate $(TF) init -backend=false -input=false >/dev/null \
	    && TF_DATA_DIR=.terraform/validate $(TF) validate ) || exit 1; \
	done

test-tf: ## Run the plan-only Terraform tests
	# init is needed even though the tests mock the provider: mock_provider borrows the real
	# provider's schema, so the plugin still has to be installed. -backend=false keeps it
	# credential-free.
	$(TF) init -backend=false -input=false >/dev/null
	$(TF) test -test-directory=tests

lint: ## Run tflint against the module and the examples
	$(TFLINT) --init
	$(TFLINT) --recursive --config "$(CURDIR)/.tflint.hcl"

docs: ## Regenerate the README input and output tables. Commit the result.
	terraform-docs .

docs-check: ## Fail if the README tables are stale
	terraform-docs --output-check .

# --- Security scanning -------------------------------------------------------
# Same ASH setup as the sibling modules. No AWS credentials; needs network on first run because
# uvx fetches ASH and ASH fetches each scanner. Exit 2 means a finding at or above
# ASH_MIN_SEVERITY, and fails the target on purpose.

ASH_VERSION      ?= v3.7.0
ASH              ?= uvx --from git+https://github.com/awslabs/automated-security-helper.git@$(ASH_VERSION) ash
ASH_OUTPUT_DIR   ?= .ash/ash_output
ASH_MIN_SEVERITY ?= medium

scan: ## Run an ASH security scan in local mode
	$(ASH) --mode local \
	  --source-dir . \
	  --output-dir $(ASH_OUTPUT_DIR) \
	  --min-severity $(ASH_MIN_SEVERITY)

scan-report: ## Summarise the last scan's findings without re-scanning
	$(ASH) report --output-dir $(ASH_OUTPUT_DIR) --format markdown

# --- Apply and teardown ------------------------------------------------------
# A module is never applied directly. These act on TF_DIR.

init: ## terraform init in TF_DIR
	cd $(TF_DIR) && $(TF) init -input=false

plan: init ## terraform plan in TF_DIR
	cd $(TF_DIR) && $(TF) plan

apply: init ## terraform apply in TF_DIR, interactively
	@echo "Creates CloudWatch alarms (billed per alarm per month) and an SNS topic."
	@echo "Email subscriptions receive nothing until each address confirms."
	@echo ""
	cd $(TF_DIR) && $(TF) apply

output: ## terraform output for TF_DIR
	cd $(TF_DIR) && $(TF) output

destroy: ## terraform destroy for TF_DIR
	cd $(TF_DIR) && $(TF) destroy

clean: ## Remove validation state and scan output
	rm -rf .terraform/validate examples/*/.terraform $(ASH_OUTPUT_DIR)
