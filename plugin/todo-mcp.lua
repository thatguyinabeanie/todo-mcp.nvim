-- Don't load plugin twice
if vim.g.loaded_todo_mcp then
  return
end
vim.g.loaded_todo_mcp = true

-- Create user command
vim.api.nvim_create_user_command("TodoMCP", function(opts)
  if opts.args == "toggle" or opts.args == "" then
    require("todo-mcp.ui").toggle()
  elseif opts.args == "add" then
    vim.ui.input({ prompt = "New todo: " }, function(input)
      if input and input ~= "" then
        require("todo-mcp.db").add(input)
        vim.notify("Todo added: " .. input)
      end
    end)
  elseif opts.args == "server" then
    -- Start the MCP server (for debugging)
    require("todo-mcp.mcp").start_server()
  elseif opts.args:match("^export") then
    local export = require("todo-mcp.export")
    local format = opts.args:match("^export%s+(%w+)")
    
    if format == "markdown" or format == "md" then
      export.export_markdown()
    elseif format == "json" then
      export.export_json()
    elseif format == "yaml" or format == "yml" then
      export.export_yaml()
    elseif format == "all" then
      export.export_all()
    else
      vim.notify("Usage: :TodoMCP export {markdown|json|yaml|all}", vim.log.levels.ERROR)
    end
  elseif opts.args:match("^import") then
    local export = require("todo-mcp.export")
    local rest = opts.args:match("^import%s+(.+)")
    
    if rest then
      local format, file_path = rest:match("^(%w+)%s*(.*)$")
      
      if format == "markdown" or format == "md" then
        export.import_markdown(file_path ~= "" and file_path or nil)
      elseif format == "json" then
        export.import_json(file_path ~= "" and file_path or nil)
      else
        vim.notify("Usage: :TodoMCP import {markdown|json} [file_path]", vim.log.levels.ERROR)
      end
    else
      vim.notify("Usage: :TodoMCP import {markdown|json} [file_path]", vim.log.levels.ERROR)
    end
  end
end, {
  nargs = "*",
  complete = function(_, cmdline, _)
    local args = vim.split(cmdline, "%s+")
    
    if #args == 2 then
      return { "toggle", "add", "server", "export", "import" }
    elseif #args == 3 then
      if args[2] == "export" then
        return { "markdown", "json", "yaml", "all" }
      elseif args[2] == "import" then
        return { "markdown", "json" }
      end
    end
    
    return {}
  end,
  desc = "Todo list with MCP support"
})