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
        -- Get current columns to see what we're working with
        local columns = {}
        for _, col in ipairs(pragma) do
          columns[col.name] = true
        end
        
        -- Add new columns if they don't exist
        if not columns.title then
          db:eval("ALTER TABLE todos ADD COLUMN title TEXT")
        end
        if not columns.status then
          db:eval("ALTER TABLE todos ADD COLUMN status TEXT DEFAULT 'todo'")
        end
        if not columns.metadata then
          db:eval("ALTER TABLE todos ADD COLUMN metadata TEXT DEFAULT '{}'")
        end
        if not columns.frontmatter_raw then
          db:eval("ALTER TABLE todos ADD COLUMN frontmatter_raw TEXT")
        end
        if not columns.completed_at then
          db:eval("ALTER TABLE todos ADD COLUMN completed_at TEXT")
        end
        
        -- Migrate existing data for title
        db:eval([[
          UPDATE todos 
          SET title = substr(content, 1, 
            CASE 
              WHEN instr(content, char(10)) > 0 
              THEN instr(content, char(10)) - 1 
              ELSE length(content) 
            END
          )
          WHERE title IS NULL OR title = ''
        ]])
        
        -- Update status based on done field if it exists
        if columns.done then
          db:eval("UPDATE todos SET status = 'done' WHERE done = 1 AND (status IS NULL OR status = '')")
          db:eval("UPDATE todos SET status = 'todo' WHERE done = 0 AND (status IS NULL OR status = '')")
        else
          -- If no done column, set all to todo status
          db:eval("UPDATE todos SET status = 'todo' WHERE status IS NULL OR status = ''")
        end
      end
    end
  },
  
  -- Migration 2: Add priority and tags columns
  {
    version = 2,
    up = function(db)
      -- Get current columns
      local columns = {}
      local pragma = db:eval("PRAGMA table_info(todos)")
      for _, col in ipairs(pragma) do
        columns[col.name] = true
      end
      
      -- Add missing columns
      if not columns.priority then
        db:eval("ALTER TABLE todos ADD COLUMN priority TEXT DEFAULT 'medium'")
        db:eval("UPDATE todos SET priority = 'medium' WHERE priority IS NULL")
      end
      
      if not columns.tags then
        db:eval("ALTER TABLE todos ADD COLUMN tags TEXT DEFAULT ''")
        db:eval("UPDATE todos SET tags = '' WHERE tags IS NULL")
      end
    end
  },
  
  -- Migration 3: Convert priority to flexible sections
  {
    version = 3,
    up = function(db)
      -- Get current columns
      local columns = {}
      local pragma = db:eval("PRAGMA table_info(todos)")
      for _, col in ipairs(pragma) do
        columns[col.name] = true
      end
      
      -- Add section and position columns if they don't exist
      if not columns.section then
        db:eval("ALTER TABLE todos ADD COLUMN section TEXT DEFAULT 'Tasks'")
      end
      
      if not columns.position then
        db:eval("ALTER TABLE todos ADD COLUMN position INTEGER DEFAULT 0")
      end
      
      -- Migrate priority data to sections if priority column exists
      if columns.priority then
        db:eval([[
          UPDATE todos 
          SET section = CASE 
            WHEN priority = 'high' THEN '🔥 High Priority'
            WHEN priority = 'medium' THEN '⚡ Medium Priority'
            WHEN priority = 'low' THEN '💤 Low Priority'
            ELSE 'Tasks'
          END
          WHERE section IS NULL OR section = 'Tasks'
        ]])
        
        -- Set position based on creation order within sections
        db:eval([[
          UPDATE todos 
          SET position = (
            SELECT COUNT(*) 
            FROM todos t2 
            WHERE t2.section = todos.section 
            AND t2.created_at < todos.created_at
          )
        ]])
      end
    end
  },
  
  -- Migration 4: Ensure done column exists for legacy compatibility
  {
    version = 4,
    up = function(db)
      -- Get current columns
      local columns = {}
      local pragma = db:eval("PRAGMA table_info(todos)")
      for _, col in ipairs(pragma) do
        columns[col.name] = true
      end
      
      -- Add done column if it doesn't exist
      if not columns.done then
        db:eval("ALTER TABLE todos ADD COLUMN done INTEGER DEFAULT 0")
        -- Sync done status from status column
        db:eval("UPDATE todos SET done = 1 WHERE status = 'done'")
        db:eval("UPDATE todos SET done = 0 WHERE status != 'done' OR status IS NULL")
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
  local ok, current_version = pcall(M.get_version, db)
  if not ok then
    current_version = 0
  end
  
  for _, migration in ipairs(M.migrations) do
    if migration.version > current_version then
      -- Run migration with error handling
      local migration_ok, err = pcall(migration.up, db)
      if migration_ok then
        -- Record successful migration
        local record_ok = pcall(function()
          db:eval("INSERT INTO schema_version (version) VALUES (?)", migration.version)
        end)
        if record_ok then
          vim.schedule(function()
            vim.notify("Applied database migration " .. migration.version, vim.log.levels.INFO)
          end)
        end
      else
        -- Log error but don't fail completely
        vim.schedule(function()
          vim.notify("Migration " .. migration.version .. " failed: " .. tostring(err), vim.log.levels.WARN)
        end)
      end
    end
  end
end

return M