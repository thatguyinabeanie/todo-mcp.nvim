-- Configuration management for todo-mcp.nvim
-- Supports global config in ~/.config/todo-mcp/ with project-level overrides
local M = {}

-- Default configuration
M.defaults = {
  version = "1.0",
  -- Database settings
  db = {
    global_path = vim.fn.expand("~/.local/share/nvim/todo-mcp.db"),
    project_relative = true,
    project_dir = ".todo-mcp",
    name = "todos.db"
  },
  -- UI settings
  ui = {
    width = 80,
    height = 30,
    border = "rounded",
    view_mode = "list",
    style = {
      preset = "modern",
      priority_style = "emoji",
      layout = "grouped",
      show_metadata = true,
      show_timestamps = "relative",
      done_style = "dim"
    },
    floating_preview = true,
    status_line = true,
    animation = true
  },
  -- Export settings
  export = {
    directory = "exports",
    confirm = true,
    formats = {"markdown", "json", "yaml"}
  },
  -- Integration settings
  integrations = {
    todo_comments = {
      enabled = true,
      auto_import = false
    },
    external = {
      enabled = true,
      auto_sync = false,
      default_integration = "none"
    },
    ai = {
      enabled = true,
      auto_analyze = false,
      min_confidence = 60,
      context_lines = 10
    }
  },
  -- Keymaps
  keymaps = {
    toggle = "<leader>td",
    add = "a",
    delete = "d", 
    toggle_done = "<CR>",
    quit = "q"
  },
  -- Project settings
  project = {
    auto_setup = true,
    ignore_patterns = {"*.db", "*.db-*", "exports/"},
    share_with_team = false
  }
}

-- Get config directory paths
M.get_config_paths = function()
  return {
    global = vim.fn.expand("~/.config/todo-mcp"),
    project = vim.fn.getcwd() .. "/.todo-mcp"
  }
end

-- Load configuration from file
M.load_config_file = function(path)
  if vim.fn.filereadable(path) == 1 then
    local content = table.concat(vim.fn.readfile(path), "\n")
    local ok, config = pcall(vim.fn.json_decode, content)
    if ok then
      return config
    else
      vim.notify("Error parsing config at " .. path .. ": " .. config, vim.log.levels.WARN)
    end
  end
  return nil
end

-- Save configuration to file
M.save_config_file = function(config, path)
  local dir = vim.fn.fnamemodify(path, ":h")
  vim.fn.mkdir(dir, "p")
  
  local json_str = vim.fn.json_encode(config)
  
  -- Pretty print
  json_str = json_str:gsub(',%s*"', ',\n  "')
  json_str = json_str:gsub('{%s*"', '{\n  "')
  json_str = json_str:gsub('}$', '\n}')
  json_str = json_str:gsub('%[{', '[\n    {')
  json_str = json_str:gsub('},{', '},\n    {')
  json_str = json_str:gsub('}%]', '}\n  ]')
  
  vim.fn.writefile(vim.split(json_str, "\n"), path)
end

-- Load global configuration
M.load_global_config = function()
  local paths = M.get_config_paths()
  return M.load_config_file(paths.global .. "/config.json")
end

-- Load project configuration
M.load_project_config = function()
  local paths = M.get_config_paths()
  return M.load_config_file(paths.project .. "/config.json")
end

-- Save global configuration
M.save_global_config = function(config)
  local paths = M.get_config_paths()
  M.save_config_file(config, paths.global .. "/config.json")
end

-- Save project configuration
M.save_project_config = function(config)
  local paths = M.get_config_paths()
  M.save_config_file(config, paths.project .. "/config.json")
end

-- Merge configurations (project overrides global)
M.merge_configs = function(global, project, setup_opts)
  -- Start with defaults
  local config = vim.deepcopy(M.defaults)
  
  -- Merge global config
  if global then
    config = vim.tbl_deep_extend("force", config, global)
  end
  
  -- Merge project config
  if project then
    config = vim.tbl_deep_extend("force", config, project)
  end
  
  -- Merge setup options (highest priority)
  if setup_opts then
    config = vim.tbl_deep_extend("force", config, setup_opts)
  end
  
  return config
end

-- Get effective configuration
M.get_config = function(setup_opts)
  local global_config = M.load_global_config()
  local project_config = M.load_project_config()
  
  return M.merge_configs(global_config, project_config, setup_opts)
end

-- Get database path based on configuration
M.get_db_path = function(config)
  config = config or M.get_config()
  
  if config.db.project_relative then
    -- Check if in a git repository
    local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
    local is_git_repo = handle and handle:read("*a"):match("true")
    if handle then handle:close() end
    
    if is_git_repo then
      return vim.fn.getcwd() .. "/" .. config.db.project_dir .. "/" .. config.db.name
    end
  end
  
  -- Fall back to global database
  return config.db.global_path
end

-- Get export directory based on configuration
M.get_export_dir = function(config)
  config = config or M.get_config()
  
  local base_dir = config.export.directory
  
  -- If it's a relative path and we're in a project
  if not base_dir:match("^/") and not base_dir:match("^~") then
    local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
    local is_git_repo = handle and handle:read("*a"):match("true")
    if handle then handle:close() end
    
    if is_git_repo and config.db.project_relative then
      return vim.fn.getcwd() .. "/" .. config.db.project_dir .. "/" .. base_dir
    else
      return vim.fn.getcwd() .. "/" .. base_dir
    end
  end
  
  return vim.fn.expand(base_dir)
end

-- Check if project is configured
M.is_project_configured = function()
  local project_config_path = vim.fn.getcwd() .. "/.todo-mcp/config.json"
  return vim.fn.filereadable(project_config_path) == 1
end

-- Initialize default global config if it doesn't exist
M.init_global_config = function()
  local global_config = M.load_global_config()
  if not global_config then
    M.save_global_config(M.defaults)
    return M.defaults
  end
  return global_config
end

return M