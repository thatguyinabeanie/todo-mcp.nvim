local M = {}
local config_manager = require("todo-mcp.config")

M.setup = function(opts)
  opts = opts or {}
  
  -- Initialize global config if needed
  config_manager.init_global_config()
  
  -- Get merged configuration (global + project + setup opts)
  M.opts = config_manager.get_config(opts)
  
  -- Initialize modules lazily
  local db_path = config_manager.get_db_path(M.opts)
  require("todo-mcp.db").setup(db_path)
  require("todo-mcp.mcp").setup(M.opts.mcp_server or { host = "localhost", port = 3333 })
  require("todo-mcp.ui").setup(M.opts.ui)
  require("todo-mcp.keymaps").setup(M.opts.keymaps)
  
  -- Setup pickers and integrations
  require("todo-mcp.pickers").setup()
  
  -- Setup integrations
  if M.opts.integrations.todo_comments.enabled then
    local tc_integration = require("todo-mcp.integrations.todo-comments")
    tc_integration.config = vim.tbl_extend("force", tc_integration.config, M.opts.integrations.todo_comments)
    tc_integration.setup()
    
    -- Setup code actions
    require("todo-mcp.integrations.code-actions").setup()
    
    -- Setup quickfix
    require("todo-mcp.integrations.quickfix").setup()
  end
  
  -- Setup external integrations
  if M.opts.integrations.external.enabled then
    require("todo-mcp.integrations.external").setup()
    
    -- Auto-sync status changes
    if M.opts.integrations.external.auto_sync then
      vim.api.nvim_create_autocmd("User", {
        pattern = "TodoMCPStatusChanged",
        callback = function(event)
          local external = require("todo-mcp.integrations.external")
          local todo_id = event.data.todo_id
          local new_status = event.data.new_status
          
          vim.schedule(function()
            external.sync_todo_to_external(todo_id, new_status)
          end)
        end
      })
      
      -- Periodic sync for updates from external sources
      vim.fn.timer_start(30000, function()
        vim.schedule(function()
          local external = require("todo-mcp.integrations.external")
          external.sync_from_external()
        end)
      end, { ["repeat"] = -1 })
    end
  end
  
  -- Setup AI integration
  if M.opts.integrations.ai.enabled then
    local ai_analyzer = require("todo-mcp.ai.analyzer")
    ai_analyzer.config = M.opts.integrations.ai
    ai_analyzer.setup()
    
    if M.opts.integrations.ai.auto_analyze then
      -- Auto-analyze new todos
      vim.api.nvim_create_autocmd("User", {
        pattern = "TodoMCPCreated",
        callback = function(event)
          local todo_id = event.data.todo_id
          vim.schedule(function()
            ai_analyzer.analyze_todo(todo_id)
          end)
        end
      })
    end
  end
  
  -- Setup enterprise features
  if M.opts.integrations.enterprise and M.opts.integrations.enterprise.enabled then
    if M.opts.integrations.enterprise.team_sync.enabled then
      require("todo-mcp.enterprise.team-sync").setup(M.opts.integrations.enterprise.team_sync)
    end
    if M.opts.integrations.enterprise.reporting.enabled then
      require("todo-mcp.enterprise.reporting").setup(M.opts.integrations.enterprise.reporting)
    end
  end
end

-- API functions
M.add = function(content, options)
  return require("todo-mcp.db").add(content, options)
end

M.get_all = function()
  return require("todo-mcp.db").get_all()
end

M.toggle_ui = function()
  require("todo-mcp.ui").toggle()
end

M.search = function(query, filters)
  return require("todo-mcp.db").search(query, filters)
end

M.get_config = function()
  return M.opts
end

-- Plugin commands
vim.api.nvim_create_user_command("TodoMCP", function(opts)
  local args = vim.split(opts.args, " ")
  local cmd = args[1]
  
  if cmd == "toggle" or cmd == "" then
    M.toggle_ui()
  elseif cmd == "add" then
    vim.ui.input({ prompt = "Todo: " }, function(content)
      if content then
        M.add(content)
        vim.notify("Todo added", vim.log.levels.INFO)
      end
    end)
  elseif cmd == "search" then
    local query = table.concat(vim.list_slice(args, 2), " ")
    require("todo-mcp.pickers").search_todos(query)
  elseif cmd == "export" then
    local format = args[2] or "markdown"
    local export = require("todo-mcp.export")
    if format == "all" then
      export.export_all()
    elseif format == "markdown" or format == "md" then
      export.export_markdown()
    elseif format == "json" then
      export.export_json()
    elseif format == "yaml" then
      export.export_yaml()
    else
      vim.notify("Unknown export format: " .. format, vim.log.levels.ERROR)
    end
  elseif cmd == "import" then
    local format = args[2]
    local file = args[3]
    local import = require("todo-mcp.export")
    if format == "json" then
      import.import_json(file)
    elseif format == "markdown" or format == "md" then
      import.import_markdown(file)
    else
      vim.notify("Unknown import format: " .. format, vim.log.levels.ERROR)
    end
  elseif cmd == "setup" then
    local mode = args[2] or "project"
    local wizard = require("todo-mcp.setup-wizard")
    wizard.run(function(config)
      if config then
        -- Reload configuration
        M.opts = config_manager.get_config(M.opts)
        vim.notify("Configuration updated", vim.log.levels.INFO)
      end
    end, mode)
  elseif cmd == "config" then
    -- Open config file in editor
    local mode = args[2] or "project"
    local config_path
    if mode == "global" then
      config_path = vim.fn.expand("~/.config/todo-mcp/config.json")
    else
      config_path = vim.fn.getcwd() .. "/.todo-mcp/config.json"
    end
    
    if vim.fn.filereadable(config_path) == 1 then
      vim.cmd("edit " .. config_path)
    else
      vim.notify("Config file not found. Run :TodoMCP setup " .. mode, vim.log.levels.WARN)
    end
  elseif cmd == "style" then
    -- Cycle visual style
    require("todo-mcp.ui").cycle_style()
  else
    vim.notify("Unknown TodoMCP command: " .. cmd, vim.log.levels.ERROR)
  end
end, {
  nargs = "*",
  complete = function(ArgLead, CmdLine, CursorPos)
    local commands = {"toggle", "add", "search", "export", "import", "setup", "config", "style"}
    local args = vim.split(CmdLine, " ")
    
    if #args == 2 then
      return vim.tbl_filter(function(cmd)
        return cmd:find("^" .. ArgLead)
      end, commands)
    elseif #args == 3 and args[2] == "export" then
      return {"all", "markdown", "json", "yaml"}
    elseif #args == 3 and args[2] == "import" then
      return {"json", "markdown"}
    elseif #args == 3 and (args[2] == "setup" or args[2] == "config") then
      return {"project", "global"}
    end
    
    return {}
  end
})

-- Backwards compatibility
M.open = M.toggle_ui
M.close = function()
  require("todo-mcp.ui").close()
end

return M