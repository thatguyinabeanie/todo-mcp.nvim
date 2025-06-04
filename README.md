# todo-mcp.nvim

> ⚠️ **WORK IN PROGRESS - DO NOT USE IN PRODUCTION**
>
> This plugin is under active development and APIs may change without notice.
> Please wait for the stable v1.0 release before using in your workflow.

**The missing link between code comments and task management.**

todo-mcp.nvim is the definitive bridge that transforms ephemeral TODO
comments into persistent, actionable tasks with AI-powered insights and
seamless external integrations.

![GitHub stars](https://img.shields.io/github/stars/thatguyinabeanie/todo-mcp.nvim?style=social)
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Neovim](https://img.shields.io/badge/neovim-0.9.0+-green.svg)

## Features

### 🎨 **Modern UI Experience**
- **Floating Preview Windows**: Live todo details with navigation
- **Smooth Animations**: Fade transitions and responsive interactions
- **Progress Visualization**: Real-time completion bars and statistics
- **Modern Design**: Unicode borders, elegant typography, and visual hierarchy
- **Multiple Themes**: 5 built-in presets (minimal, emoji, modern, sections,
  ascii)
- **Enhanced Navigation**: j/k keys with automatic preview updates

### 🚀 **Core Features**

- **Fast Performance**: SQLite-backed for instant responsiveness
- **MCP Integration**: LLMs can read/write todos via Model Context Protocol
- **Vim-Native**: Intuitive keybindings and modal interface
- **Persistent Storage**: Todos stored in `~/.local/share/nvim/todo-mcp.db`
- **Smart Search**: Find todos by content, priority, tags, or files
- **Rich Metadata**: Tags, priorities, timestamps, and file linking
- **Lazy Loading**: Fast startup with proper lazy loading support

### 🔌 **Enterprise Integrations**

- **Linear**: Sync with modern development workflows
- **GitHub**: Bridge code comments to GitHub issues
- **JIRA**: Enterprise project management integration
- **AI Analysis**: Context detection and smart categorization

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

**Navigation & Actions:**

- `j/k` - Navigate with live preview updates
- `<CR>` - Toggle todo done/undone
- `p` - Toggle floating preview window

**Todo Management:**

- `a` - Add new todo
- `A` - Add todo with priority/tags/file linking
- `d` - Delete todo under cursor

**Search & Navigation:**

- `/` - Search todos with filters
- `<C-c>` - Clear search
- `gf` - Jump to linked file

**Export & Help:**

- `em` - Export to Markdown
- `ej` - Export to JSON
- `ey` - Export to YAML
- `ea` - Export all formats
- `?` - Show comprehensive help
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

2. Configure your MCP client (e.g., Claude Desktop) to connect to the
   server.

3. Available MCP tools:

   - `list_todos` - List all todos
   - `add_todo` - Add a new todo with metadata
   - `update_todo` - Update todo content or status
   - `delete_todo` - Delete a todo
   - `search_todos` - Search and filter todos

#### External Issue Tracker Integration

Additional MCP servers are available for integrating with external issue
trackers (GitHub, JIRA, Linear). These require additional dependencies:

```bash
luarocks install dkjson luasocket
```

See `mcp-servers/README.md` for setup instructions.

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

    -- Modern UI options (new!)
    modern_ui = true,           -- Enable modern styling
    animation_speed = 150,      -- Animation duration (ms)
    floating_preview = true,    -- Show floating preview windows
    preview_enabled = true,     -- Enable preview on navigation
    status_line = true,         -- Status line integration

    -- View style (see View Styles section below)
    style = {
      preset = "modern" -- minimal | emoji | modern | sections | compact | ascii
    }
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

### Configuration Examples

See the `examples/` directory for detailed configuration examples:

- `minimal-config.lua` - Simplest setup with defaults
- `full-config.lua` - All available options documented
- `project-config.lua` - Project-specific todo management
- `ui-config.lua` - Various UI style examples
- `enterprise-config.lua` - Enterprise features setup

### Custom Global Keymaps

Disable default keymaps and set your own:

```lua
vim.g.todo_mcp_no_default_keymaps = true
vim.keymap.set("n", "<leader>tt", "<Plug>(todo-mcp-toggle)")
vim.keymap.set("n", "<leader>ta", "<Plug>(todo-mcp-add)")
vim.keymap.set("n", "<leader>tA", "<Plug>(todo-mcp-add-advanced)")
```

## View Styles

The plugin supports multiple view styles to match your preference:

### Minimal

```text
○ Buy milk
○ Fix parser bug
● Deploy to staging
```

### Modern (New Default)

```text
📝 Todo Manager (2/5 done)
    ▓▓▓▓░░░░░░░░░░░░░░░░ 40% │ 3 active │ 1 in progress
─────────────────────────────────────────────────────

## ▲ High Priority
● 🔥 Fix parser bug @main.lua:42 #urgent

## ■ Medium Priority
◐ ⚡ Update documentation
○ 💤 Review pull requests

## ✅ Completed
✓ Deploy to staging
```

### Emoji

```text
○ Buy milk
◐ 🔥 Fix parser bug @main.lua:42
✅ 🚀 Deploy to staging
```

### Sections

```text
## 🔥 High Priority
◐ Fix parser bug

## ⚡ Medium Priority
○ Update docs

## ✅ Completed
● Deploy to staging
```

### Custom Style

```lua
ui = {
  style = {
    status_indicators = { todo = "▷", in_progress = "▶", done = "■" },
    priority_style = "bracket", -- Shows [H] [M] [L]
    layout = "priority_sections",
    show_metadata = true,
    show_timestamps = "relative",
    done_style = "strikethrough"
  },
  
  -- Modern UI customization
  modern_ui = true,
  animation_speed = 200, -- Slower animations
  floating_preview = false  -- Disable floating previews
}
```

## Preview System

The new floating preview system shows rich todo details:

```text
┌─ Preview ──────────────────────┐
│ 📋 Fix parser bug              │
│                                │
│ Status: in_progress            │
│ Priority: high                 │
│ Created: 2 hours ago           │
│                                │
│ Content:                       │
│ ─────────                      │
│ The JSON parser fails when     │
│ encountering nested arrays     │
│ with special characters.       │
│                                │
│ Tags: urgent, parser           │
│ File: ~/src/main.lua:42        │
└────────────────────────────────┘
```

- **Auto-preview**: Shows on j/k navigation
- **Toggle**: Press `p` to show/hide
- **Rich details**: Content, metadata, file links
- **Smart positioning**: Appears to the right of main window

## MCP Configuration

Add to your MCP configuration file:

```json
{
  "mcpServers": {
    "todo-mcp": {
      "command": "lua",
      "args": ["/path/to/todo-mcp.nvim/mcp-server.lua"],
      "env": {
        "TODO_MCP_DB": "~/.local/share/nvim/todo-mcp.db"
      }
    }
  }
}
```

## Language Support

todo-mcp.nvim automatically works with **any language that Neovim
recognizes**. It uses Neovim's built-in filetype detection, so if Neovim can
detect the file type, todo-mcp.nvim will work with it.

- **No configuration needed** - Works out of the box with all languages
- **Automatic detection** - Uses Neovim's filetype system
- **Framework awareness** - Detects common frameworks when relevant
- **Lazy loading** - Language features load only when needed

## Performance & Compatibility

**Requirements:**

- Neovim 0.7+ (0.9+ recommended for best experience)
- SQLite3 (system command)
- Lua 5.1+ or LuaJIT (for standalone MCP server)

**Performance:**

- **Instant startup**: Lazy loading with minimal impact
- **Smooth animations**: Configurable 50-500ms transitions
- **Efficient rendering**: Cached queries and optimized updates
- **Memory conscious**: Automatic cleanup of preview windows

**Terminal Support:**

- **Modern terminals**: Full Unicode and color support
- **Legacy terminals**: ASCII preset for compatibility
- **SSH/Remote**: Works seamlessly over SSH connections

## License

MIT
