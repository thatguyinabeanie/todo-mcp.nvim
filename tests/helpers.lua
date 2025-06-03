-- Test helpers for todo-mcp.nvim
local M = {}

-- Test database path
M.test_db_path = "/tmp/todo-mcp-test.db"

-- Setup test environment
M.setup_test_env = function()
  -- Use test database
  require('todo-mcp.db').setup(M.test_db_path)
  
  -- Clear any existing data
  local db = require('todo-mcp.db').get_db()
  if db then
    db:eval("DELETE FROM todos")
  end
  
  -- Reset any global state
  package.loaded['todo-mcp.integrations.todo-comments'] = nil
  package.loaded['todo-mcp.mcp'] = nil
end

-- Cleanup test environment  
M.cleanup_test_env = function()
  -- Remove test database
  vim.fn.delete(M.test_db_path)
  
  -- Clean up any test files
  vim.fn.system("rm -f /tmp/test_*.js /tmp/test_*.lua")
  
  -- Reset package cache for modules we might have mocked
  package.loaded['todo-mcp.mcp'] = nil
end

-- Create a test file with content
M.create_test_file = function(filename, lines)
  local filepath = "/tmp/" .. filename
  
  -- Write content to file
  local file = io.open(filepath, "w")
  if file then
    for _, line in ipairs(lines) do
      file:write(line .. "\n")
    end
    file:close()
  end
  
  return filepath
end

-- Mock MCP client for testing
local MockMCPClient = {}
MockMCPClient.__index = MockMCPClient

function MockMCPClient:new()
  local obj = {
    initialized = false,
    requests = {},
    responses = {}
  }
  setmetatable(obj, self)
  return obj
end

function MockMCPClient:send(request)
  table.insert(self.requests, request)
  
  local method = request.method
  local id = request.id
  
  if method == "initialize" then
    return {
      jsonrpc = "2.0",
      id = id,
      result = {
        capabilities = {
          tools = { listChanged = false }
        },
        serverInfo = {
          name = "todo-mcp-server",
          version = "1.0.0"
        }
      }
    }
  elseif method == "tools/list" then
    return {
      jsonrpc = "2.0", 
      id = id,
      result = {
        tools = {
          {
            name = "list_todos",
            description = "List all todos"
          },
          {
            name = "add_todo", 
            description = "Add a new todo"
          },
          {
            name = "update_todo",
            description = "Update a todo"
          },
          {
            name = "search_todos",
            description = "Search todos"
          }
        }
      }
    }
  elseif method == "tools/call" then
    return self:handle_tool_call(request.params, id)
  else
    return {
      jsonrpc = "2.0",
      id = id,
      error = {
        code = -32601,
        message = "Method not found"
      }
    }
  end
end

function MockMCPClient:handle_tool_call(params, id)
  local tool_name = params.name
  local args = params.arguments or {}
  
  if tool_name == "add_todo" then
    local db = require('todo-mcp.db')
    local todo_id = db.add(args.content, {
      title = args.content,
      priority = args.priority or "medium",
      tags = args.tags
    })
    
    return {
      jsonrpc = "2.0",
      id = id,
      result = {
        success = true,
        todo_id = todo_id
      }
    }
  elseif tool_name == "list_todos" then
    local db = require('todo-mcp.db')
    local todos = db.get_all()
    
    return {
      jsonrpc = "2.0",
      id = id,
      result = {
        todos = todos
      }
    }
  elseif tool_name == "update_todo" then
    local db = require('todo-mcp.db')
    local success = db.update(args.todo_id, {
      status = args.status
    })
    
    return {
      jsonrpc = "2.0",
      id = id,
      result = {
        success = success
      }
    }
  elseif tool_name == "search_todos" then
    local db = require('todo-mcp.db')
    local todos = db.search(args.query)
    
    return {
      jsonrpc = "2.0",
      id = id,
      result = {
        todos = todos
      }
    }
  else
    return {
      jsonrpc = "2.0",
      id = id,
      error = {
        code = -32602,
        message = "Unknown tool: " .. tool_name
      }
    }
  end
end

function MockMCPClient:close()
  -- Nothing to do for mock client
end

-- Start mock MCP server
M.start_mcp_server = function()
  return MockMCPClient:new()
end

-- Initialize MCP client
M.initialize_mcp_client = function(client)
  local response = client:send({
    jsonrpc = "2.0",
    id = 1,
    method = "initialize",
    params = {}
  })
  
  client.initialized = response.result ~= nil
  return client.initialized
end

-- Custom assertions for testing
function M.assert_has_element(element, list)
  for _, item in ipairs(list) do
    if item == element then
      return true
    end
  end
  error("Expected element '" .. tostring(element) .. "' not found in list")
end

function M.assert_matches(pattern, text)
  if not string.find(text, pattern) then
    error("Expected pattern '" .. pattern .. "' not found in text: " .. text)
  end
end

function M.assert_does_not_match(pattern, text)
  if string.find(text, pattern) then
    error("Unexpected pattern '" .. pattern .. "' found in text: " .. text)
  end
end

-- Add custom matchers to busted if available
if assert and assert.register and type(assert.register) == "function" then
  assert:register("matcher", "has_element", function(state, arguments)
    local element = arguments[1]
    return function(value)
      for _, item in ipairs(value) do
        if item == element then
          return true
        end
      end
      return false
    end
  end)
  
  assert:register("matcher", "matches", function(state, arguments)
    local pattern = arguments[1]
    return function(value)
      return string.find(value, pattern) ~= nil
    end
  end)
end

return M