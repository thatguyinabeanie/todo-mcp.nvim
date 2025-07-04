local M = {}

M.setup = function(opts)
  opts = opts or {}
  
  -- Set default options
  M.opts = vim.tbl_deep_extend("force", {
    -- MCP server configuration
    mcp_server = {
      host = "localhost",
      port = 3333,
    },
    -- Database location
    db_path = vim.fn.expand("~/.local/share/nvim/todo-mcp.db"),
    -- UI settings
    ui = {
      width = 80,
      height = 30,
      border = "rounded",
      view_mode = "list", -- "list" or "markdown"
      style = {
        preset = "sections", -- Uses priority sections with emojis
        -- Beautiful defaults with priority sections and emoji
        priority_style = "emoji",
        priority_indicators = {
          high = "🔥",
          medium = "⚡",
          low = "💤"
        },
        layout = "priority_sections", -- Groups by priority
        show_metadata = true,
        show_timestamps = "relative",
        done_style = "dim"
      }
    },
    -- Internal keymaps (for todo list popup)
    keymaps = {
      toggle = "<leader>td",  -- Global keymap to toggle todo list
      add = "a",
      delete = "d",
      toggle_done = "<CR>",
      quit = "q",
    },
    -- Picker preference (telescope | fzf | snacks | auto)
    picker = "auto",
    -- Export settings
    export = {
      directory = function() return vim.fn.getcwd() end,
      -- Can also be a static path:
      -- directory = vim.fn.expand("~/Documents/todos"),
      confirm = true, -- Show confirmation before exporting
    },
    -- Integration settings
    integrations = {
      todo_comments = {
        enabled = true,
        auto_import = false,
      },
      external = {
        enabled = true,
        auto_sync = true,
        default_integration = "github",
        debug = false
      },
      ai = {
        enabled = true,
        auto_analyze = false, -- Analyze new TODOs automatically
        min_confidence = 60,  -- Minimum confidence to apply AI suggestions
        context_lines = 10    -- Lines of context to analyze around TODO
      },
      enterprise = {
        enabled = false,      -- Enable enterprise features
        team_sync = {
          enabled = false,
          sync_server = nil,
          team_id = nil,
          user_id = nil,
          sync_interval = 300 -- 5 minutes
        },
        reporting = {
          enabled = true,
          auto_generate = false,
          export_format = "markdown"
        }
      }
    }
  }, opts)
  
  -- Initialize modules lazily
  require("todo-mcp.db").setup(M.opts.db_path)
  require("todo-mcp.mcp").setup(M.opts.mcp_server)
  require("todo-mcp.ui").setup(M.opts.ui)
  require("todo-mcp.keymaps").setup(M.opts.keymaps)
  
  -- Setup pickers and integrations
  require("todo-mcp.pickers").setup()
  
  -- Setup integrations
  if M.opts.integrations.todo_comments.enabled then
    local tc_integration = require("todo-mcp.integrations.todo-comments")
    tc_integration.config = vim.tbl_extend("force", tc_integration.config, M.opts.integrations.todo_comments)
    tc_integration.setup()
    
    -- Setup code actions
    require("todo-mcp.integrations.code-actions").setup()
    
    -- Setup quickfix
    require("todo-mcp.integrations.quickfix").setup()
  end
  
  -- Setup external integrations
  if M.opts.integrations.external.enabled then
    require("todo-mcp.integrations.external").setup()
    
    -- Auto-sync status changes
    if M.opts.integrations.external.auto_sync then
      vim.api.nvim_create_autocmd("User", {
        pattern = "TodoMCPStatusChanged",
        callback = function(event)
          local external = require("todo-mcp.integrations.external")
          local todo_id = event.data.todo_id
          local new_status = event.data.new_status
          
          vim.schedule(function()
            external.sync_external_status(todo_id, new_status)
          end)
        end
      })
    end
  end
  
  -- Setup AI integrations
  if M.opts.integrations.ai.enabled then
    require("todo-mcp.ai.analyzer").setup()
  end
  
  -- Setup enterprise features
  if M.opts.integrations.enterprise.enabled then
    if M.opts.integrations.enterprise.team_sync.enabled then
      require("todo-mcp.enterprise.team-sync").setup(M.opts.integrations.enterprise.team_sync)
    end
    
    if M.opts.integrations.enterprise.reporting.enabled then
      require("todo-mcp.enterprise.reporting").setup(M.opts.integrations.enterprise.reporting)
    end
  end
  
  -- Setup telescope extension if available
  local has_telescope, telescope = pcall(require, 'telescope')
  if has_telescope then
    telescope.load_extension('todo_mcp')
  end
end

-- Expose main functions for <Plug> mappings
M.toggle = function()
  return require("todo-mcp.ui").toggle()
end

M.add = function(content, options)
  return require("todo-mcp.db").add(content, options)
end

M.add_with_options = function()
  return require("todo-mcp.ui").add_todo_with_options()
end

-- Open picker interface
M.picker = function(opts)
  return require("todo-mcp.pickers").open(opts)
end

-- Import from todo-comments
M.import = function()
  return require("todo-mcp.pickers").import_from_todo_comments()
end

return M