-- Project-specific configuration example for todo-mcp.nvim
-- This setup is optimized for managing todos within a specific project

require('todo-mcp').setup({
  -- Store todos in project directory
  db_path = vim.fn.getcwd() .. "/.todos/todo-mcp.db",
  
  -- Compact UI for focused work
  ui = {
    width = 60,
    height = 20,
    border = "single",
    style = {
      preset = "compact",
      layout = "priority_sections",  -- Organize by priority
      show_timestamps = "relative",   -- Show "2 hours ago" style times
      done_style = "hide",           -- Hide completed todos
    },
  },
  
  -- Project-specific keymaps
  keymaps = {
    toggle = "<leader>pt",  -- 'p' for project
  },
  
  -- Export to project docs directory
  export = {
    directory = function()
      -- Create docs directory if it doesn't exist
      local docs_dir = vim.fn.getcwd() .. "/docs"
      vim.fn.mkdir(docs_dir, "p")
      return docs_dir
    end,
    confirm = false,  -- Don't confirm for frequent exports
  },
  
  -- Enable code integration for development
  integrations = {
    todo_comments = {
      enabled = true,
      auto_import = true,  -- Auto-import TODO comments from code
    },
    external = {
      enabled = true,
      default_integration = "github",  -- Sync with GitHub issues
      auto_sync = false,  -- Manual sync only
    },
    ai = {
      enabled = true,
      auto_analyze = true,  -- Auto-analyze for better prioritization
      min_confidence = 70,
    },
  },
})

-- Project-specific keymaps
vim.keymap.set("n", "<leader>ptt", function()
  -- Add todo with current file context
  local file = vim.fn.expand("%:.")
  local line = vim.fn.line(".")
  vim.ui.input({ 
    prompt = "Todo (auto-linked to " .. file .. ":" .. line .. "): " 
  }, function(content)
    if content then
      require("todo-mcp.db").add(content, {
        file_path = vim.fn.expand("%:p"),
        line_number = line,
        priority = "medium",
      })
      require("todo-mcp.ui").refresh()
    end
  end)
end, { desc = "Add project todo with file context" })

vim.keymap.set("n", "<leader>ptr", function()
  -- Generate project report
  require("todo-mcp.enterprise.reporting").generate_report({
    format = "markdown",
    output = vim.fn.getcwd() .. "/docs/todo-report.md",
    include_completed = true,
    group_by = "priority",
  })
end, { desc = "Generate project todo report" })