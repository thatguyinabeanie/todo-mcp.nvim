local M = {}

local db = require('todo-mcp.db')
local mcp = require('todo-mcp.mcp')

-- Available external integrations
M.INTEGRATIONS = {
  linear = {
    name = "Linear",
    description = "Modern issue tracking for dev teams",
    server = "linear",
    create_tool = "create_linear_issue",
    update_tool = "update_linear_issue",
    status_field = "issue_id"
  },
  github = {
    name = "GitHub Issues", 
    description = "GitHub issue tracker",
    server = "github",
    create_tool = "create_github_issue",
    update_tool = "update_github_issue",
    status_field = "issue_number"
  },
  jira = {
    name = "JIRA",
    description = "Enterprise issue tracking",
    server = "jira",
    create_tool = "create_jira_issue", 
    update_tool = "update_jira_issue",
    status_field = "jira_key"
  }
}

-- Create external issue from todo
M.create_external_issue = function(todo_id, integration_name)
  local integration = M.INTEGRATIONS[integration_name]
  if not integration then
    return nil, "Unknown integration: " .. integration_name
  end
  
  -- Get todo data
  local todos = db.get_all()
  local todo = nil
  for _, t in ipairs(todos) do
    if t.id == todo_id then
      todo = t
      break
    end
  end
  
  if not todo then
    return nil, "Todo not found: " .. todo_id
  end
  
  -- Check if already linked
  local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
  if metadata[integration.status_field] then
    return nil, "Todo already linked to " .. integration.name .. ": " .. metadata[integration.status_field]
  end
  
  -- Call MCP server
  local result, err = mcp.call_tool(integration.server, integration.create_tool, {
    title = todo.title,
    content = todo.content,
    priority = todo.priority,
    tags = todo.tags,
    file_path = todo.file_path,
    line_number = todo.line_number,
    metadata = todo.metadata
  })
  
  if err then
    return nil, err
  end
  
  if not result.success then
    return nil, result.error or "Failed to create external issue"
  end
  
  -- Update todo with external reference
  local updated_metadata = vim.tbl_extend("force", metadata, {
    [integration.status_field] = result.issue.number or result.issue.identifier or result.issue.id,
    [integration_name .. "_url"] = result.issue.url,
    [integration_name .. "_created"] = os.date("%Y-%m-%d %H:%M:%S"),
    external_sync = true
  })
  
  db.update(todo_id, {
    metadata = vim.json.encode(updated_metadata)
  })
  
  return result.issue
end

-- Update external issue status
M.sync_external_status = function(todo_id, new_status)
  local todos = db.get_all()
  local todo = nil
  for _, t in ipairs(todos) do
    if t.id == todo_id then
      todo = t
      break
    end
  end
  
  if not todo then
    return nil, "Todo not found"
  end
  
  local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
  if not metadata.external_sync then
    return nil, "Todo not synced with external system"
  end
  
  local results = {}
  
  -- Sync with all linked external systems
  for integration_name, integration in pairs(M.INTEGRATIONS) do
    local external_id = metadata[integration.status_field]
    if external_id then
      local result, err = mcp.call_tool(integration.server, integration.update_tool, {
        [integration.status_field:gsub("_", "_")] = external_id,
        status = new_status
      })
      
      if err then
        results[integration_name] = { error = err }
      else
        results[integration_name] = { success = true, result = result }
      end
    end
  end
  
  return results
end

-- Get available integrations (check which MCP servers are configured)
M.get_available_integrations = function()
  local available = {}
  
  for name, integration in pairs(M.INTEGRATIONS) do
    -- Check if MCP server is available
    local servers = mcp.list_servers()
    local server_available = false
    
    for _, server in ipairs(servers) do
      if server.name == integration.server then
        server_available = true
        break
      end
    end
    
    if server_available then
      available[name] = integration
    end
  end
  
  return available
end

-- Bulk create external issues
M.bulk_create_external_issues = function(filter, integration_name)
  filter = filter or {}
  
  local todos = db.get_all()
  local results = {}
  
  for _, todo in ipairs(todos) do
    -- Apply filter
    local include = true
    
    if filter.priority and todo.priority ~= filter.priority then
      include = false
    end
    
    if filter.status and (todo.status or "todo") ~= filter.status then
      include = false  
    end
    
    if filter.unlinked_only then
      local metadata = todo.metadata and vim.json.decode(todo.metadata) or {}
      if metadata.external_sync then
        include = false
      end
    end
    
    if include then
      local result, err = M.create_external_issue(todo.id, integration_name)
      results[todo.id] = {
        todo = todo,
        success = result ~= nil,
        result = result,
        error = err
      }
      
      -- Rate limiting
      vim.wait(100)
    end
  end
  
  return results
end

-- Import external issues as todos
M.import_external_issues = function(integration_name, query)
  local integration = M.INTEGRATIONS[integration_name]
  if not integration then
    return nil, "Unknown integration: " .. integration_name
  end
  
  -- Search for issues
  local search_tool = integration.server .. "_search_issues"
  local result, err = mcp.call_tool(integration.server, search_tool, {
    query = query or "is:open"
  })
  
  if err then
    return nil, err
  end
  
  local imported = {}
  
  for _, issue in ipairs(result.issues or {}) do
    -- Check if already imported
    local existing = db.find_by_metadata(integration.status_field, tostring(issue.number or issue.id))
    
    if not existing then
      -- Import as new todo
      local todo_id = db.add(issue.title, {
        title = issue.title,
        content = issue.body or issue.description,
        priority = M.map_external_priority(issue, integration_name),
        status = M.map_external_status(issue, integration_name),
        tags = M.extract_external_tags(issue, integration_name),
        metadata = vim.json.encode({
          [integration.status_field] = tostring(issue.number or issue.id),
          [integration_name .. "_url"] = issue.html_url or issue.url,
          [integration_name .. "_imported"] = os.date("%Y-%m-%d %H:%M:%S"),
          external_sync = true,
          source = "external_import"
        })
      })
      
      table.insert(imported, {
        todo_id = todo_id,
        external_id = issue.number or issue.id,
        title = issue.title
      })
    end
  end
  
  return imported
end

-- Map external priority to internal
M.map_external_priority = function(issue, integration_name)
  if integration_name == "github" then
    -- GitHub doesn't have native priority, check labels
    local labels = issue.labels or {}
    for _, label in ipairs(labels) do
      local name = type(label) == "table" and label.name or label
      if name:match("priority:high") or name:match("urgent") then
        return "high"
      elseif name:match("priority:low") then
        return "low"
      end
    end
    return "medium"
    
  elseif integration_name == "linear" then
    local priority = issue.priority
    if priority == 1 then return "high"
    elseif priority == 4 then return "low"
    else return "medium" end
    
  elseif integration_name == "jira" then
    local priority = issue.fields and issue.fields.priority
    if priority then
      local priority_name = priority.name:lower()
      if priority_name:match("high") or priority_name:match("critical") or priority_name:match("blocker") then
        return "high"
      elseif priority_name:match("low") or priority_name:match("trivial") then
        return "low"
      end
    end
    return "medium"
    
  else
    return "medium"
  end
end

-- Map external status to internal
M.map_external_status = function(issue, integration_name)
  if integration_name == "github" then
    return issue.state == "closed" and "done" or "todo"
    
  elseif integration_name == "linear" then
    local state = issue.state and issue.state.name
    if state == "Done" or state == "Completed" then
      return "done"
    elseif state == "In Progress" or state == "Started" then
      return "in_progress"
    else
      return "todo"
    end
    
  elseif integration_name == "jira" then
    local status = issue.fields and issue.fields.status
    if status then
      local status_name = status.name:lower()
      if status_name:match("done") or status_name:match("closed") or status_name:match("resolved") or status_name:match("complete") then
        return "done"
      elseif status_name:match("progress") or status_name:match("development") or status_name:match("review") then
        return "in_progress"
      end
    end
    return "todo"
    
  else
    return "todo"
  end
end

-- Extract tags from external issue
M.extract_external_tags = function(issue, integration_name)
  local tags = {}
  
  if integration_name == "github" then
    local labels = issue.labels or {}
    for _, label in ipairs(labels) do
      local name = type(label) == "table" and label.name or label
      -- Skip priority labels, include others
      if not name:match("^priority:") then
        table.insert(tags, name)
      end
    end
    
  elseif integration_name == "linear" then
    local labels = issue.labels and issue.labels.nodes or {}
    for _, label in ipairs(labels) do
      table.insert(tags, label.name)
    end
    
  elseif integration_name == "jira" then
    -- Extract from JIRA labels
    local labels = issue.fields and issue.fields.labels or {}
    for _, label in ipairs(labels) do
      table.insert(tags, label)
    end
    
    -- Add issue type as tag
    local issue_type = issue.fields and issue.fields.issuetype
    if issue_type then
      table.insert(tags, issue_type.name:lower())
    end
    
    -- Add component names as tags
    local components = issue.fields and issue.fields.components or {}
    for _, component in ipairs(components) do
      table.insert(tags, component.name:lower())
    end
  end
  
  return table.concat(tags, ",")
end

-- Setup commands
M.setup = function()
  -- Create external issue command
  vim.api.nvim_create_user_command("TodoCreateExternal", function(opts)
    local parts = vim.split(opts.args, " ", { plain = true })
    local todo_id = tonumber(parts[1])
    local integration = parts[2] or "github"
    
    if not todo_id then
      vim.notify("Usage: TodoCreateExternal <todo_id> [integration]", vim.log.levels.ERROR)
      return
    end
    
    local result, err = M.create_external_issue(todo_id, integration)
    if err then
      vim.notify("Error: " .. err, vim.log.levels.ERROR)
    else
      vim.notify(string.format("Created %s issue: %s", 
        M.INTEGRATIONS[integration].name, 
        result.url or result.identifier), vim.log.levels.INFO)
    end
  end, {
    nargs = "+",
    complete = function(lead, line, pos)
      local parts = vim.split(line, " ", { plain = true })
      if #parts <= 2 then
        -- Complete todo IDs
        local todos = db.get_all()
        local completions = {}
        for _, todo in ipairs(todos) do
          table.insert(completions, tostring(todo.id))
        end
        return completions
      elseif #parts == 3 then
        -- Complete integration names
        return vim.tbl_keys(M.get_available_integrations())
      end
      return {}
    end
  })
  
  -- Bulk create command
  vim.api.nvim_create_user_command("TodoBulkCreateExternal", function(opts)
    local integration = opts.args or "github"
    
    local results = M.bulk_create_external_issues({
      unlinked_only = true,
      status = "todo"
    }, integration)
    
    local success_count = 0
    local error_count = 0
    
    for _, result in pairs(results) do
      if result.success then
        success_count = success_count + 1
      else
        error_count = error_count + 1
      end
    end
    
    vim.notify(string.format("Created %d external issues, %d errors", 
      success_count, error_count), vim.log.levels.INFO)
  end, {
    nargs = "?",
    complete = function()
      return vim.tbl_keys(M.get_available_integrations())
    end
  })
  
  -- Import external issues command
  vim.api.nvim_create_user_command("TodoImportExternal", function(opts)
    local parts = vim.split(opts.args, " ", { plain = true })
    local integration = parts[1] or "github"
    local query = table.concat(parts, " ", 2) or "is:open"
    
    local imported, err = M.import_external_issues(integration, query)
    if err then
      vim.notify("Error: " .. err, vim.log.levels.ERROR)
    else
      vim.notify(string.format("Imported %d issues from %s", 
        #imported, M.INTEGRATIONS[integration].name), vim.log.levels.INFO)
    end
  end, {
    nargs = "*",
    complete = function()
      return vim.tbl_keys(M.get_available_integrations())
    end
  })
  
  -- List available integrations command
  vim.api.nvim_create_user_command("TodoListIntegrations", function()
    local available = M.get_available_integrations()
    
    if vim.tbl_isempty(available) then
      vim.notify("No external integrations configured", vim.log.levels.WARN)
      return
    end
    
    local lines = {"Available integrations:"}
    for name, integration in pairs(available) do
      table.insert(lines, string.format("  %s - %s", name, integration.description))
    end
    
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
  end, {})
end

return M