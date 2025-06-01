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
    select = { "id", "content", "done", "created_at", "updated_at" },
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

M.add = function(content)
  clear_cache()
  
  -- Use table API to insert
  local result = todos_tbl:insert({
    content = content,
    created_at = schema.timestamp(),
    updated_at = schema.timestamp()
  })
  
  -- sqlite.lua returns the ID directly as a number
  return result
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

return M