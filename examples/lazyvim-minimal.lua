-- Minimal LazyVim configuration for todo-mcp.nvim
-- Place this in ~/.config/nvim/lua/plugins/todo-mcp.lua

return {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "kkharji/sqlite.lua",
  },
  cmd = "TodoMCP",
  keys = {
    { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" },
    { "<leader>ta", function() 
        vim.ui.input({ prompt = "Todo: " }, function(input)
          if input then
            require("todo-mcp").add(input)
            vim.notify("Todo added", vim.log.levels.INFO)
          end
        end)
      end, 
      desc = "Add Todo" 
    },
  },
  opts = {
    -- Everything else uses smart defaults
  },
}