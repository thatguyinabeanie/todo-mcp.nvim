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
        preset = "emoji", -- minimal | emoji | sections | compact | ascii
        -- Custom overrides (optional)
        -- status_indicators = { todo = "○", in_progress = "◐", done = "✓" },
        -- priority_style = "emoji", -- emoji | color | symbol | bracket | none
        -- layout = "grouped", -- flat | grouped | priority_sections
        -- show_metadata = true,
        -- show_timestamps = "relative", -- relative | absolute | none
        -- done_style = "dim", -- dim | strikethrough | hide
      }
    },
    -- Internal keymaps (for todo list popup)
    keymaps = {
      add = "a",
      delete = "d",
      toggle_done = "<CR>",
      quit = "q",
    },
    -- Picker preference (telescope | fzf | snacks | auto)
    picker = "auto",
    -- Integration settings
    integrations = {
      todo_comments = {
        enabled = true,
        auto_import = false,
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