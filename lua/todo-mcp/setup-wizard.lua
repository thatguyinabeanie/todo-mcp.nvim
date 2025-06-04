-- Setup wizard for first-time project configuration
local M = {}
local utils = require("todo-mcp.utils")
local config_manager = require("todo-mcp.config")

-- Check if project is already configured
M.is_configured = config_manager.is_project_configured

-- Load project config
M.load_config = config_manager.load_project_config

-- Save project config
M.save_config = function(config)
  config_manager.save_project_config(config)
  
  -- Add to .gitignore if it exists
  M.update_gitignore(config.db.project_dir)
  
  return vim.fn.getcwd() .. "/.todo-mcp/config.json"
end

-- Update .gitignore to include project directory
M.update_gitignore = function(project_dir)
  local gitignore_path = vim.fn.getcwd() .. "/.gitignore"
  local should_ignore_db = true
  local should_ignore_exports = false
  
  -- Check if .gitignore exists
  if vim.fn.filereadable(gitignore_path) == 1 then
    local lines = vim.fn.readfile(gitignore_path)
    local has_project_dir = false
    
    for _, line in ipairs(lines) do
      if line:match("^" .. vim.pesc(project_dir)) then
        has_project_dir = true
        break
      end
    end
    
    if not has_project_dir then
      -- Ask user what to ignore
      vim.ui.select(
        {"Ignore entire directory", "Ignore only database", "Don't add to .gitignore"},
        { prompt = "Add " .. project_dir .. " to .gitignore?" },
        function(choice)
          if choice == "Ignore entire directory" then
            table.insert(lines, "")
            table.insert(lines, "# Todo-MCP project files")
            table.insert(lines, project_dir .. "/")
          elseif choice == "Ignore only database" then
            table.insert(lines, "")
            table.insert(lines, "# Todo-MCP database")
            table.insert(lines, project_dir .. "/*.db")
            table.insert(lines, project_dir .. "/*.db-*")
          end
          
          if choice ~= "Don't add to .gitignore" then
            vim.fn.writefile(lines, gitignore_path)
          end
        end
      )
    end
  end
end

-- Run the setup wizard
M.run = function(callback, mode)
  mode = mode or "project" -- "project" or "global"
  
  -- Start with current configuration as base
  local base_config = config_manager.get_config()
  local config = {}
  
  local wizard_buf = vim.api.nvim_create_buf(false, true)
  
  -- Create welcome screen
  local title = mode == "global" and "Global Configuration" or "Project Configuration"
  local lines = {
    "╭─────────────────────────────────────────────────╮",
    "│          Welcome to Todo-MCP Setup              │",
    "│                                                 │",
    "│  " .. title .. string.rep(" ", 45 - #title) .. "│",
    "│                                                 │",
    "│  This wizard will help you configure Todo-MCP  │",
    "│  " .. (mode == "global" and "globally for all projects." or "for this project.") .. string.rep(" ", mode == "global" and 20 or 29) .. "│",
    "│                                                 │",
    "│  Press ENTER to continue or ESC to cancel      │",
    "╰─────────────────────────────────────────────────╯",
  }
  
  vim.api.nvim_buf_set_lines(wizard_buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(wizard_buf, 'modifiable', false)
  vim.api.nvim_buf_set_option(wizard_buf, 'buftype', 'nofile')
  
  local win = vim.api.nvim_open_win(wizard_buf, true, {
    relative = 'editor',
    row = math.floor((vim.o.lines - 10) / 2),
    col = math.floor((vim.o.columns - 52) / 2),
    width = 52,
    height = 10,
    style = 'minimal',
    border = 'rounded',
    title = ' Todo-MCP Setup ',
    title_pos = 'center'
  })
  
  -- Setup wizard flow
  local function step1_project_dir()
    vim.api.nvim_win_close(win, true)
    
    if mode == "global" then
      -- Skip project directory for global config
      step2_view_style()
      return
    end
    
    vim.ui.input({
      prompt = "Project directory name (default: .todo-mcp): ",
      default = base_config.db.project_dir
    }, function(input)
      if input == nil then
        -- User cancelled
        if callback then callback(nil) end
        return
      end
      
      config.db = config.db or {}
      config.db.project_dir = input ~= "" and input or base_config.db.project_dir
      step2_view_style()
    end)
  end
  
  local function step2_view_style()
    vim.ui.select(
      {"modern", "minimal", "emoji", "sections", "compact", "ascii"},
      { 
        prompt = "Select default view style:",
        format_item = function(item)
          local descriptions = {
            modern = "Modern - Clean with progress bars",
            minimal = "Minimal - Simple and fast",
            emoji = "Emoji - Visual with emoji indicators",
            sections = "Sections - Organized by priority",
            compact = "Compact - Space-efficient",
            ascii = "ASCII - Terminal-safe"
          }
          return descriptions[item] or item
        end
      },
      function(choice)
        if choice == nil then
          if callback then callback(nil) end
          return
        end
        
        config.ui = config.ui or {}
        config.ui.style = config.ui.style or {}
        config.ui.style.preset = choice
        step3_priority_style()
      end
    )
  end
  
  local function step3_priority_style()
    vim.ui.select(
      {"emoji", "color", "symbol", "bracket", "none"},
      { 
        prompt = "Select priority indicator style:",
        format_item = function(item)
          local descriptions = {
            emoji = "Emoji - 🔥⚡💤",
            color = "Color - Colored text",
            symbol = "Symbol - ▲ ■ ▼",
            bracket = "Bracket - [H] [M] [L]",
            none = "None - No indicators"
          }
          return descriptions[item] or item
        end
      },
      function(choice)
        if choice == nil then
          if callback then callback(nil) end
          return
        end
        
        config.ui = config.ui or {}
        config.ui.style = config.ui.style or {}
        config.ui.style.priority_style = choice
        step4_auto_import()
      end
    )
  end
  
  local function step4_auto_import()
    vim.ui.select(
      {"Yes", "No"},
      { prompt = "Auto-import TODO comments from code?" },
      function(choice)
        if choice == nil then
          if callback then callback(nil) end
          return
        end
        
        config.integrations = config.integrations or {}
        config.integrations.todo_comments = config.integrations.todo_comments or {}
        config.integrations.todo_comments.auto_import = choice == "Yes"
        step5_external_integration()
      end
    )
  end
  
  local function step5_external_integration()
    -- Check for git repository
    local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
    local is_git_repo = handle and handle:read("*a"):match("true")
    if handle then handle:close() end
    
    local integrations = {"none", "github"}
    local descriptions = {
      none = "None - Local todos only",
      github = "GitHub - Sync with GitHub issues"
    }
    
    -- Add other integrations if tokens are available
    if os.getenv("LINEAR_API_KEY") then
      table.insert(integrations, "linear")
      descriptions.linear = "Linear - Sync with Linear issues"
    end
    
    if os.getenv("JIRA_API_TOKEN") then
      table.insert(integrations, "jira")
      descriptions.jira = "JIRA - Sync with JIRA issues"
    end
    
    if not is_git_repo then
      config.external_integration = "none"
      step6_finish()
      return
    end
    
    vim.ui.select(
      integrations,
      { 
        prompt = "Select external integration:",
        format_item = function(item)
          return descriptions[item] or item
        end
      },
      function(choice)
        if choice == nil then
          if callback then callback(nil) end
          return
        end
        
        config.integrations = config.integrations or {}
        config.integrations.external = config.integrations.external or {}
        config.integrations.external.default_integration = choice
        step6_finish()
      end
    )
  end
  
  local function step6_finish()
    -- Save configuration
    local config_path
    if mode == "global" then
      config_manager.save_global_config(config)
      config_path = vim.fn.expand("~/.config/todo-mcp/config.json")
    else
      config_manager.save_project_config(config)
      config_path = vim.fn.getcwd() .. "/.todo-mcp/config.json"
    end
    
    -- Reload configuration
    local todo_mcp = require("todo-mcp")
    todo_mcp.opts = config_manager.get_config(todo_mcp.opts)
    
    -- Create initial structure for project config
    if mode == "project" and config.db and config.db.project_dir then
      local project_dir = vim.fn.getcwd() .. "/" .. config.db.project_dir
      vim.fn.mkdir(project_dir .. "/exports", "p")
    end
    
    -- Show completion message
    local complete_buf = vim.api.nvim_create_buf(false, true)
    local complete_lines = {
      "╭─────────────────────────────────────────────────╮",
      "│              Setup Complete! 🎉                 │",
      "│                                                 │",
      "│  Configuration saved to:                        │",
      "│  " .. vim.fn.fnamemodify(config_path, ":~:.") .. string.rep(" ", 47 - #vim.fn.fnamemodify(config_path, ":~:.")) .. "│",
      "│                                                 │",
      "│  You can now use <leader>td to open todos      │",
      "│                                                 │",
      "│  Press any key to continue                      │",
      "╰─────────────────────────────────────────────────╯",
    }
    
    vim.api.nvim_buf_set_lines(complete_buf, 0, -1, false, complete_lines)
    vim.api.nvim_buf_set_option(complete_buf, 'modifiable', false)
    
    local complete_win = vim.api.nvim_open_win(complete_buf, true, {
      relative = 'editor',
      row = math.floor((vim.o.lines - 11) / 2),
      col = math.floor((vim.o.columns - 52) / 2),
      width = 52,
      height = 11,
      style = 'minimal',
      border = 'rounded'
    })
    
    vim.api.nvim_buf_set_keymap(complete_buf, 'n', '<CR>', '', {
      callback = function()
        vim.api.nvim_win_close(complete_win, true)
        if callback then callback(config) end
      end
    })
    
    vim.api.nvim_buf_set_keymap(complete_buf, 'n', '<Esc>', '', {
      callback = function()
        vim.api.nvim_win_close(complete_win, true)
        if callback then callback(config) end
      end
    })
  end
  
  -- Start wizard on Enter press
  vim.api.nvim_buf_set_keymap(wizard_buf, 'n', '<CR>', '', {
    callback = step1_project_dir
  })
  
  -- Cancel on Escape
  vim.api.nvim_buf_set_keymap(wizard_buf, 'n', '<Esc>', '', {
    callback = function()
      vim.api.nvim_win_close(win, true)
      if callback then callback(nil) end
    end
  })
end

return M