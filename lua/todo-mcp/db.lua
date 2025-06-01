local M = {}
local schema = require("todo-mcp.schema")
local todos_tbl
local db

-- Cache for performance
local cache = {
  todos = nil,
  last_update = 0
}

-- Clear cache on modifications
local function clear_cache()
  cache.todos = nil
  cache.last_update = 0
end

M.setup = function(db_path)
  -- Load sqlite.lua
  local has_sqlite, sqlite = pcall(require, "sqlite")
  if not has_sqlite then
    error("sqlite.lua not found. Please install with: use { 'kkharji/sqlite.lua' }")
  end
  
  -- Ensure directory exists
  vim.fn.mkdir(vim.fn.fnamemodify(db_path, ":h"), "p")
  
  -- Open database
  db = sqlite:open(db_path)
  
  -- Create table directly with SQL first (more reliable)
  db:eval(schema.todos_sql)
  
  -- Run migrations to update schema
  local migrate = require("todo-mcp.migrate")
  migrate.migrate(db)
  
  -- Then create table handle for operations
  todos_tbl = db:tbl("todos")
end

M.get_all = function()
  -- Cache for 1 second to avoid excessive DB reads during UI updates
  local now = vim.loop.now()
  if cache.todos and (now - cache.last_update) < 1000 then
    return cache.todos
  end
  
  -- Use table API to get all todos
  local todos = todos_tbl:get({
    select = { "id", "title", "content", "status", "done", "priority", "tags", "file_path", "line_number", "metadata", "frontmatter_raw", "created_at", "updated_at", "completed_at" },
    order_by = {
      asc = { "done", "created_at" }
    }
  })
  
  -- Convert done field to boolean
  for _, todo in ipairs(todos) do
    todo.done = todo.done == 1
  end
  
  cache.todos = todos
  cache.last_update = now
  return todos
end

M.add = function(content, options)
  clear_cache()
  
  options = options or {}
  
  -- Extract title from content if not provided
  local title = options.title or content:match("^[^\n]+") or "Untitled"
  
  -- Use table API to insert
  local result = todos_tbl:insert({
    title = title,
    content = options.content or content,
    status = options.status or "todo",
    done = options.done and 1 or 0,
    priority = options.priority or "medium",
    tags = options.tags or "",
    file_path = options.file_path,
    line_number = options.line_number,
    metadata = options.metadata or "{}",
    frontmatter_raw = options.frontmatter_raw,
    created_at = schema.timestamp(),
    updated_at = schema.timestamp(),
    completed_at = options.completed_at
  })
  
  -- Handle different return types from sqlite.lua
  if type(result) == "number" then
    return result
  elseif type(result) == "table" and result.last_insert_rowid then
    return result.last_insert_rowid
  elseif type(result) == "table" and result[1] then
    return result[1].id or result[1]
  else
    -- Fallback: return the result as-is
    return result
  end
end

M.update = function(id, updates)
  clear_cache()
  
  local update_data = {}
  
  if updates.content then
    update_data.content = updates.content
  end
  
  if updates.done ~= nil then
    update_data.done = updates.done and 1 or 0
  end
  
  if updates.priority then
    update_data.priority = updates.priority
  end
  
  if updates.tags then
    update_data.tags = updates.tags
  end
  
  if updates.file_path then
    update_data.file_path = updates.file_path
  end
  
  if updates.line_number then
    update_data.line_number = updates.line_number
  end
  
  if updates.metadata then
    update_data.metadata = updates.metadata
  end
  
  if updates.frontmatter_raw then
    update_data.frontmatter_raw = updates.frontmatter_raw
  end
  
  if updates.title then
    update_data.title = updates.title
  end
  
  if updates.status then
    update_data.status = updates.status
  end
  
  if updates.completed_at then
    update_data.completed_at = updates.completed_at
  end
  
  if next(update_data) then
    update_data.updated_at = schema.timestamp()
    
    -- Use table API to update
    todos_tbl:update({
      where = { id = id },
      set = update_data
    })
    
    return true
  end
  
  return false
end

M.delete = function(id)
  clear_cache()
  
  -- Use table API to delete
  todos_tbl:remove({ id = id })
  
  return true
end

M.search = function(query, filters)
  filters = filters or {}
  
  -- Build where clause
  local where_parts = {}
  local where_clause = {}
  
  -- Text search in content
  if query and query ~= "" then
    table.insert(where_parts, "content LIKE ?")
    table.insert(where_clause, "%" .. query .. "%")
  end
  
  -- Priority filter
  if filters.priority then
    table.insert(where_parts, "priority = ?")
    table.insert(where_clause, filters.priority)
  end
  
  -- Tags filter (simple contains check)
  if filters.tags then
    table.insert(where_parts, "tags LIKE ?")
    table.insert(where_clause, "%" .. filters.tags .. "%")
  end
  
  -- File filter
  if filters.file_path then
    table.insert(where_parts, "file_path LIKE ?")
    table.insert(where_clause, "%" .. filters.file_path .. "%")
  end
  
  -- Done status filter
  if filters.done ~= nil then
    table.insert(where_parts, "done = ?")
    table.insert(where_clause, filters.done and 1 or 0)
  end
  
  -- Build SQL query
  local sql = "SELECT id, title, content, status, done, priority, tags, file_path, line_number, metadata, frontmatter_raw, created_at, updated_at, completed_at FROM todos"
  if #where_parts > 0 then
    sql = sql .. " WHERE " .. table.concat(where_parts, " AND ")
  end
  sql = sql .. " ORDER BY done ASC, created_at ASC"
  
  -- Execute query
  local result = db:eval(sql, where_clause)
  
  -- Convert done field to boolean
  for _, todo in ipairs(result) do
    todo.done = todo.done == 1
  end
  
  return result
end

M.toggle_done = function(id)
  clear_cache()
  
  -- Get current state
  local todos = todos_tbl:get({ where = { id = id }, limit = 1 })
  if #todos > 0 then
    local current_done = todos[1].done
    
    -- Toggle and update
    todos_tbl:update({
      where = { id = id },
      set = {
        done = current_done == 1 and 0 or 1,
        updated_at = schema.timestamp()
      }
    })
    
    return true
  end
  
  return false
end

-- Get direct database handle for advanced operations
M.get_db = function()
  return db
end

-- Find todo by metadata field (for external integrations)
M.find_by_metadata = function(field, value)
  local todos = M.get_all()
  
  for _, todo in ipairs(todos) do
    if todo.metadata then
      local metadata = vim.json.decode(todo.metadata)
      if metadata and metadata[field] == value then
        return todo
      end
    end
  end
  
  return nil
end

-- Get todos with external sync enabled
M.get_external_synced = function()
  local todos = M.get_all()
  local synced = {}
  
  for _, todo in ipairs(todos) do
    if todo.metadata then
      local metadata = vim.json.decode(todo.metadata)
      if metadata and metadata.external_sync then
        table.insert(synced, todo)
      end
    end
  end
  
  return synced
end

-- Update todo status and trigger external sync
M.update_with_sync = function(id, updates)
  local success = M.update(id, updates)
  
  if success and updates.status then
    -- Trigger external sync event
    vim.api.nvim_exec_autocmds("User", {
      pattern = "TodoMCPStatusChanged",
      data = { todo_id = id, new_status = updates.status }
    })
  end
  
  return success
end

return M