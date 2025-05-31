local M = {}
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
  -- Load sqlite.lua (check if available, otherwise fall back)
  local has_sqlite, sqlite = pcall(require, "sqlite")
  if not has_sqlite then
    error("sqlite.lua not found. Please install with: use { 'kkharji/sqlite.lua' }")
  end
  
  -- Ensure directory exists
  vim.fn.mkdir(vim.fn.fnamemodify(db_path, ":h"), "p")
  
  -- Open database
  db = sqlite:open(db_path)
  
  -- Create todos table if it doesn't exist
  db:eval([[
    CREATE TABLE IF NOT EXISTS todos (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      content TEXT NOT NULL,
      done INTEGER DEFAULT 0,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
  ]])
end

M.get_all = function()
  -- Cache for 1 second to avoid excessive DB reads during UI updates
  local now = vim.loop.now()
  if cache.todos and (now - cache.last_update) < 1000 then
    return cache.todos
  end
  
  local todos = db:eval("SELECT * FROM todos ORDER BY done ASC, created_at ASC")
  
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
  db:eval("INSERT INTO todos (content) VALUES (?)", content)
  
  -- Get the last inserted ID
  local result = db:eval("SELECT last_insert_rowid() as id")
  return result[1] and result[1].id
end

M.update = function(id, updates)
  clear_cache()
  
  if updates.content and updates.done ~= nil then
    db:eval(
      "UPDATE todos SET content = ?, done = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      updates.content, updates.done and 1 or 0, id
    )
  elseif updates.content then
    db:eval(
      "UPDATE todos SET content = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      updates.content, id
    )
  elseif updates.done ~= nil then
    db:eval(
      "UPDATE todos SET done = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
      updates.done and 1 or 0, id
    )
  else
    return false
  end
  
  return true
end

M.delete = function(id)
  clear_cache()
  db:eval("DELETE FROM todos WHERE id = ?", id)
  return true
end

M.toggle_done = function(id)
  clear_cache()
  db:eval("UPDATE todos SET done = NOT done, updated_at = CURRENT_TIMESTAMP WHERE id = ?", id)
  return true
end

return M