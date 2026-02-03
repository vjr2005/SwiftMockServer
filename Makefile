.PHONY: bootstrap setup generate edit build test clean graph spm-build spm-test help

# ─────────────────────────────────────────────
# Bootstrap (first time)
# ─────────────────────────────────────────────

## Full environment setup from scratch (mise + tuist + project)
bootstrap:
	@./scripts/bootstrap.sh

# ─────────────────────────────────────────────
# mise + Tuist
# ─────────────────────────────────────────────

## Install tools with mise and initialize the project
setup:
	mise install
	mise run setup

## Generate the Xcode project (.xcodeproj / .xcworkspace)
generate:
	mise run generate

## Open Tuist manifests in Xcode for editing
edit:
	mise run edit

## Build the framework
build:
	mise run build

## Run the tests
test:
	mise run test

## Clean generated artifacts
clean:
	mise run clean

## Display the dependency graph
graph:
	mise run graph

# ─────────────────────────────────────────────
# SPM (direct compatibility without Tuist)
# ─────────────────────────────────────────────

## Build using Swift Package Manager directly
spm-build:
	swift build

## Run tests using Swift Package Manager
spm-test:
	swift test

# ─────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────

## Show this help
help:
	@echo ""
	@echo "  SwiftMockServer - Available commands"
	@echo "  ─────────────────────────────────────────"
	@echo ""
	@echo "  make bootstrap → Full setup (mise + tuist + generate project)"
	@echo "  make setup     → Install tools with mise + generate project"
	@echo "  make generate  → Generate .xcodeproj / .xcworkspace"
	@echo "  make edit      → Edit Tuist manifests in Xcode"
	@echo "  make build     → Build the framework"
	@echo "  make test      → Run the tests"
	@echo "  make clean     → Clean generated artifacts"
	@echo "  make graph     → Display dependency graph"
	@echo "  make spm-build → Build with SPM directly"
	@echo "  make spm-test  → Test with SPM directly"
	@echo ""
	@echo "  You can also use mise directly:"
	@echo "    mise run setup / generate / build / test / clean / graph"
	@echo ""
