local M = {}

-- View style presets
M.presets = {
  minimal = {
    status_indicators = {
      todo = "○",
      in_progress = "○",
      done = "●"
    },
    priority_style = "none",
    layout = "flat",
    show_metadata = false,
    show_timestamps = "none",
    done_style = "dim"
  },
  
  emoji = {
    status_indicators = {
      todo = "◯",
      in_progress = "◐",
      done = "✅"
    },
    priority_style = "emoji",
    priority_indicators = {
      high = "🔥",
      medium = "⚡",
      low = "💤"
    },
    layout = "grouped",
    show_metadata = true,
    show_timestamps = "relative",
    done_style = "dim"
  },
  
  sections = {
    status_indicators = {
      todo = "○",
      in_progress = "◐",
      done = "●"
    },
    priority_style = "emoji",
    priority_indicators = {
      high = "🔥",
      medium = "⚡",
      low = "💤"
    },
    layout = "priority_sections",
    show_metadata = true,
    show_timestamps = "relative",
    done_style = "dim"
  },
  
  compact = {
    status_indicators = {
      todo = " ",
      in_progress = ">",
      done = "x"
    },
    priority_style = "symbol",
    priority_indicators = {
      high = "!!!",
      medium = "!!",
      low = "!"
    },
    layout = "flat",
    show_metadata = true,
    show_timestamps = "none",
    done_style = "dim"
  },
  
  ascii = {
    status_indicators = {
      todo = "[ ]",
      in_progress = "[~]",
      done = "[x]"
    },
    priority_style = "bracket",
    priority_indicators = {
      high = "[H]",
      medium = "[M]",
      low = "[L]"
    },
    layout = "flat",
    show_metadata = true,
    show_timestamps = "none",
    done_style = "strikethrough"
  },
  
  modern = {
    status_indicators = {
      todo = "●",
      in_progress = "◐",
      done = "✓"
    },
    priority_style = "modern",
    priority_indicators = {
      high = "▲",
      medium = "■",
      low = "▼"
    },
    layout = "priority_sections",
    show_metadata = true,
    show_timestamps = "relative",
    done_style = "dim"
  }
}

-- Apply preset or custom style
M.get_style = function(config)
  local style = {}
  
  -- Start with preset if specified
  if config.style and config.style.preset and M.presets[config.style.preset] then
    style = vim.tbl_deep_extend("force", {}, M.presets[config.style.preset])
  else
    -- Default to modern preset for better visual hierarchy
    style = vim.tbl_deep_extend("force", {}, M.presets.modern)
  end
  
  -- Override with custom settings
  if config.style then
    style = vim.tbl_deep_extend("force", style, config.style)
  end
  
  return style
end

-- Get status indicator for a todo
M.get_status_indicator = function(todo, style)
  local status = todo.status or (todo.done and "done" or "todo")
  return style.status_indicators[status] or "○"
end

-- Get priority indicator
M.get_priority_indicator = function(todo, style)
  if style.priority_style == "none" or not todo.priority then
    return ""
  end
  
  if todo.priority == "medium" and style.priority_style ~= "symbol" then
    return "" -- Don't show medium unless using symbols
  end
  
  return style.priority_indicators[todo.priority] or ""
end

-- Format metadata (tags, file references)
M.format_metadata = function(todo, style)
  if not style.show_metadata then
    return ""
  end
  
  local parts = {}
  
  -- File reference
  if todo.file_path then
    local file_ref = "@" .. vim.fn.fnamemodify(todo.file_path, ":t")
    if todo.line_number then
      file_ref = file_ref .. ":" .. todo.line_number
    end
    table.insert(parts, file_ref)
  end
  
  -- Tags
  if todo.tags and todo.tags ~= "" then
    for tag in todo.tags:gmatch("[^,]+") do
      table.insert(parts, "#" .. tag:gsub("^%s*", ""):gsub("%s*$", ""))
    end
  end
  
  -- Body indicator
  if todo.content and todo.content ~= "" then
    table.insert(parts, "[+]")
  end
  
  return #parts > 0 and " " .. table.concat(parts, " ") or ""
end

-- Format timestamp
M.format_timestamp = function(timestamp, style)
  if style.show_timestamps == "none" or not timestamp then
    return ""
  end
  
  if style.show_timestamps == "relative" then
    -- Convert to relative time
    local now = os.time()
    local ts = vim.fn.strptime("%Y-%m-%d %H:%M:%S", timestamp)
    local diff = now - ts
    
    if diff < 60 then
      return "just now"
    elseif diff < 3600 then
      return math.floor(diff / 60) .. " min ago"
    elseif diff < 86400 then
      return math.floor(diff / 3600) .. " hours ago"
    elseif diff < 604800 then
      return math.floor(diff / 86400) .. " days ago"
    else
      return os.date("%b %d", ts)
    end
  else
    -- Absolute time
    return timestamp
  end
end

-- Render a single todo line
M.render_todo_line = function(todo, style)
  local parts = {}
  
  -- Status indicator
  table.insert(parts, M.get_status_indicator(todo, style))
  
  -- Priority indicator
  local priority = M.get_priority_indicator(todo, style)
  if priority ~= "" then
    table.insert(parts, priority)
  end
  
  -- Title
  table.insert(parts, todo.title or "Untitled")
  
  -- Metadata
  local metadata = M.format_metadata(todo, style)
  if metadata ~= "" then
    table.insert(parts, metadata)
  end
  
  -- Join with appropriate spacing
  local line = table.concat(parts, " ")
  
  -- Apply done styling
  if todo.done or todo.status == "done" then
    if style.done_style == "strikethrough" then
      -- Add strikethrough (terminal dependent)
      line = "~~" .. line .. "~~"
    end
    -- dim styling handled by highlight groups
  end
  
  return line
end

-- Group todos by status
M.group_by_status = function(todos)
  local groups = {
    { key = "in_progress", title = "## 🚧 In Progress", todos = {} },
    { key = "todo", title = "## 📋 To Do", todos = {} },
    { key = "done", title = "## ✅ Done", todos = {} }
  }
  
  for _, todo in ipairs(todos) do
    local status = todo.status or (todo.done and "done" or "todo")
    for _, group in ipairs(groups) do
      if group.key == status then
        table.insert(group.todos, todo)
        break
      end
    end
  end
  
  return groups
end

-- Group todos by priority
M.group_by_priority = function(todos)
  local groups = {
    { key = "high", title = "## 🔥 High Priority", todos = {} },
    { key = "medium", title = "## ⚡ Medium Priority", todos = {} },
    { key = "low", title = "## 💤 Low Priority", todos = {} },
    { key = "none", title = "## 📝 No Priority", todos = {} }
  }
  
  for _, todo in ipairs(todos) do
    local priority = todo.priority or "none"
    if priority == "medium" then priority = "medium" end
    
    -- Skip done todos in priority view
    if not todo.done and todo.status ~= "done" then
      for _, group in ipairs(groups) do
        if group.key == priority or (group.key == "none" and not todo.priority) then
          table.insert(group.todos, todo)
          break
        end
      end
    end
  end
  
  -- Add completed section
  local done_group = { key = "done", title = "## ✅ Completed", todos = {} }
  for _, todo in ipairs(todos) do
    if todo.done or todo.status == "done" then
      table.insert(done_group.todos, todo)
    end
  end
  table.insert(groups, done_group)
  
  return groups
end

-- Render todos with style
M.render_todos = function(todos, style)
  local lines = {}
  
  if style.layout == "flat" then
    -- Simple flat list
    for _, todo in ipairs(todos) do
      table.insert(lines, M.render_todo_line(todo, style))
    end
    
  elseif style.layout == "grouped" then
    -- Group by status
    local groups = M.group_by_status(todos)
    for _, group in ipairs(groups) do
      if #group.todos > 0 then
        table.insert(lines, group.title)
        table.insert(lines, "")
        for _, todo in ipairs(group.todos) do
          table.insert(lines, M.render_todo_line(todo, style))
        end
        table.insert(lines, "")
      end
    end
    
  elseif style.layout == "priority_sections" then
    -- Group by priority
    local groups = M.group_by_priority(todos)
    for _, group in ipairs(groups) do
      -- Always show priority sections (high, medium, low), but hide empty "no priority" and "completed"
      if group.key == "high" or group.key == "medium" or group.key == "low" or #group.todos > 0 then
        table.insert(lines, group.title)
        table.insert(lines, "")
        if #group.todos > 0 then
          for _, todo in ipairs(group.todos) do
            table.insert(lines, M.render_todo_line(todo, style))
          end
        else
          -- Show empty message for priority sections
          if group.key ~= "none" and group.key ~= "done" then
            table.insert(lines, "  (none)")
          end
        end
        table.insert(lines, "")
      end
    end
  end
  
  return lines
end

-- Setup highlight groups
M.setup_highlights = function()
  -- Priority highlights with modern colors
  vim.api.nvim_set_hl(0, "TodoPriorityHigh", { fg = "#f38ba8", bold = true })
  vim.api.nvim_set_hl(0, "TodoPriorityMedium", { fg = "#f9e2af", bold = true })
  vim.api.nvim_set_hl(0, "TodoPriorityLow", { fg = "#a6e3a1" })
  
  -- Status highlights with enhanced visual feedback
  vim.api.nvim_set_hl(0, "TodoDone", { fg = "#6c7086", italic = true, strikethrough = true })
  vim.api.nvim_set_hl(0, "TodoInProgress", { fg = "#74c7ec", bold = true })
  vim.api.nvim_set_hl(0, "TodoActive", { fg = "#cdd6f4", bold = false })
  
  -- Metadata highlights
  vim.api.nvim_set_hl(0, "TodoMetadata", { fg = "#a6adc8", italic = true })
  vim.api.nvim_set_hl(0, "TodoTag", { fg = "#89b4fa", bold = true })
  vim.api.nvim_set_hl(0, "TodoFile", { fg = "#cba6f7", underline = true })
  
  -- Enhanced status indicators
  vim.api.nvim_set_hl(0, "TodoStatusTodo", { fg = "#fab387" })
  vim.api.nvim_set_hl(0, "TodoStatusProgress", { fg = "#74c7ec" })
  vim.api.nvim_set_hl(0, "TodoStatusDone", { fg = "#a6e3a1" })
  
  -- Section headers
  vim.api.nvim_set_hl(0, "TodoSectionHeader", { fg = "#89b4fa", bold = true })
  vim.api.nvim_set_hl(0, "TodoSeparator", { fg = "#585b70" })
  
  -- Border styling
  vim.api.nvim_set_hl(0, "TodoBorderHelp", { fg = "#74c7ec", italic = true })
  vim.api.nvim_set_hl(0, "TodoBorderCorner", { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "TodoBorderHorizontal", { link = "FloatBorder" })
  vim.api.nvim_set_hl(0, "TodoBorderVertical", { link = "FloatBorder" })
end

return M