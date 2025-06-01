#!/usr/bin/env lua

-- Comprehensive test runner for todo-mcp.nvim
-- Run with: lua tests/run_all_tests.lua

local test_files = {
  "config_validation_spec.lua",
  "syntax_validation_spec.lua", 
  "ui_rendering_spec.lua",
  "migration_compatibility_spec.lua",
  "integration_spec.lua"
}

print("=== Running todo-mcp.nvim test suite ===\n")

local total_tests = 0
local passed_tests = 0
local failed_tests = 0
local errors = {}

-- Simple test runner without external dependencies
for _, test_file in ipairs(test_files) do
  print("Running " .. test_file .. "...")
  
  local ok, result = pcall(dofile, "tests/" .. test_file)
  
  if ok then
    print("✓ " .. test_file .. " passed")
    passed_tests = passed_tests + 1
  else
    print("✗ " .. test_file .. " failed:")
    print("  " .. tostring(result))
    failed_tests = failed_tests + 1
    table.insert(errors, {file = test_file, error = result})
  end
  
  total_tests = total_tests + 1
  print("")
end

print("=== Test Summary ===")
print(string.format("Total: %d | Passed: %d | Failed: %d", 
  total_tests, passed_tests, failed_tests))

if #errors > 0 then
  print("\n=== Errors ===")
  for _, err in ipairs(errors) do
    print(err.file .. ":")
    print("  " .. tostring(err.error))
  end
  os.exit(1)
else
  print("\n✅ All tests passed!")
  os.exit(0)
end