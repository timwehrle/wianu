PROJECT ?= Wianu.xcodeproj
SCHEME ?= Wianu
CONFIGURATION ?= Debug
DESTINATION ?= platform=macOS
DERIVED_DATA ?= DerivedData

XCODEBUILD := xcodebuild -project $(PROJECT) -scheme $(SCHEME)
APP_JAVASCRIPT := Wianu/Features/Browser/Scripts Wianu/Features/ContinueWatching/Scripts
PRETTIER := Website/node_modules/.bin/prettier
ESLINT := Website/node_modules/.bin/eslint

.DEFAULT_GOAL := help

.PHONY: help build test check format format-check lint resolve clean open web dmg
.PHONY: js-tools js-format js-format-check js-lint js-check

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

format: js-format ## Format Swift and bundled JavaScript
	@command -v swiftformat >/dev/null || { echo "swiftformat is required (brew install swiftformat)" >&2; exit 1; }
	swiftformat .

format-check: js-format-check ## Check Swift and bundled JavaScript formatting
	@command -v swiftformat >/dev/null || { echo "swiftformat is required (brew install swiftformat)" >&2; exit 1; }
	swiftformat . --lint

lint: js-lint ## Lint Swift and bundled JavaScript
	@command -v swiftlint >/dev/null || { echo "swiftlint is required (brew install swiftlint)" >&2; exit 1; }
	swiftlint lint --strict

js-tools:
	@test -x "$(PRETTIER)" -a -x "$(ESLINT)" || { echo "Install JS tools: pnpm --dir Website install --frozen-lockfile" >&2; exit 1; }

js-format: js-tools ## Format bundled JavaScript using the website's Prettier style
	$(PRETTIER) --config prettier.config.mjs --write $(APP_JAVASCRIPT) prettier.config.mjs eslint.config.mjs Website/eslint.app.config.js

js-format-check: js-tools ## Check bundled JavaScript formatting
	$(PRETTIER) --config prettier.config.mjs --check $(APP_JAVASCRIPT) prettier.config.mjs eslint.config.mjs Website/eslint.app.config.js

js-lint: js-tools ## Lint bundled browser JavaScript
	$(ESLINT) --max-warnings 0 $(APP_JAVASCRIPT)

js-check: js-format-check js-lint ## Check bundled JavaScript formatting and lint

resolve: ## Resolve Swift package dependencies
	$(XCODEBUILD) -resolvePackageDependencies

clean: ## Remove Xcode build products
	$(XCODEBUILD) clean -derivedDataPath "$(DERIVED_DATA)"

open: ## Open the project in Xcode
	open "$(PROJECT)"

web: ## Start the SvelteKit development server
	cd Website && pnpm run dev --host
DMG_APP ?= $(DERIVED_DATA)/Build/Products/$(CONFIGURATION)/Wianu.app
DMG_OUTPUT ?= /tmp/Wianu-preview.dmg

dmg: ## Package an existing app with the DMG layout
	bash Scripts/create-dmg.sh "$(DMG_APP)" "$(DMG_OUTPUT)"
