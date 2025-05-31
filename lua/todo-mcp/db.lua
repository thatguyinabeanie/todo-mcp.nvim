local M = {}
local db_path

-- Use system sqlite3 command for simplicity and performance
local function execute_sql(query, get_results)
  local cmd = string.format("sqlite3 -separator '|' '%s' '%s'", db_path, query)
  if get_results then
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    return result
  else
    os.execute(cmd)
  end
end

M.setup = function(path)
  db_path = path
  
  -- Ensure directory exists
  vim.fn.mkdir(vim.fn.fnamemodify(db_path, ":h"), "p")
  
  -- Create todos table if it doesn't exist
  execute_sql([[
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      content TEXT NOT NULL,
      done INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  ]])
end

-- Cache for performance
local cache = {
  todos = nil,
  last_update = 0
}

M.get_all = function()
  -- Cache for 1 second to avoid excessive DB reads during UI updates
  local now = vim.loop.now()
  if cache.todos and (now - cache.last_update) < 1000 then
    return cache.todos
  end
  
  local result = execute_sql("SELECT id, content, done FROM todos ORDER BY done ASC, created_at ASC;", true)
  local todos = {}
  
  for line in result:gmatch("[^\n]+") do
    local id, content, done = line:match("^(%d+)|(.+)|(%d+)$")
    if id then
      table.insert(todos, {
        id = tonumber(id),
        content = content,
        done = done == "1"
      })
    end
  end
  
  cache.todos = todos
  cache.last_update = now
  return todos
end

-- Clear cache on modifications
local function clear_cache()
  cache.todos = nil
  cache.last_update = 0
end

M.add = function(content)
  clear_cache()
  -- Escape single quotes
  content = content:gsub("'", "''")
  execute_sql(string.format("INSERT INTO todos (content) VALUES ('%s');", content))
  
  -- Get the last inserted ID
  local id_result = execute_sql("SELECT last_insert_rowid();", true)
  return tonumber(id_result:match("(%d+)"))
end

M.update = function(id, updates)
  clear_cache()
  local set_clauses = {}
  
  if updates.content then
    local escaped = updates.content:gsub("'", "''")
    table.insert(set_clauses, string.format("content = '%s'", escaped))
  end
  
  if updates.done ~= nil then
    table.insert(set_clauses, string.format("done = %d", updates.done and 1 or 0))
  end
  
  if #set_clauses > 0 then
    table.insert(set_clauses, "updated_at = CURRENT_TIMESTAMP")
    local query = string.format("UPDATE todos SET %s WHERE id = %d;", table.concat(set_clauses, ", "), id)
    execute_sql(query)
    return true
  end
  
  return false
end

M.delete = function(id)
  clear_cache()
  execute_sql(string.format("DELETE FROM todos WHERE id = %d;", id))
  return true
end

M.toggle_done = function(id)
  clear_cache()
  execute_sql(string.format("UPDATE todos SET done = NOT done, updated_at = CURRENT_TIMESTAMP WHERE id = %d;", id))
  return true
end

return M