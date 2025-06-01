-- Tests for database operations and new features
local helpers = require('tests.helpers')

describe("Database Operations", function()
  before_each(function()
    helpers.setup_test_env()
  end)
  
  after_each(function()
    helpers.cleanup_test_env()
  end)
  
  describe("basic operations", function()
    it("should add and retrieve todos", function()
      local db = require('todo-mcp.db')
      
      local todo_id = db.add("Test todo", {
        title = "Test todo",
        priority = "high",
        tags = "test,database"
      })
      
      assert.is_number(todo_id)
      
      local todos = db.get_all()
      assert.equals(1, #todos)
      assert.equals("Test todo", todos[1].title)
      assert.equals("high", todos[1].priority)
      assert.equals("test,database", todos[1].tags)
    end)
    
    it("should update todo fields", function()
      local db = require('todo-mcp.db')
      
      local todo_id = db.add("Original content", {
        title = "Original title",
        priority = "low"
      })
      
      local success = db.update(todo_id, {
        title = "Updated title",
        priority = "high",
        status = "in_progress"
      })
      
      assert.is_true(success)
      
      local todos = db.get_all()
      local updated_todo = todos[1]
      
      assert.equals("Updated title", updated_todo.title)
      assert.equals("high", updated_todo.priority)
      assert.equals("in_progress", updated_todo.status)
    end)
  end)
  
  describe("metadata support", function()
    it("should store and retrieve JSON metadata", function()
      local db = require('todo-mcp.db')
      
      local metadata = {
        source = "todo-comment",
        original_tag = "FIXME",
        context = {
          file_type = "javascript",
          git_branch = "feature/auth"
        }
      }
      
      local todo_id = db.add("Test with metadata", {
        title = "Test with metadata",
        metadata = vim.json.encode(metadata)
      })
      
      local todos = db.get_all()
      local retrieved_todo = todos[1]
      
      assert.is_not_nil(retrieved_todo.metadata)
      
      local decoded_metadata = vim.json.decode(retrieved_todo.metadata)
      assert.equals("todo-comment", decoded_metadata.source)
      assert.equals("FIXME", decoded_metadata.original_tag)
      assert.equals("javascript", decoded_metadata.context.file_type)
    end)
  end)
  
  describe("external sync support", function()
    it("should find todo by external metadata field", function()
      local db = require('todo-mcp.db')
      
      -- Add todo with external sync metadata
      local todo_id = db.add("External synced todo", {
        title = "External synced todo",
        metadata = vim.json.encode({
          issue_number = 123,
          github_url = "https://github.com/test/repo/issues/123",
          external_sync = true
        })
      })
      
      local found_todo = db.find_by_metadata("issue_number", 123)
      
      assert.is_not_nil(found_todo)
      assert.equals(todo_id, found_todo.id)
      assert.equals("External synced todo", found_todo.title)
    end)
    
    it("should get todos with external sync enabled", function()
      local db = require('todo-mcp.db')
      
      -- Add regular todo
      db.add("Regular todo", {
        title = "Regular todo"
      })
      
      -- Add externally synced todo
      db.add("Synced todo", {
        title = "Synced todo", 
        metadata = vim.json.encode({
          external_sync = true,
          github_url = "https://github.com/test/repo/issues/456"
        })
      })
      
      local synced_todos = db.get_external_synced()
      
      assert.equals(1, #synced_todos)
      assert.equals("Synced todo", synced_todos[1].title)
    end)
  end)
  
  describe("status change events", function()
    it("should trigger sync event when updating with sync", function()
      local db = require('todo-mcp.db')
      
      local event_fired = false
      local event_data = nil
      
      -- Set up event listener
      vim.api.nvim_create_autocmd("User", {
        pattern = "TodoMCPStatusChanged",
        callback = function(event)
          event_fired = true
          event_data = event.data
        end
      })
      
      local todo_id = db.add("Test status sync", {
        title = "Test status sync"
      })
      
      -- Update with sync
      local success = db.update_with_sync(todo_id, {
        status = "done"
      })
      
      assert.is_true(success)
      
      -- Process pending events
      vim.wait(10)
      
      assert.is_true(event_fired)
      assert.is_not_nil(event_data)
      assert.equals(todo_id, event_data.todo_id)
      assert.equals("done", event_data.new_status)
    end)
  end)
  
  describe("search functionality", function()
    it("should search by content", function()
      local db = require('todo-mcp.db')
      
      db.add("Fix authentication bug", {
        title = "Fix authentication bug",
        content = "TODO: The login system has a security vulnerability"
      })
      
      db.add("Update documentation", {
        title = "Update documentation", 
        content = "TODO: Add API documentation for new endpoints"
      })
      
      local results = db.search("authentication")
      
      assert.equals(1, #results)
      assert.equals("Fix authentication bug", results[1].title)
    end)
    
    it("should filter by priority", function()
      local db = require('todo-mcp.db')
      
      db.add("High priority task", {
        title = "High priority task",
        priority = "high"
      })
      
      db.add("Low priority task", {
        title = "Low priority task",
        priority = "low"
      })
      
      local results = db.search("", { priority = "high" })
      
      assert.equals(1, #results)
      assert.equals("High priority task", results[1].title)
    end)
    
    it("should filter by tags", function()
      local db = require('todo-mcp.db')
      
      db.add("Backend task", {
        title = "Backend task",
        tags = "backend,api,security"
      })
      
      db.add("Frontend task", {
        title = "Frontend task",
        tags = "frontend,ui,react"
      })
      
      local results = db.search("", { tags = "backend" })
      
      assert.equals(1, #results)
      assert.equals("Backend task", results[1].title)
    end)
  end)
  
  describe("migration support", function()
    it("should handle database schema migrations", function()
      local migrate = require('todo-mcp.migrate')
      local db_handle = require('todo-mcp.db').get_db()
      
      -- This should not error even if migrations already applied
      local success = pcall(migrate.migrate, db_handle)
      assert.is_true(success)
      
      -- Verify all expected columns exist
      local result = db_handle:eval("PRAGMA table_info(todos)")
      local column_names = {}
      
      for _, row in ipairs(result) do
        table.insert(column_names, row.name)
      end
      
      -- Check for key columns
      assert.has_element("id", column_names)
      assert.has_element("title", column_names)
      assert.has_element("content", column_names)
      assert.has_element("metadata", column_names)
      assert.has_element("frontmatter_raw", column_names)
    end)
  end)
end)