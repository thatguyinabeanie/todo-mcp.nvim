# todo-mcp.nvim

A fast, SQLite-backed todo list plugin for Neovim with Model Context Protocol (MCP) support. This allows LLMs like Claude to read and manage your todo list.

## Features

- 🚀 **Fast**: SQLite-backed for instant performance
- 🤖 **MCP Support**: LLMs can read/write todos via Model Context Protocol
- ⌨️ **Vim-friendly**: Intuitive keybindings and modal interface
- 💾 **Persistent**: Todos stored in `~/.local/share/nvim/todo-mcp.db`
- 🎨 **Clean UI**: Centered popup with minimal design
- 🔍 **Search & Filter**: Find todos by content, priority, tags, or files
- 🏷️ **Tags & Priorities**: Organize todos with metadata
- 🔗 **Code Linking**: Link todos to specific files and line numbers
- ⚡ **Lazy Loading**: Fast startup with proper lazy loading support

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim) with lazy loading:

```lua
{
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = {
    "kkharji/sqlite.lua",  -- Required for database operations
  },
  cmd = "TodoMCP",  -- Load on command
  keys = {
    { "<leader>td", "<Plug>(todo-mcp-toggle)", desc = "Toggle todo list" },
    { "<leader>ta", "<Plug>(todo-mcp-add)", desc = "Add todo" },
    { "<leader>tA", "<Plug>(todo-mcp-add-advanced)", desc = "Add todo with options" },
  },
  config = function()
    require("todo-mcp").setup({
      -- Configuration is optional
    })
  end
}
```

Alternative (no lazy loading):

```lua
{
  "thatguyinabeanie/todo-mcp.nvim",
  dependencies = { "kkharji/sqlite.lua" },
  config = function()
    require("todo-mcp").setup()
  end
}
```

## Usage

### Global Keymaps

- `<leader>td` - Toggle todo list popup
- `<leader>ta` - Add new todo (quick)
- `<leader>tA` - Add todo with priority/tags/file linking

### Inside Todo List

- `a` - Add new todo
- `A` - Add todo with priority/tags/file linking
- `d` - Delete todo under cursor  
- `<CR>` - Toggle todo done/undone
- `/` - Search todos
- `<C-c>` - Clear search
- `gf` - Jump to linked file
- `?` - Show help
- `q` or `<Esc>` - Close popup

### Export/Import Commands

```vim
:TodoMCP export markdown    " Export to ~/todos.md
:TodoMCP export json        " Export to ~/todos.json
:TodoMCP export yaml        " Export to ~/todos.yaml
:TodoMCP export all         " Export to all formats

:TodoMCP import markdown [file]    " Import from markdown
:TodoMCP import json [file]        " Import from JSON
```

### With MCP (for LLMs)

1. Start the MCP server:
```bash
lua ~/.local/share/nvim/plugged/todo-mcp.nvim/mcp-server.lua
```

2. Configure your MCP client (e.g., Claude Desktop) to connect to the server.

3. Available MCP tools:
- `list_todos` - List all todos
- `add_todo` - Add a new todo with metadata
- `update_todo` - Update todo content or status
- `delete_todo` - Delete a todo
- `search_todos` - Search and filter todos

## Configuration

```lua
require("todo-mcp").setup({
  -- Database location
  db_path = vim.fn.expand("~/.local/share/nvim/todo-mcp.db"),
  
  -- UI settings
  ui = {
    width = 80,
    height = 30,
    border = "rounded",
  },
  
  -- Internal keymaps (inside todo list popup)
  keymaps = {
    add = "a",
    delete = "d", 
    toggle_done = "<CR>",
    quit = "q",
  },
})
```

### Custom Global Keymaps

Disable default keymaps and set your own:

```lua
vim.g.todo_mcp_no_default_keymaps = true
vim.keymap.set("n", "<leader>tt", "<Plug>(todo-mcp-toggle)")
vim.keymap.set("n", "<leader>ta", "<Plug>(todo-mcp-add)")
vim.keymap.set("n", "<leader>tA", "<Plug>(todo-mcp-add-advanced)")
```

## MCP Configuration

Add to your MCP configuration file:

```json
{
  "mcpServers": {
    "todo-mcp": {
      "command": "python3",
      "args": ["/path/to/todo-mcp.nvim/mcp-server.py"],
      "env": {
        "TODO_MCP_DB": "~/.local/share/nvim/todo-mcp.db"
      }
    }
  }
}
```

## Requirements

- Neovim 0.7+
- SQLite3 (system command)
- Lua 5.1+ or LuaJIT (for standalone MCP server)

## License

MIT