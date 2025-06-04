-- Minimal configuration example for todo-mcp.nvim
-- This is the simplest setup to get started

require('todo-mcp').setup({
  -- Just use defaults for everything
})

-- That's it! The plugin will use sensible defaults:
-- - Database stored in ~/.local/share/nvim/todo-mcp.db
-- - UI with emoji style and rounded borders
-- - Export to current working directory with confirmation
-- - <leader>td to toggle the todo list
-- - All integrations enabled but not auto-syncing