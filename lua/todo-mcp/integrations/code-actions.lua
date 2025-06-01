local M = {}

local db = require('todo-mcp.db')
local tc_integration = require('todo-mcp.integrations.todo-comments')

-- Register code action provider
M.setup = function()
  -- Store original handler
  local original_handler = vim.lsp.handlers["textDocument/codeAction"]
  
  -- Override code action handler
  vim.lsp.handlers["textDocument/codeAction"] = function(err, result, ctx, config)
    if err or not result then
      if original_handler then
        return original_handler(err, result, ctx, config)
      end
      return
    end
    
    -- Check if cursor is on a TODO comment
    local todo_comment = tc_integration.get_todo_at_cursor()
    
    if todo_comment then
      result = result or {}
      
      -- Add our custom actions
      if not tc_integration.is_tracked(todo_comment.file, todo_comment.line) then
        table.insert(result, {
          title = "📝 Track in todo-mcp",
          kind = "quickfix",
          command = {
            title = "Track TODO",
            command = "todo-mcp.track",
            arguments = { todo_comment }
          }
        })
        
        table.insert(result, {
          title = "📝 Track with options...",
          kind = "quickfix",
          command = {
            title = "Track TODO with options",
            command = "todo-mcp.track-with-options",
            arguments = { todo_comment }
          }
        })
      else
        local todo = tc_integration.get_tracked_todo(todo_comment.file, todo_comment.line)
        if todo then
          -- Add status-based actions
          if todo.status ~= "done" then
            table.insert(result, {
              title = "✅ Mark as done",
              kind = "quickfix",
              command = {
                title = "Complete TODO",
                command = "todo-mcp.complete",
                arguments = { todo.id }
              }
            })
            
            if todo.status ~= "in_progress" then
              table.insert(result, {
                title = "🚧 Mark as in progress",
                kind = "quickfix",
                command = {
                  title = "Start TODO",
                  command = "todo-mcp.start",
                  arguments = { todo.id }
                }
              })
            end
          end
          
          table.insert(result, {
            title = "✏️ Edit in todo-mcp",
            kind = "quickfix",
            command = {
              title = "Edit TODO",
              command = "todo-mcp.edit",
              arguments = { todo.id }
            }
          })
          
          table.insert(result, {
            title = "🔗 Show details",
            kind = "quickfix",
            command = {
              title = "Show TODO details",
              command = "todo-mcp.show",
              arguments = { todo.id }
            }
          })
        end
      end
    end
    
    -- Call original handler
    if original_handler then
      return original_handler(err, result, ctx, config)
    end
  end
  
  -- Register commands
  vim.api.nvim_create_user_command("TodoMCPTrack", function()
    local todo_comment = tc_integration.get_todo_at_cursor()
    if todo_comment then
      tc_integration.track_todo(todo_comment)
    else
      vim.notify("No TODO comment found at cursor", vim.log.levels.WARN)
    end
  end, {})
  
  vim.api.nvim_create_user_command("TodoMCPTrackWithOptions", function()
    local todo_comment = tc_integration.get_todo_at_cursor()
    if todo_comment then
      M.track_with_options(todo_comment)
    else
      vim.notify("No TODO comment found at cursor", vim.log.levels.WARN)
    end
  end, {})
  
  -- Register LSP commands
  M.register_lsp_commands()
end

-- Register LSP command handlers
M.register_lsp_commands = function()
  local commands = {
    ["todo-mcp.track"] = function(args)
      local todo_comment = args.arguments[1]
      tc_integration.track_todo(todo_comment)
    end,
    
    ["todo-mcp.track-with-options"] = function(args)
      local todo_comment = args.arguments[1]
      M.track_with_options(todo_comment)
    end,
    
    ["todo-mcp.complete"] = function(args)
      local todo_id = args.arguments[1]
      db.update(todo_id, {
        status = "done",
        done = true,
        completed_at = require('todo-mcp.schema').timestamp()
      })
      vim.notify("TODO #" .. todo_id .. " marked as done", vim.log.levels.INFO)
    end,
    
    ["todo-mcp.start"] = function(args)
      local todo_id = args.arguments[1]
      db.update(todo_id, {
        status = "in_progress",
      })
      vim.notify("TODO #" .. todo_id .. " marked as in progress", vim.log.levels.INFO)
    end,
    
    ["todo-mcp.edit"] = function(args)
      local todo_id = args.arguments[1]
      local todos = db.get_all()
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          require('todo-mcp.markdown-ui').open_todo(todo)
          break
        end
      end
    end,
    
    ["todo-mcp.show"] = function(args)
      local todo_id = args.arguments[1]
      local todos = db.get_all()
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          M.show_todo_details(todo)
          break
        end
      end
    end,
  }
  
  -- Register command executor
  vim.lsp.commands = vim.lsp.commands or {}
  for cmd, handler in pairs(commands) do
    vim.lsp.commands[cmd] = handler
  end
end

-- Track with options
M.track_with_options = function(todo_comment)
  -- Priority selection
  vim.ui.select(
    { "low", "medium", "high" },
    { prompt = "Select priority:" },
    function(priority)
      if not priority then return end
      
      -- Tags input
      vim.ui.input(
        { prompt = "Tags (comma-separated):" },
        function(tags)
          tags = tags or ""
          
          -- Additional notes
          vim.ui.input(
            { prompt = "Additional notes (optional):" },
            function(notes)
              -- Create todo with all options
              local context = tc_integration.detect_context(todo_comment.file)
              
              db.add(todo_comment.text, {
                title = todo_comment.text:sub(1, 50),
                content = notes or todo_comment.text,
                priority = priority,
                tags = string.lower(todo_comment.tag) .. 
                       (tags ~= "" and ("," .. tags) or "") ..
                       (context.tags and ("," .. context.tags) or ""),
                file_path = todo_comment.file,
                line_number = todo_comment.line,
                metadata = vim.json.encode({
                  source = "todo-comment",
                  original_tag = todo_comment.tag,
                  context = context,
                })
              })
              
              -- Update cache and virtual text
              tc_integration.update_cache()
              tc_integration.update_virtual_text(todo_comment.file, todo_comment.line)
              
              vim.notify("TODO tracked with custom options!", vim.log.levels.INFO)
            end
          )
        end
      )
    end
  )
end

-- Show todo details in floating window
M.show_todo_details = function(todo)
  local frontmatter = require('todo-mcp.frontmatter')
  local markdown = frontmatter.todo_to_markdown(todo)
  
  local lines = vim.split(markdown, "\n")
  
  -- Create buffer
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, 'filetype', 'markdown')
  vim.api.nvim_buf_set_option(buf, 'modifiable', false)
  
  -- Calculate window size
  local width = math.min(80, vim.o.columns - 10)
  local height = math.min(#lines + 2, vim.o.lines - 10)
  
  -- Create floating window
  local win = vim.api.nvim_open_win(buf, true, {
    relative = 'editor',
    row = (vim.o.lines - height) / 2,
    col = (vim.o.columns - width) / 2,
    width = width,
    height = height,
    style = 'minimal',
    border = 'rounded',
    title = ' Todo #' .. todo.id .. ' ',
    title_pos = 'center',
  })
  
  -- Close on q or <Esc>
  local close = function()
    vim.api.nvim_win_close(win, true)
  end
  
  vim.keymap.set('n', 'q', close, { buffer = buf })
  vim.keymap.set('n', '<Esc>', close, { buffer = buf })
end

return M