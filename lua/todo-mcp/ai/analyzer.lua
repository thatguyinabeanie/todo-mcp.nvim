local M = {}

local db = require('todo-mcp.db')
local ai_context = require('todo-mcp.ai.context')
local ai_estimation = require('todo-mcp.ai.estimation')

-- Analyze all existing TODOs with AI
M.analyze_all_todos = function(options)
  options = options or {}
  local todos = db.get_all()
  local results = {
    analyzed = 0,
    updated = 0,
    errors = 0,
    insights = {}
  }
  
  for _, todo in ipairs(todos) do
    local success, insights = pcall(M.analyze_single_todo, todo, options)
    
    if success and insights then
      results.analyzed = results.analyzed + 1
      
      if insights.updated then
        results.updated = results.updated + 1
      end
      
      table.insert(results.insights, {
        todo_id = todo.id,
        title = todo.title,
        insights = insights
      })
    else
      results.errors = results.errors + 1
    end
    
    -- Rate limiting to avoid overwhelming the system
    if options.rate_limit ~= false then
      vim.wait(50)
    end
  end
  
  return results
end

-- Analyze a single TODO with AI
M.analyze_single_todo = function(todo, options)
  options = options or {}
  
  -- Skip if already AI-enhanced (unless forced)
  local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
  if metadata.ai_enhanced and not options.force then
    return { skipped = true, reason = "already_enhanced" }
  end
  
  local insights = {
    original_priority = todo.priority,
    original_tags = todo.tags,
    updated = false
  }
  
  -- Get enhanced context if file still exists
  local enhanced_context = nil
  local surrounding_lines = {}
  
  if todo.file_path and vim.fn.filereadable(todo.file_path) == 1 then
    local tc_integration = require('todo-mcp.integrations.todo-comments')
    surrounding_lines = tc_integration.get_surrounding_lines(todo.file_path, todo.line_number)
    
    enhanced_context = ai_context.detect_enhanced_context(
      todo.file_path,
      todo.content or todo.title,
      surrounding_lines
    )
  end
  
  -- AI-powered estimation
  local ai_insights = ai_estimation.enhance_with_ai_estimation({
    text = todo.content or todo.title,
    file_path = todo.file_path,
    line_number = todo.line_number,
    surrounding_lines = surrounding_lines,
    metadata = todo.metadata
  }, enhanced_context)
  
  insights.ai_priority = ai_insights.ai_priority
  insights.estimated_effort = ai_insights.estimated_effort
  insights.confidence_score = ai_insights.confidence_score
  insights.context = enhanced_context
  
  -- Update TODO if confidence is high enough or if forced
  local should_update = options.force or 
                       ai_insights.confidence_score > (options.min_confidence or 60)
  
  if should_update then
    local updates = {}
    
    -- Update priority if AI suggests different and confidence is high
    if ai_insights.ai_priority ~= todo.priority and ai_insights.confidence_score > 70 then
      updates.priority = ai_insights.ai_priority
      insights.priority_changed = true
    end
    
    -- Add AI-generated tags
    if enhanced_context and enhanced_context.smart_tags then
      local existing_tags = todo.tags and vim.split(todo.tags, ",") or {}
      local new_tags = vim.list_extend(existing_tags, enhanced_context.smart_tags)
      local unique_tags = M.deduplicate_tags(new_tags)
      
      if table.concat(unique_tags, ",") ~= (todo.tags or "") then
        updates.tags = table.concat(unique_tags, ",")
        insights.tags_enhanced = true
      end
    end
    
    -- Update metadata with AI insights
    updates.metadata = ai_insights.updated_metadata
    
    if next(updates) then
      db.update(todo.id, updates)
      insights.updated = true
      insights.updates = updates
    end
  end
  
  return insights
end

-- Batch re-prioritize TODOs based on AI analysis
M.batch_reprioritize = function(filter_options, analysis_options)
  filter_options = filter_options or {}
  analysis_options = analysis_options or { min_confidence = 75 }
  
  local todos = db.get_all()
  local filtered_todos = M.filter_todos(todos, filter_options)
  
  local results = {
    analyzed = 0,
    reprioritized = 0,
    priority_changes = {}
  }
  
  for _, todo in ipairs(filtered_todos) do
    local insights = M.analyze_single_todo(todo, analysis_options)
    
    if insights and insights.priority_changed then
      results.reprioritized = results.reprioritized + 1
      table.insert(results.priority_changes, {
        todo_id = todo.id,
        title = todo.title,
        old_priority = insights.original_priority,
        new_priority = insights.ai_priority,
        confidence = insights.confidence_score
      })
    end
    
    results.analyzed = results.analyzed + 1
    vim.wait(30) -- Rate limiting
  end
  
  return results
end

-- Generate TODO insights report
M.generate_insights_report = function()
  local todos = db.get_all()
  local report = {
    total_todos = #todos,
    ai_enhanced = 0,
    priority_distribution = { high = 0, medium = 0, low = 0 },
    effort_distribution = {},
    common_patterns = {},
    recommendations = {}
  }
  
  local tag_frequency = {}
  local complexity_areas = {}
  
  for _, todo in ipairs(todos) do
    -- Count priority distribution
    local priority = todo.priority or "medium"
    report.priority_distribution[priority] = (report.priority_distribution[priority] or 0) + 1
    
    -- Check if AI enhanced
    local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
    if metadata.ai_enhanced then
      report.ai_enhanced = report.ai_enhanced + 1
      
      -- Analyze AI insights
      if metadata.ai_estimation then
        local effort = metadata.ai_estimation.effort.level
        report.effort_distribution[effort] = (report.effort_distribution[effort] or 0) + 1
        
        -- Collect complexity areas
        if metadata.ai_estimation.complexity.factors then
          for area, _ in pairs(metadata.ai_estimation.complexity.factors) do
            complexity_areas[area] = (complexity_areas[area] or 0) + 1
          end
        end
      end
    end
    
    -- Tag frequency analysis
    if todo.tags then
      for tag in todo.tags:gmatch("[^,]+") do
        tag = tag:gsub("^%s*(.-)%s*$", "%1") -- Trim whitespace
        tag_frequency[tag] = (tag_frequency[tag] or 0) + 1
      end
    end
  end
  
  -- Generate top patterns
  local sorted_tags = M.sort_by_frequency(tag_frequency)
  report.common_patterns.tags = vim.list_slice(sorted_tags, 1, 10)
  
  local sorted_complexity = M.sort_by_frequency(complexity_areas)
  report.common_patterns.complexity_areas = vim.list_slice(sorted_complexity, 1, 5)
  
  -- Generate recommendations
  report.recommendations = M.generate_recommendations(report, todos)
  
  return report
end

-- Smart TODO suggestions based on code analysis
M.suggest_missing_todos = function(filepath)
  if not filepath or vim.fn.filereadable(filepath) ~= 1 then
    return {}
  end
  
  local suggestions = {}
  local lines = vim.fn.readfile(filepath)
  
  for i, line in ipairs(lines) do
    -- Look for code patterns that might need TODOs
    local patterns = {
      {
        pattern = "console%.log",
        suggestion = "Remove debug console.log statement",
        priority = "low",
        tags = "cleanup,debug"
      },
      {
        pattern = "XXX",
        suggestion = "Review XXX marker",
        priority = "medium", 
        tags = "review"
      },
      {
        pattern = "HACK",
        suggestion = "Address hack with proper solution",
        priority = "medium",
        tags = "refactor,technical-debt"
      },
      {
        pattern = "setTimeout.*1000",
        suggestion = "Review hardcoded timeout values",
        priority = "low",
        tags = "performance,magic-numbers"
      },
      {
        pattern = "any",
        suggestion = "Replace 'any' type with specific type",
        priority = "medium",
        tags = "typescript,type-safety"
      }
    }
    
    for _, pattern_info in ipairs(patterns) do
      if line:find(pattern_info.pattern) and not line:find("TODO") and not line:find("FIXME") then
        table.insert(suggestions, {
          file = filepath,
          line = i,
          content = pattern_info.suggestion,
          priority = pattern_info.priority,
          tags = pattern_info.tags,
          confidence = 60,
          pattern_matched = pattern_info.pattern
        })
      end
    end
  end
  
  return suggestions
end

-- Helper functions
M.filter_todos = function(todos, filter_options)
  local filtered = {}
  
  for _, todo in ipairs(todos) do
    local include = true
    
    if filter_options.priority and todo.priority ~= filter_options.priority then
      include = false
    end
    
    if filter_options.has_file_link and not todo.file_path then
      include = false
    end
    
    if filter_options.not_ai_enhanced then
      local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
      if metadata.ai_enhanced then
        include = false
      end
    end
    
    if include then
      table.insert(filtered, todo)
    end
  end
  
  return filtered
end

M.deduplicate_tags = function(tags)
  local seen = {}
  local unique = {}
  
  for _, tag in ipairs(tags) do
    tag = tag:gsub("^%s*(.-)%s*$", "%1") -- Trim
    if tag ~= "" and not seen[tag] then
      seen[tag] = true
      table.insert(unique, tag)
    end
  end
  
  return unique
end

M.sort_by_frequency = function(frequency_table)
  local sorted = {}
  
  for item, count in pairs(frequency_table) do
    table.insert(sorted, { item = item, count = count })
  end
  
  table.sort(sorted, function(a, b) return a.count > b.count end)
  
  return sorted
end

M.generate_recommendations = function(report, todos)
  local recommendations = {}
  
  -- Priority balance recommendation
  local total = report.total_todos
  local high_ratio = report.priority_distribution.high / total
  
  if high_ratio > 0.4 then
    table.insert(recommendations, {
      type = "priority_balance",
      message = string.format("%.0f%% of TODOs are high priority. Consider reviewing priorities.", high_ratio * 100),
      action = "Review and adjust priority levels"
    })
  end
  
  -- AI enhancement recommendation
  local ai_ratio = report.ai_enhanced / total
  if ai_ratio < 0.5 then
    table.insert(recommendations, {
      type = "ai_enhancement",
      message = string.format("Only %.0f%% of TODOs are AI-enhanced. Run analysis for better insights.", ai_ratio * 100),
      action = "Run :TodoAnalyzeAll to enhance with AI insights"
    })
  end
  
  -- Effort distribution recommendation
  if report.effort_distribution.large and report.effort_distribution.large > total * 0.3 then
    table.insert(recommendations, {
      type = "effort_breakdown",
      message = "Many large-effort TODOs detected. Consider breaking them down.",
      action = "Split large TODOs into smaller, manageable tasks"
    })
  end
  
  return recommendations
end

-- Setup commands
M.setup = function()
  -- Analyze all TODOs command
  vim.api.nvim_create_user_command("TodoAnalyzeAll", function(opts)
    local options = { force = opts.bang }
    local results = M.analyze_all_todos(options)
    
    vim.notify(string.format(
      "AI Analysis complete: %d analyzed, %d updated, %d errors",
      results.analyzed, results.updated, results.errors
    ), vim.log.levels.INFO)
  end, { bang = true })
  
  -- Generate insights report command
  vim.api.nvim_create_user_command("TodoInsightsReport", function()
    local report = M.generate_insights_report()
    M.display_insights_report(report)
  end, {})
  
  -- Batch reprioritize command
  vim.api.nvim_create_user_command("TodoReprioritize", function(opts)
    local results = M.batch_reprioritize({ not_ai_enhanced = true })
    
    vim.notify(string.format(
      "Reprioritization complete: %d analyzed, %d priorities changed",
      results.analyzed, results.reprioritized
    ), vim.log.levels.INFO)
    
    if #results.priority_changes > 0 then
      M.display_priority_changes(results.priority_changes)
    end
  end, {})
  
  -- Suggest missing TODOs command
  vim.api.nvim_create_user_command("TodoSuggest", function()
    local filepath = vim.fn.expand("%:p")
    local suggestions = M.suggest_missing_todos(filepath)
    
    if #suggestions > 0 then
      M.display_todo_suggestions(suggestions)
    else
      vim.notify("No TODO suggestions for this file", vim.log.levels.INFO)
    end
  end, {})
end

-- Display functions
M.display_insights_report = function(report)
  local lines = {
    "# TODO Insights Report",
    "",
    "## Overview",
    "- Total TODOs: " .. report.total_todos,
    "- AI Enhanced: " .. report.ai_enhanced .. " (" .. math.floor(report.ai_enhanced / report.total_todos * 100) .. "%)",
    "",
    "## Priority Distribution",
  }
  
  for priority, count in pairs(report.priority_distribution) do
    table.insert(lines, "- " .. priority:gsub("^%l", string.upper) .. ": " .. count)
  end
  
  table.insert(lines, "")
  table.insert(lines, "## Common Tags")
  
  for i, tag_info in ipairs(report.common_patterns.tags) do
    if i <= 5 then
      table.insert(lines, "- " .. tag_info.item .. " (" .. tag_info.count .. ")")
    end
  end
  
  if #report.recommendations > 0 then
    table.insert(lines, "")
    table.insert(lines, "## Recommendations")
    
    for _, rec in ipairs(report.recommendations) do
      table.insert(lines, "- " .. rec.message)
      table.insert(lines, "  Action: " .. rec.action)
    end
  end
  
  -- Display in floating window
  M.show_in_floating_window(lines, "TODO Insights Report")
end

M.show_in_floating_window = function(lines, title)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(#lines + 2, vim.o.lines - 10)
  
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' ' .. title .. ' ',
    title_pos = 'center',
  })
  
  vim.keymap.set('n', 'q', function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

return M