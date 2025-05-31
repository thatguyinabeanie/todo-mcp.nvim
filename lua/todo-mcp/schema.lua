-- Shared database schema definition
local M = {}

-- Table schema for sqlite.lua
M.todos_schema = {
  id = { "integer", primary = true },
  content = { "text", required = true },
  done = { "integer", default = 0 },
  created_at = { "text", default = "CURRENT_TIMESTAMP" },
  updated_at = { "text", default = "CURRENT_TIMESTAMP" }
}

-- SQL for manual creation
M.todos_sql = [[
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    done INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
]]

-- Helper to format timestamps
M.timestamp = function()
  if pcall(require, "sqlite") then
    local sqlite = require("sqlite")
    return sqlite.lib.strftime("%Y-%m-%d %H:%M:%S", "now")
  else
    return os.date("%Y-%m-%d %H:%M:%S")
  end
end

return M