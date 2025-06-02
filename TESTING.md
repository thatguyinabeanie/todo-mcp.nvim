# Testing Guide

This document explains how to run and write tests for todo-mcp.nvim.
# TODO: update testing guide
## Overview

The test suite focuses on critical integrations and happy paths for our new functionality:

- **MCP Server Integration** - Core protocol functionality
- **Todo-Comments Integration** - Bidirectional sync between comments and database
- **AI Features** - Context detection and smart estimation
- **External Integrations** - GitHub, Linear, JIRA connectivity
- **Database Operations** - New features like external sync and metadata

## Running Tests

### Prerequisites

```bash
# Install test dependencies
make install-deps

# Or manually:
luarocks install luacheck  # Optional, for linting
sudo apt-get install sqlite3 libsqlite3-dev  # For database tests
```

### Quick Test Commands

```bash
# Run all tests
make test

# Run specific test suites
make test-mcp           # MCP server tests
make test-integration   # Integration tests  
make test-ai           # AI feature tests
make test-db           # Database tests

# Run linting
make lint

# Clean test artifacts
make clean
```

### Development Workflow

```bash
# Quick tests for development
make test-quick

# Watch mode (requires entr)
make test-watch
```

### Manual Test Runner

```bash
# Run specific test files
lua tests/run_tests.lua mcp_server
lua tests/run_tests.lua todo_comments

# Run all tests matching pattern
lua tests/run_tests.lua integration
```

## Test Structure

### Test Files

```
tests/
├── run_tests.lua              # Test runner and framework
├── helpers.lua                # Test utilities and mocks
├── mcp_server_spec.lua         # MCP protocol tests
├── todo_comments_integration_spec.lua  # Todo-comments sync tests
├── ai_integration_spec.lua     # AI feature tests
├── external_integration_spec.lua       # External system tests
└── database_spec.lua           # Database operation tests
```

### Test Categories

**1. MCP Server Tests**
- Server initialization and capability negotiation
- Tool listing and invocation
- Todo CRUD operations via MCP
- Search functionality
- Error handling

**2. Todo-Comments Integration Tests**
- TODO detection at cursor position
- Tracking TODOs and creating database entries
- Priority mapping (FIXME → high, TODO → medium)
- Context detection (file type, git branch)
- Virtual text indicators
- Bidirectional sync status

**3. AI Integration Tests**
- File structure pattern detection
- Code context analysis from surrounding lines
- Priority estimation based on content
- Effort estimation with story points
- Enhanced tracking with AI insights
- Batch analysis and re-prioritization

**4. External Integration Tests**
- Integration availability detection
- Priority/status mapping between systems
- Tag extraction from external issues
- External metadata handling
- Error handling for API failures

**5. Database Tests**
- Basic CRUD operations
- JSON metadata storage and retrieval
- External sync metadata queries
- Status change event triggering
- Search and filtering
- Schema migration support

## Writing Tests

### Test Structure

```lua
-- tests/example_spec.lua
local helpers = require('tests.helpers')

describe("Feature Name", function()
  before_each(function()
    helpers.setup_test_env()
  end)
  
  after_each(function()
    helpers.cleanup_test_env()
  end)
  
  describe("specific functionality", function()
    it("should do something", function()
      -- Test code here
      assert.equals("expected", actual)
    end)
  end)
end)
```

### Available Assertions

```lua
assert.equals(expected, actual)
assert.is_true(value)
assert.is_false(value)
assert.is_nil(value)
assert.is_not_nil(value)
assert.is_number(value)
assert.is_table(value)
assert.matches(pattern, text)
assert.does_not_match(pattern, text)
assert.has_element(element, list)
```

### Test Helpers

```lua
local helpers = require('tests.helpers')

-- Environment setup
helpers.setup_test_env()    -- Clean database, reset state
helpers.cleanup_test_env()  -- Remove test files and database

-- File utilities
local file_path = helpers.create_test_file("test.js", {
  "// TODO: Example todo comment",
  "function example() {}"
})

-- MCP testing
local client = helpers.start_mcp_server()
helpers.initialize_mcp_client(client)
local response = client:send(mcp_request)
```

### Mocking External Dependencies

The test framework provides mocks for:

- **Vim APIs** - All vim.* functions
- **MCP Client** - Request/response simulation
- **File System** - File creation and reading
- **Network** - HTTP requests for external integrations

Example:
```lua
-- Mock MCP for testing external integrations
local mock_mcp = {
  call_tool = function(server, tool, args)
    return { success = true, issue = { number = 123 } }
  end
}
package.loaded['todo-mcp.mcp'] = mock_mcp
```

## Continuous Integration

Tests run automatically on:
- Push to `main` or `develop` branches
- Pull requests to `main`
- Multiple Lua versions (5.1, 5.2, 5.3, 5.4, LuaJIT)
- Multiple Neovim versions (stable, nightly)

See `.github/workflows/test.yml` for CI configuration.

## Test Philosophy

Our testing approach focuses on:

1. **Critical Path Coverage** - Test the most important user journeys
2. **Integration Testing** - Verify components work together
3. **Happy Path Focus** - Ensure core functionality works reliably
4. **MCP Protocol Compliance** - Validate MCP server behavior
5. **External API Simulation** - Mock external services for reliable testing

We don't aim for 100% coverage but prioritize testing:
- New features we built (AI, external sync, enterprise features)
- Integration points between components
- MCP protocol implementation
- Database operations with new schema

## Debugging Tests

### Verbose Output

```bash
# Add debug prints to test files
print("Debug: variable =", vim.inspect(variable))

# Run single test for debugging
lua tests/run_tests.lua specific_test
```

### Test Isolation

Each test runs in isolation with:
- Fresh test database
- Clean package cache
- Mocked external dependencies
- Temporary test files

### Common Issues

**Database Locks**
```bash
# Clean up test database if tests hang
rm /tmp/todo-mcp-test.db
```

**Package Loading**
```bash
# Clear Lua package cache if modules don't update
lua -e "package.loaded['todo-mcp.module'] = nil"
```

**File Permissions**
```bash
# Ensure test directory is writable
chmod +w tests/ /tmp/
```

## Performance Testing

While not included in the basic test suite, you can manually test performance:

```lua
-- Test database performance with large datasets
local db = require('todo-mcp.db')
local start_time = os.clock()

for i = 1, 1000 do
  db.add("Performance test " .. i, { priority = "medium" })
end

local end_time = os.clock()
print("Added 1000 todos in", end_time - start_time, "seconds")
```

## Contributing Tests

When adding new features:

1. **Write tests first** for new functionality
2. **Focus on integration points** between components
3. **Test error conditions** and edge cases
4. **Mock external dependencies** to avoid network calls
5. **Keep tests fast** - aim for <1 second per test file

Example test PR checklist:
- [ ] Tests cover happy path for new feature
- [ ] Integration tests verify component interaction
- [ ] Error cases are handled gracefully
- [ ] Tests run in isolation without side effects
- [ ] CI passes on all supported versions
