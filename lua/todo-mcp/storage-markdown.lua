-- Alternative markdown-based storage backend
local M = {}
local todo_file

M.setup = function(file_path)
  todo_file = file_path or vim.fn.expand("~/.local/share/nvim/todos.md")
  vim.fn.mkdir(vim.fn.fnamemodify(todo_file, ":h"), "p")
  
  -- Create file if doesn't exist
  if vim.fn.filereadable(todo_file) == 0 then
    vim.fn.writefile({"# Todo List", ""}, todo_file)
  end
end

M.get_all = function()
  local lines = vim.fn.readfile(todo_file)
  local todos = {}
  local id = 0
  
  for _, line in ipairs(lines) do
    -- Parse markdown checkboxes: - [ ] todo or - [x] done
    local done, content = line:match("^%- %[([x ]?)%] (.+)$")
    if content then
      id = id + 1
      table.insert(todos, {
        id = id,
        content = content,
        done = done == "x"
      })
    end
  end
  
  return todos
end

M.save_all = function(todos)
  local lines = {"# Todo List", ""}
  
  for _, todo in ipairs(todos) do
    local checkbox = todo.done and "[x]" or "[ ]"
    table.insert(lines, string.format("- %s %s", checkbox, todo.content))
  end
  
  vim.fn.writefile(lines, todo_file)
end

M.add = function(content)
  local todos = M.get_all()
  table.insert(todos, {
    id = #todos + 1,
    content = content,
    done = false
  })
  M.save_all(todos)
  return #todos
end

M.toggle_done = function(id)
  local todos = M.get_all()
  if todos[id] then
    todos[id].done = not todos[id].done
    M.save_all(todos)
    return true
  end
  return false
end

M.delete = function(id)
  local todos = M.get_all()
  if todos[id] then
    table.remove(todos, id)
    M.save_all(todos)
    return true
  end
  return false
end

M.update = function(id, updates)
  local todos = M.get_all()
  if todos[id] then
    if updates.content then
      todos[id].content = updates.content
    end
    if updates.done ~= nil then
      todos[id].done = updates.done
    end
    M.save_all(todos)
    return true
  end
  return false
end

return M