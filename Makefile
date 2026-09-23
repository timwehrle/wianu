PROJECT ?= Wianu.xcodeproj
SCHEME ?= Wianu
CONFIGURATION ?= Debug
DESTINATION ?= platform=macOS
DERIVED_DATA ?= DerivedData

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME)

.DEFAULT_GOAL := help

.PHONY: help build test check format format-check lint resolve clean open

help: ## Show the available commands
	@awk 'BEGIN {FS = ":.*## "; printf "Usage: make <target>\n\nTargets:\n"} /^[a-zA-Z0-9_-]+:.*## / {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the app without code signing
	$(XCODEBUILD) build \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO

test: ## Run the test suite
	$(XCODEBUILD) test \
		-configuration "$(CONFIGURATION)" \
		-destination "$(DESTINATION)" \
		-derivedDataPath "$(DERIVED_DATA)" \
		CODE_SIGNING_ALLOWED=NO

check: format-check lint test ## Run all checks used before submitting a change

format: ## Format Swift source files
	@command -v swiftformat >/dev/null || { echo "swiftformat is required (brew install swiftformat)" >&2; exit 1; }
	swiftformat .

format-check: ## Check Swift formatting without changing files
	@command -v swiftformat >/dev/null || { echo "swiftformat is required (brew install swiftformat)" >&2; exit 1; }
	swiftformat . --lint

lint: ## Run SwiftLint in strict mode
	@command -v swiftlint >/dev/null || { echo "swiftlint is required (brew install swiftlint)" >&2; exit 1; }
	swiftlint lint --strict

resolve: ## Resolve Swift package dependencies
	$(XCODEBUILD) -resolvePackageDependencies

clean: ## Remove Xcode build products
	$(XCODEBUILD) clean -derivedDataPath "$(DERIVED_DATA)"

open: ## Open the project in Xcode
	open "$(PROJECT)"

web: ## Start the SvelteKit development server
	cd Website && pnpm run dev --host