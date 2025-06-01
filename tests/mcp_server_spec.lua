-- Tests for MCP server functionality
local helpers = require('tests.helpers')

describe("MCP Server Integration", function()
  local mcp_client
  
  before_each(function()
    helpers.setup_test_env()
    mcp_client = helpers.start_mcp_server()
  end)
  
  after_each(function()
    helpers.cleanup_test_env()
    if mcp_client then
      mcp_client:close()
    end
  end)
  
  describe("server initialization", function()
    it("should respond to initialize request", function()
      local response = mcp_client:send({
        jsonrpc = "2.0",
        id = 1,
        method = "initialize",
        params = {}
      })
      
      assert.equals("2.0", response.jsonrpc)
      assert.equals(1, response.id)
      assert.is_not_nil(response.result.capabilities)
      assert.equals("todo-mcp-server", response.result.serverInfo.name)
    end)
  end)
  
  describe("tool listing", function()
    it("should list available tools", function()
      helpers.initialize_mcp_client(mcp_client)
      
      local response = mcp_client:send({
        jsonrpc = "2.0",
        id = 2,
        method = "tools/list"
      })
      
      assert.is_table(response.result.tools)
      
      local tool_names = {}
      for _, tool in ipairs(response.result.tools) do
        table.insert(tool_names, tool.name)
      end
      
      assert.has_element("list_todos", tool_names)
      assert.has_element("add_todo", tool_names)
      assert.has_element("update_todo", tool_names)
    end)
  end)
  
  describe("todo operations", function()
    it("should add and retrieve todos", function()
      helpers.initialize_mcp_client(mcp_client)
      
      -- Add a todo
      local add_response = mcp_client:send({
        jsonrpc = "2.0",
        id = 3,
        method = "tools/call",
        params = {
          name = "add_todo",
          arguments = {
            content = "Test todo from MCP",
            priority = "high",
            tags = "test,mcp"
          }
        }
      })
      
      assert.is_true(add_response.result.success)
      local todo_id = add_response.result.todo_id
      assert.is_number(todo_id)
      
      -- List todos
      local list_response = mcp_client:send({
        jsonrpc = "2.0",
        id = 4,
        method = "tools/call",
        params = {
          name = "list_todos"
        }
      })
      
      assert.is_table(list_response.result.todos)
      assert.is_true(#list_response.result.todos > 0)
      
      -- Find our todo
      local found_todo = nil
      for _, todo in ipairs(list_response.result.todos) do
        if todo.id == todo_id then
          found_todo = todo
          break
        end
      end
      
      assert.is_not_nil(found_todo)
      assert.equals("Test todo from MCP", found_todo.content)
      assert.equals("high", found_todo.priority)
      assert.matches("test", found_todo.tags)
    end)
    
    it("should update todo status", function()
      helpers.initialize_mcp_client(mcp_client)
      
      -- Add a todo first
      local add_response = mcp_client:send({
        jsonrpc = "2.0",
        id = 5,
        method = "tools/call",
        params = {
          name = "add_todo",
          arguments = {
            content = "Todo to update",
            priority = "medium"
          }
        }
      })
      
      local todo_id = add_response.result.todo_id
      
      -- Update the todo
      local update_response = mcp_client:send({
        jsonrpc = "2.0",
        id = 6,
        method = "tools/call",
        params = {
          name = "update_todo",
          arguments = {
            todo_id = todo_id,
            status = "done"
          }
        }
      })
      
      assert.is_true(update_response.result.success)
      
      -- Verify the update
      local list_response = mcp_client:send({
        jsonrpc = "2.0",
        id = 7,
        method = "tools/call",
        params = {
          name = "list_todos"
        }
      })
      
      local updated_todo = nil
      for _, todo in ipairs(list_response.result.todos) do
        if todo.id == todo_id then
          updated_todo = todo
          break
        end
      end
      
      assert.equals("done", updated_todo.status)
    end)
  end)
  
  describe("search functionality", function()
    it("should search todos by content", function()
      helpers.initialize_mcp_client(mcp_client)
      
      -- Add test todos
      mcp_client:send({
        jsonrpc = "2.0",
        id = 8,
        method = "tools/call",
        params = {
          name = "add_todo",
          arguments = {
            content = "Fix database connection",
            tags = "backend,database"
          }
        }
      })
      
      mcp_client:send({
        jsonrpc = "2.0",
        id = 9,
        method = "tools/call",
        params = {
          name = "add_todo",
          arguments = {
            content = "Update frontend styles",
            tags = "frontend,css"
          }
        }
      })
      
      -- Search for database todos
      local search_response = mcp_client:send({
        jsonrpc = "2.0",
        id = 10,
        method = "tools/call",
        params = {
          name = "search_todos",
          arguments = {
            query = "database"
          }
        }
      })
      
      assert.is_table(search_response.result.todos)
      assert.equals(1, #search_response.result.todos)
      assert.matches("database", search_response.result.todos[1].content)
    end)
  end)
end)