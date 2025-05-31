# todo-mcp.nvim

A fast, SQLite-backed todo list plugin for Neovim with Model Context Protocol (MCP) support. This allows LLMs like Claude to read and manage your todo list.

## Features

- 🚀 **Fast**: SQLite-backed for instant performance
- 🤖 **MCP Support**: LLMs can read/write todos via Model Context Protocol
- ⌨️ **Vim-friendly**: Intuitive keybindings and modal interface
- 💾 **Persistent**: Todos stored in `~/.local/share/nvim/todo-mcp.db`
- 🎨 **Clean UI**: Centered popup with minimal design

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "your-username/todo-mcp.nvim",
  config = function()
    require("todo-mcp").setup({
      keymaps = {
        toggle = "<leader>td",  -- Toggle todo list
      }
    })
  end
}
```

## Usage

### In Neovim

- `<leader>td` - Toggle todo list popup
- `a` - Add new todo
- `d` - Delete todo under cursor  
- `<CR>` - Toggle todo done/undone
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
python3 ~/.local/share/nvim/plugged/todo-mcp.nvim/mcp-server.py
```

2. Configure your MCP client (e.g., Claude Desktop) to connect to the server.

3. Available MCP tools:
- `list_todos` - List all todos
- `add_todo` - Add a new todo
- `update_todo` - Update todo content or status
- `delete_todo` - Delete a todo

## Configuration

```lua
require("todo-mcp").setup({
  -- Database location
  db_path = vim.fn.expand("~/.local/share/nvim/todo-mcp.db"),
  
  -- UI settings
  ui = {
    width = 60,
    height = 20,
    border = "rounded",
  },
  
  -- Keymaps
  keymaps = {
    toggle = "<leader>td",
    add = "a",
    delete = "d", 
    toggle_done = "<CR>",
    quit = "q",
  },
})
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
- Python 3.6+ (for MCP server)

## License

MIT