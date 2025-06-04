local M = {}
local db = require("todo-mcp.db")
local api = vim.api

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
    -- Check if this is a git repository and if setup wizard is needed
    local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
    local is_git_repo = handle and handle:read("*a"):match("true")
    if handle then handle:close() end
    
    if is_git_repo then
      local config_manager = require("todo-mcp.config")
      local wizard = require("todo-mcp.setup-wizard")
      
      -- Check if auto_setup is enabled in config
      local config = config_manager.get_config()
      if config.project and config.project.auto_setup and not config_manager.is_project_configured() then
        -- Run setup wizard first
        wizard.run(function(proj_config)
          if proj_config then
            -- Reload configuration
            local merged_config = config_manager.get_config()
            local db_path = config_manager.get_db_path(merged_config)
            require("todo-mcp.db").setup(db_path)
            -- Open UI after setup
            M.open()
          end
        end, "project")
        return
      else
        -- Ensure we're using the right database path
        local db_path = config_manager.get_db_path(config)
        require("todo-mcp.db").setup(db_path)
      end
    end
    
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
    title = " 📋 Todo Manager (MCP) ",
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
  
  -- Get todos from database (search or all)
  if M.state.search_active and M.state.search_query ~= "" then
    M.state.todos = db.search(M.state.search_query, M.state.search_filters)
  else
    M.state.todos = db.get_all()
  end
  
  -- Render based on view mode
  local lines = {}
  
  if M.config.view_mode == "markdown" then
    -- Use markdown renderer
    local markdown_ui = require("todo-mcp.markdown-ui")
    lines = markdown_ui.render_list(M.state.todos)
    
    -- Set filetype for syntax highlighting
    api.nvim_buf_set_option(M.state.buf, "filetype", "markdown")
  else
    -- Use new view system
    local views = require("todo-mcp.views")
    
    -- Modern title bar with progress visualization
    local title = "📝 Todo Manager"
    local stats_line = ""
    if #M.state.todos > 0 then
      local done_count = 0
      local in_progress_count = 0
      for _, todo in ipairs(M.state.todos) do
        if todo.done or todo.status == "done" then 
          done_count = done_count + 1 
        elseif todo.status == "in_progress" then
          in_progress_count = in_progress_count + 1
        end
      end
      
      local total = #M.state.todos
      local completion_pct = math.floor((done_count / total) * 100)
      
      -- Progress bar visualization
      local bar_width = 20
      local filled = math.floor((done_count / total) * bar_width)
      local progress_bar = string.rep("\u{2593}", filled) .. string.rep("\u{2591}", bar_width - filled)
      
      title = title .. " (" .. done_count .. "/" .. total .. " done)"
      stats_line = string.format("    %s %d%% │ %d active │ %d in progress", 
        progress_bar, completion_pct, total - done_count, in_progress_count)
    end
    
    table.insert(lines, title)
    if stats_line ~= "" then
      table.insert(lines, stats_line)
    end
    table.insert(lines, string.rep("─", math.max(vim.fn.strwidth(title), vim.fn.strwidth(stats_line))))
    table.insert(lines, "")
    
    -- Add search header if active  
    if M.state.search_active then
      local search_line = "🔍 Search: " .. M.state.search_query
      if next(M.state.search_filters) then
        local filter_parts = {}
        for k, v in pairs(M.state.search_filters) do
          table.insert(filter_parts, k .. ":" .. tostring(v))
        end
        search_line = search_line .. " [" .. table.concat(filter_parts, ", ") .. "]"
      end
      table.insert(lines, search_line)
      table.insert(lines, string.rep("─", vim.fn.strwidth(search_line)))
      table.insert(lines, "")
    end
    
    -- Render todos using the configured style
    local todo_lines = views.render_todos(M.state.todos, M.style)
    for _, line in ipairs(todo_lines) do
      table.insert(lines, line)
    end
  end
  
  if #lines == 0 then
    lines = { 
      "╭─ Welcome to Todo Manager ─╮",
      "│                           │",
      "│  No todos yet! Get started │",
      "│  by pressing 'a' to add   │",
      "│  your first todo item.    │",
      "│                           │",
      "╰───────────────────────────╯",
      "",
      "  💡 Quick start: a=add  A=add+  /=search  ?=help"
    }
  else
    -- Simple help hint at the bottom
    table.insert(lines, "")
    table.insert(lines, string.rep("─", 40))
    table.insert(lines, "    Press ? for help")
  end
  
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buf, "modifiable", false)
  
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
end

M.setup_keymaps = function()
  local keymaps = require("todo-mcp").opts.keymaps
  local buf = M.state.buf
  
  -- Add todo
  vim.keymap.set("n", keymaps.add, function()
    vim.ui.input({ prompt = "New todo: " }, function(input)
      if input and input ~= "" then
        db.add(input)
        M.refresh()
      end
    end)
  end, { buffer = buf })
  
  -- Delete todo
  vim.keymap.set("n", keymaps.delete, function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      db.delete(M.state.todos[idx].id)
      M.refresh()
    end
  end, { buffer = buf })
  
  -- Toggle done
  vim.keymap.set("n", keymaps.toggle_done, function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      db.toggle_done(M.state.todos[idx].id)
      M.refresh()
    end
  end, { buffer = buf })
  
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
  
  -- Add todo with options
  vim.keymap.set("n", "A", function()
    M.add_todo_with_options()
  end, { buffer = buf, desc = "Add todo with priority/tags" })
  
  -- Jump to file
  vim.keymap.set("n", "gf", function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] and M.state.todos[idx].file_path then
      M.close()
      vim.cmd("edit " .. M.state.todos[idx].file_path)
      if M.state.todos[idx].line_number then
        vim.cmd(M.state.todos[idx].line_number)
      end
    end
  end, { buffer = buf, desc = "Jump to linked file" })
  
  -- Toggle preview
  vim.keymap.set("n", "p", function()
    M.state.preview_enabled = not M.state.preview_enabled
    if M.state.preview_enabled then
      local todo_idx = M.get_cursor_todo_idx()
      if todo_idx and M.state.todos[todo_idx] then
        M.show_preview(M.state.todos[todo_idx])
      end
      vim.notify("Preview enabled", vim.log.levels.INFO)
    else
      M.close_preview()
      vim.notify("Preview disabled", vim.log.levels.INFO)
    end
  end, { buffer = buf, desc = "Toggle preview" })
  
  -- Enhanced navigation with preview
  vim.keymap.set("n", "j", function()
    M.move_cursor("down")
  end, { buffer = buf, desc = "Move down with preview" })
  
  vim.keymap.set("n", "k", function()
    M.move_cursor("up")
  end, { buffer = buf, desc = "Move up with preview" })
  
  -- Open todo in markdown view
  vim.keymap.set("n", "<CR>", function()
    local idx = M.get_cursor_todo_idx()
    if idx and M.state.todos[idx] then
      if M.config.view_mode == "markdown" then
        local markdown_ui = require("todo-mcp.markdown-ui")
        markdown_ui.open_todo(M.state.todos[idx])
      else
        db.toggle_done(M.state.todos[idx].id)
        M.refresh()
      end
    end
  end, { buffer = buf, desc = "Open todo / Toggle done" })
  
  -- Help
  vim.keymap.set("n", "?", function()
    local help = {
      "╭─ Todo Manager Keymaps ────────────────────╮",
      "│                                           │",
      "│  Navigation & Actions:                    │",
      "│  j/k     - Navigate with live preview     │",
      "│  <CR>    - Toggle done/undone             │",
      "│  p       - Toggle preview window          │",
      "│                                           │",
      "│  Todo Management:                         │",
      "│  a       - Add new todo                   │",
      "│  A       - Add todo with priority/tags    │",
      "│  d       - Delete todo                    │",
      "│                                           │",
      "│  Linking Files:                           │",
      "│  When adding a todo (A), you'll be asked  │",
      "│  if you want to link it to the current   │",
      "│  file and line number.                    │",
      "│  gf      - Jump to linked file            │",
      "│                                           │",
      "│  Search & Navigation:                     │",
      "│  /       - Search todos                   │",
      "│  <C-c>   - Clear search                   │",
      "│                                           │",
      "│  Export Options:                          │",
      "│  em      - Export to Markdown             │",
      "│  ej      - Export to JSON                 │",
      "│  ey      - Export to YAML                 │",
      "│  ea      - Export all formats             │",
      "│                                           │",
      "│  UI Options:                              │",
      "│  S       - Cycle visual style             │",
      "│                                           │",
      "│  ?       - Show this help                 │",
      "│  q/<Esc> - Close                          │",
      "│                                           │",
      "╰───────────────────────────────────────────╯"
    }
    local help_buf = api.nvim_create_buf(false, true)
    api.nvim_buf_set_lines(help_buf, 0, -1, false, help)
    
    local help_win = api.nvim_open_win(help_buf, true, {
      relative = "editor",
      row = math.floor(vim.o.lines * 0.1),
      col = math.floor(vim.o.columns * 0.2),
      width = math.min(48, vim.o.columns - 4),
      height = #help,
      border = "rounded",
      style = "minimal",
      title = " Help ",
      title_pos = "center"
    })
    
    api.nvim_win_set_option(help_win, "winhl", "Normal:TodoNormal")
    
    vim.keymap.set("n", "<Esc>", function()
      api.nvim_win_close(help_win, true)
      api.nvim_buf_delete(help_buf, { force = true })
    end, { buffer = help_buf })
    
    vim.keymap.set("n", "q", function()
      api.nvim_win_close(help_win, true)
      api.nvim_buf_delete(help_buf, { force = true })
    end, { buffer = help_buf })
  end, { buffer = buf })
  
  -- Quit
  vim.keymap.set("n", keymaps.quit, M.close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", M.close, { buffer = buf })
  
  -- Cycle through visual styles
  vim.keymap.set("n", "S", function()
    M.cycle_style()
  end, { buffer = buf, desc = "Cycle visual style" })
end

-- Helper to calculate header offset
M.get_header_offset = function()
  local offset = 3 -- title + separator + blank line
  if #M.state.todos > 0 then
    offset = offset + 1 -- stats line
  end
  if M.state.search_active then
    offset = offset + 2 -- search line + separator
  end
  return offset
end

-- Helper to get todo index accounting for headers
M.get_cursor_todo_idx = function()
  local cursor_line = api.nvim_win_get_cursor(M.state.win)[1]
  
  if M.config.view_mode == "markdown" then
    -- In markdown mode, we need different offset calculation
    -- TODO: Implement proper line-to-todo mapping for markdown view
    -- For now, simple approach
    local current_line = 0
    local todo_idx = 0
    local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
    
    for i, line in ipairs(lines) do
      if line:match("^###") then
        todo_idx = todo_idx + 1
        if i >= cursor_line then
          return todo_idx
        end
      end
    end
    return nil
  else
    -- For non-markdown views, we need to map buffer lines to todo indices
    local line_map = M.build_line_to_todo_map()
    return line_map[cursor_line]
  end
end

-- Build a map from line numbers to todo indices
M.build_line_to_todo_map = function()
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local line_map = {}
  local todo_idx = 0
  
  -- Skip past the header offset
  local header_offset = M.get_header_offset()
  
  for i = header_offset + 1, #lines do
    local line = lines[i]
    -- Skip empty lines and section headers
    if line ~= "" and not line:match("^##") and not line:match("^─+$") and not line:match("^╭─") and not line:match("^│") and not line:match("^╰─") then
      todo_idx = todo_idx + 1
      if todo_idx <= #M.state.todos then
        line_map[i] = todo_idx
      end
    end
  end
  
  return line_map
end

-- Get the line number for a todo index
M.get_line_for_todo = function(todo_idx)
  if not todo_idx or todo_idx < 1 or todo_idx > #M.state.todos then
    return nil
  end
  
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local current_todo = 0
  local header_offset = M.get_header_offset()
  
  for i = header_offset + 1, #lines do
    local line = lines[i]
    -- Skip empty lines and section headers
    if line ~= "" and not line:match("^##") and not line:match("^─+$") and not line:match("^╭─") and not line:match("^│") and not line:match("^╰─") then
      current_todo = current_todo + 1
      if current_todo == todo_idx then
        return i
      end
    end
  end
  
  return nil
end

M.add_todo_with_options = function()
  vim.ui.input({ prompt = "Todo content: " }, function(content)
    if not content or content == "" then
      return
    end
    
    vim.ui.select({ "low", "medium", "high" }, { prompt = "Priority: " }, function(priority)
      priority = priority or "medium"
      
      vim.ui.input({ prompt = "Tags (optional): " }, function(tags)
        tags = tags or ""
        
        -- Get current file context
        local current_file = vim.fn.expand("%:p")
        local current_line = vim.fn.line(".")
        
        local options = {
          priority = priority,
          tags = tags
        }
        
        -- Ask if they want to link to current file
        if current_file ~= "" then
          vim.ui.select({ "Yes", "No" }, { 
            prompt = "Link to current file (" .. vim.fn.fnamemodify(current_file, ":t") .. ":" .. current_line .. ")? " 
          }, function(choice)
            if choice == "Yes" then
              options.file_path = current_file
              options.line_number = current_line
            end
            
            db.add(content, options)
            M.refresh()
          end)
        else
          db.add(content, options)
          M.refresh()
        end
      end)
    end)
  end)
end

-- Setup modern highlight groups
M.setup_modern_highlights = function()
  -- Main UI highlights
  vim.api.nvim_set_hl(0, "TodoNormal", { 
    bg = "#1e1e2e", 
    fg = "#cdd6f4" 
  })
  vim.api.nvim_set_hl(0, "TodoCursorLine", { 
    bg = "#313244", 
    bold = true 
  })
  vim.api.nvim_set_hl(0, "TodoFading", { 
    bg = "#11111b", 
    fg = "#6c7086" 
  })
  
  -- Border highlights
  vim.api.nvim_set_hl(0, "TodoBorderCorner", { 
    fg = "#89b4fa", 
    bold = true 
  })
  vim.api.nvim_set_hl(0, "TodoBorderHorizontal", { 
    fg = "#74c7ec" 
  })
  vim.api.nvim_set_hl(0, "TodoBorderVertical", { 
    fg = "#74c7ec" 
  })
  
  -- Progress bar highlights
  vim.api.nvim_set_hl(0, "TodoProgressFilled", { 
    fg = "#a6e3a1", 
    bold = true 
  })
  vim.api.nvim_set_hl(0, "TodoProgressEmpty", { 
    fg = "#45475a" 
  })
  
  -- Status highlights with modern colors
  vim.api.nvim_set_hl(0, "TodoTitleBar", { 
    fg = "#89b4fa", 
    bold = true 
  })
  vim.api.nvim_set_hl(0, "TodoStats", { 
    fg = "#f9e2af", 
    italic = true 
  })
  vim.api.nvim_set_hl(0, "TodoFooter", { 
    fg = "#cba6f7", 
    italic = true 
  })
end

-- Floating preview window functionality
M.show_preview = function(todo)
  if not todo or not M.config.floating_preview then
    return
  end
  
  -- Validate main window still exists
  if not M.state.win or not api.nvim_win_is_valid(M.state.win) then
    return
  end
  
  -- Close existing preview
  M.close_preview()
  
  -- Create preview content
  local content = {
    "📋 " .. (todo.title or "Untitled"),
    "",
    "Status: " .. (todo.status or "todo"),
    "Priority: " .. (todo.priority or "medium"),
    "Created: " .. (todo.created_at or "unknown"),
    "",
    "Content:",
    "─────────",
  }
  
  -- Add content lines
  if todo.content then
    for line in todo.content:gmatch("[^\n]+") do
      table.insert(content, line)
    end
  else
    table.insert(content, "(empty)")
  end
  
  -- Add tags if present
  if todo.tags and todo.tags ~= "" then
    table.insert(content, "")
    table.insert(content, "Tags: " .. todo.tags)
  end
  
  -- Add file reference if present
  if todo.file_path then
    table.insert(content, "")
    table.insert(content, "File: " .. vim.fn.fnamemodify(todo.file_path, ":~"))
    if todo.line_number then
      table.insert(content, "Line: " .. todo.line_number)
    end
  end
  
  -- Calculate preview window size and position
  local max_width = math.min(60, math.floor(vim.o.columns * 0.4))
  local max_height = math.min(#content + 2, math.floor(vim.o.lines * 0.6))
  
  -- Position to the right of main window
  local main_config = api.nvim_win_get_config(M.state.win)
  local preview_col = main_config.col + main_config.width + 2
  
  -- Check if preview would go off-screen
  if preview_col + max_width > vim.o.columns then
    -- Try positioning to the left instead
    preview_col = main_config.col - max_width - 2
    if preview_col < 0 then
      -- If no room on either side, overlap the main window
      preview_col = math.max(0, vim.o.columns - max_width - 2)
    end
  end
  
  -- Create preview buffer
  M.state.preview_buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(M.state.preview_buf, "buftype", "nofile")
  api.nvim_buf_set_lines(M.state.preview_buf, 0, -1, false, content)
  api.nvim_buf_set_option(M.state.preview_buf, "modifiable", false)
  
  -- Create preview window
  local ok, win_or_err = pcall(api.nvim_open_win, M.state.preview_buf, false, {
    relative = "editor",
    row = main_config.row,
    col = preview_col,
    width = max_width,
    height = max_height,
    border = "rounded",
    style = "minimal",
    title = " Preview ",
    title_pos = "center",
    noautocmd = true,
    zindex = 60  -- Ensure preview is above main window
  })
  
  if not ok then
    vim.notify("Failed to create preview window: " .. tostring(win_or_err), vim.log.levels.ERROR)
    if M.state.preview_buf and api.nvim_buf_is_valid(M.state.preview_buf) then
      api.nvim_buf_delete(M.state.preview_buf, { force = true })
    end
    M.state.preview_buf = nil
    return
  end
  
  M.state.preview_win = win_or_err
  
  -- Set preview window options
  pcall(api.nvim_win_set_option, M.state.preview_win, "winhl", "Normal:TodoNormal")
end

M.close_preview = function()
  if M.state.preview_win and api.nvim_win_is_valid(M.state.preview_win) then
    api.nvim_win_close(M.state.preview_win, true)
  end
  if M.state.preview_buf and api.nvim_buf_is_valid(M.state.preview_buf) then
    api.nvim_buf_delete(M.state.preview_buf, { force = true })
  end
  M.state.preview_win = nil
  M.state.preview_buf = nil
end

-- Enhanced cursor movement with preview
M.move_cursor = function(direction)
  if not M.state.win or not api.nvim_win_is_valid(M.state.win) then
    return
  end
  
  local current_pos = api.nvim_win_get_cursor(M.state.win)
  local new_line = current_pos[1]
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  
  -- Move to next/previous non-empty, non-header line
  repeat
    if direction == "down" then
      new_line = new_line + 1
      if new_line > #lines then
        new_line = current_pos[1]  -- Stay at current position
        break
      end
    elseif direction == "up" then
      new_line = new_line - 1
      if new_line < 1 then
        new_line = current_pos[1]  -- Stay at current position
        break
      end
    end
    
    local line = lines[new_line]
    -- Check if this is a todo line (not empty, not a header, not a border)
    if line ~= "" and not line:match("^##") and not line:match("^─+$") and not line:match("^╭─") and not line:match("^│") and not line:match("^╰─") then
      break  -- Found a todo line
    end
  until false
  
  if new_line ~= current_pos[1] then
    api.nvim_win_set_cursor(M.state.win, { new_line, 0 })
    
    -- Update selected state
    local todo_idx = M.get_cursor_todo_idx()
    if todo_idx then
      M.state.selected = todo_idx
    end
  end
  
  -- Show preview for current todo if enabled
  if M.state.preview_enabled then
    local todo_idx = M.get_cursor_todo_idx()
    if todo_idx and M.state.todos[todo_idx] then
      M.show_preview(M.state.todos[todo_idx])
    else
      M.close_preview()
    end
  end
end

-- Status line integration
M.update_status_line = function()
  if not M.config.status_line then
    return
  end
  
  local stats = require("todo-mcp.query").stats()
  local status_text = string.format(
    "Todos: %d/%d done (%d%%)", 
    stats.completed, 
    stats.total, 
    math.floor(stats.completion_rate)
  )
  
  vim.g.todo_mcp_status = status_text
  vim.cmd("redrawstatus")
end

-- Cycle through visual styles
M.cycle_style = function()
  local config_manager = require("todo-mcp.config")
  local config = config_manager.get_config()
  
  -- Define style order
  local styles = {"modern", "minimal", "emoji", "sections", "compact", "ascii"}
  local current_style = config.ui.style.preset or "modern"
  
  -- Find current index
  local current_index = 1
  for i, style in ipairs(styles) do
    if style == current_style then
      current_index = i
      break
    end
  end
  
  -- Get next style
  local next_index = (current_index % #styles) + 1
  local next_style = styles[next_index]
  
  -- Update config
  config.ui.style.preset = next_style
  
  -- Save to appropriate config file
  local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
  local is_git_repo = handle and handle:read("*a"):match("true")
  if handle then handle:close() end
  
  if is_git_repo and config_manager.is_project_configured() then
    -- Update project config
    local project_config = config_manager.load_project_config() or {}
    project_config.ui = project_config.ui or {}
    project_config.ui.style = project_config.ui.style or {}
    project_config.ui.style.preset = next_style
    config_manager.save_project_config(project_config)
  else
    -- Update global config
    local global_config = config_manager.load_global_config() or {}
    global_config.ui = global_config.ui or {}
    global_config.ui.style = global_config.ui.style or {}
    global_config.ui.style.preset = next_style
    config_manager.save_global_config(global_config)
  end
  
  -- Update current style
  M.style = require("todo-mcp.views").get_style(next_style)
  
  -- Refresh display
  M.refresh()
  
  -- Show notification
  vim.notify("Visual style changed to: " .. next_style, vim.log.levels.INFO)
end

return M