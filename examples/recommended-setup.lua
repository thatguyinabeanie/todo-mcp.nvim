-- Recommended LazyVim Setup for todo-mcp.nvim
-- Place in: ~/.config/nvim/lua/plugins/todo-mcp.lua

return {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "kkharji/sqlite.lua",
    -- Optional integrations
    "folke/todo-comments.nvim",
    "nvim-telescope/telescope.nvim",
  },
  cmd = "TodoMCP",
  keys = {
    -- Core functionality
    { "<leader>t", group = "todo" },
    { "<leader>td", "<cmd>TodoMCP toggle<cr>", desc = "Toggle Todo List" },
    { "<leader>ta", "<cmd>TodoMCP add<cr>", desc = "Add Todo" },
    { "<leader>ts", "<cmd>TodoMCP search<cr>", desc = "Search Todos" },
    { "<leader>tS", "<cmd>TodoMCP style<cr>", desc = "Cycle Visual Style" },
    
    -- Export
    { "<leader>te", group = "export" },
    { "<leader>tem", "<cmd>TodoMCP export markdown<cr>", desc = "Export to Markdown" },
    { "<leader>tej", "<cmd>TodoMCP export json<cr>", desc = "Export to JSON" },
    { "<leader>tea", "<cmd>TodoMCP export all<cr>", desc = "Export All Formats" },
    
    -- Config
    { "<leader>tc", group = "config" },
    { "<leader>tcp", "<cmd>TodoMCP config project<cr>", desc = "Edit Project Config" },
    { "<leader>tcg", "<cmd>TodoMCP config global<cr>", desc = "Edit Global Config" },
  },
  opts = {
    -- Modern UI settings
    ui = {
      width = 90,
      height = 35,
      border = "rounded",
      style = {
        preset = "modern",  -- modern | minimal | emoji | sections | compact | ascii
      },
    },
    -- Use project-specific databases in git repos
    db = {
      project_relative = true,
    },
    -- Export settings
    export = {
      directory = "exports",  -- Relative to project root
      confirm = true,
    },
    -- Picker preference (auto-detects best available)
    picker = "auto",  -- telescope | fzf | snacks | auto
    -- Integration settings
    integrations = {
      todo_comments = {
        enabled = true,
        auto_import = false,  -- Set to true to auto-sync TODO comments
      },
    },
    -- Project settings
    project = {
      auto_setup = true,  -- Run setup wizard on first use
    },
  },
  config = function(_, opts)
    require("todo-mcp").setup(opts)
    
    -- Optional: Set up which-key groups
    local ok, which_key = pcall(require, "which-key")
    if ok then
      which_key.register({
        ["<leader>t"] = { name = "+todo" },
        ["<leader>te"] = { name = "+export" },
        ["<leader>tc"] = { name = "+config" },
      })
    end
  end,
}