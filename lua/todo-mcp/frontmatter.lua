local M = {}

-- Parse YAML frontmatter from markdown text
M.parse = function(text)
  local lines = vim.split(text, "\n", { plain = true })
  local in_frontmatter = false
  local frontmatter_lines = {}
  local content_lines = {}
  local frontmatter_ended = false
  
  for i, line in ipairs(lines) do
    if i == 1 and line == "---" then
      in_frontmatter = true
    elseif in_frontmatter and line == "---" then
      in_frontmatter = false
      frontmatter_ended = true
    elseif in_frontmatter then
      table.insert(frontmatter_lines, line)
    elseif frontmatter_ended or i > 1 then
      table.insert(content_lines, line)
    end
  end
  
  -- Parse frontmatter
  local frontmatter = {}
  for _, line in ipairs(frontmatter_lines) do
    local key, value = line:match("^(%w+):%s*(.*)$")
    if key and value then
      -- Handle different value types
      value = value:gsub("^%s*", ""):gsub("%s*$", "") -- trim
      
      -- Parse arrays [tag1, tag2, tag3]
      if value:match("^%[.*%]$") then
        local array_content = value:sub(2, -2) -- remove [ ]
        local items = {}
        for item in array_content:gmatch("[^,]+") do
          table.insert(items, item:gsub("^%s*", ""):gsub("%s*$", ""))
        end
        frontmatter[key] = items
      -- Parse null
      elseif value == "null" or value == "" then
        frontmatter[key] = nil
      -- Parse booleans
      elseif value == "true" then
        frontmatter[key] = true
      elseif value == "false" then
        frontmatter[key] = false
      -- Keep as string
      else
        frontmatter[key] = value
      end
    end
  end
  
  -- Join content lines
  local content = table.concat(content_lines, "\n"):gsub("^%s*", "")
  
  return frontmatter, content
end

-- Serialize frontmatter and content to markdown
M.serialize = function(frontmatter, content)
  local lines = { "---" }
  
  -- Sort keys for consistent output
  local keys = {}
  for k in pairs(frontmatter) do
    table.insert(keys, k)
  end
  table.sort(keys)
  
  -- Add frontmatter fields
  for _, key in ipairs(keys) do
    local value = frontmatter[key]
    if type(value) == "table" then
      -- Array of tags
      table.insert(lines, key .. ": [" .. table.concat(value, ", ") .. "]")
    elseif value == nil then
      table.insert(lines, key .. ": null")
    elseif type(value) == "boolean" then
      table.insert(lines, key .. ": " .. tostring(value))
    else
      table.insert(lines, key .. ": " .. tostring(value))
    end
  end
  
  table.insert(lines, "---")
  table.insert(lines, "")
  
  -- Add content
  if content and content ~= "" then
    table.insert(lines, content)
  end
  
  return table.concat(lines, "\n")
end

-- Convert database todo to markdown format
M.todo_to_markdown = function(todo)
  local frontmatter = {
    title = todo.title or todo.content:match("^[^\n]+") or "Untitled",
    status = todo.status or (todo.done and "done" or "todo"),
    priority = todo.priority,
    createdAt = todo.created_at,
    updatedAt = todo.updated_at,
  }
  
  -- Optional fields
  if todo.completed_at then
    frontmatter.completedAt = todo.completed_at
  end
  
  if todo.tags and todo.tags ~= "" then
    -- Parse comma-separated tags
    local tags = {}
    for tag in todo.tags:gmatch("[^,]+") do
      table.insert(tags, tag:gsub("^%s*", ""):gsub("%s*$", ""))
    end
    frontmatter.tags = tags
  end
  
  if todo.file_path then
    frontmatter.file = todo.file_path
    if todo.line_number then
      frontmatter.line = todo.line_number
    end
  end
  
  -- Add arbitrary fields from metadata
  if todo.metadata then
    local ok, extra_fields = pcall(vim.json.decode, todo.metadata)
    if ok and type(extra_fields) == "table" then
      for key, value in pairs(extra_fields) do
        -- Don't override core fields
        if not frontmatter[key] then
          frontmatter[key] = value
        end
      end
    end
  end
  
  return M.serialize(frontmatter, todo.content or "")
end

-- Convert markdown to database todo format
M.markdown_to_todo = function(markdown_text)
  local frontmatter, content = M.parse(markdown_text)
  
  -- Core fields that map to database columns
  local core_fields = {
    "title", "status", "priority", "tags", "file", "line",
    "createdAt", "updatedAt", "completedAt"
  }
  
  local todo = {
    title = frontmatter.title or content:match("^[^\n]+") or "Untitled",
    content = content,
    status = frontmatter.status or "todo",
    priority = frontmatter.priority or "medium",
    created_at = frontmatter.createdAt,
    updated_at = frontmatter.updatedAt,
    completed_at = frontmatter.completedAt,
  }
  
  -- Convert done status
  if frontmatter.status == "done" then
    todo.done = true
  else
    todo.done = false
  end
  
  -- Convert tags array to comma-separated string
  if frontmatter.tags and type(frontmatter.tags) == "table" then
    todo.tags = table.concat(frontmatter.tags, ", ")
  elseif frontmatter.tags then
    todo.tags = tostring(frontmatter.tags)
  end
  
  -- File linking
  if frontmatter.file then
    todo.file_path = frontmatter.file
    todo.line_number = frontmatter.line
  end
  
  -- Extract arbitrary fields into metadata
  local metadata = {}
  for key, value in pairs(frontmatter) do
    local is_core = false
    for _, core_field in ipairs(core_fields) do
      if key == core_field then
        is_core = true
        break
      end
    end
    
    if not is_core then
      metadata[key] = value
    end
  end
  
  -- Store metadata as JSON if there are any extra fields
  if next(metadata) then
    todo.metadata = vim.json.encode(metadata)
  end
  
  -- Store original frontmatter for perfect reconstruction
  todo.frontmatter_raw = M.serialize(frontmatter, ""):match("^(.-)\n---")
  
  return todo
end

return M