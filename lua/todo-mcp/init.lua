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
    },
    -- Internal keymaps (for todo list popup)
    keymaps = {
      add = "a",
      delete = "d",
      toggle_done = "<CR>",
      quit = "q",
    },
  }, opts)
  
  -- Initialize modules lazily
  require("todo-mcp.db").setup(M.opts.db_path)
  require("todo-mcp.mcp").setup(M.opts.mcp_server)
  require("todo-mcp.ui").setup(M.opts.ui)
  require("todo-mcp.keymaps").setup(M.opts.keymaps)
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

return M