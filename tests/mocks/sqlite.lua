-- Mock sqlite.lua for testing
local M = {}

-- Mock database object
local MockDB = {}
MockDB.__index = MockDB

function MockDB:open()
  return self
end

function MockDB:execute(query)
  -- Simple mock implementation
  return true
end

function MockDB:eval(query)
  -- Return mock data based on query
  if query:match("SELECT.*FROM sqlite_master") then
    -- Return empty table to simulate no tables exist yet
    return {}
  elseif query:match("SELECT.*FROM todos") then
    return {}
  end
  return {}
end

function MockDB:exists()
  return true
end

function MockDB:schema()
  return {
    todos = {
      id = "INTEGER PRIMARY KEY",
      title = "TEXT NOT NULL",
      content = "TEXT",
      status = "TEXT DEFAULT 'todo'",
      priority = "TEXT DEFAULT 'medium'",
      done = "INTEGER DEFAULT 0",
      created_at = "TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
      updated_at = "TIMESTAMP DEFAULT CURRENT_TIMESTAMP",
      due_date = "TIMESTAMP",
      tags = "TEXT",
      file_path = "TEXT",
      line_number = "INTEGER",
      metadata = "TEXT"
    }
  }
end

function MockDB:get_first_row(query, args)
  return nil
end

function MockDB:get_rows(query, args)
  return {}
end

function MockDB:insert(table_name, data)
  return { id = 1 }
end

function MockDB:update(table_name, data)
  return true
end

function MockDB:delete(table_name, where)
  return true
end

function MockDB:close()
  return true
end

-- Mock sqlite module  
function M.new(path)
  return setmetatable({ path = path }, MockDB)
end

M.db = M.new

-- Make module callable like sqlite.lua
setmetatable(M, {
  __index = {
    open = function(self, path)
      return M.new(path)
    end
  }
})

return M