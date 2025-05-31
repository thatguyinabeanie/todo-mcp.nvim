-- Standalone MCP server that can run inside or outside Neovim
local M = {}

-- JSON handling (uses vim.json if in Neovim, otherwise minimal implementation)
local json = (function()
  if vim and vim.json then
    return vim.json
  else
    -- Minimal JSON for standalone use
    local encode, decode
    
    local escape_char_map = {
      ["\\"] = "\\\\", ["\""] = "\\\"", ["\b"] = "\\b", ["\f"] = "\\f",
      ["\n"] = "\\n", ["\r"] = "\\r", ["\t"] = "\\t"
    }
    
    local function escape_char(c)
      return escape_char_map[c] or string.format("\\u%04x", c:byte())
    end
    
    local function encode_string(val)
      return '"' .. val:gsub('[%z\1-\31\\"]', escape_char) .. '"'
    end
    
    function encode(val)
      local t = type(val)
      if t == "string" then return encode_string(val)
      elseif t == "number" or t == "boolean" then return tostring(val)
      elseif t == "nil" then return "null"
      elseif t == "table" then
        local is_array = true
        local n = 0
        for k, _ in pairs(val) do
          if type(k) ~= "number" or k <= 0 or k % 1 ~= 0 then
            is_array = false
            break
          end
          n = math.max(n, k)
        end
        if is_array and n == #val then
          local parts = {}
          for i = 1, #val do
            parts[i] = encode(val[i])
          end
          return "[" .. table.concat(parts, ",") .. "]"
        else
          local parts = {}
          for k, v in pairs(val) do
            table.insert(parts, encode_string(tostring(k)) .. ":" .. encode(v))
          end
          return "{" .. table.concat(parts, ",") .. "}"
        end
      end
      error("Cannot encode type: " .. t)
    end
    
    function decode(str)
      -- Simple pattern-based decoder (not fully compliant but works for MCP)
      str = str:gsub('^%s*(.-)%s*$', '%1') -- trim
      
      if str:sub(1,1) == '"' and str:sub(-1) == '"' then
        -- String
        return str:sub(2, -2):gsub('\\(.)', {n='\n', r='\r', t='\t', ['"']='"', ['\\']='\\'})
      elseif str == "true" then
        return true
      elseif str == "false" then
        return false
      elseif str == "null" then
        return nil
      elseif str:match("^%-?%d+%.?%d*$") then
        -- Number
        return tonumber(str)
      elseif str:sub(1,1) == "{" then
        -- Object (simplified)
        local obj = {}
        local content = str:sub(2, -2)
        -- Very basic parsing - won't handle nested objects well
        for key, value in content:gmatch('"([^"]+)"%s*:%s*([^,}]+)') do
          obj[key] = decode(value)
        end
        return obj
      elseif str:sub(1,1) == "[" then
        -- Array (simplified)
        local arr = {}
        local content = str:sub(2, -2)
        for value in content:gmatch('[^,]+') do
          table.insert(arr, decode(value))
        end
        return arr
      end
      
      return str
    end
    
    return {encode = encode, decode = decode}
  end
end)()

-- Database setup
local db, db_ops

local function get_db_path()
  if vim then
    return vim.fn.expand("~/.local/share/nvim/todo-mcp.db")
  else
    return (os.getenv("HOME") or ".") .. "/.local/share/nvim/todo-mcp.db"
  end
end

local db_path = get_db_path()

-- Try to use sqlite.lua if available
local has_sqlite, sqlite = pcall(require, "sqlite")

if has_sqlite then
  -- Use sqlite.lua
  db = sqlite:open(db_path)
  
  db_ops = {
    init = function()
      db:eval([[
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          done INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ]])
    end,
    
    get_all = function()
      local todos = db:eval("SELECT * FROM todos ORDER BY done ASC, created_at ASC")
      for _, todo in ipairs(todos) do
        todo.done = todo.done == 1
      end
      return todos
    end,
    
    add = function(content)
      db:eval("INSERT INTO todos (content) VALUES (?)", content)
      local result = db:eval("SELECT last_insert_rowid() as id")
      return result[1] and result[1].id
    end,
    
    update = function(id, content, done)
      if content and done ~= nil then
        db:eval(
          "UPDATE todos SET content = ?, done = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
          content, done and 1 or 0, id
        )
      elseif content then
        db:eval(
          "UPDATE todos SET content = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
          content, id
        )
      elseif done ~= nil then
        db:eval(
          "UPDATE todos SET done = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?",
          done and 1 or 0, id
        )
      else
        return false
      end
      return true
    end,
    
    delete = function(id)
      db:eval("DELETE FROM todos WHERE id = ?", id)
      return true
    end
  }
else
  -- Fallback to sqlite3 command
  local function execute_sql(query, get_results)
    local cmd = string.format("sqlite3 -separator '|' '%s' '%s'", db_path, query)
    if get_results then
      local handle = io.popen(cmd)
      if handle then
        local result = handle:read("*a")
        handle:close()
        return result
      end
      return ""
    else
      os.execute(cmd)
    end
  end
  
  db_ops = {
    init = function()
      execute_sql([[
        CREATE TABLE IF NOT EXISTS todos (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          content TEXT NOT NULL,
          done INTEGER DEFAULT 0,
          created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
          updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        );
      ]])
    end,
    
    get_all = function()
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
      
      return todos
    end,
    
    add = function(content)
      content = content:gsub("'", "''")
      execute_sql(string.format("INSERT INTO todos (content) VALUES ('%s');", content))
      local id_result = execute_sql("SELECT last_insert_rowid();", true)
      return tonumber(id_result:match("(%d+)"))
    end,
    
    update = function(id, content, done)
      local set_clauses = {}
      
      if content then
        local escaped = content:gsub("'", "''")
        table.insert(set_clauses, string.format("content = '%s'", escaped))
      end
      
      if done ~= nil then
        table.insert(set_clauses, string.format("done = %d", done and 1 or 0))
      end
      
      if #set_clauses > 0 then
        table.insert(set_clauses, "updated_at = CURRENT_TIMESTAMP")
        local query = string.format("UPDATE todos SET %s WHERE id = %d;", table.concat(set_clauses, ", "), id)
        execute_sql(query)
        return true
      end
      
      return false
    end,
    
    delete = function(id)
      execute_sql(string.format("DELETE FROM todos WHERE id = %d;", id))
      return true
    end
  }
end

-- MCP handlers
M.handlers = {
  initialize = function(request)
    return {
      protocolVersion = "2024-11-05",
      capabilities = {
        tools = {}
      },
      serverInfo = {
        name = "todo-mcp",
        version = "1.0.0"
      }
    }
  end,
  
  ["tools/list"] = function(request)
    return {
      tools = {
        {
          name = "list_todos",
          description = "List all todo items",
          inputSchema = {
            type = "object",
            properties = {}
          }
        },
        {
          name = "add_todo",
          description = "Add a new todo item",
          inputSchema = {
            type = "object",
            properties = {
              content = {
                type = "string",
                description = "The todo item content"
              }
            },
            required = {"content"}
          }
        },
        {
          name = "update_todo",
          description = "Update a todo item",
          inputSchema = {
            type = "object",
            properties = {
              id = {
                type = "number",
                description = "The todo item ID"
              },
              content = {
                type = "string",
                description = "New content (optional)"
              },
              done = {
                type = "boolean",
                description = "Mark as done/undone (optional)"
              }
            },
            required = {"id"}
          }
        },
        {
          name = "delete_todo",
          description = "Delete a todo item",
          inputSchema = {
            type = "object",
            properties = {
              id = {
                type = "number",
                description = "The todo item ID to delete"
              }
            },
            required = {"id"}
          }
        }
      }
    }
  end,
  
  ["tools/call"] = function(request)
    local params = request.params or {}
    local tool_name = params.name
    local args = params.arguments or {}
    
    if tool_name == "list_todos" then
      return { todos = db_ops.get_all() }
    
    elseif tool_name == "add_todo" then
      if args.content then
        local id = db_ops.add(args.content)
        return { id = id, success = true }
      else
        return { error = "Missing content parameter" }
      end
    
    elseif tool_name == "update_todo" then
      if args.id then
        local success = db_ops.update(args.id, args.content, args.done)
        return { success = success }
      else
        return { error = "Missing id parameter" }
      end
    
    elseif tool_name == "delete_todo" then
      if args.id then
        local success = db_ops.delete(args.id)
        return { success = success }
      else
        return { error = "Missing id parameter" }
      end
    
    else
      return { error = "Unknown tool: " .. tostring(tool_name) }
    end
  end
}

-- Handle a single request
function M.handle_request(request)
  local handler = M.handlers[request.method]
  if handler then
    return handler(request)
  else
    return { error = "Unknown method: " .. tostring(request.method) }
  end
end

-- Run as stdio server
function M.run_server()
  db_ops.init()
  
  while true do
    local line = io.read("*l")
    if not line then break end
    
    local ok, request = pcall(json.decode, line)
    if ok and request then
      local response = M.handle_request(request)
      
      -- Add JSON-RPC fields
      response.jsonrpc = "2.0"
      if request.id then
        response.id = request.id
      end
      
      -- Send response
      io.write(json.encode(response) .. "\n")
      io.flush()
    else
      -- Send error response
      local error_response = {
        jsonrpc = "2.0",
        error = {
          code = -32700,
          message = "Parse error"
        }
      }
      io.write(json.encode(error_response) .. "\n")
      io.flush()
    end
  end
end

-- If run directly (not required as module)
if not pcall(debug.getlocal, 4, 1) then
  M.run_server()
end

return M