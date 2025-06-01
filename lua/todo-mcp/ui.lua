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
  search_filters = {}
}

M.setup = function(config)
  M.config = config
  M.config.view_mode = config.view_mode or "markdown" -- "list" or "markdown"
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
  
  -- Create window
  M.state.win = api.nvim_open_win(M.state.buf, true, {
    relative = "editor",
    row = row,
    col = col,
    width = width,
    height = height,
    border = M.config.border,
    style = "minimal",
    title = " Todo List (MCP) ",
    title_pos = "center"
  })
  
  -- Set window options
  api.nvim_win_set_option(M.state.win, "cursorline", true)
  api.nvim_win_set_option(M.state.win, "wrap", false)
  
  -- Load and render todos
  M.refresh()
  
  -- Set up buffer keymaps
  M.setup_keymaps()
end

M.close = function()
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_close(M.state.win, true)
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
    -- Original list view
    -- Add title bar
    local title = "📝 Todo List"
    if #M.state.todos > 0 then
      local done_count = 0
      for _, todo in ipairs(M.state.todos) do
        if todo.done then done_count = done_count + 1 end
      end
      title = title .. " (" .. done_count .. "/" .. #M.state.todos .. " done)"
    end
    table.insert(lines, title)
    table.insert(lines, string.rep("═", #title))
    table.insert(lines, "")
  end
  
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
    table.insert(lines, string.rep("─", #search_line))
  end
  
  for i, todo in ipairs(M.state.todos) do
    local prefix = todo.done and "✓" or "○"
    local line = string.format("%s %s", prefix, todo.content)
    
    -- Add priority and tags
    local meta = {}
    if todo.priority and todo.priority ~= "medium" then
      table.insert(meta, "!" .. todo.priority)
    end
    if todo.tags and todo.tags ~= "" then
      table.insert(meta, "#" .. todo.tags)
    end
    if todo.file_path then
      local file_display = vim.fn.fnamemodify(todo.file_path, ":t")
      if todo.line_number then
        file_display = file_display .. ":" .. todo.line_number
      end
      table.insert(meta, "@" .. file_display)
    end
    
    if #meta > 0 then
      line = line .. " " .. table.concat(meta, " ")
    end
    
    table.insert(lines, line)
  end
  
  if #lines == 0 then
    lines = { 
      "  No todos yet. Press 'a' to add one.",
      "",
      "  Quick commands: a=add A=add+ /=search ?=help q=quit"
    }
  else
    -- Add footer with command hints
    table.insert(lines, "")
    table.insert(lines, "  a=add A=add+ /=search gf=jump ?=help q=quit")
  end
  
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buf, "modifiable", false)
  
  -- Restore cursor position
  if M.state.selected > #M.state.todos then
    M.state.selected = math.max(1, #M.state.todos)
  end
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    -- Account for title and search header offset
    local cursor_line = M.state.selected
    local offset = 3 -- title + separator + blank line
    if M.state.search_active then
      offset = offset + 2 -- search line + separator
    end
    cursor_line = cursor_line + offset
    api.nvim_win_set_cursor(M.state.win, { cursor_line, 0 })
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
    local idx = api.nvim_win_get_cursor(M.state.win)[1]
    -- Account for title and search header offset
    local offset = 3 -- title + separator + blank line
    if M.state.search_active then
      offset = offset + 2 -- search line + separator
    end
    idx = idx - offset
    if M.state.todos[idx] then
      db.delete(M.state.todos[idx].id)
      M.refresh()
    end
  end, { buffer = buf })
  
  -- Toggle done
  vim.keymap.set("n", keymaps.toggle_done, function()
    local idx = api.nvim_win_get_cursor(M.state.win)[1]
    -- Account for title and search header offset
    local offset = 3 -- title + separator + blank line
    if M.state.search_active then
      offset = offset + 2 -- search line + separator
    end
    idx = idx - offset
    if M.state.todos[idx] then
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
    local idx = api.nvim_win_get_cursor(M.state.win)[1]
    -- Account for title and search header offset
    local offset = 3 -- title + separator + blank line
    if M.state.search_active then
      offset = offset + 2 -- search line + separator
    end
    idx = idx - offset
    if M.state.todos[idx] and M.state.todos[idx].file_path then
      M.close()
      vim.cmd("edit " .. M.state.todos[idx].file_path)
      if M.state.todos[idx].line_number then
        vim.cmd(M.state.todos[idx].line_number)
      end
    end
  end, { buffer = buf, desc = "Jump to linked file" })
  
  -- Open todo in markdown view
  vim.keymap.set("n", "<CR>", function()
    if M.config.view_mode == "markdown" then
      local idx = M.get_cursor_todo_idx()
      if M.state.todos[idx] then
        local markdown_ui = require("todo-mcp.markdown-ui")
        markdown_ui.open_todo(M.state.todos[idx])
      end
    else
      -- Original toggle done behavior
      local idx = api.nvim_win_get_cursor(M.state.win)[1]
      local offset = 3
      if M.state.search_active then
        offset = offset + 2
      end
      idx = idx - offset
      if M.state.todos[idx] then
        db.toggle_done(M.state.todos[idx].id)
        M.refresh()
      end
    end
  end, { buffer = buf, desc = "Open todo / Toggle done" })
  
  -- Help
  vim.keymap.set("n", "?", function()
    local help = {
      "Todo List Keymaps:",
      "",
      "a       - Add new todo",
      "A       - Add todo with priority/tags",
      "d       - Delete todo",
      "<CR>    - Toggle done/undone",
      "/       - Search todos",
      "<C-c>   - Clear search",
      "gf      - Jump to linked file",
      "em      - Export to Markdown",
      "ej      - Export to JSON", 
      "ey      - Export to YAML",
      "ea      - Export all formats",
      "?       - Show this help",
      "q/<Esc> - Close"
    }
    vim.notify(table.concat(help, "\n"))
  end, { buffer = buf })
  
  -- Quit
  vim.keymap.set("n", keymaps.quit, M.close, { buffer = buf })
  vim.keymap.set("n", "<Esc>", M.close, { buffer = buf })
end

-- Helper to get todo index accounting for headers
M.get_cursor_todo_idx = function()
  local idx = api.nvim_win_get_cursor(M.state.win)[1]
  
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
        if i >= idx then
          return todo_idx
        end
      end
    end
    return nil
  else
    -- Original offset calculation
    local offset = 3 -- title + separator + blank line
    if M.state.search_active then
      offset = offset + 2 -- search line + separator
    end
    return idx - offset
  end
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

return M