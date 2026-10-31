# Put flags in SHELL for compatibility with macOS GNU Make 3.81.
SHELL := /bin/bash -eu -o pipefail
.SHELLFLAGS := -c
.DEFAULT_GOAL := help

# Override with a local checkout, for example:
# make regenerate BOOTSTRAPPER='uv run --directory ../swift-package-generator-based-on-openapi swift-bootstrapper'
BOOTSTRAPPER ?= uvx --refresh --from git+https://github.com/atacan/swift-package-generator-based-on-openapi.git swift-bootstrapper
INTERACTIONS_OPENAPI_URL := https://ai.google.dev/static/api/interactions.openapi.json
OPENAPI_URL := https://generativelanguage.googleapis.com/$$discovery/OPENAPI3_0?version=v1beta

.PHONY: help download-discovery-openapi download-interactions-openapi test-generation download-openapi regenerate prepare-openapi generate generate-openapi overlay-openapi build test test-offline format clean_spm_cache

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "} /^[a-zA-Z_-]+:.*## / {printf "  %-22s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

download-openapi: download-discovery-openapi download-interactions-openapi ## Download both official specs (no API key needed)

download-discovery-openapi: ## Download the Discovery spec
	@tmp=$$(mktemp .original-openapi.XXXXXX); \
	trap 'rm -f "$$tmp" "$$tmp.sorted"' EXIT; \
	curl --fail --silent --show-error --location '$(OPENAPI_URL)' -o "$$tmp"; \
	python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert "openapi" in s and "paths" in s and "components" in s, "Invalid OpenAPI document"' "$$tmp"; \
	python3 -m json.tool --sort-keys "$$tmp" > "$$tmp.sorted"; \
	mv "$$tmp.sorted" specifications/discovery/original_openapi.json

download-interactions-openapi: ## Download the beta Interactions spec
	@tmp=$$(mktemp .original-openapi.XXXXXX); \
	trap 'rm -f "$$tmp" "$$tmp.sorted"' EXIT; \
	curl --fail --silent --show-error --location '$(INTERACTIONS_OPENAPI_URL)' -o "$$tmp"; \
	python3 -c 'import json,sys; s=json.load(open(sys.argv[1])); assert "openapi" in s and "paths" in s and "components" in s, "Invalid OpenAPI document"' "$$tmp"; \
	python3 -m json.tool --sort-keys "$$tmp" > "$$tmp.sorted"; \
	mv "$$tmp.sorted" specifications/interactions/original_openapi.json

regenerate: ## Sanitize both inputs, merge, and regenerate Swift
	@mkdir -p .generation
	$(BOOTSTRAPPER) transform specifications/discovery/original_openapi.json .generation/discovery.json --overlay specifications/discovery/openapi-overlay.json
	$(BOOTSTRAPPER) transform specifications/interactions/original_openapi.json .generation/interactions.json --overlay specifications/interactions/openapi-overlay.json
	python3 scripts/merge_openapi.py .generation/discovery.json .generation/interactions.json original_openapi.json
	$(BOOTSTRAPPER) bootstrap '$(CURDIR)'

prepare-openapi: download-openapi ## Download the latest spec and regenerate Swift
	$(MAKE) regenerate

# Compatibility aliases always start from the original to avoid accumulating overlays.
generate generate-openapi overlay-openapi: regenerate

build: ## Build all products
	swift build

test: ## Run tests; live tests require RUN_LIVE_TESTS=1 and GEMINI_API_KEY
	swift test

test-generation: ## Verify schema composition and generation inputs
	python3 -m unittest discover -s scripts/tests -v

test-offline: test-generation ## Run offline tests with live API tests disabled
	RUN_LIVE_TESTS=0 swift test

format: ## Format handwritten Swift
	find Sources Tests -name '*.swift' -not -path '*/GeneratedSources/*' -print0 | xargs -0 swift-format -i --configuration .swift-format

clean_spm_cache:
	swift package purge-cache

.PHONY: merge_main check_uncommitted
# Existing repository maintenance shortcuts.
check_uncommitted:
	@git diff-index --quiet HEAD -- || (echo 'Uncommitted changes detected. Aborting.'; exit 1)

merge_main:
	$(eval BRANCH := $(shell git branch --show-current))
	git checkout main
	git merge $(BRANCH)
	git push
