local M = {}

local db = require('todo-mcp.db')
local tc_integration = require('todo-mcp.integrations.todo-comments')

-- Populate quickfix with todos
M.todos_to_quickfix = function(filter)
  filter = filter or "all"
  
  local todos = db.get_all()
  local qf_list = {}
  
  for _, todo in ipairs(todos) do
    -- Apply filter
    local include = true
    
    if filter == "untracked" then
      include = not todo.file_path
    elseif filter == "high-priority" then
      include = todo.priority == "high"
    elseif filter == "in-progress" then
      include = todo.status == "in_progress"
    elseif filter == "done" then
      include = todo.status == "done" or todo.done
    elseif filter == "orphaned" then
      local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
      include = metadata.orphaned == true
    end
    
    if include then
      local qf_entry = {
        filename = todo.file_path or "",
        lnum = todo.line_number or 1,
        col = 1,
        text = string.format("[%s] %s", 
          string.upper(todo.priority or "medium"), 
          todo.title or "Untitled"
        ),
        type = M.priority_to_type(todo.priority),
        valid = todo.file_path ~= nil,
      }
      
      -- Add metadata to text
      local meta = {}
      if todo.status and todo.status ~= "todo" then
        table.insert(meta, todo.status)
      end
      if todo.tags and todo.tags ~= "" then
        table.insert(meta, "#" .. todo.tags:gsub(", ", " #"))
      end
      if #meta > 0 then
        qf_entry.text = qf_entry.text .. " (" .. table.concat(meta, " ") .. ")"
      end
      
      table.insert(qf_list, qf_entry)
    end
  end
  
  -- Set quickfix list
  vim.fn.setqflist(qf_list, 'r')
  vim.cmd("copen")
  
  -- Set title
  local title = "Todo-MCP: " .. filter:gsub("-", " "):gsub("^%l", string.upper)
  vim.fn.setqflist({}, 'a', { title = title })
  
  return #qf_list
end

-- Convert priority to quickfix type
M.priority_to_type = function(priority)
  local type_map = {
    high = "E",  -- Error
    medium = "W", -- Warning
    low = "I",   -- Info
  }
  return type_map[priority] or "W"
end

-- Find untracked TODO comments and add to quickfix
M.untracked_to_quickfix = function()
  -- Get all TODO comments from project
  local todo_comments = M.find_all_todo_comments()
  
  -- Get tracked todos
  local tracked = {}
  local todos = db.get_all()
  for _, todo in ipairs(todos) do
    if todo.file_path and todo.line_number then
      local key = todo.file_path .. ":" .. todo.line_number
      tracked[key] = true
    end
  end
  
  -- Filter untracked
  local qf_list = {}
  for _, comment in ipairs(todo_comments) do
    local key = comment.filename .. ":" .. comment.lnum
    if not tracked[key] then
      table.insert(qf_list, {
        filename = comment.filename,
        lnum = comment.lnum,
        col = comment.col or 1,
        text = string.format("[%s] %s", comment.tag, comment.text),
        type = M.tag_to_type(comment.tag),
        valid = 1,
      })
    end
  end
  
  vim.fn.setqflist(qf_list, 'r')
  vim.cmd("copen")
  vim.fn.setqflist({}, 'a', { title = "Todo-MCP: Untracked TODOs" })
  
  return #qf_list
end

-- Convert TODO tag to quickfix type
M.tag_to_type = function(tag)
  local type_map = {
    FIXME = "E",
    FIX = "E",
    HACK = "W",
    TODO = "W",
    PERF = "W",
    NOTE = "I",
    TEST = "I",
  }
  return type_map[tag] or "W"
end

-- Find all TODO comments in project (simplified version)
M.find_all_todo_comments = function()
  local results = {}
  
  -- Use ripgrep to find TODO comments
  local cmd = "rg --no-heading --with-filename --line-number --column " ..
              "'\\b(TODO|FIXME|FIX|HACK|WARN|WARNING|PERF|NOTE|TEST)\\b:?\\s*(.*)' " ..
              vim.fn.getcwd()
  
  local output = vim.fn.systemlist(cmd)
  
  for _, line in ipairs(output) do
    local filename, lnum, col, content = line:match("^(.+):(%d+):(%d+):(.*)$")
    if filename then
      local tag, text = content:match("\\b(TODO|FIXME|FIX|HACK|WARN|WARNING|PERF|NOTE|TEST)\\b:?%s*(.*)$")
      if tag and text then
        table.insert(results, {
          filename = filename,
          lnum = tonumber(lnum),
          col = tonumber(col),
          tag = tag,
          text = text,
        })
      end
    end
  end
  
  return results
end

-- Group todos by file for quickfix
M.by_file_to_quickfix = function()
  local todos = db.get_all()
  local by_file = {}
  
  -- Group by file
  for _, todo in ipairs(todos) do
    if todo.file_path then
      if not by_file[todo.file_path] then
        by_file[todo.file_path] = {}
      end
      table.insert(by_file[todo.file_path], todo)
    end
  end
  
  -- Create quickfix entries
  local qf_list = {}
  for filepath, file_todos in pairs(by_file) do
    -- Sort by line number
    table.sort(file_todos, function(a, b)
      return (a.line_number or 0) < (b.line_number or 0)
    end)
    
    for _, todo in ipairs(file_todos) do
      table.insert(qf_list, {
        filename = filepath,
        lnum = todo.line_number or 1,
        col = 1,
        text = string.format("[%s] %s", 
          string.upper(todo.priority or "medium"), 
          todo.title or "Untitled"
        ),
        type = M.priority_to_type(todo.priority),
        valid = 1,
      })
    end
  end
  
  vim.fn.setqflist(qf_list, 'r')
  vim.cmd("copen")
  vim.fn.setqflist({}, 'a', { title = "Todo-MCP: By File" })
  
  return #qf_list
end

-- Setup quickfix commands
M.setup = function()
  -- Todo quickfix commands
  vim.api.nvim_create_user_command("TodoQuickfix", function(opts)
    local filter = opts.args or "all"
    local count = M.todos_to_quickfix(filter)
    vim.notify(string.format("Found %d todos matching filter: %s", count, filter))
  end, {
    nargs = "?",
    complete = function()
      return { "all", "untracked", "high-priority", "in-progress", "done", "orphaned", "by-file" }
    end,
  })
  
  -- Specific commands
  vim.api.nvim_create_user_command("TodoQuickfixUntracked", function()
    local count = M.untracked_to_quickfix()
    vim.notify(string.format("Found %d untracked TODO comments", count))
  end, {})
  
  vim.api.nvim_create_user_command("TodoQuickfixByFile", function()
    local count = M.by_file_to_quickfix()
    vim.notify(string.format("Organized %d todos by file", count))
  end, {})
  
  -- Quickfix mappings for todo operations
  vim.api.nvim_create_autocmd("FileType", {
    pattern = "qf",
    callback = function()
      -- Only apply to our quickfix lists
      local title = vim.fn.getqflist({ title = 0 }).title
      if not title:match("Todo%-MCP") then return end
      
      local buf = vim.api.nvim_get_current_buf()
      
      -- Track untracked TODO
      vim.keymap.set("n", "t", function()
        local qf_entry = vim.fn.getqflist()[vim.fn.line('.')]
        if qf_entry and qf_entry.valid == 1 then
          -- Check if this is an untracked TODO
          if title:match("Untracked") then
            local todo_comment = {
              file = qf_entry.filename,
              line = qf_entry.lnum,
              text = qf_entry.text:match("%[(.+)%] (.+)$") or qf_entry.text,
              tag = qf_entry.text:match("%[(.+)%]") or "TODO",
            }
            tc_integration.track_todo(todo_comment)
            vim.notify("TODO tracked!", vim.log.levels.INFO)
            
            -- Refresh quickfix
            M.untracked_to_quickfix()
          end
        end
      end, { buffer = buf, desc = "Track TODO" })
      
      -- Toggle done status
      vim.keymap.set("n", "d", function()
        local qf_entry = vim.fn.getqflist()[vim.fn.line('.')]
        if qf_entry and qf_entry.valid == 1 then
          -- Find todo by file and line
          local todos = db.get_all()
          for _, todo in ipairs(todos) do
            if todo.file_path == qf_entry.filename and todo.line_number == qf_entry.lnum then
              db.toggle_done(todo.id)
              vim.notify("TODO status toggled!", vim.log.levels.INFO)
              
              -- Refresh quickfix
              M.todos_to_quickfix("all")
              break
            end
          end
        end
      end, { buffer = buf, desc = "Toggle done" })
      
      -- Show help
      vim.keymap.set("n", "?", function()
        vim.notify("Quickfix mappings: t=track, d=toggle done, <CR>=goto", vim.log.levels.INFO)
      end, { buffer = buf, desc = "Show help" })
    end
  })
end

return M