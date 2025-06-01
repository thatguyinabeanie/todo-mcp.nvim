-- Tests for todo-comments.nvim integration
local helpers = require('tests.helpers')

describe("Todo Comments Integration", function()
  local test_file
  
  before_each(function()
    helpers.setup_test_env()
    test_file = helpers.create_test_file("test.js", {
      "function example() {",
      "  // TODO: Add input validation",
      "  // FIXME: Memory leak in loop",
      "  return process(data);",
      "}"
    })
  end)
  
  after_each(function()
    helpers.cleanup_test_env()
  end)
  
  describe("todo detection", function()
    it("should detect TODO at cursor position", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {2, 0}) -- Line with TODO
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      local todo_comment = tc_integration.get_todo_at_cursor()
      
      assert.is_not_nil(todo_comment)
      assert.equals("Add input validation", todo_comment.text)
      assert.equals("TODO", todo_comment.tag)
      assert.equals(test_file, todo_comment.file)
      assert.equals(2, todo_comment.line)
    end)
    
    it("should return nil when not on a TODO line", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {1, 0}) -- First line (function)
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      local todo_comment = tc_integration.get_todo_at_cursor()
      
      assert.is_nil(todo_comment)
    end)
  end)
  
  describe("todo tracking", function()
    it("should track TODO comment and create database entry", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {2, 0})
      
      local db = require('todo-mcp.db')
      local initial_count = #db.get_all()
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      local todo_comment = tc_integration.get_todo_at_cursor()
      
      local todo_id = tc_integration.track_todo(todo_comment)
      
      assert.is_number(todo_id)
      
      local todos = db.get_all()
      assert.equals(initial_count + 1, #todos)
      
      -- Find the tracked todo
      local tracked_todo = nil
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          tracked_todo = todo
          break
        end
      end
      
      assert.is_not_nil(tracked_todo)
      assert.equals("Add input validation", tracked_todo.title)
      assert.equals("medium", tracked_todo.priority) -- Default for TODO
      assert.equals(test_file, tracked_todo.file_path)
      assert.equals(2, tracked_todo.line_number)
    end)
    
    it("should map FIXME to high priority", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {3, 0}) -- Line with FIXME
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      local todo_comment = tc_integration.get_todo_at_cursor()
      local todo_id = tc_integration.track_todo(todo_comment)
      
      local db = require('todo-mcp.db')
      local todos = db.get_all()
      
      local tracked_todo = nil
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          tracked_todo = todo
          break
        end
      end
      
      assert.equals("high", tracked_todo.priority)
      assert.equals("FIXME", vim.json.decode(tracked_todo.metadata).original_tag)
    end)
  end)
  
  describe("context detection", function()
    it("should detect file type and add appropriate tags", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {2, 0})
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      local todo_comment = tc_integration.get_todo_at_cursor()
      local todo_id = tc_integration.track_todo(todo_comment)
      
      local db = require('todo-mcp.db')
      local todos = db.get_all()
      
      local tracked_todo = nil
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          tracked_todo = todo
          break
        end
      end
      
      assert.matches("javascript", tracked_todo.tags)
      
      local metadata = vim.json.decode(tracked_todo.metadata)
      assert.equals("js", metadata.context.filetype)
    end)
  end)
  
  describe("virtual text updates", function()
    it("should show virtual text for tracked TODO", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {2, 0})
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      local todo_comment = tc_integration.get_todo_at_cursor()
      local todo_id = tc_integration.track_todo(todo_comment)
      
      -- Update cache and virtual text
      tc_integration.update_cache()
      tc_integration.update_virtual_text(test_file, 2)
      
      -- Check if virtual text was set (this is a simplified check)
      local bufnr = vim.fn.bufnr(test_file)
      local extmarks = vim.api.nvim_buf_get_extmarks(
        bufnr,
        vim.api.nvim_create_namespace('todo_mcp_tracking'),
        0, -1,
        {}
      )
      
      assert.is_true(#extmarks > 0)
    end)
  end)
  
  describe("tracking status", function()
    it("should correctly identify tracked vs untracked TODOs", function()
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {2, 0})
      
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      
      -- Initially not tracked
      assert.is_false(tc_integration.is_tracked(test_file, 2))
      
      -- Track the TODO
      local todo_comment = tc_integration.get_todo_at_cursor()
      tc_integration.track_todo(todo_comment)
      tc_integration.update_cache()
      
      -- Now should be tracked
      assert.is_true(tc_integration.is_tracked(test_file, 2))
      
      -- Line 3 should still be untracked
      assert.is_false(tc_integration.is_tracked(test_file, 3))
    end)
  end)
end)