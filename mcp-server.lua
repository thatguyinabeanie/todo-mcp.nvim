#!/usr/bin/env lua
-- Todo MCP Server - Pure Lua implementation with minimal dependencies

local json = require("dkjson") or require("cjson") or (function()
  -- Minimal JSON implementation if no JSON library available
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
    local pos = 1
    local function skip_whitespace()
      pos = str:find("[^ \t\r\n]", pos) or #str + 1
    end

    local function decode_error(msg)
      error(string.format("JSON decode error at position %d: %s", pos, msg))
    end

    local function decode_value()
      skip_whitespace()
      local char = str:sub(pos, pos)

      if char == '"' then
        -- String
        pos = pos + 1
        local start = pos
        while pos <= #str do
          local c = str:sub(pos, pos)
          if c == '"' then
            local result = str:sub(start, pos - 1)
            pos = pos + 1
            return result:gsub("\\.", {["\\n"] = "\n", ["\\r"] = "\r", ["\\t"] = "\t", ["\\\""] = '"', ["\\\\"] = "\\"})
          elseif c == "\\" then
            pos = pos + 2
          else
            pos = pos + 1
          end
        end
        decode_error("Unterminated string")
      elseif char == "{" then
        -- Object
        pos = pos + 1
        local obj = {}
        skip_whitespace()
        if str:sub(pos, pos) == "}" then
          pos = pos + 1
          return obj
        end
        while true do
          skip_whitespace()
          if str:sub(pos, pos) ~= '"' then decode_error("Expected string key") end
          local key = decode_value()
          skip_whitespace()
          if str:sub(pos, pos) ~= ":" then decode_error("Expected ':'") end
          pos = pos + 1
          obj[key] = decode_value()
          skip_whitespace()
          local c = str:sub(pos, pos)
          if c == "}" then
            pos = pos + 1
            return obj
          elseif c == "," then
            pos = pos + 1
          else
            decode_error("Expected ',' or '}'")
          end
        end
      elseif char == "[" then
        -- Array
        pos = pos + 1
        local arr = {}
        skip_whitespace()
        if str:sub(pos, pos) == "]" then
          pos = pos + 1
          return arr
        end
        while true do
          table.insert(arr, decode_value())
          skip_whitespace()
          local c = str:sub(pos, pos)
          if c == "]" then
            pos = pos + 1
            return arr
          elseif c == "," then
            pos = pos + 1
          else
            decode_error("Expected ',' or ']'")
          end
        end
      elseif str:sub(pos, pos + 3) == "true" then
        pos = pos + 4
        return true
      elseif str:sub(pos, pos + 4) == "false" then
        pos = pos + 5
        return false
      elseif str:sub(pos, pos + 3) == "null" then
        pos = pos + 4
        return nil
      else
        -- Number
        local num_str = str:match("^%-?%d+%.?%d*[eE]?[+-]?%d*", pos)
        if num_str then
          pos = pos + #num_str
          return tonumber(num_str)
        else
          decode_error("Invalid value")
        end
      end
    end

    local ok, result = pcall(decode_value)
    if ok then return result else return nil, result end
  end

  return {encode = encode, decode = decode}
end)()

-- Database operations using sqlite3 command
local db_path = os.getenv("TODO_MCP_DB") or os.getenv("HOME") .. "/.local/share/nvim/todo-mcp.db"

local function execute_sql(query, get_results)
  local cmd = string.format("sqlite3 -separator '|' '%s' '%s'", db_path, query)
  if get_results then
    local handle = io.popen(cmd)
    if handle then
      local result = handle:read("*a")
      handle:close()
      return result
    end
    return nil
  else
    os.execute(cmd)
  end
end

-- Initialize database
execute_sql([[
  CREATE TABLE IF NOT EXISTS todos (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content TEXT NOT NULL,
    done INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
]])

-- Database functions
local function get_all_todos()
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
end

local function add_todo(content)
  content = content:gsub("'", "''")
  execute_sql(string.format("INSERT INTO todos (content) VALUES ('%s');", content))
  local id_result = execute_sql("SELECT last_insert_rowid();", true)
  return tonumber(id_result:match("(%d+)"))
end

local function update_todo(id, content, done)
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
end

local function delete_todo(id)
  execute_sql(string.format("DELETE FROM todos WHERE id = %d;", id))
  return true
end

-- MCP protocol implementation
local function handle_request(request)
  local method = request.method

  if method == "initialize" then
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

  elseif method == "tools/list" then
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

  elseif method == "tools/call" then
    local params = request.params or {}
    local tool_name = params.name
    local args = params.arguments or {}

    if tool_name == "list_todos" then
      return { todos = get_all_todos() }

    elseif tool_name == "add_todo" then
      if args.content then
        local id = add_todo(args.content)
        return { id = id, success = true }
      else
        return { error = "Missing content parameter" }
      end

    elseif tool_name == "update_todo" then
      if args.id then
        local success = update_todo(args.id, args.content, args.done)
        return { success = success }
      else
        return { error = "Missing id parameter" }
      end

    elseif tool_name == "delete_todo" then
      if args.id then
        local success = delete_todo(args.id)
        return { success = success }
      else
        return { error = "Missing id parameter" }
      end

    else
      return { error = "Unknown tool: " .. tostring(tool_name) }
    end

  else
    return { error = "Unknown method: " .. tostring(method) }
  end
end

-- Main server loop
while true do
  local line = io.read("*l")
  if not line then break end

  local ok, request = pcall(json.decode, line)
  if ok and request then
    local response = handle_request(request)

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