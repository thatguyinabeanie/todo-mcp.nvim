local M = {}
local db = require("todo-mcp.db")
local api = vim.api

M.state = {
  buf = nil,
  win = nil,
  todos = {},
  selected = 1
}

M.setup = function(config)
  M.config = config
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
  
  -- Get todos from database
  M.state.todos = db.get_all()
  
  -- Render todos
  local lines = {}
  for i, todo in ipairs(M.state.todos) do
    local prefix = todo.done and "✓" or "○"
    local line = string.format("%s %s", prefix, todo.content)
    table.insert(lines, line)
  end
  
  if #lines == 0 then
    lines = { "  No todos yet. Press 'a' to add one." }
  end
  
  api.nvim_buf_set_option(M.state.buf, "modifiable", true)
  api.nvim_buf_set_lines(M.state.buf, 0, -1, false, lines)
  api.nvim_buf_set_option(M.state.buf, "modifiable", false)
  
  -- Restore cursor position
  if M.state.selected > #M.state.todos then
    M.state.selected = math.max(1, #M.state.todos)
  end
  if M.state.win and api.nvim_win_is_valid(M.state.win) then
    api.nvim_win_set_cursor(M.state.win, { M.state.selected, 0 })
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
    if M.state.todos[idx] then
      db.delete(M.state.todos[idx].id)
      M.refresh()
    end
  end, { buffer = buf })
  
  -- Toggle done
  vim.keymap.set("n", keymaps.toggle_done, function()
    local idx = api.nvim_win_get_cursor(M.state.win)[1]
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
  
  -- Help
  vim.keymap.set("n", "?", function()
    local help = {
      "Todo List Keymaps:",
      "",
      "a       - Add new todo",
      "d       - Delete todo",
      "<CR>    - Toggle done/undone",
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

return M