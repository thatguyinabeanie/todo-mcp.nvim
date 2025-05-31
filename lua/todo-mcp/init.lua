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
      width = 60,
      height = 20,
      border = "rounded",
    },
    -- Keymaps
    keymaps = {
      toggle = "<leader>td",
      add = "a",
      delete = "d",
      toggle_done = "<CR>",
      quit = "q",
    },
  }, opts)
  
  -- Initialize modules
  require("todo-mcp.db").setup(M.opts.db_path)
  require("todo-mcp.mcp").setup(M.opts.mcp_server)
  require("todo-mcp.ui").setup(M.opts.ui)
  require("todo-mcp.keymaps").setup(M.opts.keymaps)
end

return M