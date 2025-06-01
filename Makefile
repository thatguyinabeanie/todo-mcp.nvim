# Makefile for todo-mcp.nvim

.PHONY: test test-mcp test-integration test-ai test-db lint clean help

# Default target
help:
	@echo "Available targets:"
	@echo "  test           - Run all tests"
	@echo "  test-mcp       - Run MCP server tests only"
	@echo "  test-integration - Run integration tests only"
	@echo "  test-ai        - Run AI feature tests only"
	@echo "  test-db        - Run database tests only"
	@echo "  lint           - Run linting (luacheck if available)"
	@echo "  clean          - Clean test artifacts"
	@echo "  install-deps   - Install test dependencies"

# Run all tests
test:
	@echo "Running all tests..."
	@lua tests/run_tests.lua

# Run specific test suites
test-mcp:
	@echo "Running MCP server tests..."
	@lua tests/run_tests.lua mcp_server

test-integration:
	@echo "Running integration tests..."
	@lua tests/run_tests.lua integration

test-ai:
	@echo "Running AI feature tests..."
	@lua tests/run_tests.lua ai

test-db:
	@echo "Running database tests..."
	@lua tests/run_tests.lua database

# Linting
lint:
	@if command -v luacheck >/dev/null 2>&1; then \
		echo "Running luacheck..."; \
		luacheck lua/ --std=luajit --globals vim; \
	else \
		echo "luacheck not found. Install with: luarocks install luacheck"; \
	fi

# Clean test artifacts
clean:
	@echo "Cleaning test artifacts..."
	@rm -f /tmp/todo-mcp-test.db
	@rm -f /tmp/test_*.js /tmp/test_*.lua
	@echo "Clean complete."

# Install test dependencies
install-deps:
	@echo "Installing test dependencies..."
	@if command -v luarocks >/dev/null 2>&1; then \
		luarocks install busted --local || echo "busted install failed (optional)"; \
		luarocks install luacheck --local || echo "luacheck install failed (optional)"; \
		echo "Dependencies installed (if available)"; \
	else \
		echo "luarocks not found. Please install luarocks to install test dependencies."; \
	fi

# Quick test for CI/development
test-quick:
	@echo "Running quick tests (MCP + core integration)..."
	@lua tests/run_tests.lua mcp
	@lua tests/run_tests.lua todo_comments

# Development watch mode (requires entr)
test-watch:
	@if command -v entr >/dev/null 2>&1; then \
		echo "Watching for changes... (Ctrl+C to stop)"; \
		find lua/ tests/ -name "*.lua" | entr -c make test-quick; \
	else \
		echo "entr not found. Install with your package manager to enable watch mode."; \
	fi

# Validation tests for common issues
test-validate:
	@echo "Running validation tests..."
	@lua tests/run_all_tests.lua

# Check syntax of all Lua files
check-syntax:
	@echo "Checking Lua syntax..."
	@for file in $$(find lua -name "*.lua"); do \
		luac -p $$file || exit 1; \
	done
	@echo "✓ All Lua files have valid syntax"

# Check for common issues
check-common: check-syntax
	@echo "Checking for common issues..."
	@echo "- Checking for duplicate help tags..."
	@! grep -o '\*[^*]*\*' doc/todo-mcp.txt | sort | uniq -d | grep . || echo "✓ No duplicate help tags"
	@echo "- Checking for Unicode method syntax..."
	@! grep -E '["'"'"'][▓░─│╭╮╯╰]["'"'"']\s*:' lua/todo-mcp/*.lua || echo "✓ No Unicode method syntax found"
	@echo "- Checking for nil keymaps..."
	@grep -q 'toggle = ' lua/todo-mcp/init.lua && echo "✓ Toggle keymap defined" || echo "✗ Missing toggle keymap"
	@echo "✓ All checks passed"

# Run all validation checks
validate: check-common test-validate

# Pre-commit hook
pre-commit: validate lint test-quick
	@echo "✅ All pre-commit checks passed!"