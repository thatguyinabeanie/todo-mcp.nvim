local M = {}

local db = require('todo-mcp.db')
local views = require('todo-mcp.views')

-- Check for available pickers
local has_telescope, telescope = pcall(require, 'telescope')
local has_snacks, snacks = pcall(require, 'snacks')
local has_fzf, fzf = pcall(require, 'fzf-lua')

-- Snacks.nvim picker
M.snacks_picker = function(opts)
  if not has_snacks then
    vim.notify("snacks.nvim not found", vim.log.levels.ERROR)
    return
  end
  
  opts = opts or {}
  local style = views.get_style(require('todo-mcp').opts.ui or {})
  
  local todos = db.get_all()
  local items = {}
  
  for _, todo in ipairs(todos) do
    local status_icon = views.get_status_indicator(todo, style)
    local priority_icon = views.get_priority_indicator(todo, style)
    local metadata = views.format_metadata(todo, style)
    
    table.insert(items, {
      text = string.format("%s %s %s%s", 
        status_icon,
        priority_icon,
        todo.title,
        metadata
      ),
      todo = todo,
    })
  end
  
  snacks.picker({
    title = "📝 Todo List",
    items = items,
    format = function(item)
      return item.text
    end,
    actions = {
      ["<CR>"] = function(item, picker)
        picker:close()
        local markdown_ui = require('todo-mcp.markdown-ui')
        markdown_ui.open_todo(item.todo)
      end,
      ["<C-d>"] = function(item, picker)
        db.toggle_done(item.todo.id)
        picker:refresh()
      end,
      ["<C-x>"] = function(item, picker)
        db.delete(item.todo.id)
        picker:refresh()
      end,
    },
  })
end

-- FZF-Lua picker
M.fzf_picker = function(opts)
  if not has_fzf then
    vim.notify("fzf-lua not found", vim.log.levels.ERROR)
    return
  end
  
  opts = opts or {}
  local style = views.get_style(require('todo-mcp').opts.ui or {})
  
  local todos = db.get_all()
  local entries = {}
  local todo_map = {}
  
  for i, todo in ipairs(todos) do
    local status_icon = views.get_status_indicator(todo, style)
    local priority_icon = views.get_priority_indicator(todo, style)
    local metadata = views.format_metadata(todo, style)
    
    local entry = string.format("%s %s %s%s", 
      status_icon,
      priority_icon,
      todo.title,
      metadata
    )
    
    table.insert(entries, entry)
    todo_map[entry] = todo
  end
  
  local function preview_todo(selected)
    if not selected or #selected == 0 then return end
    local todo = todo_map[selected[1]]
    if not todo then return end
    
    -- Generate preview content
    local lines = {}
    local frontmatter = require('todo-mcp.frontmatter')
    local markdown = frontmatter.todo_to_markdown(todo)
    
    for line in markdown:gmatch("[^\n]+") do
      table.insert(lines, line)
    end
    
    return lines
  end
  
  fzf.fzf_exec(entries, {
    prompt = "Todos> ",
    preview = preview_todo,
    actions = {
      ["default"] = function(selected)
        if not selected or #selected == 0 then return end
        local todo = todo_map[selected[1]]
        if todo then
          local markdown_ui = require('todo-mcp.markdown-ui')
          markdown_ui.open_todo(todo)
        end
      end,
      ["ctrl-d"] = function(selected)
        if not selected or #selected == 0 then return end
        local todo = todo_map[selected[1]]
        if todo then
          db.toggle_done(todo.id)
          -- Refresh picker
          M.fzf_picker(opts)
        end
      end,
      ["ctrl-x"] = function(selected)
        if not selected or #selected == 0 then return end
        local todo = todo_map[selected[1]]
        if todo then
          local confirm = vim.fn.confirm("Delete todo: " .. todo.title .. "?", "&Yes\n&No", 2)
          if confirm == 1 then
            db.delete(todo.id)
            -- Refresh picker
            M.fzf_picker(opts)
          end
        end
      end,
      ["ctrl-a"] = function()
        vim.ui.input({ prompt = "New todo: " }, function(input)
          if input and input ~= "" then
            db.add(input)
            -- Refresh picker
            M.fzf_picker(opts)
          end
        end)
      end,
    },
    winopts = {
      height = 0.85,
      width = 0.80,
      preview = {
        layout = 'vertical',
        vertical = 'up:45%',
      },
    },
  })
end

-- Integration with todo-comments
M.import_from_todo_comments = function()
  local has_todo_comments, todo_comments = pcall(require, 'todo-comments')
  if not has_todo_comments then
    vim.notify("todo-comments.nvim not found", vim.log.levels.ERROR)
    return
  end
  
  -- Use todo-comments search functionality
  local search_opts = {
    keywords = { "TODO", "FIXME", "FIX", "HACK", "WARN", "PERF", "NOTE" },
  }
  
  -- This is a simplified version - actual implementation would need
  -- to hook into todo-comments properly
  vim.notify("Scanning for TODO comments...", vim.log.levels.INFO)
  
  local priority_map = {
    TODO = "medium",
    FIXME = "high",
    FIX = "high",
    HACK = "low",
    WARN = "high",
    PERF = "medium",
    NOTE = "low",
  }
  
  -- Get project root
  local root = vim.fn.getcwd()
  
  -- Use ripgrep to find TODO comments (similar to todo-comments)
  local cmd = string.format(
    "rg --no-heading --with-filename --line-number --column --smart-case '%s' '%s'",
    "\\b(TODO|FIXME|FIX|HACK|WARN|PERF|NOTE)\\b.{0,}:",
    root
  )
  
  local results = vim.fn.systemlist(cmd)
  local imported = 0
  
  for _, line in ipairs(results) do
    local filename, lnum, col, text = line:match("^(.+):(%d+):(%d+):(.*)$")
    if filename then
      local tag, content = text:match("\\b(TODO|FIXME|FIX|HACK|WARN|PERF|NOTE)\\b:?%s*(.*)$")
      if tag and content then
        -- Check if already tracked
        local existing = db.search(content:sub(1, 50), {
          file_path = filename,
          line_number = tonumber(lnum)
        })
        
        if #existing == 0 then
          db.add(content, {
            title = content:sub(1, 50),
            priority = priority_map[tag] or "medium",
            tags = string.lower(tag),
            file_path = filename,
            line_number = tonumber(lnum),
            metadata = vim.json.encode({
              source = "todo-comment",
              original_tag = tag,
              imported_at = os.date("%Y-%m-%d %H:%M:%S"),
            })
          })
          imported = imported + 1
        end
      end
    end
  end
  
  vim.notify(string.format("Imported %d new TODOs from code comments", imported), vim.log.levels.INFO)
end

-- Smart picker that uses available picker
M.open = function(opts)
  opts = opts or {}
  
  -- Check user preference
  local preferred = opts.picker or require('todo-mcp').opts.picker
  
  -- Try preferred picker first
  if preferred == "telescope" and has_telescope then
    require('telescope').extensions.todo_mcp.todos(opts)
  elseif preferred == "fzf" and has_fzf then
    M.fzf_picker(opts)
  elseif preferred == "snacks" and has_snacks then
    M.snacks_picker(opts)
  else
    -- Auto-detect available picker
    if has_telescope then
      require('telescope').extensions.todo_mcp.todos(opts)
    elseif has_fzf then
      M.fzf_picker(opts)
    elseif has_snacks then
      M.snacks_picker(opts)
    else
      -- Fallback to built-in UI
      require('todo-mcp.ui').toggle()
    end
  end
end

-- Register commands for different pickers
M.setup = function()
  -- Picker commands
  vim.api.nvim_create_user_command('TodoPicker', function(cmd)
    M.open({ picker = cmd.args })
  end, {
    nargs = '?',
    complete = function()
      return { 'telescope', 'fzf', 'snacks' }
    end,
  })
  
  -- Import command
  vim.api.nvim_create_user_command('TodoImport', function()
    M.import_from_todo_comments()
  end, {})
end

return M