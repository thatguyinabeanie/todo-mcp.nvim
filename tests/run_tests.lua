#!/usr/bin/env lua

-- Test runner for todo-mcp.nvim
-- Usage: lua tests/run_tests.lua [test_pattern]

local function setup_test_environment()
  -- Add project root to package path
  local script_path = arg[0]
  local project_root = script_path:match("^(.*)/tests/") or script_path:match("^(.*)/")
  
  -- Debug path
  -- print("Script path:", script_path)
  -- print("Project root:", project_root)
  
  -- Always add both relative and absolute paths
  package.path = "lua/?.lua;lua/?/init.lua;tests/mocks/?.lua;" .. package.path
  
  if project_root then
    package.path = project_root .. "/lua/?.lua;" .. project_root .. "/lua/?/init.lua;" .. 
                   project_root .. "/tests/mocks/?.lua;" .. package.path
  end
  
  -- Mock vim APIs for testing
  _G.vim = {
    fn = {
      expand = function(path) return path:gsub("~", os.getenv("HOME") or "/tmp") end,
      mkdir = function(path, mode) os.execute("mkdir -p " .. path) end,
      bufnr = function(file) return file == "" and 0 or 1 end,
      shellescape = function(str) return "'" .. str:gsub("'", "'\"'\"'") .. "'" end,
      fnamemodify = function(path, modifier)
        if modifier == ":h" then
          return path:match("(.*)/") or "."
        elseif modifier == ":t" then
          return path:match("/([^/]*)$") or path
        elseif modifier == ":e" then
          return path:match("%.([^.]*)$") or ""
        end
        return path
      end,
      readfile = function(path)
        local file = io.open(path, "r")
        if not file then return {} end
        local lines = {}
        for line in file:lines() do
          table.insert(lines, line)
        end
        file:close()
        return lines
      end,
      filereadable = function(path)
        local file = io.open(path, "r")
        if file then
          file:close()
          return 1
        end
        return 0
      end,
      delete = function(path)
        os.remove(path)
      end,
      system = function(cmd)
        local handle = io.popen(cmd)
        if not handle then return "" end
        local result = handle:read("*a") or ""
        handle:close()
        return result
      end,
      systemlist = function(cmd)
        local result = _G.vim.fn.system(cmd)
        return vim.split(result, "\n")
      end,
      getcwd = function() return os.getenv("PWD") or "." end
    },
    
    api = {
      nvim_create_namespace = function(name) return math.random(1000, 9999) end,
      nvim_buf_set_extmark = function() end,
      nvim_buf_clear_namespace = function() end,
      nvim_buf_get_extmarks = function() return {} end,
      nvim_get_current_buf = function() return 1 end,
      nvim_buf_get_name = function() return "/tmp/test.lua" end,
      nvim_buf_get_lines = function() return {"-- test file"} end,
      nvim_win_get_cursor = function() return {1, 0} end,
      nvim_win_set_cursor = function() end,
      nvim_buf_line_count = function() return 10 end,
      nvim_create_autocmd = function() end,
      nvim_exec_autocmds = function() end,
      nvim_create_user_command = function() end,
      nvim_set_hl = function() end
    },
    
    cmd = function(command) 
      if command:match("^edit ") then
        -- Mock editing a file
      end
    end,
    
    wait = function(ms) 
      -- Mock wait function
    end,
    
    schedule = function(fn) 
      fn() -- Execute immediately in tests
    end,
    
    split = function(str, sep)
      local result = {}
      local pattern = string.format("([^%s]+)", sep)
      for match in str:gmatch(pattern) do
        table.insert(result, match)
      end
      return result
    end,
    
    tbl_extend = function(behavior, ...)
      local result = {}
      for i = 1, select("#", ...) do
        local tbl = select(i, ...)
        if tbl then
          for k, v in pairs(tbl) do
            if behavior == "force" or result[k] == nil then
              result[k] = v
            end
          end
        end
      end
      return result
    end,
    
    tbl_deep_extend = function(behavior, ...)
      local function deep_copy(tbl)
        if type(tbl) ~= "table" then
          return tbl
        end
        local copy = {}
        for k, v in pairs(tbl) do
          copy[k] = deep_copy(v)
        end
        return copy
      end
      
      local result = {}
      for i = 1, select("#", ...) do
        local tbl = select(i, ...)
        if tbl then
          for k, v in pairs(tbl) do
            if type(v) == "table" and type(result[k]) == "table" and behavior ~= "force" then
              result[k] = _G.vim.tbl_deep_extend(behavior, result[k], v)
            elseif behavior == "force" or result[k] == nil then
              result[k] = deep_copy(v)
            end
          end
        end
      end
      return result
    end,
    
    tbl_keys = function(tbl)
      local keys = {}
      for k, _ in pairs(tbl) do
        table.insert(keys, k)
      end
      return keys
    end,
    
    list_extend = function(list1, list2)
      for _, item in ipairs(list2) do
        table.insert(list1, item)
      end
      return list1
    end,
    
    json = {
      encode = function(obj)
        -- Simple JSON encoder for tests
        if type(obj) == "table" then
          local parts = {}
          local is_array = true
          for k, v in pairs(obj) do
            if type(k) ~= "number" then
              is_array = false
              break
            end
          end
          
          if is_array then
            for i, v in ipairs(obj) do
              table.insert(parts, _G.vim.json.encode(v))
            end
            return "[" .. table.concat(parts, ",") .. "]"
          else
            for k, v in pairs(obj) do
              table.insert(parts, '"' .. k .. '":' .. _G.vim.json.encode(v))
            end
            return "{" .. table.concat(parts, ",") .. "}"
          end
        elseif type(obj) == "string" then
          return '"' .. obj:gsub('"', '\\"') .. '"'
        elseif type(obj) == "number" or type(obj) == "boolean" then
          return tostring(obj)
        elseif obj == nil then
          return "null"
        end
        return '""'
      end,
      
      decode = function(str)
        -- Simple JSON decoder for tests
        -- This is a very basic implementation
        if str == "null" then return nil end
        if str == "true" then return true end
        if str == "false" then return false end
        if str:match("^%d+$") then return tonumber(str) end
        if str:match('^".*"$') then return str:sub(2, -2) end
        if str:match("^%{.*%}$") then
          local obj = {}
          -- Very basic object parsing
          local content = str:sub(2, -2)
          for key_val in content:gmatch('"([^"]+)":"?([^",}]*)"?') do
            local key, val = key_val:match('([^:]+):(.*)')
            if key and val then
              obj[key:gsub('"', '')] = val:gsub('"', '')
            end
          end
          return obj
        end
        return {}
      end
    },
    
    loop = {
      now = function() return os.time() * 1000 end
    },
    
    log = {
      levels = {
        ERROR = 1,
        WARN = 2,
        INFO = 3,
        DEBUG = 4
      }
    },
    
    notify = function(msg, level) 
      print("[NOTIFY] " .. msg)
    end,
    
    keymap = {
      set = function() end
    },
    
    defer_fn = function(fn, ms)
      fn() -- Execute immediately in tests
    end,
    
    v = {
      shell_error = 0
    }
  }
  
  -- Mock os.date for consistent testing
  local original_date = os.date
  os.date = function(format, time)
    if format == "%Y-%m-%d %H:%M:%S" then
      return "2024-01-01 12:00:00"
    end
    return original_date(format, time)
  end
end

local function run_test_file(test_file)
  print("Running " .. test_file .. "...")
  
  local success, err = pcall(dofile, test_file)
  
  if success then
    print("✓ " .. test_file .. " passed")
    return true
  else
    print("✗ " .. test_file .. " failed:")
    print("  " .. tostring(err))
    return false
  end
end

local function main()
  setup_test_environment()
  
  local test_pattern = arg[1] or "*"
  local test_dir = "tests"
  
  -- Find test files
  local test_files = {}
  local find_cmd = string.format('find %s -name "*%s*spec.lua" -type f', test_dir, test_pattern)
  local handle = io.popen(find_cmd)
  
  if handle then
    for line in handle:lines() do
      table.insert(test_files, line)
    end
    handle:close()
  end
  
  if #test_files == 0 then
    print("No test files found matching pattern: " .. test_pattern)
    return 1
  end
  
  print("Found " .. #test_files .. " test files")
  print("")
  
  local passed = 0
  local failed = 0
  
  for _, test_file in ipairs(test_files) do
    if run_test_file(test_file) then
      passed = passed + 1
    else
      failed = failed + 1
    end
    print("")
  end
  
  print("Results:")
  print("  Passed: " .. passed)
  print("  Failed: " .. failed)
  print("  Total:  " .. (passed + failed))
  
  return failed > 0 and 1 or 0
end

-- Simple assert library for tests
_G.assert = {
  equals = function(expected, actual)
    if expected ~= actual then
      error(string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
    end
  end,
  
  is_true = function(value)
    if value ~= true then
      error("Expected true, got " .. tostring(value))
    end
  end,
  
  is_false = function(value)
    if value ~= false then
      error("Expected false, got " .. tostring(value))
    end
  end,
  
  is_nil = function(value)
    if value ~= nil then
      error("Expected nil, got " .. tostring(value))
    end
  end,
  
  is_not_nil = function(value)
    if value == nil then
      error("Expected non-nil value")
    end
  end,
  
  is_number = function(value)
    if type(value) ~= "number" then
      error("Expected number, got " .. type(value))
    end
  end,
  
  is_table = function(value)
    if type(value) ~= "table" then
      error("Expected table, got " .. type(value))
    end
  end,
  
  matches = function(pattern, text)
    if not string.find(text or "", pattern) then
      error("Pattern '" .. pattern .. "' not found in: " .. tostring(text))
    end
  end,
  
  does_not_match = function(pattern, text)
    if string.find(text or "", pattern) then
      error("Pattern '" .. pattern .. "' unexpectedly found in: " .. tostring(text))
    end
  end,
  
  has_element = function(element, list)
    for _, item in ipairs(list) do
      if item == element then
        return
      end
    end
    error("Element '" .. tostring(element) .. "' not found in list")
  end,
  
  has_no_errors = function(fn)
    local success, err = pcall(fn)
    if not success then
      error("Expected no errors, got: " .. tostring(err))
    end
  end,
  
  is_function = function(value)
    if type(value) ~= "function" then
      error("Expected function, got " .. type(value))
    end
  end
}

-- Simple describe/it test framework
_G.describe = function(name, fn)
  print("  " .. name)
  -- Reset before_each and after_each for this describe block
  local saved_before_each = _G._before_each
  local saved_after_each = _G._after_each
  _G._before_each = nil
  _G._after_each = nil
  
  fn()
  
  -- Restore previous before_each and after_each
  _G._before_each = saved_before_each
  _G._after_each = saved_after_each
end

_G.it = function(name, fn)
  -- Run before_each if defined
  if _G._before_each then
    local setup_success, setup_err = pcall(_G._before_each)
    if not setup_success then
      error("before_each failed: " .. tostring(setup_err))
    end
  end
  
  -- Run the test
  local success, err = pcall(fn)
  
  -- Run after_each if defined
  if _G._after_each then
    pcall(_G._after_each)
  end
  
  if not success then
    error("Test '" .. name .. "' failed: " .. tostring(err))
  end
end

_G.before_each = function(fn)
  _G._before_each = fn
end

_G.after_each = function(fn)
  _G._after_each = fn
end

-- Run the tests
os.exit(main())