SCHEME       := Switch
APP          := Switch.app
DERIVED      := build/DerivedData
PRODUCT      := $(DERIVED)/Build/Products/Release/$(APP)
INSTALL_DIR  := $(HOME)/bin

.DEFAULT_GOAL := help
.PHONY: help test build install clean project

help:
	@echo "usage: make <\033[36mtarget\033[0m>"
	@echo
	@echo "available targets:"
	@grep -E '^[a-zA-Z._-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'

test: project ## Run the test suite
	xcodebuild test \
		-scheme $(SCHEME) \
		-destination 'platform=macOS'

build: project ## Build a release into ./build
	xcodebuild build \
		-scheme $(SCHEME) \
		-configuration Release \
		-destination 'platform=macOS' \
		-derivedDataPath $(DERIVED)

install: test build ## Test, build, and copy Switch.app to ~/bin
	mkdir -p $(INSTALL_DIR)
	rm -rf "$(INSTALL_DIR)/$(APP)"
	cp -R "$(PRODUCT)" "$(INSTALL_DIR)/$(APP)"
	@echo "Installed $(INSTALL_DIR)/$(APP)"

clean: ## Remove ./build
	rm -rf build

# Internal: regenerate Switch.xcodeproj from project.yml. A dependency of
# build/test, so it's not listed in help.
project:
	xcodegen generate
