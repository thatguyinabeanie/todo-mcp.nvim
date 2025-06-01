local telescope = require('telescope')
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local entry_display = require('telescope.pickers.entry_display')

local db = require('todo-mcp.db')
local views = require('todo-mcp.views')

-- Check if todo-comments is available
local has_todo_comments, todo_comments = pcall(require, 'todo-comments')

local M = {}

-- Format todo for telescope entry
local make_entry = function(style)
  return function(todo)
    local displayer = entry_display.create({
      separator = " ",
      items = {
        { width = 3 },  -- Status
        { width = 3 },  -- Priority  
        { remaining = true },  -- Title + metadata
      },
    })

    local function make_display(entry)
      local status_icon = views.get_status_indicator(entry.value, style)
      local priority_icon = views.get_priority_indicator(entry.value, style)
      local metadata = views.format_metadata(entry.value, style)
      
      return displayer({
        status_icon,
        priority_icon,
        entry.value.title .. metadata,
      })
    end

    return {
      value = todo,
      display = make_display,
      ordinal = todo.title .. " " .. (todo.tags or ""),
    }
  end
end

-- Browse all todos
M.todos = function(opts)
  opts = opts or {}
  local style = views.get_style(require('todo-mcp').opts.ui or {})
  
  pickers.new(opts, {
    prompt_title = "Todo List",
    finder = finders.new_dynamic({
      fn = function()
        return db.get_all()
      end,
      entry_maker = make_entry(style),
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          local markdown_ui = require('todo-mcp.markdown-ui')
          markdown_ui.open_todo(selection.value)
        end
      end)
      
      -- Additional mappings
      map('i', '<C-d>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          db.toggle_done(selection.value.id)
          -- Refresh picker
          action_state.get_current_picker(prompt_bufnr):refresh()
        end
      end)
      
      map('i', '<C-x>', function()
        local selection = action_state.get_selected_entry()
        if selection then
          db.delete(selection.value.id)
          -- Refresh picker
          action_state.get_current_picker(prompt_bufnr):refresh()
        end
      end)
      
      return true
    end,
  }):find()
end

-- Show untracked TODO comments from todo-comments.nvim
M.untracked = function(opts)
  if not has_todo_comments then
    vim.notify("todo-comments.nvim not found", vim.log.levels.ERROR)
    return
  end
  
  opts = opts or {}
  
  -- Get all TODO comments from todo-comments
  local todo_results = {}
  todo_comments.search(function(results)
    todo_results = results
  end)
  
  -- Get all tracked todos
  local tracked = {}
  for _, todo in ipairs(db.get_all()) do
    if todo.file_path and todo.line_number then
      local key = todo.file_path .. ":" .. todo.line_number
      tracked[key] = true
    end
  end
  
  -- Filter out already tracked
  local untracked = {}
  for _, result in ipairs(todo_results) do
    local key = result.filename .. ":" .. result.lnum
    if not tracked[key] then
      table.insert(untracked, result)
    end
  end
  
  pickers.new(opts, {
    prompt_title = "Untracked TODOs",
    finder = finders.new_table({
      results = untracked,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%s:%d: %s %s", 
            vim.fn.fnamemodify(entry.filename, ":~:."),
            entry.lnum,
            entry.tag,
            entry.text
          ),
          ordinal = entry.text,
          filename = entry.filename,
          lnum = entry.lnum,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          -- Import this TODO
          local todo_comment = selection.value
          local priority_map = {
            TODO = "medium",
            FIXME = "high",
            FIX = "high",
            HACK = "low",
            PERF = "medium",
            NOTE = "low",
          }
          
          db.add(todo_comment.text, {
            title = todo_comment.text:sub(1, 50),
            priority = priority_map[todo_comment.tag] or "medium",
            tags = string.lower(todo_comment.tag),
            file_path = todo_comment.filename,
            line_number = todo_comment.lnum,
            metadata = vim.json.encode({
              source = "todo-comment",
              original_tag = todo_comment.tag,
            })
          })
          
          vim.notify("Imported: " .. todo_comment.text:sub(1, 30) .. "...")
        end
      end)
      
      return true
    end,
  }):find()
end

-- Setup telescope extension
M.setup = function(ext_config, config)
  -- Setup commands
  vim.api.nvim_create_user_command('TodoMCPTelescope', function(opts)
    local cmd = opts.args
    if cmd == 'todos' then
      M.todos()
    elseif cmd == 'untracked' then
      M.untracked()
    else
      vim.notify("Unknown command: " .. cmd, vim.log.levels.ERROR)
    end
  end, {
    nargs = 1,
    complete = function()
      return { 'todos', 'untracked' }
    end,
  })
end

-- Combined view of tracked and untracked TODOs
M.all = function(opts)
  opts = opts or {}
  local style = views.get_style(require('todo-mcp').opts.ui or {})
  
  -- Get tracked todos
  local tracked = db.get_all()
  
  -- Get untracked TODO comments
  local untracked = {}
  if has_todo_comments then
    local qf_integration = require('todo-mcp.integrations.quickfix')
    local todo_comments = qf_integration.find_all_todo_comments()
    
    -- Filter out tracked ones
    local tracked_map = {}
    for _, todo in ipairs(tracked) do
      if todo.file_path and todo.line_number then
        tracked_map[todo.file_path .. ":" .. todo.line_number] = true
      end
    end
    
    for _, comment in ipairs(todo_comments) do
      local key = comment.filename .. ":" .. comment.lnum
      if not tracked_map[key] then
        table.insert(untracked, {
          type = "untracked",
          file = comment.filename,
          line = comment.lnum,
          tag = comment.tag,
          text = comment.text,
          display_text = "[UNTRACKED] " .. comment.tag .. ": " .. comment.text,
        })
      end
    end
  end
  
  -- Combine both lists
  local all_items = {}
  
  -- Add tracked todos
  for _, todo in ipairs(tracked) do
    table.insert(all_items, {
      type = "tracked",
      todo = todo,
      display_text = views.render_todo_line(todo, style),
    })
  end
  
  -- Add untracked
  for _, item in ipairs(untracked) do
    table.insert(all_items, item)
  end
  
  pickers.new(opts, {
    prompt_title = "All TODOs (Tracked + Untracked)",
    finder = finders.new_table({
      results = all_items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = entry.display_text,
          ordinal = entry.display_text,
          filename = entry.type == "tracked" and entry.todo.file_path or entry.file,
          lnum = entry.type == "tracked" and entry.todo.line_number or entry.line,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
    previewer = conf.file_previewer(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          if selection.value.type == "tracked" then
            -- Open tracked todo
            local markdown_ui = require('todo-mcp.markdown-ui')
            markdown_ui.open_todo(selection.value.todo)
          else
            -- Track untracked todo
            local tc_integration = require('todo-mcp.integrations.todo-comments')
            tc_integration.track_todo({
              file = selection.value.file,
              line = selection.value.line,
              tag = selection.value.tag,
              text = selection.value.text,
            })
            vim.notify("TODO tracked!", vim.log.levels.INFO)
          end
        end
      end)
      
      return true
    end,
  }):find()
end

-- Show orphaned TODOs (tracked but comment removed)
M.orphaned = function(opts)
  opts = opts or {}
  local style = views.get_style(require('todo-mcp').opts.ui or {})
  
  local todos = db.get_all()
  local orphaned = {}
  
  for _, todo in ipairs(todos) do
    local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
    if metadata.orphaned then
      table.insert(orphaned, todo)
    end
  end
  
  pickers.new(opts, {
    prompt_title = "Orphaned TODOs",
    finder = finders.new_table({
      results = orphaned,
      entry_maker = make_entry(style),
    }),
    sorter = conf.generic_sorter(opts),
    attach_mappings = function(prompt_bufnr, map)
      actions.select_default:replace(function()
        actions.close(prompt_bufnr)
        local selection = action_state.get_selected_entry()
        if selection then
          local markdown_ui = require('todo-mcp.markdown-ui')
          markdown_ui.open_todo(selection.value)
        end
      end)
      
      return true
    end,
  }):find()
end

-- Show statistics view
M.stats = function(opts)
  opts = opts or {}
  
  local todos = db.get_all()
  local stats = {
    total = #todos,
    by_status = { todo = 0, in_progress = 0, done = 0 },
    by_priority = { high = 0, medium = 0, low = 0 },
    tracked = 0,
    orphaned = 0,
  }
  
  for _, todo in ipairs(todos) do
    -- Count by status
    local status = todo.status or (todo.done and "done" or "todo")
    stats.by_status[status] = (stats.by_status[status] or 0) + 1
    
    -- Count by priority
    local priority = todo.priority or "medium"
    stats.by_priority[priority] = (stats.by_priority[priority] or 0) + 1
    
    -- Count tracked (has file link)
    if todo.file_path then
      stats.tracked = stats.tracked + 1
    end
    
    -- Count orphaned
    local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
    if metadata.orphaned then
      stats.orphaned = stats.orphaned + 1
    end
  end
  
  -- Create display items
  local items = {
    { category = "Overview", key = "Total TODOs", value = stats.total },
    { category = "Overview", key = "Tracked (linked to code)", value = stats.tracked },
    { category = "Overview", key = "Orphaned", value = stats.orphaned },
    
    { category = "Status", key = "To Do", value = stats.by_status.todo },
    { category = "Status", key = "In Progress", value = stats.by_status.in_progress },
    { category = "Status", key = "Done", value = stats.by_status.done },
    
    { category = "Priority", key = "High", value = stats.by_priority.high },
    { category = "Priority", key = "Medium", value = stats.by_priority.medium },
    { category = "Priority", key = "Low", value = stats.by_priority.low },
  }
  
  pickers.new(opts, {
    prompt_title = "Todo Statistics",
    finder = finders.new_table({
      results = items,
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%-10s %-25s %d", 
            entry.category, entry.key, entry.value),
          ordinal = entry.category .. " " .. entry.key,
        }
      end,
    }),
    sorter = conf.generic_sorter(opts),
  }):find()
end

return telescope.register_extension({
  setup = M.setup,
  exports = {
    todos = M.todos,
    all = M.all,
    untracked = M.untracked,
    orphaned = M.orphaned,
    stats = M.stats,
  },
})