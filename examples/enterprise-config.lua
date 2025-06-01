-- Enterprise configuration example for todo-mcp.nvim
-- This demonstrates the full feature set for large teams and organizations

require('todo-mcp').setup({
  -- Database location (consider shared network location for teams)
  db_path = vim.fn.expand("~/.local/share/nvim/todo-mcp.db"),
  
  -- UI configuration
  ui = {
    width = 100,
    height = 40,
    border = "rounded",
    view_mode = "markdown",
    style = {
      preset = "sections", -- Best for detailed enterprise workflows
      show_metadata = true,
      show_timestamps = "relative",
      done_style = "dim"
    }
  },
  
  -- Picker configuration (Telescope recommended for enterprise)
  picker = "telescope",
  
  -- Integration settings
  integrations = {
    -- todo-comments.nvim integration with AI enhancement
    todo_comments = {
      enabled = true,
      auto_import = false, -- Manual control for enterprise environments
      ai_enhanced = true,  -- Use AI for better categorization
      show_virtual_text = true,
      show_prompts = true,
      auto_sync = true,
      on_remove = "orphan" -- Don't auto-complete, mark as orphaned
    },
    
    -- External system integrations
    external = {
      enabled = true,
      auto_sync = true,
      default_integration = "linear", -- Modern choice for dev teams
      debug = false,
      batch_size = 5,      -- Limit concurrent API calls
      rate_limit_ms = 500, -- Be respectful to external APIs
      cache_ttl = 600      -- Cache for 10 minutes
    },
    
    -- AI-powered features
    ai = {
      enabled = true,
      auto_analyze = true,  -- Automatically analyze new TODOs
      min_confidence = 70,  -- Higher confidence threshold for enterprise
      context_lines = 15,   -- More context for better analysis
      priority_mapping = {
        -- Custom priority mapping for organization
        security = "high",
        performance = "high",
        bug = "high",
        feature = "medium",
        documentation = "low",
        cleanup = "low"
      }
    },
    
    -- Enterprise features
    enterprise = {
      enabled = true,
      
      -- Team synchronization
      team_sync = {
        enabled = true,
        sync_server = "https://todo-sync.yourcompany.com",
        team_id = "dev-team-alpha",
        user_id = vim.fn.system("git config user.email"):gsub("\n", ""),
        auth_token = os.getenv("TODO_SYNC_TOKEN"),
        sync_interval = 300, -- 5 minutes
        conflict_resolution = "manual", -- Let users resolve conflicts
        auto_assign = true,  -- Auto-assign based on git blame
        notifications = true,
        retention_days = 90  -- Keep sync history for 90 days
      },
      
      -- Reporting and analytics
      reporting = {
        enabled = true,
        auto_generate = true,  -- Generate weekly reports
        export_format = "html", -- Rich format for stakeholders
        export_path = vim.fn.expand("~/todo-reports/"),
        include_metadata = true,
        anonymize_data = false, -- Keep detailed data for internal use
        retention_days = 365,   -- Keep reports for 1 year
        
        -- Custom report scheduling
        schedule = {
          daily_summary = true,
          weekly_report = true,
          monthly_analytics = true
        }
      },
      
      -- Compliance and audit
      compliance = {
        enabled = true,
        audit_trail = true,   -- Track all changes
        data_retention = 2555, -- 7 years for compliance
        export_audit_logs = true,
        anonymize_exports = false
      }
    }
  },
  
  -- Custom keymaps for enterprise workflows
  keymaps = {
    -- Standard mappings
    add = "a",
    delete = "d", 
    toggle_done = "<CR>",
    quit = "q",
    
    -- Enterprise-specific mappings
    assign = "A",           -- Assign to team member
    comment = "c",          -- Add comment
    sync = "s",             -- Manual sync
    report = "r",           -- Generate report
    analyze = "i",          -- AI analysis
    export = "e",           -- Export to external system
    audit = "u"             -- Show audit trail
  }
})

-- Enterprise-specific commands and automations
local todo_mcp = require('todo-mcp')

-- Automatic team assignment based on file ownership
vim.api.nvim_create_autocmd("User", {
  pattern = "TodoMCPCreated",
  callback = function(event)
    local todo_id = event.data.todo_id
    local team_sync = require('todo-mcp.enterprise.team-sync')
    
    -- Auto-assign based on git blame
    vim.schedule(function()
      team_sync.auto_assign_by_file_ownership(todo_id)
    end)
  end
})

-- Weekly report generation
vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    -- Check if it's Monday and generate weekly report
    local weekday = tonumber(os.date("%w"))
    if weekday == 1 then -- Monday
      vim.defer_fn(function()
        local reporting = require('todo-mcp.enterprise.reporting')
        local report = reporting.generate_comprehensive_report()
        reporting.export_report(report, "html")
        
        vim.notify("Weekly TODO report generated", vim.log.levels.INFO)
      end, 5000) -- Delay 5 seconds after startup
    end
  end
})

-- Priority escalation for overdue high-priority items
vim.api.nvim_create_autocmd("User", {
  pattern = "TodoMCPDailyCheck",
  callback = function()
    local db = require('todo-mcp.db')
    local todos = db.get_all()
    
    for _, todo in ipairs(todos) do
      if todo.priority == "high" and todo.status ~= "done" then
        local created = todo.created_at and 
          os.time() - require('todo-mcp.enterprise.reporting').parse_date(todo.created_at)
        
        -- Escalate if high priority and older than 3 days
        if created and created > (3 * 24 * 60 * 60) then
          -- Send notification to team lead
          local team_sync = require('todo-mcp.enterprise.team-sync')
          team_sync.send_team_notification({
            type = "priority_escalation",
            todo_id = todo.id,
            title = todo.title,
            age_days = math.floor(created / (24 * 60 * 60))
          })
        end
      end
    end
  end
})

-- Integration with external issue tracking
vim.api.nvim_create_user_command("TodoBulkExport", function(opts)
  local filter = opts.args or "priority:high"
  local external = require('todo-mcp.integrations.external')
  
  -- Export all high-priority TODOs to Linear/JIRA
  local results = external.bulk_create_external_issues({
    priority = "high",
    unlinked_only = true
  }, "linear")
  
  local success_count = 0
  for _, result in pairs(results) do
    if result.success then
      success_count = success_count + 1
    end
  end
  
  vim.notify(string.format("Exported %d high-priority TODOs to Linear", success_count), 
    vim.log.levels.INFO)
end, { nargs = "?" })

-- Custom priority workflow for enterprise
vim.api.nvim_create_user_command("TodoTriage", function()
  local ai_analyzer = require('todo-mcp.ai.analyzer')
  
  -- Analyze all unprocessed TODOs and suggest priorities
  local results = ai_analyzer.batch_reprioritize({
    not_ai_enhanced = true
  }, {
    min_confidence = 80 -- High confidence for enterprise
  })
  
  -- Generate triage report
  local lines = {"# Todo Triage Report", ""}
  
  for _, change in ipairs(results.priority_changes) do
    table.insert(lines, string.format("## %s", change.title))
    table.insert(lines, string.format("- **Old Priority**: %s", change.old_priority))
    table.insert(lines, string.format("- **Suggested Priority**: %s", change.new_priority))
    table.insert(lines, string.format("- **Confidence**: %.0f%%", change.confidence))
    table.insert(lines, "")
  end
  
  -- Display triage results
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = 2,
    col = 2,
    width = vim.o.columns - 4,
    height = vim.o.lines - 6,
    style = 'minimal',
    border = 'rounded',
    title = ' TODO Triage Results ',
    title_pos = 'center'
  })
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end, {})

-- Environment-specific configuration
if os.getenv("TODO_MCP_ENV") == "production" then
  -- Production environment tweaks
  todo_mcp.opts.integrations.external.rate_limit_ms = 1000 -- More conservative
  todo_mcp.opts.integrations.ai.auto_analyze = false -- Manual control in prod
  
elseif os.getenv("TODO_MCP_ENV") == "development" then
  -- Development environment tweaks
  todo_mcp.opts.integrations.ai.min_confidence = 50 -- Lower threshold for experimentation
  todo_mcp.opts.integrations.external.debug = true -- Verbose logging
end

-- Team-specific customizations based on git team
local git_team = vim.fn.system("git config team.name 2>/dev/null"):gsub("\n", "")

if git_team == "frontend" then
  -- Frontend team prefers React/UI focused priorities
  todo_mcp.opts.integrations.ai.priority_mapping = vim.tbl_extend("force",
    todo_mcp.opts.integrations.ai.priority_mapping, {
      ui = "high",
      ux = "high", 
      accessibility = "high",
      performance = "high"
    })
    
elseif git_team == "backend" then
  -- Backend team focuses on API/data priorities
  todo_mcp.opts.integrations.ai.priority_mapping = vim.tbl_extend("force",
    todo_mcp.opts.integrations.ai.priority_mapping, {
      api = "high",
      database = "high",
      security = "high",
      performance = "high"
    })
end

return todo_mcp