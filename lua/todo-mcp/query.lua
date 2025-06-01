-- Advanced query capabilities using sqlite.lua
local M = {}
local db = require("todo-mcp.db")

-- Search todos by content
M.search = function(query)
  local handle = db.get_db()
  if not handle then
    error("Database not initialized")
  end
  
  -- Check if status column exists
  local columns = {}
  local pragma = handle:eval("PRAGMA table_info(todos)")
  for _, col in ipairs(pragma) do
    columns[col.name] = true
  end
  
  local order_clause = columns.status and "ORDER BY status ASC, created_at DESC" or "ORDER BY done ASC, created_at DESC"
  
  return handle:eval(
    "SELECT * FROM todos WHERE content LIKE ? " .. order_clause,
    "%" .. query .. "%"
  )
end

-- Get todos by date range
M.by_date_range = function(start_date, end_date)
  local handle = db.get_db()
  if not handle then
    error("Database not initialized")
  end
  
  return handle:eval(
    "SELECT * FROM todos WHERE created_at BETWEEN ? AND ? ORDER BY created_at DESC",
    start_date, end_date
  )
end

-- Get statistics
M.stats = function()
  local handle = db.get_db()
  if not handle then
    error("Database not initialized")
  end
  
  -- Check if status column exists
  local columns = {}
  local pragma = handle:eval("PRAGMA table_info(todos)")
  for _, col in ipairs(pragma) do
    columns[col.name] = true
  end
  
  local stats = {}
  
  -- Total todos
  local total = handle:eval("SELECT COUNT(*) as count FROM todos")
  stats.total = total[1].count
  
  -- Completed todos
  local completed_query = columns.status and "SELECT COUNT(*) as count FROM todos WHERE status = 'done'" or "SELECT COUNT(*) as count FROM todos WHERE done = 1"
  local completed = handle:eval(completed_query)
  stats.completed = completed[1].count
  
  -- Active todos
  stats.active = stats.total - stats.completed
  
  -- Completion rate
  stats.completion_rate = stats.total > 0 and (stats.completed / stats.total * 100) or 0
  
  -- Recent activity (last 7 days)
  local recent = handle:eval([[
    SELECT COUNT(*) as count 
    FROM todos 
    WHERE updated_at >= datetime('now', '-7 days')
  ]])
  stats.recent_activity = recent[1].count
  
  return stats
end

-- Get todos grouped by completion status
M.grouped = function()
  local handle = db.get_db()
  if not handle then
    error("Database not initialized")
  end
  
  -- Check if status column exists
  local columns = {}
  local pragma = handle:eval("PRAGMA table_info(todos)")
  for _, col in ipairs(pragma) do
    columns[col.name] = true
  end
  
  local result = {
    active = {},
    completed = {}
  }
  
  local order_clause = columns.status and "ORDER BY status ASC, created_at DESC" or "ORDER BY done ASC, created_at DESC"
  local todos = handle:eval("SELECT * FROM todos " .. order_clause)
  
  for _, todo in ipairs(todos) do
    local is_done = columns.status and (todo.status == "done") or (todo.done == 1)
    if is_done then
      table.insert(result.completed, todo)
    else
      table.insert(result.active, todo)
    end
  end
  
  return result
end

-- Archive old completed todos
M.archive_completed = function(days_old)
  days_old = days_old or 30
  local handle = db.get_db()
  if not handle then
    error("Database not initialized")
  end
  
  -- Check if status column exists
  local columns = {}
  local pragma = handle:eval("PRAGMA table_info(todos)")
  for _, col in ipairs(pragma) do
    columns[col.name] = true
  end
  
  -- First, export old completed todos
  local where_clause = columns.status and "WHERE status = 'done'" or "WHERE done = 1"
  local old_todos = handle:eval([[
    SELECT * FROM todos 
    ]] .. where_clause .. [[ 
    AND updated_at < datetime('now', '-' || ? || ' days')
  ]], days_old)
  
  if #old_todos > 0 then
    -- Save to archive file
    local archive_path = vim.fn.expand("~/.local/share/nvim/todo-archive.json")
    local archive = {}
    
    -- Load existing archive if it exists
    if vim.fn.filereadable(archive_path) == 1 then
      local content = table.concat(vim.fn.readfile(archive_path), "\n")
      archive = vim.fn.json_decode(content) or {}
    end
    
    -- Add old todos to archive
    local timestamp = os.date("%Y-%m-%d %H:%M:%S")
    table.insert(archive, {
      archived_at = timestamp,
      todos = old_todos
    })
    
    -- Save archive
    vim.fn.writefile({vim.fn.json_encode(archive)}, archive_path)
    
    -- Delete from main database
    handle:eval([[
      DELETE FROM todos 
      ]] .. where_clause .. [[ 
      AND updated_at < datetime('now', '-' || ? || ' days')
    ]], days_old)
    
    return #old_todos
  end
  
  return 0
end

return M