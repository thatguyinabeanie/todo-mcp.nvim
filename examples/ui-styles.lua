-- UI Style Examples for todo-mcp.nvim
-- Shows different visual style configurations
-- Place in: ~/.config/nvim/lua/plugins/todo-mcp.lua

-- Modern Style (Default) - Clean with progress bars
local modern = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "kkharji/sqlite.lua" },
  cmd = "TodoMCP",
  keys = {
    { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" },
    { "<leader>tS", "<cmd>TodoMCP style<cr>", desc = "Cycle Style" },
  },
  opts = {
    ui = {
      style = {
        preset = "modern",
        show_metadata = true,
        show_timestamps = "relative",
        priority_style = "emoji",
      },
    },
  },
}

-- Minimal Style - Fast and distraction-free
local minimal = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "kkharji/sqlite.lua" },
  cmd = "TodoMCP",
  keys = { { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" } },
  opts = {
    ui = {
      width = 60,
      height = 20,
      border = "none",
      style = {
        preset = "minimal",
        show_metadata = false,
        show_timestamps = "none",
        done_style = "hide",
      },
    },
  },
}

-- Emoji Style - Visual and fun
local emoji = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "kkharji/sqlite.lua" },
  cmd = "TodoMCP",
  keys = { { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" } },
  opts = {
    ui = {
      style = {
        preset = "emoji",
        priority_style = "emoji",  -- 🔥⚡💤
        status_indicators = {
          todo = "📝",
          in_progress = "🚧",
          done = "✅",
        },
      },
    },
  },
}

-- ASCII Style - Terminal-safe, SSH-friendly
local ascii = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "kkharji/sqlite.lua" },
  cmd = "TodoMCP",
  keys = { { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" } },
  opts = {
    ui = {
      border = "ascii",
      style = {
        preset = "ascii",
        priority_style = "bracket",  -- [H] [M] [L]
        status_indicators = {
          todo = "[ ]",
          in_progress = "[~]",
          done = "[x]",
        },
      },
    },
  },
}

-- Sections Style - Organized by priority
local sections = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "kkharji/sqlite.lua" },
  cmd = "TodoMCP",
  keys = { { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" } },
  opts = {
    ui = {
      width = 90,
      height = 40,
      style = {
        preset = "sections",
        layout = "priority_sections",
        show_metadata = true,
        priority_style = "symbol",  -- ▲ ■ ▼
      },
    },
  },
}

-- Custom Style - Mix and match
local custom = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "nvim-lua/plenary.nvim", "kkharji/sqlite.lua" },
  cmd = "TodoMCP",
  keys = { { "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" } },
  opts = {
    ui = {
      width = 85,
      height = 35,
      border = "rounded",
      style = {
        -- Start with a preset
        preset = "modern",
        -- Then customize specific elements
        status_indicators = {
          todo = "○",
          in_progress = "◐",
          done = "●",
        },
        priority_indicators = {
          high = "!!!",
          medium = "!!",
          low = "!",
        },
        priority_style = "custom",
        layout = "grouped",
        show_metadata = true,
        show_timestamps = "absolute",
        done_style = "strikethrough",
      },
    },
  },
}

-- Export your preferred style
return modern  -- Change this to minimal, emoji, ascii, sections, or custom