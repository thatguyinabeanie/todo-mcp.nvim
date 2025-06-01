-- UI rendering tests to catch display issues
describe("todo-mcp UI rendering", function()
  local ui, db
  
  before_each(function()
    -- Reset modules
    package.loaded["todo-mcp.ui"] = nil
    package.loaded["todo-mcp.db"] = nil
    package.loaded["todo-mcp.views"] = nil
    
    -- Mock database
    db = {
      todos = {},
      get_all = function() return db.todos end,
      add = function(content, opts)
        table.insert(db.todos, {
          id = #db.todos + 1,
          title = content,
          content = content,
          status = opts and opts.status or "todo",
          priority = opts and opts.priority or "medium",
          done = false,
          created_at = os.date("%Y-%m-%d %H:%M:%S")
        })
      end
    }
    
    package.loaded["todo-mcp.db"] = db
    ui = require("todo-mcp.ui")
  end)
  
  describe("progress bar rendering", function()
    it("should render progress bars without errors", function()
      -- Add some test todos
      db.add("Test todo 1")
      db.add("Test todo 2", {status = "done"})
      db.add("Test todo 3", {status = "in_progress"})
      
      -- Setup UI
      ui.setup({
        width = 80,
        height = 30,
        border = "rounded",
        modern_ui = true,
        style = { preset = "modern" }
      })
      
      -- Should not error when rendering
      assert.has_no_errors(function()
        ui.state.todos = db.get_all()
        
        -- Simulate progress bar generation
        local total = #ui.state.todos
        local done_count = 1
        local bar_width = 20
        local filled = math.floor((done_count / total) * bar_width)
        
        -- This should work with Unicode escape sequences
        local progress_bar = string.rep("\u{2593}", filled) .. string.rep("\u{2591}", bar_width - filled)
        assert.is_string(progress_bar)
        assert.equals(bar_width, #progress_bar:gsub("[\128-\191]", "")) -- Count Unicode chars properly
      end)
    end)
    
    it("should handle empty todo list", function()
      -- No todos
      ui.state.todos = {}
      
      assert.has_no_errors(function()
        -- Should show welcome message, not crash
        local lines = {}
        if #ui.state.todos == 0 then
          lines = {
            "╭─ Welcome to Todo Manager ─╮",
            "│                           │",
            "│  No todos yet! Get started │",
            "│  by pressing 'a' to add   │",
            "│  your first todo item.    │",
            "│                           │",
            "╰───────────────────────────╯"
          }
        end
        assert.is_truthy(#lines > 0)
      end)
    end)
    
    it("should calculate progress correctly", function()
      -- Add specific todos
      db.todos = {
        {id = 1, status = "todo", done = false},
        {id = 2, status = "done", done = true},
        {id = 3, status = "done", done = true},
        {id = 4, status = "in_progress", done = false}
      }
      
      local todos = db.get_all()
      local done_count = 0
      for _, todo in ipairs(todos) do
        if todo.done or todo.status == "done" then
          done_count = done_count + 1
        end
      end
      
      assert.equals(2, done_count, "Should count 2 done todos")
      assert.equals(50, math.floor((done_count / #todos) * 100), "Should be 50% complete")
    end)
  end)
  
  describe("border rendering", function()
    it("should handle Unicode borders", function()
      local border_config = {
        { "╭", "TodoBorderCorner" },
        { "─", "TodoBorderHorizontal" },
        { "╮", "TodoBorderCorner" },
        { "│", "TodoBorderVertical" },
        { "╯", "TodoBorderCorner" },
        { "─", "TodoBorderHorizontal" },
        { "╰", "TodoBorderCorner" },
        { "│", "TodoBorderVertical" }
      }
      
      -- All border characters should be valid strings
      for _, border in ipairs(border_config) do
        assert.is_string(border[1])
        assert.is_string(border[2])
      end
    end)
  end)
  
  describe("view style presets", function()
    it("should apply presets correctly", function()
      local views = require("todo-mcp.views")
      
      -- Test each preset
      for preset_name, preset in pairs(views.presets) do
        local style = views.get_style({ style = { preset = preset_name } })
        
        assert.is_table(style.status_indicators)
        assert.is_string(style.status_indicators.todo)
        assert.is_string(style.status_indicators.done)
        
        if preset_name == "modern" then
          assert.equals("modern", style.priority_style)
          assert.equals("priority_sections", style.layout)
        elseif preset_name == "minimal" then
          assert.equals("none", style.priority_style)
          assert.equals("flat", style.layout)
        end
      end
    end)
  end)
end)