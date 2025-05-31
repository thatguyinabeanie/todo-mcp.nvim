-- Utility functions
local M = {}

-- Get the configured database path
M.get_db_path = function()
  local plugin_opts = pcall(require, "todo-mcp") and require("todo-mcp").opts
  
  if plugin_opts and plugin_opts.db_path then
    return plugin_opts.db_path
  elseif vim then
    return vim.fn.expand("~/.local/share/nvim/todo-mcp.db")
  else
    return (os.getenv("HOME") or ".") .. "/.local/share/nvim/todo-mcp.db"
  end
end

-- Check if running inside Neovim
M.is_neovim = function()
  return vim and vim.fn and true or false
end

-- Safe require
M.safe_require = function(module)
  local ok, result = pcall(require, module)
  return ok and result or nil
end

-- Format date for display
M.format_date = function(date_str)
  if not date_str then return "" end
  
  -- Try to parse and format nicely
  local year, month, day, hour, min, sec = date_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  if year then
    -- Today's date
    local today = os.date("%Y-%m-%d")
    local date_part = string.format("%s-%s-%s", year, month, day)
    
    if date_part == today then
      return string.format("Today %s:%s", hour, min)
    else
      return string.format("%s/%s %s:%s", month, day, hour, min)
    end
  end
  
  return date_str
end

return M