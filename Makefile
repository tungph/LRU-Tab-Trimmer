# Makefile for LRU Tab Trimmer Firefox Extension
# Usage: make [target]

# Variables
EXTENSION_NAME = lru-tab-trimmer
VERSION = $(shell grep '"version"' manifest.json | cut -d '"' -f 4)
BUILD_DIR = build
DIST_DIR = dist
SRC_FILES = manifest.json \
	background.js \
	firefox.js \
	hidden.js \
	menu.js \
	plugins.js \
	schema.json \
	$(wildcard modes/*.js) \
	$(wildcard plugins/**/*.js) \
	$(wildcard data/**/*) \
	$(wildcard _locales/**/*) \
	$(wildcard data/icons/**/*.png)

# Firefox specific
FIREFOX_PROFILE ?= development
WEB_EXT = web-ext

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
NC = \033[0m # No Color

.PHONY: all help clean build test run lint package install watch dev

# Default target
all: help

# Help target
help:
	@echo "$(GREEN)LRU Tab Trimmer Firefox Extension - Makefile$(NC)"
	@echo ""
	@echo "Available targets:"
	@echo "  $(YELLOW)dev$(NC)        - Run extension in Firefox with auto-reload"
	@echo "  $(YELLOW)run$(NC)        - Run extension in Firefox (temporary install)"
	@echo "  $(YELLOW)build$(NC)      - Build the extension"
	@echo "  $(YELLOW)package$(NC)    - Create .xpi file for distribution"
	@echo "  $(YELLOW)lint$(NC)       - Lint the extension code"
	@echo "  $(YELLOW)clean$(NC)      - Clean build artifacts"
	@echo "  $(YELLOW)test$(NC)       - Run tests"
	@echo "  $(YELLOW)watch$(NC)      - Watch for changes and auto-reload"
	@echo "  $(YELLOW)validate$(NC)   - Validate manifest and structure"
	@echo "  $(YELLOW)sign$(NC)       - Sign the extension (requires API keys)"
	@echo ""
	@echo "Usage: make [target]"

# Clean build artifacts
clean:
	@echo "$(YELLOW)Cleaning build artifacts...$(NC)"
	@rm -rf $(BUILD_DIR) $(DIST_DIR)
	@rm -f *.xpi
	@rm -f web-ext-artifacts/*.xpi
	@echo "$(GREEN)✓ Cleaned$(NC)"

# Build the extension
build: clean
	@echo "$(YELLOW)Building extension...$(NC)"
	@mkdir -p $(BUILD_DIR)
	@cp -r manifest.json $(BUILD_DIR)/
	@cp -r *.js $(BUILD_DIR)/ 2>/dev/null || true
	@cp -r schema.json $(BUILD_DIR)/
	@cp -r modes $(BUILD_DIR)/
	@cp -r plugins $(BUILD_DIR)/
	@cp -r data $(BUILD_DIR)/
	@cp -r _locales $(BUILD_DIR)/
	@echo "$(GREEN)✓ Build complete in $(BUILD_DIR)/$(NC)"

# Package the extension as .xpi
package: build
	@echo "$(YELLOW)Creating extension package...$(NC)"
	@mkdir -p $(DIST_DIR)
	@cd $(BUILD_DIR) && zip -r ../$(DIST_DIR)/$(EXTENSION_NAME)-$(VERSION).xpi * \
		-x "*.DS_Store" \
		-x "*/.git/*" \
		-x "*/node_modules/*" \
		-x "*/.*"
	@echo "$(GREEN)✓ Package created: $(DIST_DIR)/$(EXTENSION_NAME)-$(VERSION).xpi$(NC)"
	@echo "  Size: $$(du -h $(DIST_DIR)/$(EXTENSION_NAME)-$(VERSION).xpi | cut -f1)"

# Run extension in Firefox (requires web-ext)
run:
	@echo "$(YELLOW)Starting Firefox with extension...$(NC)"
	@command -v $(WEB_EXT) >/dev/null 2>&1 || { \
		echo "$(RED)Error: web-ext is not installed$(NC)"; \
		echo "Install with: npm install -g web-ext"; \
		exit 1; \
	}
	@$(WEB_EXT) run --firefox-profile=$(FIREFOX_PROFILE) --browser-console

# Development mode with auto-reload
dev:
	@echo "$(YELLOW)Starting development mode with auto-reload...$(NC)"
	@command -v $(WEB_EXT) >/dev/null 2>&1 || { \
		echo "$(RED)Error: web-ext is not installed$(NC)"; \
		echo "Install with: npm install -g web-ext"; \
		exit 1; \
	}
	@$(WEB_EXT) run --firefox-profile=$(FIREFOX_PROFILE) --browser-console --watch-file . --reload

# Watch for changes
watch:
	@echo "$(YELLOW)Watching for changes...$(NC)"
	@command -v $(WEB_EXT) >/dev/null 2>&1 || { \
		echo "$(RED)Error: web-ext is not installed$(NC)"; \
		echo "Install with: npm install -g web-ext"; \
		exit 1; \
	}
	@$(WEB_EXT) run --firefox-profile=$(FIREFOX_PROFILE) --watch-file . --reload

# Lint the extension
lint:
	@echo "$(YELLOW)Linting extension...$(NC)"
	@command -v $(WEB_EXT) >/dev/null 2>&1 || { \
		echo "$(RED)Error: web-ext is not installed$(NC)"; \
		echo "Install with: npm install -g web-ext"; \
		exit 1; \
	}
	@$(WEB_EXT) lint --ignore-files "*.md" "Makefile" "misc/*" ".git/*"
	@echo "$(GREEN)✓ Linting complete$(NC)"

# Validate manifest and structure
validate:
	@echo "$(YELLOW)Validating extension structure...$(NC)"
	@if [ ! -f manifest.json ]; then \
		echo "$(RED)✗ manifest.json not found$(NC)"; \
		exit 1; \
	fi
	@python3 -m json.tool manifest.json > /dev/null 2>&1 || { \
		echo "$(RED)✗ manifest.json is not valid JSON$(NC)"; \
		exit 1; \
	}
	@echo "$(GREEN)✓ manifest.json is valid$(NC)"
	@if [ ! -d _locales ]; then \
		echo "$(RED)✗ _locales directory not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ _locales directory exists$(NC)"
	@if [ ! -f background.js ]; then \
		echo "$(RED)✗ background.js not found$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)✓ background.js exists$(NC)"
	@echo "$(GREEN)✓ Extension structure is valid$(NC)"

# Sign the extension (requires Mozilla API keys)
sign: package
	@echo "$(YELLOW)Signing extension...$(NC)"
	@if [ -z "$${AMO_JWT_ISSUER}" ] || [ -z "$${AMO_JWT_SECRET}" ]; then \
		echo "$(RED)Error: AMO_JWT_ISSUER and AMO_JWT_SECRET environment variables must be set$(NC)"; \
		echo "Get your API keys from: https://addons.mozilla.org/developers/addon/api/key/"; \
		exit 1; \
	fi
	@$(WEB_EXT) sign --api-key=$${AMO_JWT_ISSUER} --api-secret=$${AMO_JWT_SECRET} \
		--source-dir=$(BUILD_DIR) \
		--artifacts-dir=$(DIST_DIR)
	@echo "$(GREEN)✓ Extension signed$(NC)"

# Install web-ext tool
install-tools:
	@echo "$(YELLOW)Installing development tools...$(NC)"
	@command -v npm >/dev/null 2>&1 || { \
		echo "$(RED)Error: npm is not installed$(NC)"; \
		echo "Please install Node.js and npm first"; \
		exit 1; \
	}
	npm install -g web-ext
	@echo "$(GREEN)✓ web-ext installed$(NC)"

# Test the extension (placeholder for actual tests)
test: validate lint
	@echo "$(YELLOW)Running tests...$(NC)"
	@echo "$(YELLOW)Note: Add your test suite here$(NC)"
	@# Add test commands here when you have tests
	@echo "$(GREEN)✓ Tests passed$(NC)"

# Quick reload for development
reload:
	@echo "$(YELLOW)Reloading extension...$(NC)"
	@osascript -e 'tell application "Firefox" to activate' 2>/dev/null || true
	@osascript -e 'tell application "System Events" to keystroke "r" using {command down, shift down}' 2>/dev/null || true
	@echo "$(GREEN)✓ Reload command sent$(NC)"

# Open Firefox extension debugging page
debug:
	@echo "$(YELLOW)Opening Firefox debugging page...$(NC)"
	@open -a Firefox "about:debugging#/runtime/this-firefox" 2>/dev/null || \
		firefox "about:debugging#/runtime/this-firefox" 2>/dev/null || \
		echo "$(RED)Could not open Firefox$(NC)"

# Check for common issues
doctor:
	@echo "$(YELLOW)Checking environment...$(NC)"
	@echo -n "Checking for web-ext... "
	@command -v web-ext >/dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗ (run 'make install-tools')$(NC)"
	@echo -n "Checking for Firefox... "
	@command -v firefox >/dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo -n "Checking for npm... "
	@command -v npm >/dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo -n "Checking for Python3... "
	@command -v python3 >/dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo -n "Checking manifest.json... "
	@python3 -m json.tool manifest.json > /dev/null 2>&1 && echo "$(GREEN)✓$(NC)" || echo "$(RED)✗$(NC)"
	@echo ""
	@echo "$(GREEN)Environment check complete$(NC)"

# Create a development profile for Firefox
create-profile:
	@echo "$(YELLOW)Creating Firefox development profile...$(NC)"
	@firefox -CreateProfile "$(FIREFOX_PROFILE) $$(pwd)/firefox-profile" 2>/dev/null || \
		echo "$(RED)Could not create profile. Firefox may not be installed.$(NC)"
	@echo "$(GREEN)✓ Profile created: $(FIREFOX_PROFILE)$(NC)"

# Statistics about the codebase
stats:
	@echo "$(YELLOW)Extension Statistics:$(NC)"
	@echo "  Version: $(VERSION)"
	@echo "  JavaScript files: $$(find . -name '*.js' -not -path './build/*' -not -path './dist/*' -not -path './node_modules/*' | wc -l)"
	@echo "  Total lines of code: $$(find . -name '*.js' -not -path './build/*' -not -path './dist/*' -not -path './node_modules/*' | xargs wc -l | tail -1 | awk '{print $$1}')"
	@echo "  Locales: $$(ls -d _locales/*/ 2>/dev/null | wc -l)"
	@echo "  Size (uncompressed): $$(du -sh . --exclude=build --exclude=dist --exclude=.git 2>/dev/null | cut -f1 || du -sh . | cut -f1)"

# Update version in manifest.json
version:
	@if [ -z "$(NEW_VERSION)" ]; then \
		echo "$(RED)Error: NEW_VERSION not specified$(NC)"; \
		echo "Usage: make version NEW_VERSION=1.0.1"; \
		exit 1; \
	fi
	@echo "$(YELLOW)Updating version to $(NEW_VERSION)...$(NC)"
	@sed -i.bak 's/"version": ".*"/"version": "$(NEW_VERSION)"/' manifest.json
	@rm manifest.json.bak
	@echo "$(GREEN)✓ Version updated to $(NEW_VERSION)$(NC)"
