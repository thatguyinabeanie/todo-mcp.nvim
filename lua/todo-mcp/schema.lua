-- Shared database schema definition
local M = {}

-- Table schema for sqlite.lua
M.todos_schema = {
  id = {"int", "primary", "key"},
  title = "text",  -- New: extracted from frontmatter
  content = "text", -- Now stores markdown body only
  status = {"text", default = "todo"}, -- todo, in_progress, done
  priority = {"text", default = "medium"},
  tags = {"text", default = ""},
  file_path = "text",
  line_number = "int",
  created_at = {"text", default = "CURRENT_TIMESTAMP"},
  updated_at = {"text", default = "CURRENT_TIMESTAMP"},
  completed_at = "text", -- New: timestamp when completed
  ensure = true
}

-- SQL for manual creation
M.todos_sql = [[
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    content TEXT DEFAULT '',
    status TEXT DEFAULT 'todo',
    priority TEXT DEFAULT 'medium',
    tags TEXT DEFAULT '',
    file_path TEXT,
    line_number INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP
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