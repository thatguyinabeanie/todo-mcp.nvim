local M = {}
local db = require("todo-mcp.db")
local api = vim.api

-- Convert todos to hierarchical markdown
M.todos_to_markdown = function(todos)
  local lines = {}
  local sections = {
    { key = "high", title = "## 🔥 High Priority", todos = {} },
    { key = "medium", title = "## ⚡ Medium Priority", todos = {} },
    { key = "low", title = "## 💤 Low Priority", todos = {} },
    { key = "done", title = "## ✅ Completed", todos = {} }
  }
  
  -- Group todos by priority/status
  for _, todo in ipairs(todos) do
    if todo.done or todo.status == "done" then
      table.insert(sections[4].todos, todo)
    elseif todo.priority == "high" then
      table.insert(sections[1].todos, todo)
    elseif todo.priority == "low" then
      table.insert(sections[3].todos, todo)
    else -- medium or no priority
      table.insert(sections[2].todos, todo)
    end
  end
  
  -- Render sections
  for _, section in ipairs(sections) do
    table.insert(lines, section.title)
    table.insert(lines, "")
    
    if #section.todos > 0 then
      for _, todo in ipairs(section.todos) do
        local checkbox = todo.done and "- [x]" or "- [ ]"
        local content = todo.content or todo.title or ""
        table.insert(lines, checkbox .. " " .. content)
      end
    end
    table.insert(lines, "")
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
  local current_section = "medium"
  
  for _, line in ipairs(lines) do
    -- Check for section headers
    if line:match("^## 🔥") then
      current_section = "high"
    elseif line:match("^## ⚡") then
      current_section = "medium"
    elseif line:match("^## 💤") then
      current_section = "low"
    elseif line:match("^## ✅") then
      current_section = "done"
    elseif line:match("^%- %[[ x]%]") then
      -- Parse todo item
      local done = line:match("^%- %[x%]") ~= nil
      local content = line:gsub("^%- %[[ x]%] ", "")
      if content ~= "" then
        table.insert(todos, {
          content = content,
          priority = current_section == "done" and "medium" or current_section,
          done = done or current_section == "done",
          status = (done or current_section == "done") and "done" or "todo"
        })
      end
    end
  end
  
  -- Clear database and add all todos
  db.clear()
  for _, todo in ipairs(todos) do
    db.add(todo.content, {
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
  command_buf = nil
}

M.setup = function(config)
  M.config = config
  M.config.view_mode = config.view_mode or "list" -- "list" or "markdown"
  M.config.animation_speed = config.animation_speed or 150 -- milliseconds
  M.config.preview_enabled = config.preview_enabled ~= false -- default true
  M.config.modern_ui = config.modern_ui ~= false -- default true
  M.config.status_line = config.status_line ~= false -- default true
  M.config.floating_preview = config.floating_preview ~= false -- default true
  
  -- Setup view style
  local views = require("todo-mcp.views")
  M.style = views.get_style(config)
  
  -- Setup highlights
  views.setup_highlights()
  M.setup_modern_highlights()
end

M.toggle = function()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    M.close()
  else
    M.open()
  end
end

M.open = function()
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

M.close = function()
  -- Clean up timers
  if M.state.status_line_timer then
    M.state.status_line_timer:stop()
    M.state.status_line_timer = nil
  end
  
  -- Close preview window if open
  M.close_preview()
  
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
  
  if M.state.buf and api.nvim_buf_is_valid(M.state.buf) then
    api.nvim_buf_delete(M.state.buf, { force = true })
  end
  
  M.state.win = nil
  M.state.buf = nil
end

M.refresh = function()
  if not M.state.buf or not api.nvim_buf_is_valid(M.state.buf) then
    return
  end
  
  -- Get todos from database
  M.state.todos = db.get_all()
  
  -- Convert todos to hierarchical markdown
  local lines = M.todos_to_markdown(M.state.todos)
  
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
      "## ✅ Completed",
      "",
      "",
      "💡 Press 'o' to add new line, '?' for help"
    }
  end
  
  -- Set content and make buffer editable
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buf, "filetype", "markdown")
  
  -- Update window title
  local title = string.format(" 📋 Todo Manager (%d/%d) ", done_count, total_count)
  api.nvim_win_set_config(M.state.win, { title = title })
  
  -- Restore cursor position
  if M.state.selected > #M.state.todos then
    M.state.selected = math.max(1, #M.state.todos)
  end
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    -- Find the actual line number for the selected todo
    local cursor_line = M.get_line_for_todo(M.state.selected)
    if cursor_line then
      api.nvim_win_set_cursor(M.state.win, { cursor_line, 0 })
    else
      -- Fallback to first todo line if available
      cursor_line = M.get_line_for_todo(1)
      if cursor_line then
        api.nvim_win_set_cursor(M.state.win, { cursor_line, 0 })
        M.state.selected = 1
      end
    end
    
    -- Refresh preview if enabled
    if M.state.preview_enabled then
      local todo_idx = M.get_cursor_todo_idx()
      if todo_idx and M.state.todos[todo_idx] then
        M.show_preview(M.state.todos[todo_idx])
      else
        M.close_preview()
      end
    end
  end
  
  -- Update window title with stats
  M.update_window_title()
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
    title = string.format(" 📋 Todo Manager (%d/%d) ", done_count, #M.state.todos)
  else
    title = " 📋 Todo Manager "
  end
  
  -- Update window config
  api.nvim_win_set_config(M.state.win, { title = title })
end

M.setup_keymaps = function()
  local keymaps = require("todo-mcp").opts.keymaps
  local buf = M.state.buf
  
  -- Auto-sync on buffer write
  vim.api.nvim_create_autocmd("BufWritePost", {
    buffer = buf,
    callback = function()
      M.sync_markdown_to_db()
      M.refresh()
    end
  })
  
  -- Sync on buffer leave
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      M.sync_markdown_to_db()
    end
  })
  
  -- Toggle checkbox on current line
  vim.keymap.set("n", "<CR>", function()
    local line_num = vim.fn.line(".")
    local line = vim.fn.getline(line_num)
    
    if line:match("^%- %[ %]") then
      -- Toggle to done
      local new_line = line:gsub("^%- %[ %]", "- [x]")
      vim.fn.setline(line_num, new_line)
    elseif line:match("^%- %[x%]") then
      -- Toggle to undone  
      local new_line = line:gsub("^%- %[x%]", "- [ ]")
      vim.fn.setline(line_num, new_line)
    end
    
    M.sync_markdown_to_db()
  end, { buffer = buf, desc = "Toggle todo" })
  
  -- Quit
  vim.keymap.set("n", keymaps.quit, function()
    M.sync_markdown_to_db()
    M.close()
  end, { buffer = buf })
  
  -- Help
  vim.keymap.set("n", "?", function()
    local help_lines = {
      "# Todo Manager Help",
      "",
      "## Editing",
      "- Use normal markdown editing",
      "- `o` - new line below",
      "- `O` - new line above", 
      "- `i`/`a` - insert mode",
      "",
      "## Todo Format",
      "- `- [ ] todo content` - unchecked todo",
      "- `- [x] todo content` - checked todo",
      "",
      "## Keybindings",
      "- `<CR>` - toggle checkbox on current line",
      "- `q` - quit and save",
      "- `?` - show this help",
      "",
      "## Sections",
      "Todos are automatically organized by section:",
      "- `## 🔥 High Priority`",
      "- `## ⚡ Medium Priority`", 
      "- `## 💤 Low Priority`",
      "- `## ✅ Completed`",
      "",
      "Changes are auto-saved to database!"
    }
    
    local help_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(help_buf, 0, -1, false, help_lines)
    vim.api.nvim_buf_set_option(help_buf, "filetype", "markdown")
    vim.api.nvim_buf_set_option(help_buf, "modifiable", false)
    
    local help_win = vim.api.nvim_open_win(help_buf, true, {
      relative = "editor",
      width = 60,
      height = 25,
      row = 5,
      col = 10,
      border = "rounded",
      title = " Help ",
      title_pos = "center"
    })
    
    vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(help_win, true)
    end, { buffer = help_buf })
  end, { buffer = buf, desc = "Show help" })
end

return M