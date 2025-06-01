#!/usr/bin/env lua

-- Comprehensive test runner for todo-mcp.nvim
-- Run with: lua tests/run_all_tests.lua

-- Load our minimal test framework
require("tests.minimal_test_framework")

local test_files = {
  "config_validation_spec.lua",
  "syntax_validation_spec.lua", 
  "ui_rendering_spec.lua",
  "migration_compatibility_spec.lua",
  "integration_spec.lua"
}

print("=== Running todo-mcp.nvim test suite ===")
print("(Using minimal test framework)\n")

local total_passed = 0
local total_failed = 0
local all_errors = {}

-- Run each test file
for _, test_file in ipairs(test_files) do
  print("Running " .. test_file .. "...")
  
  -- Reset test results
  local framework = require("tests.minimal_test_framework")
  framework.results = {
    passed = 0,
    failed = 0,
    errors = {}
  }
  
  -- Run the test file
  local ok, result = pcall(dofile, "tests/" .. test_file)
  
  if ok then
    local results = framework.results
    total_passed = total_passed + results.passed
    total_failed = total_failed + results.failed
    
    if #results.errors > 0 then
      for _, err in ipairs(results.errors) do
        table.insert(all_errors, {
          file = test_file,
          test = err.test or err.suite,
          error = err.error
        })
      end
    end
    
    print(string.format("  Results: %d passed, %d failed", 
      results.passed, results.failed))
  else
    print("✗ " .. test_file .. " failed to load:")
    print("  " .. tostring(result))
    total_failed = total_failed + 1
    table.insert(all_errors, {file = test_file, error = result})
  end
  
  print("")
end

print("=== Test Summary ===")
print(string.format("Total: %d | Passed: %d | Failed: %d", 
  total_passed + total_failed, total_passed, total_failed))

if #all_errors > 0 then
  print("\n=== Failed Tests ===")
  for _, err in ipairs(all_errors) do
    if err.test then
      print(err.file .. " - " .. err.test .. ":")
    else
      print(err.file .. ":")
    end
    print("  " .. tostring(err.error))
  end
  os.exit(1)
else
  print("\n✅ All tests passed!")
  os.exit(0)
end