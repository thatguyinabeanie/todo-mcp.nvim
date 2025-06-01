-- ═══════════════════════════════════════════════════════════════════════════════
-- todo-mcp.nvim UI Configuration Examples
-- ═══════════════════════════════════════════════════════════════════════════════

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🎨 Modern UI Configuration (Recommended)                                   │
-- └─────────────────────────────────────────────────────────────────────────────┘

local modern_config = {
  ui = {
    -- Window settings
    width = 85,
    height = 35,
    border = "rounded",
    
    -- Modern UI features (v2.0+)
    modern_ui = true,           -- Enable Unicode borders and modern styling
    animation_speed = 150,      -- Smooth animations (50-500ms, 0 to disable)
    floating_preview = true,    -- Show floating preview windows
    preview_enabled = true,     -- Auto-preview on navigation
    status_line = true,         -- Status line integration
    view_mode = "list",         -- "list" or "markdown"
    
    -- Visual theme
    style = {
      preset = "modern",        -- Enhanced visual hierarchy
      show_metadata = true,     -- Show tags, file links, timestamps
      show_timestamps = "relative", -- "relative", "absolute", or "none"
      done_style = "dim"        -- "dim", "strikethrough", or "hidden"
    }
  },
  
  -- Keymaps
  keymaps = {
    add = "a",
    delete = "d",
    toggle_done = "<CR>",
    quit = "q"
  }
}

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🎯 Minimal Configuration (Performance Focus)                               │
-- └─────────────────────────────────────────────────────────────────────────────┘

local minimal_config = {
  ui = {
    width = 70,
    height = 25,
    border = "single",
    
    -- Disable heavy features for performance
    modern_ui = false,
    animation_speed = 0,        -- No animations
    floating_preview = false,   -- No floating windows
    preview_enabled = false,    -- No auto-preview
    status_line = false,        -- No status line updates
    
    style = {
      preset = "minimal",       -- Clean, distraction-free
      show_metadata = false,    -- Hide extra information
      show_timestamps = "none", -- No timestamps
      layout = "flat"           -- Simple list layout
    }
  }
}

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🌈 Colorful Configuration (Visual Appeal)                                  │
-- └─────────────────────────────────────────────────────────────────────────────┘

local colorful_config = {
  ui = {
    width = 90,
    height = 40,
    border = "rounded",
    
    modern_ui = true,
    animation_speed = 200,      -- Slower, more noticeable animations
    floating_preview = true,
    preview_enabled = true,
    status_line = true,
    
    style = {
      preset = "emoji",         -- Emoji indicators
      priority_style = "emoji", -- 🔥⚡💤 indicators
      layout = "priority_sections", -- Group by priority
      show_metadata = true,
      show_timestamps = "relative",
      done_style = "strikethrough"
    }
  }
}

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 📊 Professional Configuration (Enterprise Use)                             │
-- └─────────────────────────────────────────────────────────────────────────────┘

local professional_config = {
  ui = {
    width = 95,
    height = 45,
    border = "double",
    
    modern_ui = true,
    animation_speed = 100,      -- Quick, professional animations
    floating_preview = true,
    preview_enabled = true,
    status_line = true,
    
    style = {
      preset = "sections",      -- Organized by priority sections
      priority_style = "bracket", -- [H] [M] [L] indicators
      layout = "priority_sections",
      show_metadata = true,
      show_timestamps = "absolute", -- Full timestamps
      done_style = "dim"
    }
  },
  
  -- Enterprise features
  integrations = {
    linear = { enabled = true },
    github = { enabled = true },
    jira = { enabled = true }
  }
}

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🖥️  Terminal-Safe Configuration (SSH/Legacy Support)                       │
-- └─────────────────────────────────────────────────────────────────────────────┘

local terminal_safe_config = {
  ui = {
    width = 80,
    height = 30,
    border = "single",
    
    modern_ui = false,          -- Disable Unicode features
    animation_speed = 0,        -- No animations for SSH
    floating_preview = false,   -- Avoid complex windows
    preview_enabled = false,
    status_line = false,
    
    style = {
      preset = "ascii",         -- ASCII-only characters
      priority_style = "bracket", -- [H] [M] [L]
      layout = "flat",
      show_metadata = true,
      show_timestamps = "none",
      done_style = "none"       -- No visual effects
    }
  }
}

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🎨 Custom Theme Configuration                                              │
-- └─────────────────────────────────────────────────────────────────────────────┘

local custom_theme_config = {
  ui = {
    width = 80,
    height = 30,
    border = "rounded",
    
    modern_ui = true,
    animation_speed = 150,
    floating_preview = true,
    preview_enabled = true,
    status_line = true,
    
    style = {
      -- Custom status indicators
      status_indicators = {
        todo = "▷",
        in_progress = "▶",
        done = "▣"
      },
      
      -- Custom priority indicators
      priority_style = "custom",
      priority_indicators = {
        high = "🚨",
        medium = "⚠️",
        low = "📝"
      },
      
      layout = "grouped",
      show_metadata = true,
      show_timestamps = "relative",
      done_style = "strikethrough"
    }
  }
}

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🎯 Usage Examples                                                          │
-- └─────────────────────────────────────────────────────────────────────────────┘

-- Choose one configuration and use it like this:
-- require("todo-mcp").setup(modern_config)

-- Or mix and match options:
-- require("todo-mcp").setup({
--   ui = vim.tbl_deep_extend("force", modern_config.ui, {
--     width = 100,  -- Override just the width
--     style = { preset = "emoji" }  -- Override the theme
--   })
-- })

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 🎨 Custom Highlight Configuration                                          │
-- └─────────────────────────────────────────────────────────────────────────────┘

local function setup_custom_highlights()
  -- Modern dark theme (Catppuccin-inspired)
  vim.api.nvim_set_hl(0, "TodoNormal", { bg = "#1e1e2e", fg = "#cdd6f4" })
  vim.api.nvim_set_hl(0, "TodoCursorLine", { bg = "#313244", bold = true })
  vim.api.nvim_set_hl(0, "TodoBorderCorner", { fg = "#89b4fa", bold = true })
  vim.api.nvim_set_hl(0, "TodoBorderHorizontal", { fg = "#74c7ec" })
  vim.api.nvim_set_hl(0, "TodoBorderVertical", { fg = "#74c7ec" })
  
  -- Priority colors
  vim.api.nvim_set_hl(0, "TodoPriorityHigh", { fg = "#f38ba8", bold = true })
  vim.api.nvim_set_hl(0, "TodoPriorityMedium", { fg = "#f9e2af", bold = true })
  vim.api.nvim_set_hl(0, "TodoPriorityLow", { fg = "#a6e3a1" })
  
  -- Status indicators
  vim.api.nvim_set_hl(0, "TodoDone", { fg = "#6c7086", italic = true, strikethrough = true })
  vim.api.nvim_set_hl(0, "TodoInProgress", { fg = "#74c7ec", bold = true })
  vim.api.nvim_set_hl(0, "TodoActive", { fg = "#cdd6f4" })
end

-- Apply custom highlights after setup
-- vim.api.nvim_create_autocmd("User", {
--   pattern = "TodoMCPSetup",
--   callback = setup_custom_highlights
-- })

-- ┌─────────────────────────────────────────────────────────────────────────────┐
-- │ 📚 Complete Setup Example                                                  │
-- └─────────────────────────────────────────────────────────────────────────────┘

-- Complete lazy.nvim configuration with modern UI:
local complete_setup = {
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = {
    "kkharji/sqlite.lua",
  },
  cmd = "TodoMCP",
  keys = {
    { "<leader>td", "<Plug>(todo-mcp-toggle)", desc = "Toggle todo list" },
    { "<leader>ta", "<Plug>(todo-mcp-add)", desc = "Add todo" },
    { "<leader>tA", "<Plug>(todo-mcp-add-advanced)", desc = "Add todo with options" },
  },
  config = function()
    require("todo-mcp").setup(modern_config)
    
    -- Optional: Setup custom highlights
    setup_custom_highlights()
    
    -- Optional: Status line integration
    if modern_config.ui.status_line then
      vim.opt.statusline = "%<%f %h%m%r%=%-14.(%l,%c%V%) %P %{v:lua.vim.g.todo_mcp_status or ''}"
    end
  end
}

return {
  modern = modern_config,
  minimal = minimal_config,
  colorful = colorful_config,
  professional = professional_config,
  terminal_safe = terminal_safe_config,
  custom_theme = custom_theme_config,
  complete_setup = complete_setup,
  setup_custom_highlights = setup_custom_highlights
}