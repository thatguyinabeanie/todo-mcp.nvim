local M = {}
local db = require("todo-mcp.db")
local json = vim.json

-- MCP server implementation
M.setup = function(config)
  -- Create MCP server using stdio
  local server = {
    name = "todo-mcp",
    version = "1.0.0",
    capabilities = {
      tools = {}
    }
  }
  
  -- Define available tools
  local tools = {
    ["list_todos"] = {
      description = "List all todo items",
      inputSchema = {
        type = "object",
        properties = {}
      },
      handler = function(params)
        local todos = db.get_all()
        return { todos = todos }
      end
    },
    ["add_todo"] = {
      description = "Add a new todo item",
      inputSchema = {
        type = "object",
        properties = {
          content = { type = "string", description = "The todo item content" }
        },
        required = { "content" }
      },
      handler = function(params)
        local id = db.add(params.content)
        return { id = id, success = id ~= nil }
      end
    },
    ["update_todo"] = {
      description = "Update a todo item",
      inputSchema = {
        type = "object",
        properties = {
          id = { type = "number", description = "The todo item ID" },
          content = { type = "string", description = "New content (optional)" },
          done = { type = "boolean", description = "Mark as done/undone (optional)" }
        },
        required = { "id" }
      },
      handler = function(params)
        local updates = {}
        if params.content then updates.content = params.content end
        if params.done ~= nil then updates.done = params.done end
        
        local success = db.update(params.id, updates)
        return { success = success }
      end
    },
    ["delete_todo"] = {
      description = "Delete a todo item",
      inputSchema = {
        type = "object",
        properties = {
          id = { type = "number", description = "The todo item ID to delete" }
        },
        required = { "id" }
      },
      handler = function(params)
        local success = db.delete(params.id)
        return { success = success }
      end
    }
  }
  
  -- Start MCP server (stdio mode for performance)
  M.start_server = function()
    local handle_request = function(request)
      if request.method == "initialize" then
        return {
          protocolVersion = "2024-11-05",
          capabilities = {
            tools = {}
          },
          serverInfo = {
            name = server.name,
            version = server.version
          }
        }
      elseif request.method == "tools/list" then
        local tool_list = {}
        for name, tool in pairs(tools) do
          table.insert(tool_list, {
            name = name,
            description = tool.description,
            inputSchema = tool.inputSchema
          })
        end
        return { tools = tool_list }
      elseif request.method == "tools/call" then
        local tool = tools[request.params.name]
        if tool then
          return tool.handler(request.params.arguments or {})
        else
          return { error = "Tool not found: " .. request.params.name }
        end
      end
    end
    
    -- Read from stdin and write to stdout for MCP communication
    vim.loop.new_thread(function()
      while true do
        local line = io.read("*l")
        if line then
          local ok, request = pcall(json.decode, line)
          if ok then
            local response = handle_request(request)
            response.id = request.id
            io.write(json.encode(response) .. "\n")
            io.flush()
          end
        end
      end
    end)
  end
end

return M