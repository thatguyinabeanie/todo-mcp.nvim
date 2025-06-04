-- LazyVim configuration for todo-mcp.nvim
-- Place this in ~/.config/nvim/lua/plugins/todo-mcp.lua

return {
  -- Todo-MCP plugin configuration
  {
    "thatguyinabeanie/todo-mcp.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "kkharji/sqlite.lua",
      -- Optional but recommended
      "nvim-telescope/telescope.nvim",
      "folke/todo-comments.nvim",
    },
    -- Load on command or keymap
    cmd = { "TodoMCP" },
    keys = {
      { "<leader>td", "<cmd>TodoMCP toggle<cr>", desc = "Toggle Todo List" },
      { "<leader>ta", "<cmd>TodoMCP add<cr>", desc = "Add Todo" },
      { "<leader>ts", "<cmd>TodoMCP search<cr>", desc = "Search Todos" },
      { "<leader>tS", "<cmd>TodoMCP style<cr>", desc = "Cycle Todo Style" },
      -- Additional convenience mappings
      { "<leader>te", group = "todo export" },
      { "<leader>tem", "<cmd>TodoMCP export markdown<cr>", desc = "Export to Markdown" },
      { "<leader>tej", "<cmd>TodoMCP export json<cr>", desc = "Export to JSON" },
      { "<leader>tey", "<cmd>TodoMCP export yaml<cr>", desc = "Export to YAML" },
      { "<leader>tea", "<cmd>TodoMCP export all<cr>", desc = "Export All Formats" },
      -- Setup and config
      { "<leader>tc", group = "todo config" },
      { "<leader>tcp", "<cmd>TodoMCP config project<cr>", desc = "Edit Project Config" },
      { "<leader>tcg", "<cmd>TodoMCP config global<cr>", desc = "Edit Global Config" },
      { "<leader>tcs", "<cmd>TodoMCP setup project<cr>", desc = "Run Setup Wizard" },
    },
    opts = {
      -- These are setup() options, not config options
      -- Most config is handled by the config system
      db = {
        project_relative = true,  -- Use project-specific databases
      },
      ui = {
        width = 90,              -- Wider for modern displays
        height = 35,
        border = "rounded",
        style = {
          preset = "modern",     -- LazyVim users often prefer modern UI
        },
      },
      keymaps = {
        toggle = "<leader>td",   -- This is for the global toggle
        -- Internal keymaps (inside todo list)
        add = "a",
        delete = "d",
        toggle_done = "<CR>",
        quit = "q",
      },
      -- Picker preference
      picker = "auto",           -- "telescope" | "fzf" | "snacks" | "auto"
                                -- LazyVim users might prefer "snacks" explicitly
                                -- "auto" will use: telescope > fzf > snacks > built-in
      integrations = {
        todo_comments = {
          enabled = true,        -- LazyVim includes todo-comments by default
          auto_import = false,   -- Set to true if you want auto-sync
        },
      },
      project = {
        auto_setup = true,       -- Run wizard on first use in projects
      },
    },
    config = function(_, opts)
      require("todo-mcp").setup(opts)
      
      -- Optional: Set up which-key descriptions if you have it
      local ok, which_key = pcall(require, "which-key")
      if ok then
        which_key.register({
          ["<leader>t"] = { name = "+todo" },
          ["<leader>te"] = { name = "+export" },
          ["<leader>tc"] = { name = "+config" },
        })
      end
      
      -- Optional: Add to dashboard
      local dashboard_ok, dashboard = pcall(require, "alpha.themes.dashboard")
      if dashboard_ok then
        -- Add to dashboard buttons
        table.insert(dashboard.section.buttons.val, 
          dashboard.button("t", "󰄵  Todo List", "<cmd>TodoMCP toggle<cr>"))
      end
    end,
  },
  
  -- Optional: Enhanced todo-comments integration
  {
    "folke/todo-comments.nvim",
    optional = true,
    opts = function(_, opts)
      -- Add todo-mcp specific keywords if desired
      opts.keywords = vim.tbl_extend("force", opts.keywords or {}, {
        TASK = { icon = "󰄵", color = "info", alt = { "TASKS" } },
        DONE = { icon = "✓", color = "hint", alt = { "COMPLETED" } },
      })
      return opts
    end,
  },
  
  -- Optional: Add telescope integration
  {
    "nvim-telescope/telescope.nvim",
    optional = true,
    keys = {
      {
        "<leader>st",
        function()
          require("telescope").extensions.todo_mcp.todos()
        end,
        desc = "Search Todos (Telescope)",
      },
    },
    opts = function(_, opts)
      -- Ensure telescope loads the extension
      return vim.tbl_deep_extend("force", opts, {
        extensions = {
          todo_mcp = {
            -- Extension-specific options
          },
        },
      })
    end,
    config = function(_, opts)
      local telescope = require("telescope")
      telescope.setup(opts)
      -- Load todo-mcp extension if available
      pcall(telescope.load_extension, "todo_mcp")
    end,
  },
  
  -- Optional: Noice integration for better notifications
  {
    "folke/noice.nvim",
    optional = true,
    opts = {
      routes = {
        -- Route todo-mcp notifications to mini view
        {
          filter = {
            event = "notify",
            find = "Todo",
          },
          view = "mini",
        },
      },
    },
  },
  
  -- Optional: Add lualine component
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      -- Add todo count to lualine
      local function todo_status()
        local ok, stats = pcall(function()
          return require("todo-mcp.query").stats()
        end)
        if not ok or not stats then
          return ""
        end
        
        if stats.total == 0 then
          return ""
        end
        
        local icon = stats.completion_rate == 100 and "✓" or "󰄵"
        return string.format("%s %d/%d", icon, stats.completed, stats.total)
      end
      
      -- Add to lualine sections
      table.insert(opts.sections.lualine_x, 1, todo_status)
      
      return opts
    end,
  },
}

-- Alternative: Minimal configuration
-- return {
--   {
--     "thatguyinabeanie/todo-mcp.nvim",
--     dependencies = {
--       "nvim-lua/plenary.nvim",
--       "kkharji/sqlite.lua",
--     },
--     cmd = "TodoMCP",
--     keys = {
--       { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" },
--     },
--     opts = {},
--   },
-- }