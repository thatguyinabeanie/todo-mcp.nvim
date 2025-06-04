local M = {}
local db = require("todo-mcp.db")
local api = vim.api

-- Convert todos to hierarchical markdown with flexible sections
M.todos_to_markdown = function(todos)
  local lines = {}
  local sections = {}
  local section_order = {}
  
  -- Group todos by section
  for _, todo in ipairs(todos) do
    local section_name = todo.section or "Tasks"
    if not sections[section_name] then
      sections[section_name] = {}
      table.insert(section_order, section_name)
    end
    table.insert(sections[section_name], todo)
  end
  
  -- Sort todos within sections by position
  for section_name, section_todos in pairs(sections) do
    table.sort(section_todos, function(a, b)
      return (a.position or 0) < (b.position or 0)
    end)
  end
  
  -- Render sections in order
  for _, section_name in ipairs(section_order) do
    table.insert(lines, "## " .. section_name)
    table.insert(lines, "")
    
    for _, todo in ipairs(sections[section_name]) do
      local checkbox = (todo.done or todo.status == "done") and "- [x]" or "- [ ]"
      local content = todo.content or todo.title or ""
      table.insert(lines, checkbox .. " " .. content)
    end
    table.insert(lines, "")
  end
  
  -- If no todos, show default sections
  if #lines == 0 then
    local default_sections = {
      "## 🔥 High Priority",
      "",
      "## ⚡ Medium Priority",
      "",
      "## 💤 Low Priority",
      "",
      "## ✅ Completed"
    }
    return default_sections
  end
  
  return lines
end

-- Parse markdown back to todos and sync to database
M.sync_markdown_to_db = function()
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then
    return
  end
  
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local todos = {}
  local current_section = "Tasks"
  local position = 0
  
  for _, line in ipairs(lines) do
    -- Check for section headers
    if line:match("^## ") then
      current_section = line:gsub("^## ", "")
      position = 0
    elseif line:match("^%- %[[ x]%]") then
      -- Parse todo item
      local done = line:match("^%- %[x%]") ~= nil
      local content = line:gsub("^%- %[[ x]%] ", "")
      if content ~= "" then
        -- Infer priority from section name
        local priority = "medium"
        if current_section:match("High") or current_section:match("🔥") then
          priority = "high"
        elseif current_section:match("Low") or current_section:match("💤") then
          priority = "low"
        end
        
        table.insert(todos, {
          content = content,
          section = current_section,
          position = position,
          priority = priority,
          done = done,
          status = done and "done" or "todo"
        })
        position = position + 1
      end
    end
  end
  
  -- Clear database and add all todos
  db.clear()
  for _, todo in ipairs(todos) do
    db.add(todo.content, {
      section = todo.section,
      position = todo.position,
      priority = todo.priority,
      status = todo.status
    })
  end
end

M.state = {
  buf = nil,
  win = nil,
  todos = {},
  selected = 1,
  search_active = false,
  search_query = "",
  search_filters = {},
  animation_enabled = true,
  last_render_time = 0,
  preview_win = nil,
  preview_buf = nil,
  preview_enabled = false,
  status_line_timer = nil,
  command_win = nil,
  command_buf = nil,
  edit_mode = false,
  original_lines = {}
}

M.setup = function(config)
  M.config = config
  M.config.view_mode = config.view_mode or "markdown" -- "markdown" is now default
  M.config.animation_speed = config.animation_speed or 150 -- milliseconds
  M.config.preview_enabled = config.preview_enabled ~= false -- default true
  M.config.modern_ui = config.modern_ui ~= false -- default true
  M.config.status_line = config.status_line ~= false -- default true
  M.config.floating_preview = config.floating_preview ~= false -- default true
  -- Safely detect user level with fallback
  local user_level = "beginner"
  if config.user_level then
    user_level = config.user_level
  else
    local ok, detected_level = pcall(M.detect_user_level)
    if ok then
      user_level = detected_level
    end
  end
  M.config.user_level = user_level
  
  -- Setup view style
  local views = require("todo-mcp.views")
  M.style = views.get_style(config)
  
  -- Setup highlights
  views.setup_highlights()
end

M.toggle = function()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    M.close()
  else
    M.open()
  end
end

M.open = function()
  -- Track session for progressive disclosure
  M.track_usage("session_start")
  
  -- Ensure we have config defaults
  if not M.config then
    M.config = {
      width = 80,
      height = 30,
      border = "rounded",
      modern_ui = true
    }
  end
  
  -- Ensure we have style
  if not M.style then
    local views = require("todo-mcp.views")
    M.style = views.get_style(M.config)
    views.setup_highlights()
  end
  
  -- Create buffer
  M.state.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.buf, "buftype", "nofile")
  api.nvim_buf_set_option(M.state.buf, "filetype", "todo-mcp")
  
  -- Calculate window position (centered)
  local width = M.config.width
  local height = M.config.height
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create window with modern styling
  local border_style = M.config.modern_ui and {
    { "╭", "TodoBorderCorner" },
    { "─", "TodoBorderHorizontal" },
    { "╮", "TodoBorderCorner" },
    { "│", "TodoBorderVertical" },
    { "╯", "TodoBorderCorner" },
    { "─", "TodoBorderHorizontal" },
    { "╰", "TodoBorderCorner" },
    { "│", "TodoBorderVertical" }
  } or M.config.border
  
  -- Add help hint to bottom border after window creation
  local add_border_help = M.config.modern_ui
  
  M.state.win = api.nvim_open_win(M.state.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = border_style,
    style = "minimal",
    title = " 📋 Todo Manager ",
    title_pos = "center",
    footer = M.config.modern_ui and {{ " ?=help ", "TodoBorderHelp" }} or nil,
    footer_pos = "right",
    noautocmd = true,
    zindex = 50  -- Base z-index for main window
  })
  
  -- Set window options
  api.nvim_win_set_option(M.state.win, "cursorline", true)
  api.nvim_win_set_option(M.state.win, "wrap", false)
  api.nvim_win_set_option(M.state.win, "number", false)
  api.nvim_win_set_option(M.state.win, "relativenumber", false)
  api.nvim_win_set_option(M.state.win, "signcolumn", "no")
  api.nvim_win_set_option(M.state.win, "winhl", "Normal:TodoNormal,CursorLine:TodoCursorLine")
  
  -- Enable smooth scrolling animation
  if M.config.animation_speed and M.config.animation_speed > 0 then
    api.nvim_win_set_option(M.state.win, "smoothscroll", true)
  end
  
  -- Load and render todos
  M.refresh()
  
  -- Set up buffer keymaps
  M.setup_keymaps()
end

-- Close preview window
M.close_preview = function()
  if M.state.preview_win and api.nvim_win_is_valid(M.state.preview_win) then
    api.nvim_win_close(M.state.preview_win, true)
    M.state.preview_win = nil
  end
  if M.state.preview_buf and api.nvim_buf_is_valid(M.state.preview_buf) then
    api.nvim_buf_delete(M.state.preview_buf, { force = true })
    M.state.preview_buf = nil
  end
end

M.close = function()
  -- Clean up timers
  if M.state.status_line_timer then
    M.state.status_line_timer:stop()
    M.state.status_line_timer = nil
  end
  
  -- Close preview window if open
  if M.close_preview then
    M.close_preview()
  end
  
  -- Smooth close animation
  if M.config.animation_enabled and M.state.win and api.nvim_win_is_valid(M.state.win) then
    -- Quick fade effect by changing window highlighting
    pcall(api.nvim_win_set_option, M.state.win, "winhl", "Normal:TodoFading")
    vim.defer_fn(function()
      if M.state.win and api.nvim_win_is_valid(M.state.win) then
        api.nvim_win_close(M.state.win, true)
      end
    end, 50)
  else
    if M.state.win and api.nvim_win_is_valid(M.state.win) then
      api.nvim_win_close(M.state.win, true)
    end
  end
  
  if M.state.help_hint_win and api.nvim_win_is_valid(M.state.help_hint_win) then
    api.nvim_win_close(M.state.help_hint_win, true)
  end
  
  if M.state.buf and api.nvim_buf_is_valid(M.state.buf) then
    api.nvim_buf_delete(M.state.buf, { force = true })
  end
  
  M.state.win = nil
  M.state.buf = nil
  M.state.help_hint_win = nil
end

M.refresh = function()
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then
    return
  end
  
  -- Get todos from database (search or all)
  if M.state.search_active and M.state.search_query ~= "" then
    M.state.todos = db.search(M.state.search_query, M.state.search_filters)
  else
    M.state.todos = db.get_all()
  end
  
  -- Use views module to render with style
  local views = require("todo-mcp.views")
  local lines = views.render_todos(M.state.todos, M.style)
  
  -- Count stats for title
  local total_count = #M.state.todos
  local done_count = 0
  for _, todo in ipairs(M.state.todos) do
    if todo.done or todo.status == "done" then
      done_count = done_count + 1
    end
  end
  
  if #lines == 0 then
    lines = { 
      "## 🔥 High Priority",
      "",
      "## ⚡ Medium Priority", 
      "",
      "## 💤 Low Priority",
      "",
      "",
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━",
      "",
      "  Welcome to Todo Manager!",
      "",
      "  Quick Start:",
      "  • Press 'a' or 'o' to add your first todo",
      "  • Use j/k to navigate between todos",
      "  • Press Enter to mark todos as done",
      "  • Press '?' for complete help",
      "",
      "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    }
  end
  
  -- Set content
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buf, "modifiable", M.state.edit_mode)
  
  -- Show edit mode indicator
  if M.state.edit_mode then
    local edit_indicator = " 🖊️  EDIT MODE - Press 'e' to save, <Esc> to cancel "
    api.nvim_win_set_config(M.state.win, { 
      title = edit_indicator,
      title_pos = "center"
    })
  else
    M.update_window_title()
  end
  
  -- Update window title
  local title = string.format(" 📋 Todo Manager (%d/%d)", done_count, total_count)
  if M.state.search_active then
    title = string.format(" 🔍 Searching: %s (%d/%d)", M.state.search_query, done_count, total_count)
  end
  
  -- Add sync status
  local sync_status = M.get_sync_status()
  if sync_status ~= "" then
    title = title .. sync_status
  end
  
  title = title .. " "
  api.nvim_win_set_config(M.state.win, { title = title })
  
end

-- Get sync status indicator
M.get_sync_status = function()
  local opts = require("todo-mcp").opts
  local status_parts = {}
  
  -- Check external integrations
  if opts.integrations then
    if opts.integrations.linear and opts.integrations.linear.enabled then
      table.insert(status_parts, "Linear")
    end
    if opts.integrations.github and opts.integrations.github.enabled then
      table.insert(status_parts, "GitHub")
    end
    if opts.integrations.jira and opts.integrations.jira.enabled then
      table.insert(status_parts, "JIRA")
    end
  end
  
  if #status_parts > 0 then
    return " 🔄 " .. table.concat(status_parts, ",")
  end
  return ""
end

-- Update window title with current stats
M.update_window_title = function()
  if not M.state.win or not api.nvim_win_is_valid(M.state.win) then
    return
  end
  
  local title = " 📋 Todo Manager"
  if M.state.todos and #M.state.todos > 0 then
    local done_count = 0
    for _, todo in ipairs(M.state.todos) do
      if todo.done or todo.status == "done" then 
        done_count = done_count + 1 
      end
    end
    title = string.format(" 📋 Todo Manager (%d/%d)", done_count, #M.state.todos)
  else
    title = " 📋 Todo Manager"
  end
  
  -- Add sync status
  local sync_status = M.get_sync_status()
  if sync_status ~= "" then
    title = title .. sync_status
  end
  
  title = title .. " "
  
  -- Update window config
  api.nvim_win_set_config(M.state.win, { title = title })
end

-- Visual feedback helper
M.flash_line = function(line_num, highlight_group)
  local ns_id = api.nvim_create_namespace("todo_mcp_flash")
  api.nvim_buf_add_highlight(M.state.buf, ns_id, highlight_group or "Visual", line_num - 1, 0, -1)
  vim.defer_fn(function()
    api.nvim_buf_clear_namespace(M.state.buf, ns_id, 0, -1)
  end, 150)
end

-- Show notification with visual feedback
M.notify = function(msg, level)
  level = level or "info"
  vim.notify(msg, vim.log.levels[level:upper()], { title = "Todo Manager" })
end

M.setup_keymaps = function()
  local keymaps = require("todo-mcp").opts.keymaps
  local buf = M.state.buf
  
  -- Add todo with inline editing
  vim.keymap.set("n", keymaps.add, function()
    M.start_inline_add()
  end, { buffer = buf, desc = "Add todo" })
  
  -- Add with vim-like 'o'
  vim.keymap.set("n", "o", function()
    M.start_inline_add()
  end, { buffer = buf, desc = "Add todo (vim-like)" })
  
  -- Tab for preview
  vim.keymap.set("n", "<Tab>", function()
    M.show_todo_preview()
  end, { buffer = buf, desc = "Preview todo details" })
  
  -- Delete todo
  vim.keymap.set("n", keymaps.delete, function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      local todo = M.state.todos[idx]
      vim.ui.select({"Delete", "Cancel"}, {
        prompt = "Delete todo: " .. (todo.content or todo.title or ""):sub(1, 40) .. "?",
      }, function(choice)
        if choice == "Delete" then
          local cursor_line = api.nvim_win_get_cursor(M.state.win)[1]
          M.flash_line(cursor_line, "ErrorMsg")
          db.delete(todo.id)
          M.notify("Todo deleted", "warn")
          M.refresh()
        end
      end)
    end
  end, { buffer = buf, desc = "Delete todo" })
  
  -- Toggle done
  vim.keymap.set("n", keymaps.toggle_done, function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      local todo = M.state.todos[idx]
      db.toggle_done(todo.id)
      -- Visual feedback
      local cursor_line = api.nvim_win_get_cursor(M.state.win)[1]
      M.flash_line(cursor_line, todo.done and "DiffDelete" or "DiffAdd")
      M.notify(todo.done and "Todo uncompleted" or "Todo completed! ✓", "info")
      M.refresh()
    end
  end, { buffer = buf, desc = "Toggle done" })
  
  -- Priority controls
  vim.keymap.set("n", "+", function()
    M.increase_priority()
  end, { buffer = buf, desc = "Increase priority" })
  
  vim.keymap.set("n", "-", function()
    M.decrease_priority()
  end, { buffer = buf, desc = "Decrease priority" })
  
  -- Quick priority setters
  vim.keymap.set("n", "1", function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      db.update(M.state.todos[idx].id, { priority = "high" })
      M.flash_line(api.nvim_win_get_cursor(M.state.win)[1], "DiffAdd")
      M.notify("🔥 Set to high priority", "info")
      M.refresh()
    end
  end, { buffer = buf, desc = "Set high priority" })
  
  vim.keymap.set("n", "2", function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      db.update(M.state.todos[idx].id, { priority = "medium" })
      M.flash_line(api.nvim_win_get_cursor(M.state.win)[1], "DiffText")
      M.notify("⚡ Set to medium priority", "info")
      M.refresh()
    end
  end, { buffer = buf, desc = "Set medium priority" })
  
  vim.keymap.set("n", "3", function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      db.update(M.state.todos[idx].id, { priority = "low" })
      M.flash_line(api.nvim_win_get_cursor(M.state.win)[1], "Comment")
      M.notify("💤 Set to low priority", "info")
      M.refresh()
    end
  end, { buffer = buf, desc = "Set low priority" })
  
  -- Add todo with options (priority/tags)
  vim.keymap.set("n", "A", function()
    M.add_todo_with_options()
  end, { buffer = buf, desc = "Add todo with options" })
  
  -- Search
  vim.keymap.set("n", "/", function()
    M.state.search_active = true
    vim.ui.input({ prompt = "Search todos: " }, function(input)
      if input then
        M.state.search_query = input
        M.refresh()
      else
        M.state.search_active = false
        M.refresh()
      end
    end)
  end, { buffer = buf, desc = "Search todos" })
  
  -- Clear search
  vim.keymap.set("n", "<C-c>", function()
    M.state.search_active = false
    M.state.search_query = ""
    M.state.search_filters = {}
    M.refresh()
  end, { buffer = buf, desc = "Clear search" })
  
  -- Export shortcuts
  vim.keymap.set("n", "em", function()
    require("todo-mcp.export").export_markdown()
  end, { buffer = buf, desc = "Export to Markdown" })
  
  vim.keymap.set("n", "ej", function()
    require("todo-mcp.export").export_json()
  end, { buffer = buf, desc = "Export to JSON" })
  
  vim.keymap.set("n", "ey", function()
    require("todo-mcp.export").export_yaml()
  end, { buffer = buf, desc = "Export to YAML" })
  
  vim.keymap.set("n", "ea", function()
    require("todo-mcp.export").export_all()
  end, { buffer = buf, desc = "Export all formats" })
  
  -- Help
  vim.keymap.set("n", "?", function()
    M.show_contextual_help()
  end, { buffer = buf, desc = "Show help" })
  
  -- Edit mode toggle
  vim.keymap.set("n", "E", function()
    M.toggle_edit_mode()
  end, { buffer = buf, desc = "Toggle edit mode" })
  
  -- Quit
  vim.keymap.set("n", keymaps.quit, M.close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", function()
    if M.state.edit_mode then
      M.cancel_edit_mode()
    else
      M.close()
    end
  end, { buffer = buf })
end

-- Show todo preview with metadata
M.show_todo_preview = function()
  local idx = M.get_cursor_todo_idx()
  if not idx or not M.state.todos[idx] then return end
  
  local todo = M.state.todos[idx]
  local preview_lines = {
    "┌────────────────────────────────────────┐",
    "│ 📋 TODO DETAILS                       │",
    "├────────────────────────────────────────┤",
    "",
  }
  
  -- Content
  table.insert(preview_lines, " Content: " .. (todo.content or todo.title or "No content"))
  table.insert(preview_lines, "")
  
  -- Priority
  local priority_icon = todo.priority == "high" and "🔥" or (todo.priority == "medium" and "⚡" or "💤")
  table.insert(preview_lines, " Priority: " .. priority_icon .. " " .. (todo.priority or "medium"))
  
  -- Status
  local status = todo.done and "done" or (todo.status or "todo")
  local status_icon = status == "done" and "✓" or (status == "in_progress" and "🔄" or "○")
  table.insert(preview_lines, " Status: " .. status_icon .. " " .. status)
  
  -- Tags
  if todo.tags and todo.tags ~= "" then
    table.insert(preview_lines, " Tags: 🏷️  " .. todo.tags)
  end
  
  -- File link
  if todo.file_path then
    local file_display = vim.fn.fnamemodify(todo.file_path, ":~:.")
    table.insert(preview_lines, " File: 📄 " .. file_display .. ":" .. (todo.line_number or "?"))
  end
  
  -- Timestamps
  table.insert(preview_lines, "")
  table.insert(preview_lines, " Created: " .. (todo.created_at or "Unknown"))
  if todo.updated_at then
    table.insert(preview_lines, " Updated: " .. todo.updated_at)
  end
  
  -- External ID
  if todo.external_id then
    table.insert(preview_lines, "")
    table.insert(preview_lines, " External: 🔗 " .. todo.external_id)
  end
  
  table.insert(preview_lines, "")
  table.insert(preview_lines, "└────────────────────────────────────────┘")
  
  -- Create preview buffer
  local preview_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, preview_lines)
  vim.api.nvim_buf_set_option(preview_buf, "modifiable", false)
  
  -- Calculate position relative to cursor
  local cursor_pos = api.nvim_win_get_cursor(M.state.win)
  local win_pos = api.nvim_win_get_position(M.state.win)
  local win_width = api.nvim_win_get_width(M.state.win)
  
  local preview_win = vim.api.nvim_open_win(preview_buf, false, {
    relative = "win",
    win = M.state.win,
    width = 42,
    height = #preview_lines,
    row = cursor_pos[1] - 1,
    col = win_width + 2,
    border = "none",
    style = "minimal",
    focusable = false,
    zindex = 99
  })
  
  -- Style the preview
  vim.api.nvim_win_set_option(preview_win, "winhl", "Normal:Pmenu,FloatBorder:Pmenu")
  
  -- Auto-close on cursor move
  vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI", "BufLeave"}, {
    buffer = M.state.buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(preview_win) then
        vim.api.nvim_win_close(preview_win, true)
      end
    end
  })
end

-- Helper to get todo index at cursor
M.get_cursor_todo_idx = function()
  if not M.state.win or not api.nvim_win_is_valid(M.state.win) then
    return nil
  end
  
  local cursor_line = api.nvim_win_get_cursor(M.state.win)[1]
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, cursor_line, false)
  
  local todo_idx = 0
  for i = 1, #lines do
    local line = lines[i]
    -- Count todo lines (with proper emoji indicators)
    if line:match("^[○◐●✓🔥⚡💤]") then
      todo_idx = todo_idx + 1
    end
  end
  
  return todo_idx > 0 and todo_idx or nil
end

-- Inline add functionality
M.start_inline_add = function()
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  
  -- Find current cursor position and section
  local cursor_line = api.nvim_win_get_cursor(M.state.win)[1]
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  
  -- Find current section by looking backwards
  local current_section = "Tasks"
  local section_priority = "medium"
  
  for i = cursor_line, 1, -1 do
    if lines[i]:match("^## ") then
      current_section = lines[i]:gsub("^## ", "")
      -- Infer priority from common section names
      if current_section:match("High") or current_section:match("🔥") then
        section_priority = "high"
      elseif current_section:match("Low") or current_section:match("💤") then
        section_priority = "low"
      elseif current_section:match("Completed") or current_section:match("✅") then
        section_priority = "medium" -- completed items retain their original priority
      else
        section_priority = "medium"
      end
      break
    end
  end
  
  -- Insert after current line
  local new_line = "- [ ] "
  api.nvim_buf_set_lines(M.state.buf, cursor_line, cursor_line, false, {new_line})
  
  -- Show inline hint
  local ns_id = api.nvim_create_namespace("todo_mcp_hint")
  api.nvim_buf_set_extmark(M.state.buf, ns_id, cursor_line, #new_line, {
    virt_text = {{"Type your todo and press Enter to save, Esc to cancel", "Comment"}},
    virt_text_pos = "eol"
  })
  
  -- Move cursor and enter insert mode
  api.nvim_win_set_cursor(M.state.win, {cursor_line + 1, #new_line})
  vim.cmd("startinsert!")
  
  -- Setup temp keymaps
  local save_func = function()
    vim.cmd("stopinsert")
    local line = api.nvim_buf_get_lines(M.state.buf, cursor_line, cursor_line + 1, false)[1]
    local content = line:gsub("^%- %[[ x]%] ", "")
    
    if content and content ~= "" then
      -- Count position in section
      local position = 0
      for i = 1, cursor_line do
        if lines[i]:match("^## ") then
          position = 0
        elseif lines[i]:match("^%- %[[ x]%]") then
          position = position + 1
        end
      end
      
      db.add(content, { 
        section = current_section,
        position = position,
        priority = section_priority
      })
    else
      -- Remove empty line
      api.nvim_buf_set_lines(M.state.buf, cursor_line, cursor_line + 1, false, {})
    end
    
    api.nvim_buf_set_option(M.state.buf, "modifiable", false)
    M.refresh()
  end
  
  vim.keymap.set("i", "<CR>", save_func, { buffer = M.state.buf })
  vim.keymap.set("i", "<Esc>", function()
    vim.cmd("stopinsert")
    -- Remove the line
    api.nvim_buf_set_lines(M.state.buf, cursor_line, cursor_line + 1, false, {})
    api.nvim_buf_set_option(M.state.buf, "modifiable", false)
    -- Clear hint
    api.nvim_buf_clear_namespace(M.state.buf, api.nvim_create_namespace("todo_mcp_hint"), 0, -1)
    M.refresh()
  end, { buffer = M.state.buf })
end

-- Add todo with options
M.add_todo_with_options = function()
  vim.ui.input({ prompt = "Todo content: " }, function(content)
    if not content or content == "" then return end
    
    vim.ui.select({ "low", "medium", "high" }, { 
      prompt = "Priority: ",
      format_item = function(item)
        local icons = { low = "💤", medium = "⚡", high = "🔥" }
        return icons[item] .. " " .. item:gsub("^%l", string.upper)
      end
    }, function(priority)
      priority = priority or "medium"
      
      vim.ui.input({ prompt = "Tags (optional): " }, function(tags)
        -- Map priority to default section names
        local section = priority == "high" and "🔥 High Priority" or
                       priority == "low" and "💤 Low Priority" or
                       "⚡ Medium Priority"
        
        db.add(content, {
          section = section,
          position = 999, -- Add at end of section
          priority = priority,
          tags = tags or ""
        })
        M.track_usage("todo_created")
        M.refresh()
        vim.notify("Todo added to " .. section, vim.log.levels.INFO)
      end)
    end)
  end)
end

-- Priority management
M.increase_priority = function()
  local idx = M.get_cursor_todo_idx()
  if not idx or not M.state.todos[idx] then return end
  
  local todo = M.state.todos[idx]
  local current = todo.priority or "medium"
  local new_priority = current == "low" and "medium" or current == "medium" and "high" or "high"
  
  if new_priority ~= current then
    db.update(todo.id, { priority = new_priority })
    M.refresh()
    vim.notify("Priority → " .. new_priority, vim.log.levels.INFO)
  end
end

M.decrease_priority = function()
  local idx = M.get_cursor_todo_idx()
  if not idx or not M.state.todos[idx] then return end
  
  local todo = M.state.todos[idx]
  local current = todo.priority or "medium"
  local new_priority = current == "high" and "medium" or current == "medium" and "low" or "low"
  
  if new_priority ~= current then
    db.update(todo.id, { priority = new_priority })
    M.refresh()
    vim.notify("Priority → " .. new_priority, vim.log.levels.INFO)
  end
end

-- Toggle edit mode
M.toggle_edit_mode = function()
  if M.state.edit_mode then
    M.save_edit_mode()
  else
    M.enter_edit_mode()
  end
end

-- Enter edit mode
M.enter_edit_mode = function()
  M.state.edit_mode = true
  M.state.original_lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  
  -- Update window title
  api.nvim_win_set_config(M.state.win, { 
    title = " 🖊️  EDIT MODE - Press 'E' to save, <Esc> to cancel ",
    title_pos = "center"
  })
  
  -- Show instructions at bottom
  local ns_id = api.nvim_create_namespace("todo_mcp_edit_hint")
  local line_count = api.nvim_buf_line_count(M.state.buf)
  api.nvim_buf_set_extmark(M.state.buf, ns_id, line_count - 1, 0, {
    virt_lines = {{
      {"────────────────────────────────────────────────", "Comment"},
      {"📝 Edit todos directly - [ ] = todo, [x] = done", "Comment"}
    }},
    virt_lines_above = false
  })
  
  M.notify("Edit mode: Modify todos directly in markdown", "info")
end

-- Save edit mode changes
M.save_edit_mode = function()
  M.state.edit_mode = false
  api.nvim_buf_set_option(M.state.buf, "modifiable", false)
  
  -- Clear edit hint
  api.nvim_buf_clear_namespace(M.state.buf, api.nvim_create_namespace("todo_mcp_edit_hint"), 0, -1)
  
  -- Parse markdown and update database
  M.parse_markdown_buffer()
  
  -- Update window title
  M.update_window_title()
  
  M.notify("Changes saved ✓", "info")
  M.refresh()
end

-- Cancel edit mode
M.cancel_edit_mode = function()
  M.state.edit_mode = false
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, M.state.original_lines)
  api.nvim_buf_set_option(M.state.buf, "modifiable", false)
  
  -- Clear edit hint
  api.nvim_buf_clear_namespace(M.state.buf, api.nvim_create_namespace("todo_mcp_edit_hint"), 0, -1)
  
  -- Update window title
  M.update_window_title()
  
  M.notify("Edit cancelled", "warn")
end

-- Parse markdown buffer and sync to database
M.parse_markdown_buffer = function()
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local todos_data = M.markdown_to_todos(lines)
  
  -- Clear database and re-add all todos
  db.clear()
  for _, todo_data in ipairs(todos_data) do
    db.add(todo_data.content, {
      section = todo_data.section,
      position = todo_data.position,
      priority = todo_data.priority,
      status = todo_data.status
    })
  end
end

-- Detect user level based on usage
M.detect_user_level = function()
  -- Check if user has used the plugin before
  local data_path = vim.fn.stdpath("data") .. "/todo-mcp-usage.json"
  local usage = nil
  
  -- Check if file exists first
  if vim.fn.filereadable(data_path) == 1 then
    local ok, file_content = pcall(vim.fn.readfile, data_path)
    if ok and file_content and #file_content > 0 then
      local decode_ok, decoded = pcall(vim.fn.json_decode, file_content)
      if decode_ok then
        usage = decoded
      end
    end
  end
  
  if not usage then
    -- First time user
    return "beginner"
  elseif usage.sessions < 5 then
    return "beginner"
  elseif usage.sessions < 20 then
    return "intermediate"
  else
    return "advanced"
  end
end

-- Show contextual help based on user level
M.show_contextual_help = function()
  local level = M.config.user_level or "beginner"
  local help_lines = {}
  
  if level == "beginner" then
    help_lines = {
      "╭──────────────────────────────────────────────╮",
      "│            🌟 QUICK START GUIDE               │",
      "├──────────────────────────────────────────────┤",
      "│                                               │",
      "│  Welcome! Here are the basics:                │",
      "│                                               │",
      "│  🎯 ESSENTIAL COMMANDS                        │",
      "│  ───────────────────                        │",
      "│  a or o     Add a new todo                   │",
      "│  <Enter>    Mark todo as done/undone         │",
      "│  j/k        Move between todos               │",
      "│  d          Delete a todo                    │",
      "│  q          Close this window                │",
      "│                                               │",
      "│  💡 TIP: Press '?' again for more commands   │",
      "│                                               │",
      "╰──────────────────────────────────────────────╯"
    }
  elseif level == "intermediate" then
    help_lines = {
      "╭──────────────────────────────────────────────────╮",
      "│              📖 TODO MANAGER                   │",
      "├──────────────────────────────────────────────────┤",
      "│                                                │",
      "│  ✅ TODO MANAGEMENT                            │",
      "│  a/o        Add new todo                      │",
      "│  <Enter>    Toggle done/undone                │",
      "│  d          Delete todo                       │",
      "│  E          Edit mode (direct markdown)       │",
      "│                                                │",
      "│  🔥 PRIORITY                                  │",
      "│  +/-        Change priority                   │",
      "│  1/2/3      Set high/medium/low              │",
      "│                                                │",
      "│  🔍 SEARCH                                     │",
      "│  /          Search todos                      │",
      "│  <Tab>      Preview details                   │",
      "│                                                │",
      "│  💡 TIP: Press '?' again for advanced help    │",
      "│                                                │",
      "╰──────────────────────────────────────────────────╯"
    }
  else
    -- Advanced - show all features
    help_lines = {
      "╭───────────────────────────────────────────────────────╮",
      "│                  📖 TODO MANAGER HELP                 │",
      "├───────────────────────────────────────────────────────┤",
      "│                                                       │",
      "│  🎯 BASIC NAVIGATION                                  │",
      "│  j/k or ↓/↑      Move down/up                        │",
      "│  gg / G          Go to top/bottom                    │",
      "│  <Tab>           Preview todo details                │",
      "│                                                       │",
      "│  ✅ TODO ACTIONS                                      │",
      "│  <Enter>         Toggle done/undone                  │",
      "│  a or o          Add new todo (inline)               │",
      "│  A               Add with priority & tags            │",
      "│  d               Delete current todo                 │",
      "│  E               Toggle edit mode                    │",
      "│                                                       │",
      "│  🔥 PRIORITY                                          │",
      "│  + / -           Increase/decrease priority          │",
      "│  1 / 2 / 3       Set high/medium/low priority       │",
      "│                                                       │",
      "│  🔍 SEARCH & FILTER                                   │",
      "│  /               Search todos                        │",
      "│  fp / ft / fs    Filter by priority/tag/status      │",
      "│  <C-c>           Clear search/filters                │",
      "│                                                       │",
      "│  📤 EXPORT                                            │",
      "│  em / ej / ey    Export as Markdown/JSON/YAML       │",
      "│  ea              Export all formats                  │",
      "│                                                       │",
      "│  ℹ️  TIPS                                              │",
      "│  • Todos are organized by priority sections          │",
      "│  • Use Tab to see metadata and linked files          │",
      "│  • External integrations sync automatically          │",
      "│                                                       │",
      "│  q or <Esc>      Close this help                    │",
      "╰───────────────────────────────────────────────────────╯"
    }
  end
  
  -- Create and show help window
  local help_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
  vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
  
  local help_win = vim.api.nvim_open_win(help_buf, true, {
    relative = "editor",
    width = #help_lines[1] > 56 and #help_lines[1] or 56,
    height = #help_lines,
    row = math.floor((vim.o.lines - #help_lines) / 2),
    col = math.floor((vim.o.columns - 56) / 2),
    border = "single",
    style = "minimal",
    focusable = true,
    zindex = 100
  })
  
  -- Style the help window
  vim.api.nvim_win_set_option(help_win, "winhl", "Normal:Pmenu,FloatBorder:Pmenu")
  vim.api.nvim_buf_set_option(help_buf, "filetype", "help")
  
  -- Track help views to advance user level
  M.track_usage("help_viewed")
  
  -- Close keymaps
  vim.keymap.set("n", "q", function()
    vim.api.nvim_win_close(help_win, true)
  end, { buffer = help_buf })
  
  vim.keymap.set("n", "<Esc>", function()
    vim.api.nvim_win_close(help_win, true)
  end, { buffer = help_buf })
  
  -- Allow pressing ? again to cycle through help levels
  vim.keymap.set("n", "?", function()
    vim.api.nvim_win_close(help_win, true)
    -- Cycle to next level temporarily
    local old_level = M.config.user_level
    if old_level == "beginner" then
      M.config.user_level = "intermediate"
    elseif old_level == "intermediate" then
      M.config.user_level = "advanced"
    else
      M.config.user_level = "beginner"
    end
    M.show_contextual_help()
    -- Restore original level
    M.config.user_level = old_level
  end, { buffer = help_buf })
end

-- Track usage for progressive disclosure
M.track_usage = function(action)
  local data_path = vim.fn.stdpath("data") .. "/todo-mcp-usage.json"
  local usage = {}
  
  -- Try to load existing usage if file exists
  if vim.fn.filereadable(data_path) == 1 then
    local ok, file_content = pcall(vim.fn.readfile, data_path)
    if ok and file_content and #file_content > 0 then
      local decode_ok, existing = pcall(vim.fn.json_decode, file_content)
      if decode_ok and existing then
        usage = existing
      end
    end
  end
  
  -- Initialize if needed
  usage.sessions = (usage.sessions or 0) + (action == "session_start" and 1 or 0)
  usage.todos_created = (usage.todos_created or 0) + (action == "todo_created" and 1 or 0)
  usage.help_viewed = (usage.help_viewed or 0) + (action == "help_viewed" and 1 or 0)
  usage.last_used = os.date("%Y-%m-%d %H:%M:%S")
  
  -- Ensure the data directory exists
  local data_dir = vim.fn.stdpath("data")
  if vim.fn.isdirectory(data_dir) == 0 then
    vim.fn.mkdir(data_dir, "p")
  end
  
  -- Save usage data
  local ok, _ = pcall(vim.fn.writefile, {vim.fn.json_encode(usage)}, data_path)
  if not ok then
    -- Silently fail if we can't write the usage file
    return
  end
end

-- Parse markdown lines into todo data
M.markdown_to_todos = function(lines)
  local todos = {}
  local current_section = "Tasks"
  local section_priority = "medium"
  local position = 0
  
  for _, line in ipairs(lines) do
    -- Check for section headers
    local section_match = line:match("^## (.+)")
    if section_match then
      current_section = section_match
      position = 0
      
      -- Infer priority from section name
      if section_match:match("High") or section_match:match("🔥") then
        section_priority = "high"
      elseif section_match:match("Low") or section_match:match("💤") then
        section_priority = "low"
      else
        section_priority = "medium"
      end
    end
    
    -- Check for todo items
    local todo_match = line:match("^%- %[(.?)%] (.+)")
    if todo_match then
      local checkbox, content = line:match("^%- %[(.?)%] (.+)")
      local done = checkbox == "x"
      position = position + 1
      
      table.insert(todos, {
        content = content,
        section = current_section,
        position = position,
        priority = section_priority,
        status = done and "done" or "todo"
      })
    end
  end
  
  return todos
end

return M