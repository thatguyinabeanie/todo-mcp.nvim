-- Export functionality for multiple formats
local M = {}
local db = require("todo-mcp.db")

-- Get all todos with full metadata from SQLite
local function get_todos_with_metadata()
  -- Simply use the db module's get_all function which already has all fields
  return db.get_all()
end

-- Export to Markdown format
M.export_markdown = function(file_path)
  file_path = file_path or vim.fn.expand("~/todos.md")
  local todos = get_todos_with_metadata()
  local lines = {
    "# Todo List",
    "",
    string.format("_Exported: %s_", os.date("%Y-%m-%d %H:%M:%S")),
    "",
    "## Active",
    ""
  }
  
  -- Active todos first
  for _, todo in ipairs(todos) do
    if not todo.done then
      table.insert(lines, string.format("- [ ] %s", todo.content))
      table.insert(lines, string.format("  - Created: %s", todo.created_at))
    end
  end
  
  table.insert(lines, "")
  table.insert(lines, "## Completed")
  table.insert(lines, "")
  
  -- Completed todos
  for _, todo in ipairs(todos) do
    if todo.done then
      table.insert(lines, string.format("- [x] %s", todo.content))
      table.insert(lines, string.format("  - Created: %s | Completed: %s", todo.created_at, todo.updated_at))
    end
  end
  
  vim.fn.writefile(lines, file_path)
  vim.notify("Exported to " .. file_path .. " (Markdown)")
  return file_path
end

-- Export to JSON format
M.export_json = function(file_path)
  file_path = file_path or vim.fn.expand("~/todos.json")
  local todos = get_todos_with_metadata()
  
  local data = {
    version = "1.0",
    exported_at = os.date("%Y-%m-%d %H:%M:%S"),
    todos = todos
  }
  
  local json_str = vim.fn.json_encode(data)
  -- Pretty print
  json_str = json_str:gsub(',%s*"', ',\n  "')
  json_str = json_str:gsub('{%s*"', '{\n  "')
  json_str = json_str:gsub('}$', '\n}')
  json_str = json_str:gsub('%[{', '[\n    {')
  json_str = json_str:gsub('},{', '},\n    {')
  json_str = json_str:gsub('}%]', '}\n  ]')
  
  vim.fn.writefile(vim.split(json_str, "\n"), file_path)
  vim.notify("Exported to " .. file_path .. " (JSON)")
  return file_path
end

-- Export to YAML format
M.export_yaml = function(file_path)
  file_path = file_path or vim.fn.expand("~/todos.yaml")
  local todos = get_todos_with_metadata()
  
  local lines = {
    "# Todo List Export",
    string.format("version: '1.0'"),
    string.format("exported_at: '%s'", os.date("%Y-%m-%d %H:%M:%S")),
    "",
    "todos:"
  }
  
  for _, todo in ipairs(todos) do
    table.insert(lines, string.format("  - id: %d", todo.id))
    table.insert(lines, string.format("    content: '%s'", todo.content:gsub("'", "''")))
    table.insert(lines, string.format("    done: %s", tostring(todo.done)))
    table.insert(lines, string.format("    created_at: '%s'", todo.created_at))
    table.insert(lines, string.format("    updated_at: '%s'", todo.updated_at))
    table.insert(lines, "")
  end
  
  vim.fn.writefile(lines, file_path)
  vim.notify("Exported to " .. file_path .. " (YAML)")
  return file_path
end

-- Export to all formats at once
M.export_all = function(base_path)
  base_path = base_path or vim.fn.expand("~/todos")
  
  M.export_markdown(base_path .. ".md")
  M.export_json(base_path .. ".json")
  M.export_yaml(base_path .. ".yaml")
  
  vim.notify("Exported to all formats: " .. base_path .. ".{md,json,yaml}")
end

-- Import from JSON format
M.import_json = function(file_path)
  if vim.fn.filereadable(file_path) == 0 then
    vim.notify("File not found: " .. file_path, vim.log.levels.ERROR)
    return
  end
  
  local content = table.concat(vim.fn.readfile(file_path), "\n")
  local ok, data = pcall(vim.fn.json_decode, content)
  
  if not ok then
    vim.notify("Invalid JSON file", vim.log.levels.ERROR)
    return
  end
  
  local imported = 0
  for _, todo in ipairs(data.todos or {}) do
    if todo.content then
      local id = db.add(todo.content)
      if todo.done then
        db.update(id, { done = true })
      end
      imported = imported + 1
    end
  end
  
  vim.notify(string.format("Imported %d todos from JSON", imported))
end

-- Import from Markdown format
M.import_markdown = function(file_path)
  if vim.fn.filereadable(file_path) == 0 then
    vim.notify("File not found: " .. file_path, vim.log.levels.ERROR)
    return
  end
  
  local lines = vim.fn.readfile(file_path)
  local imported = 0
  
  for _, line in ipairs(lines) do
    local done, content = line:match("^%- %[([x ]?)%] (.+)$")
    if content then
      local id = db.add(content)
      if done == "x" then
        db.update(id, { done = true })
      end
      imported = imported + 1
    end
  end
  
  vim.notify(string.format("Imported %d todos from Markdown", imported))
end

return M