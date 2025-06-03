local M = {}

local db = require('todo-mcp.db')
local has_todo_comments, todo_comments = pcall(require, 'todo-comments')

-- Cache for tracked todos by file:line
local tracked_cache = {}
local ns_id = vim.api.nvim_create_namespace('todo_mcp_tracking')

-- Priority mapping
M.priority_map = {
  TODO = "medium",
  FIXME = "high",
  FIX = "high",
  HACK = "low",
  WARN = "high",
  WARNING = "high",
  PERF = "medium",
  NOTE = "low",
  TEST = "low",
}

-- Update tracking cache
M.update_cache = function()
  tracked_cache = {}
  local todos = db.get_all()
  
  for _, todo in ipairs(todos) do
    if todo.file_path and todo.line_number then
      local key = todo.file_path .. ":" .. todo.line_number
      tracked_cache[key] = todo
    end
  end
end

-- Get TODO comment at cursor position
M.get_todo_at_cursor = function()
  if not has_todo_comments then return nil end
  
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local bufnr = vim.api.nvim_get_current_buf()
  local filename = vim.api.nvim_buf_get_name(bufnr)
  
  -- Get line content
  local line_content = vim.api.nvim_buf_get_lines(bufnr, line - 1, line, false)[1]
  if not line_content then return nil end
  
  -- Check if line contains TODO pattern
  local pattern = "\\b(TODO|FIXME|FIX|HACK|WARN|WARNING|PERF|NOTE|TEST)\\b:?%s*(.*)$"
  local tag, text = line_content:match(pattern)
  
  if tag and text then
    return {
      file = filename,
      line = line,
      tag = tag,
      text = text,
      full_line = line_content,
    }
  end
  
  return nil
end

-- Check if TODO is tracked
M.is_tracked = function(file, line)
  local key = file .. ":" .. line
  return tracked_cache[key] ~= nil
end

-- Get tracked todo info
M.get_tracked_todo = function(file, line)
  local key = file .. ":" .. line
  return tracked_cache[key]
end

-- Track a TODO comment
M.track_todo = function(todo_comment)
  if not todo_comment then return end
  
  local priority = M.priority_map[todo_comment.tag] or "medium"
  
  -- Smart context detection
  local context = M.detect_context(todo_comment.file)
  
  -- Enhanced AI context detection and estimation
  local ai_insights = nil
  if M.config.ai_enhanced then
    local ai_context = require('todo-mcp.ai.context')
    local ai_estimation = require('todo-mcp.ai.estimation')
    
    -- Get surrounding lines for better context
    local surrounding_lines = M.get_surrounding_lines(todo_comment.file, todo_comment.line)
    
    -- Enhanced context detection
    local enhanced_context = ai_context.detect_enhanced_context(
      todo_comment.file,
      todo_comment.full_line,
      surrounding_lines
    )
    
    -- AI-powered estimation
    ai_insights = ai_estimation.enhance_with_ai_estimation({
      text = todo_comment.text,
      file_path = todo_comment.file,
      line_number = todo_comment.line,
      surrounding_lines = surrounding_lines
    }, enhanced_context)
    
    -- Use AI priority if confidence is high enough
    if ai_insights.confidence_score > 70 then
      priority = ai_insights.ai_priority
    end
    
    -- Merge contexts
    context = vim.tbl_extend("force", context, enhanced_context)
  end
  
  local todo_id = db.add(todo_comment.text, {
    title = todo_comment.text:sub(1, 50),
    priority = priority,
    tags = string.lower(todo_comment.tag) .. (context.tags and ("," .. context.tags) or "") ..
           (context.smart_tags and ("," .. table.concat(context.smart_tags, ",")) or ""),
    file_path = todo_comment.file,
    line_number = todo_comment.line,
    metadata = ai_insights and ai_insights.updated_metadata or vim.json.encode({
      source = "todo-comment",
      original_tag = todo_comment.tag,
      context = context,
    })
  })
  
  -- Update cache
  M.update_cache()
  
  -- Update virtual text
  M.update_virtual_text(todo_comment.file, todo_comment.line)
  
  return todo_id
end

-- Smart context detection using Neovim's filetype
M.detect_context = function(filepath)
  local context = {}
  
  -- Use Neovim's filetype detection
  local filetype = vim.filetype.match({ filename = filepath }) or "unknown"
  context.filetype = filetype
  
  -- Auto-generate tags based on common filetype patterns
  -- This is more flexible and works with any language Neovim knows about
  local tags = {}
  
  -- Detect category based on filetype
  if filetype:match("javascript") or filetype:match("typescript") or 
     filetype:match("vue") or filetype:match("react") or
     filetype:match("html") or filetype:match("css") then
    table.insert(tags, "frontend")
  elseif filetype:match("python") or filetype:match("ruby") or
         filetype:match("go") or filetype:match("rust") or
         filetype:match("java") or filetype:match("cpp") or
         filetype:match("c$") then
    table.insert(tags, "backend")
  elseif filetype:match("lua") or filetype:match("vim") or
         filetype:match("json") or filetype:match("yaml") or
         filetype:match("toml") then
    table.insert(tags, "config")
  elseif filetype:match("markdown") or filetype:match("text") or
         filetype:match("rst") then
    table.insert(tags, "docs")
  end
  
  -- Add the filetype itself as a tag
  table.insert(tags, filetype)
  
  -- Check if it's a test file
  if filepath:match("test") or filepath:match("spec") then
    table.insert(tags, "test")
  end
  
  context.tags = table.concat(tags, ",")
  
  -- Detect by directory
  local dir = vim.fn.fnamemodify(filepath, ":h:t")
  local dir_tags = {
    components = "component",
    api = "api",
    utils = "utility",
    helpers = "utility",
    models = "model",
    controllers = "controller",
    views = "view",
    tests = "test",
    spec = "test",
    docs = "documentation",
  }
  
  if dir_tags[dir] then
    context.tags = (context.tags and (context.tags .. ",") or "") .. dir_tags[dir]
  end
  
  context.directory = dir
  
  -- Git context
  local git_branch = vim.fn.system("git branch --show-current 2>/dev/null"):gsub("\n", "")
  if git_branch ~= "" then
    context.git_branch = git_branch
    
    -- Add branch-based tags
    if git_branch:match("^feature/") then
      context.tags = (context.tags and (context.tags .. ",") or "") .. "feature"
    elseif git_branch:match("^fix/") or git_branch:match("^hotfix/") then
      context.tags = (context.tags and (context.tags .. ",") or "") .. "bugfix"
    end
  end
  
  return context
end

-- Update virtual text for a line
M.update_virtual_text = function(file, line)
  local bufnr = vim.fn.bufnr(file)
  if bufnr == -1 then return end
  
  -- Clear existing virtual text
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, line - 1, line)
  
  local todo = M.get_tracked_todo(file, line)
  if todo then
    local virt_text = {}
    
    -- Status indicator
    local status_map = {
      todo = {"○", "TodoCommentUntracked"},
      in_progress = {"◐", "TodoCommentInProgress"},
      done = {"✓", "TodoCommentDone"},
    }
    
    local status = todo.status or "todo"
    local indicator, hl = unpack(status_map[status] or status_map.todo)
    
    table.insert(virt_text, {" [" .. indicator .. " #" .. todo.id .. "]", hl})
    
    -- Add priority if high
    if todo.priority == "high" then
      table.insert(virt_text, {" !", "TodoPriorityHigh"})
    end
    
    vim.api.nvim_buf_set_extmark(bufnr, ns_id, line - 1, 0, {
      virt_text = virt_text,
      virt_text_pos = "eol",
    })
  end
end

-- Setup autocmds and highlights
M.setup = function()
  -- Define highlight groups
  vim.api.nvim_set_hl(0, "TodoCommentTracked", { fg = "#00ff00" })
  vim.api.nvim_set_hl(0, "TodoCommentUntracked", { fg = "#ff9900" })
  vim.api.nvim_set_hl(0, "TodoCommentInProgress", { fg = "#00ffff" })
  vim.api.nvim_set_hl(0, "TodoCommentDone", { fg = "#888888", italic = true })
  
  -- Initial cache update
  M.update_cache()
  
  -- Auto-update cache when todos change
  vim.api.nvim_create_autocmd("User", {
    pattern = "TodoMCPChanged",
    callback = M.update_cache,
  })
  
  -- Track cursor position
  local last_todo = nil
  vim.api.nvim_create_autocmd("CursorHold", {
    callback = function()
      local todo = M.get_todo_at_cursor()
      if todo and not vim.deep_equal(todo, last_todo) then
        last_todo = todo
        
        if not M.is_tracked(todo.file, todo.line) then
          -- Show floating preview
          M.show_tracking_prompt(todo)
        else
          -- Show tracked info
          M.show_tracked_info(todo)
        end
      else
        last_todo = nil
      end
    end
  })
  
  -- Update virtual text on buffer enter
  vim.api.nvim_create_autocmd("BufEnter", {
    callback = function(args)
      local bufnr = args.buf
      local filename = vim.api.nvim_buf_get_name(bufnr)
      
      -- Update all TODO lines in buffer
      vim.schedule(function()
        M.update_buffer_virtual_text(bufnr, filename)
      end)
    end
  })
  
  -- Sync on file write
  vim.api.nvim_create_autocmd("BufWritePost", {
    callback = function(args)
      if M.config.auto_sync then
        M.sync_file(args.file)
      end
    end
  })
end

-- Show tracking prompt
M.show_tracking_prompt = function(todo)
  local lines = {
    "╭─ Untracked TODO ──────────────╮",
    "│ " .. todo.tag .. ": " .. todo.text:sub(1, 30) .. " │",
    "│                               │",
    "│ Track this TODO? (y/n)        │",
    "╰───────────────────────────────╯",
  }
  
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  
  local width = 35
  local height = 5
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "cursor",
    row = 1,
    col = 0,
    width = width,
    height = height,
    style = "minimal",
    border = "none",
  })
  
  -- Auto-close after delay
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end, 3000)
  
  -- Set up keymaps for response
  vim.keymap.set("n", "y", function()
    M.track_todo(todo)
    vim.api.nvim_win_close(win, true)
    vim.notify("TODO tracked!", vim.log.levels.INFO)
  end, { buffer = buf })
  
  vim.keymap.set("n", "n", function()
    vim.api.nvim_win_close(win, true)
  end, { buffer = buf })
end

-- Show tracked info
M.show_tracked_info = function(todo_comment)
  local todo = M.get_tracked_todo(todo_comment.file, todo_comment.line)
  if not todo then return end
  
  local status_emoji = {
    todo = "📋",
    in_progress = "🚧",
    done = "✅"
  }
  
  local info = string.format(
    "%s TODO #%d | %s | Priority: %s",
    status_emoji[todo.status] or "📋",
    todo.id,
    todo.status or "todo",
    todo.priority or "medium"
  )
  
  vim.notify(info, vim.log.levels.INFO)
end

-- Update all virtual text in buffer
M.update_buffer_virtual_text = function(bufnr, filename)
  -- Clear all virtual text first
  vim.api.nvim_buf_clear_namespace(bufnr, ns_id, 0, -1)
  
  -- Get all lines
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  
  -- Check each line for TODO patterns
  local pattern = "\\b(TODO|FIXME|FIX|HACK|WARN|WARNING|PERF|NOTE|TEST)\\b:?%s*(.*)$"
  
  for i, line in ipairs(lines) do
    local tag, text = line:match(pattern)
    if tag and text then
      M.update_virtual_text(filename, i)
    end
  end
end

-- Sync file with database
M.sync_file = function(filepath)
  -- Find all TODOs in file
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr == -1 then return end
  
  local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
  local pattern = "\\b(TODO|FIXME|FIX|HACK|WARN|WARNING|PERF|NOTE|TEST)\\b:?%s*(.*)$"
  
  local found_todos = {}
  for i, line in ipairs(lines) do
    local tag, text = line:match(pattern)
    if tag and text then
      found_todos[filepath .. ":" .. i] = {
        file = filepath,
        line = i,
        tag = tag,
        text = text,
      }
    end
  end
  
  -- Check tracked todos for this file
  local todos = db.get_all()
  for _, todo in ipairs(todos) do
    if todo.file_path == filepath and todo.line_number then
      local key = filepath .. ":" .. todo.line_number
      
      if not found_todos[key] then
        -- TODO was removed from code
        M.handle_removed_todo(todo)
      else
        -- TODO still exists, check if text changed
        local current = found_todos[key]
        if current.text ~= todo.title then
          -- Update todo text
          db.update(todo.id, {
            title = current.text:sub(1, 50),
            content = current.text,
          })
        end
      end
    end
  end
end

-- Handle removed TODO
M.handle_removed_todo = function(todo)
  if M.config.on_remove == "complete" then
    -- Auto-complete the todo
    db.update(todo.id, {
      status = "done",
      completed_at = require('todo-mcp.schema').timestamp(),
      metadata = vim.json.encode(vim.tbl_extend("force",
        vim.json.decode(todo.metadata or "{}"),
        { auto_completed = true, reason = "comment_removed" }
      ))
    })
  elseif M.config.on_remove == "orphan" then
    -- Mark as orphaned
    db.update(todo.id, {
      metadata = vim.json.encode(vim.tbl_extend("force",
        vim.json.decode(todo.metadata or "{}"),
        { orphaned = true, orphaned_at = os.date("%Y-%m-%d %H:%M:%S") }
      ))
    })
    vim.notify("TODO #" .. todo.id .. " is now orphaned (comment removed)", vim.log.levels.WARN)
  end
end

-- Get surrounding lines for context analysis
M.get_surrounding_lines = function(filepath, line_number)
  local bufnr = vim.fn.bufnr(filepath)
  if bufnr == -1 then
    -- File not loaded, try to read from disk
    local lines = vim.fn.readfile(filepath)
    if not lines then return {} end
    
    local start_line = math.max(1, line_number - 5)
    local end_line = math.min(#lines, line_number + 5)
    local surrounding = {}
    
    for i = start_line, end_line do
      if i ~= line_number then -- Exclude the TODO line itself
        table.insert(surrounding, lines[i])
      end
    end
    
    return surrounding
  end
  
  -- File is loaded in buffer
  local start_line = math.max(0, line_number - 6)
  local end_line = math.min(vim.api.nvim_buf_line_count(bufnr), line_number + 4)
  local lines = vim.api.nvim_buf_get_lines(bufnr, start_line, end_line, false)
  
  -- Remove the TODO line itself
  table.remove(lines, 6) -- The TODO line is at index 6 (middle of the 11 lines)
  
  return lines
end

-- Configuration
M.config = {
  auto_sync = true,
  on_remove = "orphan", -- "complete" | "orphan" | "ignore"
  show_virtual_text = true,
  show_prompts = true,
  ai_enhanced = true, -- Enable AI-powered context and estimation
}

return M