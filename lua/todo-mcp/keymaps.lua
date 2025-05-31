local M = {}

M.setup = function(keymaps)
  -- Global keymap to toggle the todo list
  vim.keymap.set("n", keymaps.toggle, function()
    require("todo-mcp.ui").toggle()
  end, { desc = "Toggle Todo List (MCP)" })
end

return M