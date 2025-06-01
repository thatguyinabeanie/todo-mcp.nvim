local M = {}

local db = require('todo-mcp.db')
local json = vim.json

-- Team synchronization for enterprise environments
M.config = {
  enabled = false,
  sync_server = nil, -- URL to team sync server
  team_id = nil,
  user_id = nil,
  auth_token = nil,
  sync_interval = 300, -- 5 minutes
  conflict_resolution = "manual", -- "manual" | "server_wins" | "local_wins" | "latest_wins"
  auto_assign = true, -- Auto-assign TODOs based on file ownership
  notifications = true
}

-- Sync state management
local sync_state = {
  last_sync = 0,
  in_progress = false,
  conflicts = {},
  pending_changes = {}
}

-- Initialize team sync
M.setup = function(config)
  M.config = vim.tbl_extend("force", M.config, config or {})
  
  if not M.config.enabled then
    return
  end
  
  -- Start periodic sync if configured
  if M.config.sync_interval > 0 then
    M.start_periodic_sync()
  end
  
  -- Setup change tracking
  M.setup_change_tracking()
  
  -- Setup commands
  M.setup_commands()
end

-- Sync with team server
M.sync_with_team = function()
  if sync_state.in_progress then
    vim.notify("Sync already in progress", vim.log.levels.WARN)
    return
  end
  
  sync_state.in_progress = true
  
  local success, result = pcall(M.perform_sync)
  
  if success then
    sync_state.last_sync = os.time()
    vim.notify(string.format("Team sync completed: %s", result.summary), vim.log.levels.INFO)
  else
    vim.notify("Team sync failed: " .. result, vim.log.levels.ERROR)
  end
  
  sync_state.in_progress = false
end

-- Perform the actual sync operation
M.perform_sync = function()
  -- Get local changes since last sync
  local local_changes = M.get_local_changes_since(sync_state.last_sync)
  
  -- Send changes to server and get remote changes
  local sync_request = {
    team_id = M.config.team_id,
    user_id = M.config.user_id,
    last_sync = sync_state.last_sync,
    local_changes = local_changes
  }
  
  local remote_response = M.send_sync_request(sync_request)
  
  if not remote_response then
    error("Failed to communicate with sync server")
  end
  
  -- Apply remote changes
  local conflicts = M.apply_remote_changes(remote_response.remote_changes)
  
  -- Handle conflicts if any
  if #conflicts > 0 then
    sync_state.conflicts = conflicts
    M.handle_conflicts(conflicts)
  end
  
  return {
    summary = string.format("%d sent, %d received, %d conflicts", 
      #local_changes, #remote_response.remote_changes, #conflicts),
    conflicts = conflicts
  }
end

-- Get local changes since timestamp
M.get_local_changes_since = function(since_timestamp)
  local todos = db.get_all()
  local changes = {}
  
  for _, todo in ipairs(todos) do
    local updated_at = M.parse_timestamp(todo.updated_at)
    
    if updated_at > since_timestamp then
      table.insert(changes, {
        type = "update",
        todo_id = todo.id,
        todo = todo,
        timestamp = updated_at,
        user_id = M.config.user_id
      })
    end
  end
  
  return changes
end

-- Apply remote changes to local database
M.apply_remote_changes = function(remote_changes)
  local conflicts = {}
  
  for _, change in ipairs(remote_changes) do
    local result = M.apply_single_change(change)
    
    if result.conflict then
      table.insert(conflicts, result.conflict)
    end
  end
  
  return conflicts
end

-- Apply a single remote change
M.apply_single_change = function(change)
  if change.type == "create" then
    return M.apply_remote_create(change)
  elseif change.type == "update" then
    return M.apply_remote_update(change)
  elseif change.type == "delete" then
    return M.apply_remote_delete(change)
  end
  
  return { success = false, error = "Unknown change type" }
end

-- Apply remote todo creation
M.apply_remote_create = function(change)
  local remote_todo = change.todo
  
  -- Check if todo already exists (by external ID or file+line)
  local existing = M.find_conflicting_todo(remote_todo)
  
  if existing then
    return {
      conflict = {
        type = "create_conflict",
        local_todo = existing,
        remote_todo = remote_todo,
        change = change
      }
    }
  end
  
  -- Create new todo with team metadata
  local metadata = remote_todo.metadata and json.decode(remote_todo.metadata) or {}
  metadata.team_sync = {
    remote_id = remote_todo.id,
    created_by = change.user_id,
    team_id = M.config.team_id
  }
  
  local new_todo = vim.tbl_extend("force", remote_todo, {
    metadata = json.encode(metadata)
  })
  
  db.add(new_todo.content, new_todo)
  
  return { success = true }
end

-- Apply remote todo update
M.apply_remote_update = function(change)
  local remote_todo = change.todo
  local local_todo = M.find_local_todo_by_remote_id(remote_todo.id)
  
  if not local_todo then
    -- Remote todo doesn't exist locally, treat as create
    return M.apply_remote_create(change)
  end
  
  -- Check for conflicts
  local local_updated = M.parse_timestamp(local_todo.updated_at)
  local remote_updated = M.parse_timestamp(remote_todo.updated_at)
  
  if local_updated > change.timestamp then
    return {
      conflict = {
        type = "update_conflict",
        local_todo = local_todo,
        remote_todo = remote_todo,
        change = change
      }
    }
  end
  
  -- Apply update
  local updates = {}
  for key, value in pairs(remote_todo) do
    if key ~= "id" and local_todo[key] ~= value then
      updates[key] = value
    end
  end
  
  if next(updates) then
    db.update(local_todo.id, updates)
  end
  
  return { success = true }
end

-- Team assignment features
M.assign_todo = function(todo_id, user_id, user_name)
  local metadata = M.get_todo_metadata(todo_id)
  
  metadata.assignment = {
    user_id = user_id,
    user_name = user_name,
    assigned_at = os.date("%Y-%m-%d %H:%M:%S"),
    assigned_by = M.config.user_id
  }
  
  db.update(todo_id, {
    metadata = json.encode(metadata)
  })
  
  -- Notify team if enabled
  if M.config.notifications then
    M.send_team_notification({
      type = "todo_assigned",
      todo_id = todo_id,
      assigned_to = user_id,
      assigned_by = M.config.user_id
    })
  end
end

-- Auto-assign based on file ownership
M.auto_assign_by_file_ownership = function(todo)
  if not M.config.auto_assign then
    return
  end
  
  if not todo.file_path then
    return
  end
  
  -- Get git blame for the line
  local owner = M.get_file_line_owner(todo.file_path, todo.line_number)
  
  if owner and owner ~= M.config.user_id then
    M.assign_todo(todo.id, owner.user_id, owner.user_name)
  end
end

-- Get file line owner from git blame
M.get_file_line_owner = function(filepath, line_number)
  if not line_number then
    return nil
  end
  
  local cmd = string.format("git blame -L %d,%d --porcelain %s", 
    line_number, line_number, vim.fn.shellescape(filepath))
  
  local output = vim.fn.system(cmd)
  
  if vim.v.shell_error ~= 0 then
    return nil
  end
  
  -- Parse git blame output
  local author_mail = output:match("author%-mail <(.-)>")
  local author_name = output:match("author (.-)\n")
  
  if author_mail then
    return {
      user_id = author_mail,
      user_name = author_name or author_mail,
      email = author_mail
    }
  end
  
  return nil
end

-- Team communication features
M.add_comment = function(todo_id, comment_text)
  local metadata = M.get_todo_metadata(todo_id)
  
  if not metadata.comments then
    metadata.comments = {}
  end
  
  table.insert(metadata.comments, {
    text = comment_text,
    user_id = M.config.user_id,
    timestamp = os.date("%Y-%m-%d %H:%M:%S")
  })
  
  db.update(todo_id, {
    metadata = json.encode(metadata)
  })
  
  -- Sync comment to team
  M.sync_comment_to_team(todo_id, comment_text)
end

-- Team notifications
M.send_team_notification = function(notification)
  if not M.config.sync_server then
    return
  end
  
  local payload = {
    team_id = M.config.team_id,
    notification = notification,
    from_user = M.config.user_id,
    timestamp = os.time()
  }
  
  M.send_async_request(M.config.sync_server .. "/notifications", payload)
end

-- Conflict resolution
M.handle_conflicts = function(conflicts)
  if M.config.conflict_resolution == "server_wins" then
    M.resolve_conflicts_server_wins(conflicts)
  elseif M.config.conflict_resolution == "local_wins" then
    M.resolve_conflicts_local_wins(conflicts)
  elseif M.config.conflict_resolution == "latest_wins" then
    M.resolve_conflicts_latest_wins(conflicts)
  else
    M.show_conflict_resolution_ui(conflicts)
  end
end

-- Show interactive conflict resolution
M.show_conflict_resolution_ui = function(conflicts)
  local lines = { "# Sync Conflicts", "" }
  
  for i, conflict in ipairs(conflicts) do
    table.insert(lines, string.format("## Conflict %d: %s", i, conflict.type))
    table.insert(lines, "")
    
    if conflict.local_todo then
      table.insert(lines, "**Local version:**")
      table.insert(lines, "- " .. (conflict.local_todo.title or "Untitled"))
      table.insert(lines, "- Priority: " .. (conflict.local_todo.priority or "medium"))
      table.insert(lines, "- Updated: " .. (conflict.local_todo.updated_at or "unknown"))
    end
    
    if conflict.remote_todo then
      table.insert(lines, "")
      table.insert(lines, "**Remote version:**")
      table.insert(lines, "- " .. (conflict.remote_todo.title or "Untitled"))
      table.insert(lines, "- Priority: " .. (conflict.remote_todo.priority or "medium"))
      table.insert(lines, "- Updated: " .. (conflict.remote_todo.updated_at or "unknown"))
    end
    
    table.insert(lines, "")
    table.insert(lines, "**Resolution options:**")
    table.insert(lines, "- [l] Keep local version")
    table.insert(lines, "- [r] Use remote version")
    table.insert(lines, "- [m] Merge both versions")
    table.insert(lines, "")
  end
  
  M.show_conflict_window(lines, conflicts)
end

-- Helper functions
M.get_todo_metadata = function(todo_id)
  local todos = db.get_all()
  
  for _, todo in ipairs(todos) do
    if todo.id == todo_id then
      return todo.metadata and json.decode(todo.metadata) or {}
    end
  end
  
  return {}
end

M.parse_timestamp = function(timestamp_str)
  if not timestamp_str then
    return 0
  end
  
  -- Simple timestamp parsing (assuming ISO format)
  local year, month, day, hour, min, sec = timestamp_str:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
  
  if year then
    return os.time({
      year = tonumber(year),
      month = tonumber(month),
      day = tonumber(day),
      hour = tonumber(hour),
      min = tonumber(min),
      sec = tonumber(sec)
    })
  end
  
  return 0
end

M.start_periodic_sync = function()
  local timer = vim.loop.new_timer()
  
  timer:start(M.config.sync_interval * 1000, M.config.sync_interval * 1000, function()
    vim.schedule(function()
      if not sync_state.in_progress then
        M.sync_with_team()
      end
    end)
  end)
end

-- Setup commands
M.setup_commands = function()
  vim.api.nvim_create_user_command("TodoTeamSync", function()
    M.sync_with_team()
  end, {})
  
  vim.api.nvim_create_user_command("TodoAssign", function(opts)
    local parts = vim.split(opts.args, " ", { plain = true })
    local todo_id = tonumber(parts[1])
    local user_id = parts[2]
    local user_name = parts[3] or user_id
    
    if todo_id and user_id then
      M.assign_todo(todo_id, user_id, user_name)
      vim.notify(string.format("Assigned TODO #%d to %s", todo_id, user_name), vim.log.levels.INFO)
    else
      vim.notify("Usage: TodoAssign <todo_id> <user_id> [user_name]", vim.log.levels.ERROR)
    end
  end, { nargs = "+" })
  
  vim.api.nvim_create_user_command("TodoComment", function(opts)
    local parts = vim.split(opts.args, " ", { plain = true, trimempty = true })
    local todo_id = tonumber(parts[1])
    local comment = table.concat(parts, " ", 2)
    
    if todo_id and comment ~= "" then
      M.add_comment(todo_id, comment)
      vim.notify("Comment added to TODO #" .. todo_id, vim.log.levels.INFO)
    else
      vim.notify("Usage: TodoComment <todo_id> <comment text>", vim.log.levels.ERROR)
    end
  end, { nargs = "+" })
end

return M