-- Full configuration example for todo-mcp.nvim
-- This file shows all available configuration options with descriptions

require('todo-mcp').setup({
  -- MCP server configuration
  mcp_server = {
    host = "localhost",           -- MCP server host
    port = 3333,                  -- MCP server port
  },
  
  -- Database location
  db_path = vim.fn.expand("~/.local/share/nvim/todo-mcp.db"),
  
  -- UI settings
  ui = {
    width = 80,                   -- Width of the todo list window
    height = 30,                  -- Height of the todo list window
    border = "rounded",           -- Border style: "none", "single", "double", "rounded", "solid", "shadow"
    view_mode = "list",           -- Display mode: "list" or "markdown"
    style = {
      preset = "emoji",           -- Style preset: "minimal", "emoji", "sections", "compact", "ascii"
      
      -- Custom style overrides (optional - uncomment to use)
      -- status_indicators = {
      --   todo = "○",
      --   in_progress = "◐",
      --   done = "✓"
      -- },
      -- priority_style = "emoji", -- "emoji", "color", "symbol", "bracket", "none"
      -- layout = "grouped",       -- "flat", "grouped", "priority_sections"
      -- show_metadata = true,     -- Show creation/update times
      -- show_timestamps = "relative", -- "relative", "absolute", "none"
      -- done_style = "dim",       -- "dim", "strikethrough", "hide"
    },
    floating_preview = true,      -- Enable floating preview window
    status_line = true,           -- Show todo stats in status line
    animation = true,             -- Enable UI animations
  },
  
  -- Keymaps (for todo list popup)
  keymaps = {
    toggle = "<leader>td",        -- Global keymap to toggle todo list
    add = "a",                    -- Add new todo
    delete = "d",                 -- Delete todo
    toggle_done = "<CR>",         -- Toggle todo done/undone
    quit = "q",                   -- Close todo list
  },
  
  -- Picker preference
  picker = "auto",                -- "telescope", "fzf", "snacks", "auto"
  
  -- Export settings
  export = {
    directory = function()        -- Export directory (can be string or function)
      return vim.fn.getcwd()      -- Default: current working directory
    end,
    -- directory = "~/Documents/todos", -- Static path example
    confirm = true,               -- Show confirmation before exporting
  },
  
  -- Integration settings
  integrations = {
    -- Todo comments integration (TODO, FIXME, etc. in code)
    todo_comments = {
      enabled = true,             -- Enable todo-comments.nvim integration
      auto_import = false,        -- Auto-import TODOs from code comments
    },
    
    -- External services integration (GitHub, Jira, Linear)
    external = {
      enabled = true,             -- Enable external integrations
      auto_sync = true,           -- Auto-sync with external services
      default_integration = "github", -- Default service: "github", "jira", "linear"
      debug = false,              -- Enable debug logging
    },
    
    -- AI features
    ai = {
      enabled = true,             -- Enable AI features
      auto_analyze = false,       -- Analyze new TODOs automatically
      min_confidence = 60,        -- Minimum confidence to apply AI suggestions (0-100)
      context_lines = 10,         -- Lines of context to analyze around TODO
    },
    
    -- Enterprise features
    enterprise = {
      enabled = false,            -- Enable enterprise features
      
      -- Team synchronization
      team_sync = {
        enabled = false,          -- Enable team sync
        sync_server = nil,        -- Sync server URL
        team_id = nil,            -- Team identifier
        user_id = nil,            -- User identifier
        sync_interval = 300,      -- Sync interval in seconds (5 minutes)
      },
      
      -- Reporting
      reporting = {
        enabled = true,           -- Enable reporting features
        auto_generate = false,    -- Auto-generate reports
        export_format = "markdown", -- Report format: "markdown", "json", "yaml"
      },
    },
  },
})

-- Example of setting up additional keymaps globally
vim.keymap.set("n", "<leader>ta", function()
  require("todo-mcp.ui").add_todo_with_options()
end, { desc = "Add todo with options" })

vim.keymap.set("n", "<leader>ts", function()
  require("todo-mcp.pickers").search_todos()
end, { desc = "Search todos" })

vim.keymap.set("n", "<leader>te", function()
  require("todo-mcp.export").export_all()
end, { desc = "Export todos to all formats" })

-- Example of setting up MCP servers (if using external integrations)
-- Make sure to set these environment variables:
-- export GITHUB_TOKEN="your-github-token"
-- export JIRA_API_TOKEN="your-jira-token"
-- export LINEAR_API_KEY="your-linear-key"