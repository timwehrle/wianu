PROJECT ?= Wianu.xcodeproj
SCHEME ?= Wianu
CONFIGURATION ?= Debug
DESTINATION ?= platform=macOS
DERIVED_DATA ?= DerivedData

XCODEBUILD = xcodebuild -project "$(PROJECT)" -scheme "$(SCHEME)" \
	-configuration "$(CONFIGURATION)" -destination "$(DESTINATION)" \
	-derivedDataPath "$(DERIVED_DATA)" CODE_SIGNING_ALLOWED=NO
JS_SCRIPTS = Wianu/Features/Browser/Scripts Wianu/Features/ContinueWatching/Scripts
JS_CONFIG = prettier.config.mjs eslint.config.mjs package.json pnpm-workspace.yaml
PRETTIER = node_modules/.bin/prettier --config prettier.config.mjs
ESLINT = node_modules/.bin/eslint

.DEFAULT_GOAL := help
.PHONY: help build test format lint check clean js-check

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-10s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the app without code signing
	$(XCODEBUILD) build

test: ## Run the test suite
	$(XCODEBUILD) test

format: ## Format Swift and JavaScript
	$(ESLINT) --fix $(JS_SCRIPTS)
	$(PRETTIER) --write $(JS_SCRIPTS) $(JS_CONFIG)
	swiftformat .

js-check:
	$(PRETTIER) --check $(JS_SCRIPTS) $(JS_CONFIG)
	$(ESLINT) --max-warnings 0 $(JS_SCRIPTS)

lint: js-check ## Check formatting and lint Swift and JavaScript
	swiftformat . --lint
	swiftlint lint --strict

check: lint test ## Run all checks

clean: ## Remove Xcode build products
	$(XCODEBUILD) clean
