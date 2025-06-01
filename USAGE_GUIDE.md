# todo-mcp.nvim Usage Guide

A comprehensive guide to using the modern todo-mcp.nvim interface effectively.

## 🚀 Quick Start

### 1. Open the Todo Manager
```vim
<leader>td  " Toggle todo list (or your configured keymap)
```

### 2. First Time Experience
When you first open the plugin, you'll see a welcoming interface:

```
╭─ Welcome to Todo Manager ─╮
│                           │
│  No todos yet! Get started │
│  by pressing 'a' to add   │
│  your first todo item.    │
│                           │
╰───────────────────────────╯

  💡 Quick start: a=add  A=add+  /=search  ?=help
```

### 3. Add Your First Todo
Press `a` and enter your first todo:
```
New todo: Refactor user authentication system
```

## 🎨 Modern Interface Overview

Once you have todos, the interface transforms into a powerful task manager:

```
📝 Todo Manager (2/5 done)
    ▓▓▓▓░░░░░░░░░░░░░░░░ 40% │ 3 active │ 1 in progress
────────────────────────────────────────────────────────

## ▲ High Priority
● Fix parser bug @main.lua:42 #urgent [+]

## ■ Medium Priority  
◐ Update documentation #docs
● Review pull requests

## ✅ Completed
✓ Deploy to staging
✓ Update README

╭─ Commands ──────────────────────────────────────────╮
│ a=add  A=add+  d=delete  /=search  gf=jump  p=preview │
│ em=export md  ej=export json  ?=help  q=quit         │
╰─────────────────────────────────────────────────────╯
```

### Interface Elements

**Title Bar:**
- **Progress visualization**: Visual bar showing completion percentage
- **Counters**: Active, in-progress, and completed todo counts
- **Auto-updates**: Real-time changes as you work

**Todo Items:**
- **Status indicators**: ● (todo), ◐ (in-progress), ✓ (done)
- **Priority markers**: ▲ (high), ■ (medium), ▼ (low)
- **Metadata**: File references (@file:line), tags (#tag), content indicator ([+])
- **Smart grouping**: Organized by priority sections

**Footer:**
- **Command reference**: Quick access to all available actions
- **Context-aware**: Changes based on current state

## ⌨️ Navigation & Actions

### Essential Navigation
```vim
j/k         " Navigate up/down with live preview
<CR>        " Toggle todo done/undone
p           " Toggle floating preview window
gf          " Jump to linked file (if todo has file reference)
```

### Todo Management
```vim
a           " Add quick todo
A           " Add todo with priority, tags, and file linking
d           " Delete todo under cursor
```

### Search & Filtering
```vim
/           " Search todos (supports filters)
<C-c>       " Clear search and return to full list
```

Example searches:
- `bug` - Find todos containing "bug"
- `#urgent` - Find todos tagged with "urgent"
- `@main.lua` - Find todos linked to main.lua

### Export & Import
```vim
em          " Export to Markdown
ej          " Export to JSON
ey          " Export to YAML
ea          " Export all formats
```

## 🪟 Floating Preview System

The floating preview shows rich details about the selected todo:

```
┌─ Preview ──────────────────────────────┐
│ 📋 Fix parser bug                      │
│                                        │
│ Status: in_progress                    │
│ Priority: high                         │
│ Created: 2 hours ago                   │
│                                        │
│ Content:                               │
│ ─────────                              │
│ The JSON parser fails when             │
│ encountering nested arrays             │
│ with special characters.               │
│                                        │
│ Tags: urgent, parser                   │
│ File: ~/src/main.lua:42                │
└────────────────────────────────────────┘
```

**Preview Features:**
- **Auto-display**: Appears when navigating with j/k
- **Toggle control**: Press `p` to show/hide manually
- **Rich metadata**: Status, priority, timestamps, tags, file links
- **Smart positioning**: Adapts to screen space and main window position

## 🎯 Advanced Workflows

### 1. Code-Linked Todos
Link todos to specific code locations:

```vim
A           " Add advanced todo
```

1. Enter todo content: `Optimize database queries`
2. Choose priority: `high`
3. Enter tags: `performance, database`
4. Link to current file? `Yes`

Result:
```
● ▲ Optimize database queries @src/db.py:156 #performance #database [+]
```

### 2. Bulk Operations
```vim
/           " Search for specific criteria
#bug        " Find all bug-related todos
ea          " Export all filtered results
```

### 3. Project Management Workflow
```vim
" Morning workflow
<leader>td  " Open todo list
/           " Search for today's priorities
#urgent     " Filter urgent items
p           " Preview details of selected items
gf          " Jump to first urgent file

" End of day workflow
<leader>td  " Open todo list
<CR>        " Mark completed items as done
a           " Add tomorrow's priorities
em          " Export progress report
```

## 🎨 Customization Examples

### Theme Switching
Quickly change visual themes:

```lua
-- In your config
ui = {
  style = {
    preset = "minimal"  -- Clean, distraction-free
    -- preset = "emoji"    -- Colorful with emojis
    -- preset = "modern"   -- Enhanced hierarchy (default)
    -- preset = "sections" -- Priority-based sections
    -- preset = "ascii"    -- Terminal-safe characters
  }
}
```

### Performance Tuning
```lua
-- For SSH/remote work
ui = {
  modern_ui = false,        -- Disable Unicode
  animation_speed = 0,      -- No animations
  floating_preview = false, -- No floating windows
  style = { preset = "ascii" }
}

-- For maximum features
ui = {
  modern_ui = true,
  animation_speed = 200,    -- Smooth animations
  floating_preview = true,  -- Rich previews
  status_line = true,       -- Status integration
  style = { preset = "modern" }
}
```

## 🔧 Troubleshooting

### Common Issues

**1. Unicode characters not displaying properly**
- Switch to ASCII preset: `style = { preset = "ascii" }`
- Check terminal Unicode support
- Verify font supports box-drawing characters

**2. Previews not appearing**
- Check `floating_preview = true` in config
- Verify terminal supports floating windows
- Try toggling with `p` key

**3. Navigation feels slow**
- Reduce `animation_speed` or set to `0`
- Disable previews: `preview_enabled = false`
- Use minimal preset for better performance

**4. Status line not updating**
- Ensure `status_line = true` in config
- Add `%{v:lua.vim.g.todo_mcp_status or ''}` to statusline
- Check for statusline plugin conflicts

### Performance Tips

**For Large Todo Lists (100+ items):**
```lua
ui = {
  animation_speed = 50,     -- Faster animations
  style = {
    preset = "minimal",     -- Less visual processing
    show_metadata = false,  -- Hide extra details
    show_timestamps = "none"
  }
}
```

**For Remote/SSH Work:**
```lua
ui = {
  modern_ui = false,        -- ASCII-only
  animation_speed = 0,      -- No animations
  floating_preview = false, -- Reduce window complexity
  style = { preset = "ascii" }
}
```

## 📋 Command Reference

| Key | Action | Description |
|-----|--------|-------------|
| `j/k` | Navigate | Move with live preview |
| `<CR>` | Toggle | Mark done/undone |
| `p` | Preview | Toggle floating preview |
| `a` | Add | Quick todo creation |
| `A` | Add+ | Advanced todo with options |
| `d` | Delete | Remove selected todo |
| `/` | Search | Filter todos |
| `<C-c>` | Clear | Clear search/filters |
| `gf` | Jump | Go to linked file |
| `em` | Export | Markdown format |
| `ej` | Export | JSON format |
| `ey` | Export | YAML format |
| `ea` | Export | All formats |
| `?` | Help | Show help window |
| `q`/`<Esc>` | Quit | Close interface |

## 🎓 Pro Tips

1. **Use search extensively**: Filter by tags, files, or content to focus on relevant todos
2. **Link to code**: Always link todos to specific files/lines for better context
3. **Leverage previews**: Use j/k navigation to quickly scan todo details
4. **Organize with tags**: Use consistent tagging for easy filtering
5. **Export regularly**: Share progress with `em` (markdown) exports
6. **Customize themes**: Adapt the interface to your workflow and environment
7. **Status line integration**: Keep progress visible in your status line
8. **Keyboard-first**: Learn the keybindings for efficient todo management

## 🔗 Next Steps

- Explore **external integrations** (Linear, GitHub, JIRA) in the `INTEGRATION_GUIDE.md`
- Check out **configuration presets** in `examples/ui-config.lua`
- Read the **full documentation** in `doc/todo-mcp.txt`
- Join the community for tips and advanced workflows

---

*Happy todo managing! 🚀*