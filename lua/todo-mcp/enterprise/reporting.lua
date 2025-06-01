local M = {}

local db = require('todo-mcp.db')
local json = vim.json

-- Comprehensive reporting and analytics for enterprise environments
M.config = {
  enabled = true,
  export_formats = {"json", "csv", "html", "markdown"},
  default_export_path = vim.fn.expand("~/.local/share/nvim/todo-reports/"),
  include_metadata = true,
  anonymize_data = false,
  retention_days = 90
}

-- Generate comprehensive todo report
M.generate_comprehensive_report = function(options)
  options = options or {}
  local todos = db.get_all()
  
  local report = {
    metadata = M.generate_report_metadata(),
    summary = M.generate_summary_stats(todos),
    priority_analysis = M.analyze_priorities(todos),
    effort_analysis = M.analyze_effort_distribution(todos),
    timeline_analysis = M.analyze_timeline_trends(todos),
    team_analysis = M.analyze_team_metrics(todos),
    technical_debt = M.analyze_technical_debt(todos),
    external_integrations = M.analyze_external_sync(todos),
    ai_insights = M.analyze_ai_effectiveness(todos),
    productivity_metrics = M.calculate_productivity_metrics(todos),
    recommendations = M.generate_actionable_recommendations(todos)
  }
  
  if options.include_raw_data then
    report.raw_data = M.prepare_raw_data(todos)
  end
  
  return report
end

-- Generate report metadata
M.generate_report_metadata = function()
  return {
    generated_at = os.date("%Y-%m-%d %H:%M:%S"),
    generated_by = M.config.user_id or "unknown",
    tool_version = "todo-mcp.nvim v1.0.0",
    data_range = M.get_data_range(),
    total_projects = M.count_unique_projects(),
    report_id = M.generate_report_id()
  }
end

-- Generate summary statistics
M.generate_summary_stats = function(todos)
  local stats = {
    total_todos = #todos,
    by_status = { todo = 0, in_progress = 0, done = 0 },
    by_priority = { high = 0, medium = 0, low = 0 },
    completion_rate = 0,
    average_age_days = 0,
    external_linked = 0,
    ai_enhanced = 0
  }
  
  local total_age = 0
  local creation_dates = {}
  
  for _, todo in ipairs(todos) do
    -- Status distribution
    local status = todo.status or (todo.done and "done" or "todo")
    stats.by_status[status] = (stats.by_status[status] or 0) + 1
    
    -- Priority distribution
    local priority = todo.priority or "medium"
    stats.by_priority[priority] = (stats.by_priority[priority] or 0) + 1
    
    -- External linking
    local metadata = todo.metadata and json.decode(todo.metadata) or {}
    if metadata.external_sync then
      stats.external_linked = stats.external_linked + 1
    end
    
    -- AI enhancement
    if metadata.ai_enhanced then
      stats.ai_enhanced = stats.ai_enhanced + 1
    end
    
    -- Age calculation
    if todo.created_at then
      local created = M.parse_date(todo.created_at)
      if created then
        local age = os.difftime(os.time(), created) / (24 * 60 * 60)
        total_age = total_age + age
        table.insert(creation_dates, created)
      end
    end
  end
  
  -- Calculate derived metrics
  if #todos > 0 then
    stats.completion_rate = (stats.by_status.done / #todos) * 100
    stats.average_age_days = total_age / #todos
  end
  
  stats.creation_trend = M.analyze_creation_trend(creation_dates)
  
  return stats
end

-- Analyze priority distribution and trends
M.analyze_priorities = function(todos)
  local analysis = {
    distribution = { high = 0, medium = 0, low = 0 },
    completion_by_priority = { high = 0, medium = 0, low = 0 },
    average_resolution_time = { high = 0, medium = 0, low = 0 },
    priority_inflation = M.detect_priority_inflation(todos)
  }
  
  local priority_completion_times = { high = {}, medium = {}, low = {} }
  
  for _, todo in ipairs(todos) do
    local priority = todo.priority or "medium"
    analysis.distribution[priority] = analysis.distribution[priority] + 1
    
    if todo.status == "done" or todo.done then
      analysis.completion_by_priority[priority] = analysis.completion_by_priority[priority] + 1
      
      -- Calculate resolution time
      if todo.created_at and todo.completed_at then
        local created = M.parse_date(todo.created_at)
        local completed = M.parse_date(todo.completed_at)
        
        if created and completed then
          local resolution_time = os.difftime(completed, created) / (24 * 60 * 60)
          table.insert(priority_completion_times[priority], resolution_time)
        end
      end
    end
  end
  
  -- Calculate average resolution times
  for priority, times in pairs(priority_completion_times) do
    if #times > 0 then
      local sum = 0
      for _, time in ipairs(times) do
        sum = sum + time
      end
      analysis.average_resolution_time[priority] = sum / #times
    end
  end
  
  return analysis
end

-- Analyze effort distribution
M.analyze_effort_distribution = function(todos)
  local effort_stats = {
    distribution = {},
    total_story_points = 0,
    average_effort = 0,
    effort_accuracy = M.calculate_effort_accuracy(todos)
  }
  
  local story_point_map = { xs = 1, small = 2, medium = 5, large = 8, xl = 13 }
  local total_points = 0
  
  for _, todo in ipairs(todos) do
    local metadata = todo.metadata and json.decode(todo.metadata) or {}
    
    if metadata.ai_estimation and metadata.ai_estimation.effort then
      local effort = metadata.ai_estimation.effort.level
      effort_stats.distribution[effort] = (effort_stats.distribution[effort] or 0) + 1
      
      local points = story_point_map[effort] or 5
      total_points = total_points + points
    end
  end
  
  effort_stats.total_story_points = total_points
  effort_stats.average_effort = #todos > 0 and (total_points / #todos) or 0
  
  return effort_stats
end

-- Analyze timeline trends
M.analyze_timeline_trends = function(todos)
  local trends = {
    creation_by_month = {},
    completion_by_month = {},
    backlog_growth = {},
    velocity = M.calculate_team_velocity(todos)
  }
  
  for _, todo in ipairs(todos) do
    -- Creation trend
    if todo.created_at then
      local month = M.get_month_key(todo.created_at)
      trends.creation_by_month[month] = (trends.creation_by_month[month] or 0) + 1
    end
    
    -- Completion trend
    if todo.completed_at then
      local month = M.get_month_key(todo.completed_at)
      trends.completion_by_month[month] = (trends.completion_by_month[month] or 0) + 1
    end
  end
  
  -- Calculate backlog growth
  trends.backlog_growth = M.calculate_backlog_growth(trends.creation_by_month, trends.completion_by_month)
  
  return trends
end

-- Analyze team metrics
M.analyze_team_metrics = function(todos)
  local team_metrics = {
    contributors = {},
    assignment_distribution = {},
    collaboration_score = 0,
    bus_factor = 0
  }
  
  local contributor_stats = {}
  
  for _, todo in ipairs(todos) do
    local metadata = todo.metadata and json.decode(todo.metadata) or {}
    
    -- Analyze assignments
    if metadata.assignment then
      local assignee = metadata.assignment.user_id
      if not contributor_stats[assignee] then
        contributor_stats[assignee] = {
          assigned = 0,
          completed = 0,
          average_completion_time = 0
        }
      end
      
      contributor_stats[assignee].assigned = contributor_stats[assignee].assigned + 1
      
      if todo.status == "done" or todo.done then
        contributor_stats[assignee].completed = contributor_stats[assignee].completed + 1
      end
    end
    
    -- Analyze comments for collaboration
    if metadata.comments then
      team_metrics.collaboration_score = team_metrics.collaboration_score + #metadata.comments
    end
  end
  
  team_metrics.contributors = contributor_stats
  team_metrics.bus_factor = M.calculate_bus_factor(contributor_stats)
  
  return team_metrics
end

-- Analyze technical debt
M.analyze_technical_debt = function(todos)
  local debt_analysis = {
    total_debt_items = 0,
    debt_by_category = {},
    debt_trend = {},
    critical_debt = {},
    debt_ratio = 0
  }
  
  local debt_categories = {
    security = {"security", "auth", "vulnerability"},
    performance = {"performance", "slow", "optimize", "bottleneck"},
    maintainability = {"refactor", "clean", "simplify", "hack"},
    scalability = {"scale", "capacity", "limit"},
    documentation = {"document", "comment", "explain"}
  }
  
  for _, todo in ipairs(todos) do
    local is_debt = false
    local content = (todo.content or todo.title or ""):lower()
    
    for category, keywords in pairs(debt_categories) do
      for _, keyword in ipairs(keywords) do
        if content:find(keyword) then
          debt_analysis.debt_by_category[category] = (debt_analysis.debt_by_category[category] or 0) + 1
          is_debt = true
          
          -- Mark as critical if high priority
          if todo.priority == "high" then
            table.insert(debt_analysis.critical_debt, {
              id = todo.id,
              title = todo.title,
              category = category,
              priority = todo.priority
            })
          end
          
          break
        end
      end
    end
    
    if is_debt then
      debt_analysis.total_debt_items = debt_analysis.total_debt_items + 1
    end
  end
  
  -- Calculate debt ratio
  debt_analysis.debt_ratio = #todos > 0 and (debt_analysis.total_debt_items / #todos) * 100 or 0
  
  return debt_analysis
end

-- Productivity metrics
M.calculate_productivity_metrics = function(todos)
  local metrics = {
    throughput = M.calculate_throughput(todos),
    cycle_time = M.calculate_average_cycle_time(todos),
    work_in_progress = M.calculate_wip_limits(todos),
    flow_efficiency = M.calculate_flow_efficiency(todos)
  }
  
  return metrics
end

-- Generate actionable recommendations
M.generate_actionable_recommendations = function(todos)
  local recommendations = {}
  
  -- Priority recommendations
  local priority_stats = M.analyze_priorities(todos)
  local high_ratio = priority_stats.distribution.high / #todos
  
  if high_ratio > 0.4 then
    table.insert(recommendations, {
      type = "priority_management",
      severity = "medium",
      title = "High Priority Overload",
      description = string.format("%.0f%% of TODOs are high priority. Consider re-evaluating priorities.", high_ratio * 100),
      action = "Review and redistribute priority levels",
      impact = "Improved focus and clarity"
    })
  end
  
  -- Technical debt recommendations
  local debt_analysis = M.analyze_technical_debt(todos)
  
  if debt_analysis.debt_ratio > 30 then
    table.insert(recommendations, {
      type = "technical_debt",
      severity = "high",
      title = "Technical Debt Accumulation",
      description = string.format("%.0f%% of TODOs represent technical debt", debt_analysis.debt_ratio),
      action = "Allocate dedicated time for debt reduction",
      impact = "Improved code quality and maintainability"
    })
  end
  
  -- Team balance recommendations
  local team_metrics = M.analyze_team_metrics(todos)
  
  if team_metrics.bus_factor < 2 then
    table.insert(recommendations, {
      type = "team_balance",
      severity = "high",
      title = "Knowledge Concentration Risk",
      description = "Too much knowledge concentrated in few team members",
      action = "Distribute TODO assignments more evenly",
      impact = "Reduced risk and improved team resilience"
    })
  end
  
  -- AI enhancement recommendations
  local summary = M.generate_summary_stats(todos)
  local ai_ratio = summary.ai_enhanced / #todos
  
  if ai_ratio < 0.5 then
    table.insert(recommendations, {
      type = "ai_enhancement",
      severity = "low",
      title = "Low AI Enhancement Usage",
      description = string.format("Only %.0f%% of TODOs use AI insights", ai_ratio * 100),
      action = "Run AI analysis on existing TODOs",
      impact = "Better prioritization and effort estimation"
    })
  end
  
  return recommendations
end

-- Export functions
M.export_report = function(report, format, filepath)
  format = format or "json"
  filepath = filepath or M.generate_default_filepath(format)
  
  -- Ensure directory exists
  vim.fn.mkdir(vim.fn.fnamemodify(filepath, ":h"), "p")
  
  local success = false
  
  if format == "json" then
    success = M.export_json(report, filepath)
  elseif format == "csv" then
    success = M.export_csv(report, filepath)
  elseif format == "html" then
    success = M.export_html(report, filepath)
  elseif format == "markdown" then
    success = M.export_markdown(report, filepath)
  else
    error("Unsupported export format: " .. format)
  end
  
  if success then
    vim.notify("Report exported to: " .. filepath, vim.log.levels.INFO)
  else
    vim.notify("Failed to export report", vim.log.levels.ERROR)
  end
  
  return success, filepath
end

-- Export to JSON
M.export_json = function(report, filepath)
  local content = json.encode(report)
  return M.write_file(filepath, content)
end

-- Export to Markdown
M.export_markdown = function(report, filepath)
  local lines = {
    "# TODO Management Report",
    "",
    "Generated: " .. report.metadata.generated_at,
    "",
    "## Executive Summary",
    "",
    string.format("- **Total TODOs**: %d", report.summary.total_todos),
    string.format("- **Completion Rate**: %.1f%%", report.summary.completion_rate),
    string.format("- **External Integration**: %.1f%%", (report.summary.external_linked / report.summary.total_todos) * 100),
    string.format("- **AI Enhanced**: %.1f%%", (report.summary.ai_enhanced / report.summary.total_todos) * 100),
    "",
    "## Priority Distribution",
    ""
  }
  
  for priority, count in pairs(report.summary.by_priority) do
    table.insert(lines, string.format("- **%s**: %d (%.1f%%)", 
      priority:gsub("^%l", string.upper), 
      count, 
      (count / report.summary.total_todos) * 100))
  end
  
  table.insert(lines, "")
  table.insert(lines, "## Technical Debt Analysis")
  table.insert(lines, "")
  table.insert(lines, string.format("- **Debt Ratio**: %.1f%%", report.technical_debt.debt_ratio))
  table.insert(lines, string.format("- **Critical Debt Items**: %d", #report.technical_debt.critical_debt))
  
  if #report.recommendations > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Recommendations")
    table.insert(lines, "")
    
    for _, rec in ipairs(report.recommendations) do
      table.insert(lines, string.format("### %s (%s severity)", rec.title, rec.severity))
      table.insert(lines, "")
      table.insert(lines, rec.description)
      table.insert(lines, "")
      table.insert(lines, "**Action**: " .. rec.action)
      table.insert(lines, "")
      table.insert(lines, "**Impact**: " .. rec.impact)
      table.insert(lines, "")
    end
  end
  
  return M.write_file(filepath, table.concat(lines, "\n"))
end

-- Helper functions
M.write_file = function(filepath, content)
  local file = io.open(filepath, "w")
  if not file then
    return false
  end
  
  file:write(content)
  file:close()
  return true
end

M.parse_date = function(date_str)
  if not date_str then return nil end
  
  local year, month, day, hour, min, sec = date_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  
  if year then
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour) or 0,
      min = tonumber(min) or 0,
      sec = tonumber(sec) or 0
    })
  end
  
  return nil
end

M.get_month_key = function(date_str)
  local year, month = date_str:match("(%d+)-(%d+)")
  return year and month and (year .. "-" .. month) or "unknown"
end

M.generate_report_id = function()
  return os.date("%Y%m%d-%H%M%S") .. "-" .. math.random(1000, 9999)
end

M.generate_default_filepath = function(format)
  local timestamp = os.date("%Y%m%d-%H%M%S")
  local filename = string.format("todo-report-%s.%s", timestamp, format)
  return M.config.default_export_path .. filename
end

-- Setup commands
M.setup = function(config)
  M.config = vim.tbl_extend("force", M.config, config or {})
  
  -- Ensure export directory exists
  vim.fn.mkdir(M.config.default_export_path, "p")
  
  -- Setup commands
  vim.api.nvim_create_user_command("TodoGenerateReport", function(opts)
    local format = opts.args ~= "" and opts.args or "markdown"
    local report = M.generate_comprehensive_report({ include_raw_data = false })
    local success, filepath = M.export_report(report, format)
    
    if success and format == "html" then
      -- Try to open in browser
      vim.fn.system("open " .. vim.fn.shellescape(filepath))
    end
  end, {
    nargs = "?",
    complete = function()
      return M.config.export_formats
    end
  })
  
  vim.api.nvim_create_user_command("TodoShowSummary", function()
    local todos = db.get_all()
    local summary = M.generate_summary_stats(todos)
    M.display_summary_popup(summary)
  end, {})
end

M.display_summary_popup = function(summary)
  local lines = {
    "📊 TODO Summary",
    "",
    string.format("Total: %d", summary.total_todos),
    string.format("Completed: %d (%.1f%%)", summary.by_status.done, summary.completion_rate),
    string.format("In Progress: %d", summary.by_status.in_progress),
    string.format("Pending: %d", summary.by_status.todo),
    "",
    "Priority Distribution:",
    string.format("  High: %d", summary.by_priority.high),
    string.format("  Medium: %d", summary.by_priority.medium),
    string.format("  Low: %d", summary.by_priority.low),
    "",
    string.format("External Links: %d", summary.external_linked),
    string.format("AI Enhanced: %d", summary.ai_enhanced),
  }
  
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  local width = 40
  local height = #lines + 2
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' Summary ',
    title_pos = 'center',
  })
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

return M