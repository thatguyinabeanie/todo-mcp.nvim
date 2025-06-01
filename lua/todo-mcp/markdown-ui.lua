local M = {}
local api = vim.api
local frontmatter = require("todo-mcp.frontmatter")
local db = require("todo-mcp.db")

M.state = {
  buf = nil,
  win = nil,
  current_todo = nil,
  view_mode = "list", -- list | detail
}

-- Create buffer for single todo markdown view
M.open_todo = function(todo)
  -- Create buffer
  local buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_option(buf, "buftype", "acwrite")
  api.nvim_buf_set_option(buf, "filetype", "markdown")
  api.nvim_buf_set_name(buf, "todo://" .. todo.id)
  
  -- Convert todo to markdown
  local markdown = frontmatter.todo_to_markdown(todo)
  local lines = vim.split(markdown, "\n", { plain = true })
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  -- Calculate window size
  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(30, vim.o.lines - 5)
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)
  
  -- Create floating window
  local win = api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " ✏️  Edit Todo (Markdown) ",
    title_pos = "center",
  })
  
  -- Store state
  M.state.buf = buf
  M.state.win = win
  M.state.current_todo = todo
  
  -- Setup keymaps
  M.setup_markdown_keymaps(buf)
  
  -- Setup save on write
  api.nvim_create_autocmd("BufWriteCmd", {
    buffer = buf,
    callback = function()
      M.save_todo()
    end
  })
end

-- Save markdown back to database
M.save_todo = function()
  if not M.state.buf or not M.state.current_todo then
    return
  end
  
  -- Get markdown content
  local lines = api.nvim_buf_get_lines(M.state.buf, 0, -1, false)
  local markdown_text = table.concat(lines, "\n")
  
  -- Parse and update
  local parsed_todo = frontmatter.markdown_to_todo(markdown_text)
  
  -- Update database
  local updates = {
    title = parsed_todo.title,
    content = parsed_todo.content,
    status = parsed_todo.status,
    priority = parsed_todo.priority,
    tags = parsed_todo.tags,
    file_path = parsed_todo.file_path,
    line_number = parsed_todo.line_number,
    done = parsed_todo.done,
    completed_at = parsed_todo.completed_at,
  }
  
  -- Mark completed if status changed to done
  if parsed_todo.status == "done" and M.state.current_todo.status ~= "done" then
    updates.completed_at = require("todo-mcp.schema").timestamp()
  end
  
  db.update(M.state.current_todo.id, updates)
  
  -- Mark as saved
  api.nvim_buf_set_option(M.state.buf, "modified", false)
  
  -- Notify
  vim.notify("Todo saved", vim.log.levels.INFO)
  
  -- Refresh main list if open
  local ui = require("todo-mcp.ui")
  if ui.state.win and api.nvim_win_is_valid(ui.state.win) then
    ui.refresh()
  end
end

-- Render todos as markdown list with frontmatter preview
M.render_list = function(todos)
  local lines = {}
  
  -- Title
  table.insert(lines, "# 📝 Todo List")
  table.insert(lines, "")
  table.insert(lines, "_Press `<CR>` to open, `n` to create new, `?` for help_")
  table.insert(lines, "")
  table.insert(lines, "---")
  table.insert(lines, "")
  
  -- Group by status
  local groups = {
    { status = "todo", title = "## 📋 To Do", items = {} },
    { status = "in_progress", title = "## 🚧 In Progress", items = {} },
    { status = "done", title = "## ✅ Done", items = {} },
  }
  
  -- Sort todos into groups
  for _, todo in ipairs(todos) do
    local status = todo.status or (todo.done and "done" or "todo")
    for _, group in ipairs(groups) do
      if group.status == status then
        table.insert(group.items, todo)
        break
      end
    end
  end
  
  -- Render each group
  for _, group in ipairs(groups) do
    if #group.items > 0 then
      table.insert(lines, group.title)
      table.insert(lines, "")
      
      for _, todo in ipairs(group.items) do
        -- Mini frontmatter preview
        local preview = string.format("### %s", todo.title or "Untitled")
        table.insert(lines, preview)
        
        -- Metadata line
        local meta = {}
        if todo.priority and todo.priority ~= "medium" then
          table.insert(meta, "!" .. todo.priority)
        end
        if todo.tags and todo.tags ~= "" then
          table.insert(meta, "#" .. todo.tags:gsub(", ", " #"))
        end
        if #meta > 0 then
          table.insert(lines, "_" .. table.concat(meta, " ") .. "_")
        end
        
        -- First line of content
        if todo.content and todo.content ~= "" then
          local first_line = todo.content:match("^[^\n]+") or ""
          if #first_line > 60 then
            first_line = first_line:sub(1, 60) .. "..."
          end
          table.insert(lines, "> " .. first_line)
        end
        
        table.insert(lines, "")
      end
      
      table.insert(lines, "---")
      table.insert(lines, "")
    end
  end
  
  return lines
end

-- Setup keymaps for markdown editing
M.setup_markdown_keymaps = function(buf)
  -- Save and close
  vim.keymap.set("n", "<C-s>", function()
    M.save_todo()
  end, { buffer = buf, desc = "Save todo" })
  
  vim.keymap.set("n", "q", function()
    if vim.bo[buf].modified then
      vim.ui.select({ "Save and close", "Close without saving", "Cancel" }, 
        { prompt = "Todo has unsaved changes:" }, 
        function(choice)
          if choice == "Save and close" then
            M.save_todo()
            M.close()
          elseif choice == "Close without saving" then
            M.close()
          end
        end)
    else
      M.close()
    end
  end, { buffer = buf, desc = "Close" })
  
  -- Quick status change
  vim.keymap.set("n", "<C-d>", function()
    -- Toggle between todo/done
    local lines = api.nvim_buf_get_lines(buf, 0, -1, false)
    for i, line in ipairs(lines) do
      if line:match("^status:") then
        if line:match("todo") then
          lines[i] = "status: done"
        else
          lines[i] = "status: todo"
        end
        api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        break
      end
    end
  end, { buffer = buf, desc = "Toggle status" })
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
  M.state.current_todo = nil
end

return M