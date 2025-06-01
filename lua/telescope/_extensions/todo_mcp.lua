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

return telescope.register_extension({
  setup = M.setup,
  exports = {
    todos = M.todos,
    untracked = M.untracked,
  },
})