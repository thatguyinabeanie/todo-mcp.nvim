-- Test UI offset calculations
describe("todo-mcp UI offset calculations", function()
  local ui
  local db
  
  before_each(function()
    -- Clean reset
    for k, v in pairs(package.loaded) do
      if k:match("^todo%-mcp") then
        package.loaded[k] = nil
      end
    end
    
    -- Mock vim functions
    _G.vim = _G.vim or {}
    vim.fn = vim.fn or {}
    vim.fn.strwidth = function(str) return #str end
    vim.api = vim.api or {}
    vim.api.nvim_win_get_cursor = function(win)
      return {5, 0} -- Mock cursor on line 5
    end
    
    ui = require("todo-mcp.ui")
    db = require("todo-mcp.db")
  end)
  
  describe("header offset calculation", function()
    it("should return 3 for empty todo list", function()
      ui.state.todos = {}
      ui.state.search_active = false
      assert.equals(3, ui.get_header_offset())
    end)
    
    it("should return 4 for non-empty todo list", function()
      ui.state.todos = {{id = 1, content = "Test"}}
      ui.state.search_active = false
      assert.equals(4, ui.get_header_offset())
    end)
    
    it("should add 2 when search is active", function()
      ui.state.todos = {{id = 1, content = "Test"}}
      ui.state.search_active = true
      assert.equals(6, ui.get_header_offset())
    end)
  end)
  
  describe("cursor to todo index mapping", function()
    it("should map cursor position to correct todo", function()
      ui.state.todos = {
        {id = 1, content = "First todo"},
        {id = 2, content = "Second todo"},
        {id = 3, content = "Third todo"}
      }
      ui.state.search_active = false
      ui.state.win = 1 -- Mock window handle
      
      -- With stats line, offset is 4
      -- Line 5 should map to todo index 1
      local idx = ui.get_cursor_todo_idx()
      assert.equals(1, idx)
    end)
    
    it("should return nil for header lines", function()
      ui.state.todos = {{id = 1, content = "Test"}}
      ui.state.search_active = false
      ui.state.win = 1
      
      -- Mock cursor on line 3 (header area)
      vim.api.nvim_win_get_cursor = function(win)
        return {3, 0}
      end
      
      local idx = ui.get_cursor_todo_idx()
      assert.is_nil(idx)
    end)
    
    it("should handle search offset correctly", function()
      ui.state.todos = {{id = 1, content = "Test"}}
      ui.state.search_active = true
      ui.state.win = 1
      
      -- With search active, offset is 6 (4 + 2)
      -- Line 7 should map to todo index 1
      vim.api.nvim_win_get_cursor = function(win)
        return {7, 0}
      end
      
      local idx = ui.get_cursor_todo_idx()
      assert.equals(1, idx)
    end)
  end)
  
  describe("preview positioning", function()
    it("should show preview for correct todo", function()
      ui.state.todos = {
        {id = 1, content = "First", title = "Todo 1"},
        {id = 2, content = "Second", title = "Todo 2"}
      }
      ui.state.search_active = false
      ui.state.win = 1
      ui.config = {floating_preview = true}
      
      -- Mock cursor on line 6 (should be todo 2)
      vim.api.nvim_win_get_cursor = function(win)
        return {6, 0}
      end
      
      local shown_todo = nil
      ui.show_preview = function(todo)
        shown_todo = todo
      end
      
      -- Enable preview
      ui.state.preview_enabled = true
      local idx = ui.get_cursor_todo_idx()
      if idx and ui.state.todos[idx] then
        ui.show_preview(ui.state.todos[idx])
      end
      
      assert.is_not_nil(shown_todo)
      assert.equals("Todo 2", shown_todo.title)
    end)
  end)
end)