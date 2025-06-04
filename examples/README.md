# Todo-MCP Configuration Examples

All examples use [lazy.nvim](https://github.com/folke/lazy.nvim) plugin manager format. Place your chosen configuration in `~/.config/nvim/lua/plugins/todo-mcp.lua`.

## 📁 Available Examples

### basic-setup.lua
The simplest configuration with just the essentials. Perfect for users who want to get started quickly.

```lua
return require("todo-mcp.examples.basic-setup")
```

### recommended-setup.lua
The recommended configuration for most users. Includes keybindings, export options, and sensible defaults.

```lua
return require("todo-mcp.examples.recommended-setup")
```

### advanced-setup.lua
Full-featured configuration with all integrations, including lualine, dashboard, telescope, and external issue tracker sync.

```lua
return require("todo-mcp.examples.advanced-setup")
```

### project-specific.lua
Optimized for managing todos within a specific project. Includes automatic TODO comment import and project-focused keybindings.

```lua
return require("todo-mcp.examples.project-specific")
```

### ui-styles.lua
Examples of different visual styles (modern, minimal, emoji, ascii, sections, custom). Shows how to customize the appearance.

```lua
return require("todo-mcp.examples.ui-styles")
```

### mcp-config.json
Example configuration for MCP servers (GitHub, Jira, Linear integration). Place in your project root or configure globally.

## 🚀 Quick Start

1. Choose an example that fits your needs
2. Copy it to `~/.config/nvim/lua/plugins/todo-mcp.lua`
3. Modify as needed
4. Restart Neovim or run `:Lazy sync`

## 🎨 Customization Tips

- All examples can be mixed and matched
- Use `:TodoMCP style` to cycle through visual styles
- Run `:TodoMCP setup` for the interactive setup wizard
- Check `:h todo-mcp` for full documentation

## 🔧 Common Modifications

### Change Keybindings
```lua
keys = {
  { "<leader>T", "<cmd>TodoMCP<cr>", desc = "Todo List" },  -- Capital T instead
}
```

### Change Default Style
```lua
opts = {
  ui = {
    style = {
      preset = "minimal",  -- or "emoji", "ascii", "sections", etc.
    }
  }
}
```

### Enable Auto-import of TODO Comments
```lua
opts = {
  integrations = {
    todo_comments = {
      enabled = true,
      auto_import = true,  -- Automatically import TODO/FIXME comments
    }
  }
}
```

### Use Project-Specific Database
```lua
opts = {
  db = {
    project_relative = true,  -- Store todos in .todo-mcp/todos.db
  }
}
```