-- Minimal test framework for todo-mcp.nvim
-- Works without external dependencies

local M = {}

M.tests = {}
M.current_describe = nil
M.results = {
  passed = 0,
  failed = 0,
  errors = {}
}

-- Mock test framework functions
function describe(name, fn)
  M.current_describe = name
  print("  Testing: " .. name)
  local ok, err = pcall(fn)
  if not ok then
    table.insert(M.results.errors, {
      suite = name,
      error = err
    })
    M.results.failed = M.results.failed + 1
    print("    ✗ " .. name .. " suite failed: " .. tostring(err))
  end
  M.current_describe = nil
end

function it(name, fn)
  local full_name = (M.current_describe or "Unknown") .. " - " .. name
  local ok, err = pcall(fn)
  if ok then
    M.results.passed = M.results.passed + 1
    print("    ✓ " .. name)
  else
    M.results.failed = M.results.failed + 1
    print("    ✗ " .. name .. ": " .. tostring(err))
    table.insert(M.results.errors, {
      test = full_name,
      error = err
    })
  end
end

function before_each(fn)
  -- Store for later execution
  M.before_each_fn = fn
end

-- Assertion library
local assert = {}

function assert.is_not_nil(value, message)
  if value == nil then
    error(message or "Expected value to not be nil")
  end
end

function assert.is_nil(value, message)
  if value ~= nil then
    error(message or "Expected value to be nil")
  end
end

function assert.is_string(value, message)
  if type(value) ~= "string" then
    error(message or "Expected string, got " .. type(value))
  end
end

function assert.is_table(value, message)
  if type(value) ~= "table" then
    error(message or "Expected table, got " .. type(value))
  end
end

function assert.is_number(value, message)
  if type(value) ~= "number" then
    error(message or "Expected number, got " .. type(value))
  end
end

function assert.is_function(value, message)
  if type(value) ~= "function" then
    error(message or "Expected function, got " .. type(value))
  end
end

function assert.equals(expected, actual, message)
  if expected ~= actual then
    error(message or string.format("Expected %s, got %s", tostring(expected), tostring(actual)))
  end
end

function assert.is_true(value, message)
  if value ~= true then
    error(message or "Expected true, got " .. tostring(value))
  end
end

function assert.is_false(value, message)
  if value ~= false then
    error(message or "Expected false, got " .. tostring(value))
  end
end

function assert.is_truthy(value, message)
  if not value then
    error(message or "Expected truthy value, got " .. tostring(value))
  end
end

function assert.is_falsy(value, message)
  if value then
    error(message or "Expected falsy value, got " .. tostring(value))
  end
end

function assert.is_empty(value, message)
  if type(value) == "string" and value ~= "" then
    error(message or "Expected empty string, got " .. value)
  elseif type(value) == "table" and next(value) ~= nil then
    error(message or "Expected empty table")
  end
end

function assert.is_not_empty(value, message)
  if type(value) == "string" and value == "" then
    error(message or "Expected non-empty string")
  elseif type(value) == "table" and next(value) == nil then
    error(message or "Expected non-empty table")
  end
end

function assert.has_no_errors(fn, message)
  local ok, err = pcall(fn)
  if not ok then
    error(message or "Expected no errors, got: " .. tostring(err))
  end
end

function assert.has_error(fn, message)
  local ok, err = pcall(fn)
  if ok then
    error(message or "Expected an error but none was thrown")
  end
end

-- Export globals
_G.describe = describe
_G.it = it
_G.before_each = before_each
_G.assert = assert

-- Mock sqlite.lua if not available
if not pcall(require, "sqlite") then
  package.loaded["sqlite"] = {
    open = function(path)
      return {
        eval = function(self, sql, ...)
          return {}
        end,
        tbl = function(self, name)
          return {
            insert = function(self, data) return 1 end,
            update = function(self, opts) return true end,
            remove = function(self, opts) return true end,
            get = function(self, opts) return {} end
          }
        end
      }
    end
  }
end

-- Mock vim if not in Neovim
if not vim then
  _G.vim = {
    fn = {
      expand = function(path)
        return path:gsub("~", os.getenv("HOME") or "/tmp")
      end,
      fnamemodify = function(path, mod)
        if mod == ":h" then
          return path:match("(.*/)")
        elseif mod == ":t" then
          return path:match("([^/]+)$")
        end
        return path
      end,
      mkdir = function() return 1 end,
      filereadable = function(path)
        local f = io.open(path, "r")
        if f then
          f:close()
          return 1
        end
        return 0
      end,
      readfile = function(path)
        local lines = {}
        local f = io.open(path, "r")
        if f then
          for line in f:lines() do
            table.insert(lines, line)
          end
          f:close()
        end
        return lines
      end,
      strwidth = function(str)
        return #str:gsub("[\128-\191]", "")
      end,
      line = function() return 1 end
    },
    api = {
      nvim_create_user_command = function() end,
      nvim_set_hl = function() end,
      nvim_create_buf = function() return 1 end,
      nvim_buf_set_option = function() end,
      nvim_buf_set_lines = function() end,
      nvim_buf_get_lines = function() return {} end,
      nvim_win_set_option = function() end,
      nvim_win_get_cursor = function() return {1, 0} end,
      nvim_win_set_cursor = function() end,
      nvim_buf_is_valid = function() return true end,
      nvim_win_is_valid = function() return true end,
      nvim_win_get_config = function() return {row = 5, col = 5, width = 80, height = 30} end,
      nvim_open_win = function() return 2 end,
      nvim_win_close = function() end,
      nvim_buf_delete = function() end,
      nvim_exec_autocmds = function() end
    },
    keymap = {
      set = function(mode, lhs, rhs, opts)
        if not lhs then
          error("lhs: expected string, got nil")
        end
      end
    },
    tbl_deep_extend = function(behavior, ...)
      local result = {}
      for _, tbl in ipairs({...}) do
        for k, v in pairs(tbl or {}) do
          if type(v) == "table" and type(result[k]) == "table" then
            result[k] = vim.tbl_deep_extend(behavior, result[k], v)
          else
            result[k] = v
          end
        end
      end
      return result
    end,
    tbl_extend = function(behavior, ...)
      local result = {}
      for _, tbl in ipairs({...}) do
        for k, v in pairs(tbl or {}) do
          result[k] = v
        end
      end
      return result
    end,
    o = { lines = 50, columns = 100 },
    loop = { now = function() return os.time() * 1000 end },
    cmd = function() end,
    notify = function(msg) print("NOTIFY: " .. msg) end,
    log = { levels = { INFO = 1, WARN = 2, ERROR = 3 } },
    json = {
      decode = function(str)
        -- Simple JSON decode for tests
        if str == "{}" then return {} end
        return {parsed = true}
      end,
      encode = function(tbl)
        return "{}"
      end
    }
  }
end

return M