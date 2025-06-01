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
      description = "Add a new todo item with optional metadata",
      inputSchema = {
        type = "object",
        properties = {
          content = { type = "string", description = "The todo item content" },
          priority = { type = "string", description = "Priority level (low, medium, high)", enum = {"low", "medium", "high"} },
          tags = { type = "string", description = "Comma-separated tags" },
          file_path = { type = "string", description = "File path to link todo to" },
          line_number = { type = "number", description = "Line number to link todo to" }
        },
        required = { "content" }
      },
      handler = function(params)
        local options = {
          priority = params.priority,
          tags = params.tags,
          file_path = params.file_path,
          line_number = params.line_number
        }
        local id = db.add(params.content, options)
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
          done = { type = "boolean", description = "Mark as done/undone (optional)" },
          priority = { type = "string", description = "Priority level (optional)", enum = {"low", "medium", "high"} },
          tags = { type = "string", description = "Tags (optional)" },
          file_path = { type = "string", description = "File path to link todo to (optional)" },
          line_number = { type = "number", description = "Line number to link todo to (optional)" }
        },
        required = { "id" }
      },
      handler = function(params)
        local updates = {}
        if params.content then updates.content = params.content end
        if params.done ~= nil then updates.done = params.done end
        if params.priority then updates.priority = params.priority end
        if params.tags then updates.tags = params.tags end
        if params.file_path then updates.file_path = params.file_path end
        if params.line_number then updates.line_number = params.line_number end
        
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
    },
    ["search_todos"] = {
      description = "Search and filter todo items",
      inputSchema = {
        type = "object",
        properties = {
          query = { type = "string", description = "Text to search for in todo content" },
          priority = { type = "string", description = "Filter by priority", enum = {"low", "medium", "high"} },
          tags = { type = "string", description = "Filter by tags (partial match)" },
          file_path = { type = "string", description = "Filter by file path (partial match)" },
          done = { type = "boolean", description = "Filter by completion status" }
        }
      },
      handler = function(params)
        local filters = {
          priority = params.priority,
          tags = params.tags,
          file_path = params.file_path,
          done = params.done
        }
        local todos = db.search(params.query, filters)
        return { todos = todos, count = #todos }
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