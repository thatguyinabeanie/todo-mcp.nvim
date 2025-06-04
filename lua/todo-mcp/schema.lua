-- Shared database schema definition
local M = {}

-- Table schema for sqlite.lua
M.todos_schema = {
  id = {"int", "primary", "key"},
  title = "text",  -- New: extracted from frontmatter
  content = "text", -- Now stores markdown body only
  status = {"text", default = "todo"}, -- todo, in_progress, done
  done = {"int", default = 0}, -- Legacy compatibility: 0 or 1
  priority = {"text", default = "medium"}, -- high, medium, low
  section = {"text", default = "Tasks"}, -- Changed from priority to section
  position = {"int", default = 0}, -- Position within section
  tags = {"text", default = ""},
  file_path = "text",
  line_number = "int",
  metadata = "text", -- JSON storage for arbitrary frontmatter fields
  frontmatter_raw = "text", -- Original YAML frontmatter for fidelity
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
    done INTEGER DEFAULT 0,
    priority TEXT DEFAULT 'medium',
    section TEXT DEFAULT 'Tasks',
    position INTEGER DEFAULT 0,
    tags TEXT DEFAULT '',
    file_path TEXT,
    line_number INTEGER,
    metadata TEXT DEFAULT '{}',
    frontmatter_raw TEXT,
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