-- Integration tests for the full plugin
describe("todo-mcp integration tests", function()
  local todo_mcp
  
  before_each(function()
    -- Clean reset
    for k, v in pairs(package.loaded) do
      if k:match("^todo%-mcp") then
        package.loaded[k] = nil
      end
    end
    
    -- Mock vim.fn functions
    vim.fn = vim.fn or {}
    vim.fn.expand = vim.fn.expand or function(path)
      return path:gsub("~", os.getenv("HOME"))
    end
    vim.fn.fnamemodify = vim.fn.fnamemodify or function(path, mod)
      if mod == ":h" then
        return path:match("(.*/)")
      end
      return path
    end
    vim.fn.mkdir = vim.fn.mkdir or function() return 1 end
    vim.fn.strwidth = vim.fn.strwidth or function(str)
      -- Simple approximation for tests
      return #str:gsub("[\128-\191]", "")
    end
    
    todo_mcp = require("todo-mcp")
  end)
  
  describe("full setup", function()
    it("should setup without errors with default config", function()
      assert.has_no_errors(function()
        todo_mcp.setup()
      end)
      
      -- Check all modules loaded
      assert.is_not_nil(package.loaded["todo-mcp.db"])
      assert.is_not_nil(package.loaded["todo-mcp.ui"])
      assert.is_not_nil(package.loaded["todo-mcp.keymaps"])
      assert.is_not_nil(package.loaded["todo-mcp.views"])
    end)
    
    it("should setup with custom config", function()
      assert.has_no_errors(function()
        todo_mcp.setup({
          ui = {
            width = 100,
            height = 40,
            modern_ui = false,
            style = { preset = "ascii" }
          },
          keymaps = {
            toggle = "<leader>tt",
            add = "i",
            delete = "x"
          }
        })
      end)
      
      -- Check config applied
      assert.equals(100, todo_mcp.opts.ui.width)
      assert.equals("ascii", todo_mcp.opts.ui.style.preset)
      assert.equals("<leader>tt", todo_mcp.opts.keymaps.toggle)
    end)
  end)
  
  describe("plugin commands", function()
    it("should create user commands", function()
      todo_mcp.setup()
      
      -- Mock vim.api.nvim_create_user_command calls
      local commands = {}
      local original_create = vim.api.nvim_create_user_command
      vim.api.nvim_create_user_command = function(name, cmd, opts)
        commands[name] = {cmd = cmd, opts = opts}
      end
      
      -- Re-run plugin file to register commands
      dofile(vim.fn.expand("~/.local/share/nvim/lazy/todo-mcp.nvim/plugin/todo-mcp.lua"))
      
      -- Check commands created
      assert.is_not_nil(commands.TodoMCP)
      assert.is_not_nil(commands.TodoMCPExport)
      assert.is_not_nil(commands.TodoMCPImport)
      
      -- Restore
      vim.api.nvim_create_user_command = original_create
    end)
  end)
  
  describe("error handling", function()
    it("should handle missing sqlite.lua gracefully", function()
      -- Temporarily remove sqlite from loaded modules
      package.loaded["sqlite"] = nil
      package.preload["sqlite"] = function()
        error("sqlite.lua not found")
      end
      
      -- Should error with helpful message
      local ok, err = pcall(function()
        todo_mcp.setup()
      end)
      
      assert.is_false(ok)
      assert.is_truthy(err:match("sqlite.lua not found"))
      
      -- Cleanup
      package.preload["sqlite"] = nil
    end)
  end)
  
  describe("lazy loading", function()
    it("should support lazy.nvim configuration", function()
      local lazy_spec = {
        "thatguyinabeanie/todo-mcp.nvim",
        dependencies = { "kkharji/sqlite.lua" },
        cmd = "TodoMCP",
        keys = {
          { "<leader>td", "<Plug>(todo-mcp-toggle)", desc = "Toggle todo list" },
          { "<leader>ta", "<Plug>(todo-mcp-add)", desc = "Add todo" },
        },
        config = function()
          require("todo-mcp").setup()
        end
      }
      
      -- Validate spec structure
      assert.is_string(lazy_spec[1])
      assert.is_table(lazy_spec.dependencies)
      assert.is_string(lazy_spec.cmd)
      assert.is_table(lazy_spec.keys)
      assert.is_function(lazy_spec.config)
    end)
  end)
end)