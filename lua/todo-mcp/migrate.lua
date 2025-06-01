local M = {}

-- Database migrations
M.migrations = {
  -- Migration 1: Add new columns for markdown/frontmatter support
  {
    version = 1,
    up = function(db)
      -- Check if columns already exist
      local has_title = false
      local pragma = db:eval("PRAGMA table_info(todos)")
      for _, col in ipairs(pragma) do
        if col.name == "title" then
          has_title = true
          break
        end
      end
      
      if not has_title then
        -- Add new columns
        db:eval("ALTER TABLE todos ADD COLUMN title TEXT")
        db:eval("ALTER TABLE todos ADD COLUMN status TEXT DEFAULT 'todo'")
        db:eval("ALTER TABLE todos ADD COLUMN metadata TEXT DEFAULT '{}'")
        db:eval("ALTER TABLE todos ADD COLUMN frontmatter_raw TEXT")
        db:eval("ALTER TABLE todos ADD COLUMN completed_at TEXT")
        
        -- Migrate existing data
        db:eval([[
          UPDATE todos 
          SET title = substr(content, 1, 
            CASE 
              WHEN instr(content, char(10)) > 0 
              THEN instr(content, char(10)) - 1 
              ELSE length(content) 
            END
          )
          WHERE title IS NULL
        ]])
        
        -- Update status based on done field
        db:eval("UPDATE todos SET status = 'done' WHERE done = 1")
        db:eval("UPDATE todos SET status = 'todo' WHERE done = 0")
      end
    end
  }
}

-- Get current schema version
M.get_version = function(db)
  -- Create version table if it doesn't exist
  db:eval([[
    CREATE TABLE IF NOT EXISTS schema_version (
      version INTEGER PRIMARY KEY,
      applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ]])
  
  local result = db:eval("SELECT MAX(version) as version FROM schema_version")
  return result[1] and result[1].version or 0
end

-- Run migrations
M.migrate = function(db)
  local current_version = M.get_version(db)
  
  for _, migration in ipairs(M.migrations) do
    if migration.version > current_version then
      -- Run migration
      local ok, err = pcall(migration.up, db)
      if ok then
        -- Record successful migration
        db:eval("INSERT INTO schema_version (version) VALUES (?)", migration.version)
        vim.notify("Applied migration " .. migration.version, vim.log.levels.INFO)
      else
        vim.notify("Migration " .. migration.version .. " failed: " .. tostring(err), vim.log.levels.ERROR)
        error("Migration failed")
      end
    end
  end
end

return M