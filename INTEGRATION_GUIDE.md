# External Integration Guide

This guide explains how to connect todo-mcp.nvim with external task management systems via MCP (Model Context Protocol) servers.

## Overview

todo-mcp.nvim acts as a **bridge** between your code comments and external task management systems:

```
TODO comments → todo-mcp.nvim → External Systems
    ↓              ↓                    ↓
 Detection    Transformation      JIRA/Linear/GitHub
```

## Supported Integrations

### 1. Linear (Modern Dev Teams)
**Best for:** Startups, product teams, modern development workflows
- ✅ Automatic priority mapping
- ✅ Project assignment
- ✅ Status synchronization
- ✅ Smart labeling

### 2. GitHub Issues (Open Source)
**Best for:** Open source projects, public repositories
- ✅ File linking with line numbers
- ✅ Label-based priority
- ✅ Milestone assignment
- ✅ Auto-generated context

### 3. JIRA (Enterprise)
**Best for:** Enterprise teams, complex workflows
- ✅ Epic/Story hierarchy  
- ✅ Sprint assignment
- ✅ Custom fields and components
- ✅ Workflow states and transitions
- ✅ Advanced JQL search
- ✅ Project-specific issue types

## Quick Setup

### 1. Install Dependencies

```bash
# Install Lua HTTP libraries (choose one)
luarocks install lua-socket  # Most common
# OR
luarocks install lua-http    # Alternative
```

### 2. Configure Environment Variables

```bash
# Linear
export LINEAR_API_KEY="your_linear_api_key"

# GitHub
export GITHUB_TOKEN="your_github_token"
export GITHUB_REPO="owner/repo"  # Optional, auto-detected from git

# JIRA
export JIRA_URL="https://yourcompany.atlassian.net"
export JIRA_EMAIL="your.email@company.com" 
export JIRA_API_TOKEN="your_jira_token"
```

### 3. Configure MCP Servers

Copy `examples/mcp-config.json` to your project root and customize:

```json
{
  "mcpVersion": "2024-11-05",
  "clients": {
    "todo-mcp-nvim": {
      "servers": {
        "linear": {
          "command": "lua",
          "args": ["mcp-servers/linear-server.lua"],
          "env": {
            "LINEAR_API_KEY": "${LINEAR_API_KEY}"
          }
        }
      }
    }
  }
}
```

### 4. Enable in Neovim

```lua
require('todo-mcp').setup({
  integrations = {
    external = {
      enabled = true,
      auto_sync = true,
      default_integration = "github"  -- or "linear", "jira"
    }
  }
})
```

## Workflow Examples

### Basic Workflow: Comment → Issue

1. **Write a TODO comment:**
   ```javascript
   // TODO: Optimize database queries for user search
   function searchUsers(query) {
     // ... slow implementation
   }
   ```

2. **Track it:**
   ```vim
   :TodoCreateExternal 42 linear
   ```

3. **Result:** Linear issue created with:
   - Title: "Optimize database queries for user search"
   - Context: File path, line number, git branch
   - Priority: Auto-detected from TODO type
   - Labels: Based on file type and directory

### Advanced Workflow: Bulk Operations

1. **Create issues for all untracked TODOs:**
   ```vim
   :TodoBulkCreateExternal github
   ```

2. **Import existing issues as TODOs:**
   ```vim
   :TodoImportExternal linear "label:bug priority:high"
   ```

3. **Sync status changes:**
   ```lua
   -- Automatically syncs when you mark TODOs as done
   vim.keymap.set('n', '<leader>td', function()
     require('todo-mcp.db').update_with_sync(todo_id, { status = 'done' })
   end)
   ```

### Enterprise JIRA Workflow

1. **Create JIRA issue with project context:**
   ```javascript
   // TODO: Implement user authentication middleware
   function authenticateUser(req, res, next) {
     // ... current implementation
   }
   ```

2. **Track with JIRA-specific options:**
   ```vim
   :TodoCreateExternal 42 jira
   ```

3. **Result:** JIRA issue created with:
   - **Project:** Auto-detected or specified
   - **Issue Type:** Task/Story/Bug based on TODO type
   - **Priority:** Mapped from AI analysis
   - **Labels:** File type, directory, git branch
   - **Components:** Based on file location
   - **Description:** Rich context with file links

4. **Advanced JIRA operations:**
   ```vim
   " Import from specific JIRA project
   :TodoImportExternal jira "project = MYPROJ AND status = 'To Do'"
   
   " Create with specific project
   :TodoCreateExternal 42 jira MYPROJ
   
   " Search JIRA issues
   :TodoSearchExternal jira "assignee = currentUser() AND priority = High"
   ```

## Integration Features

### Smart Context Detection

todo-mcp.nvim automatically adds context to external issues:

```lua
-- Detected context
{
  file_type = "typescript",
  directory = "components", 
  git_branch = "feature/user-search",
  tags = "frontend,react,typescript,component"
}
```

### Bidirectional Sync

- ✅ **Neovim → External:** Status changes sync to Linear/GitHub/JIRA
- ✅ **External → Neovim:** Import issues as TODOs
- ✅ **Conflict Resolution:** Manual merge for conflicts

### Priority Mapping

| TODO Type | Linear Priority | GitHub Label | JIRA Priority |
|-----------|----------------|--------------|---------------|
| FIXME     | Urgent (1)     | priority:high| High/Critical |
| TODO      | Medium (3)     | enhancement  | Medium        |
| HACK      | Low (4)        | tech-debt    | Low           |
| PERF      | Medium (3)     | performance  | Medium        |
| SECURITY  | Urgent (1)     | security     | Blocker       |

## API Reference

### Commands

```vim
" Create external issue from todo
:TodoCreateExternal <todo_id> [integration]

" Bulk create for all untracked TODOs
:TodoBulkCreateExternal [integration]

" Import external issues as TODOs
:TodoImportExternal [integration] [query]

" List available integrations
:TodoListIntegrations
```

### Lua API

```lua
local external = require('todo-mcp.integrations.external')

-- Create external issue
local issue = external.create_external_issue(42, "linear")

-- Sync status
external.sync_external_status(42, "done")

-- Bulk operations
local results = external.bulk_create_external_issues({
  priority = "high",
  unlinked_only = true
}, "github")

-- Import issues
local imported = external.import_external_issues("linear", "is:open assignee:me")
```

## Troubleshooting

### Common Issues

**1. "No MCP servers configured"**
- Check `mcp-config.json` exists and is valid
- Verify environment variables are set
- Check server permissions

**2. "Authentication failed"**
- Verify API tokens are correct and not expired
- Check token permissions (read/write access)
- Test tokens with curl:

```bash
# GitHub
curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user

# Linear  
curl -H "Authorization: Bearer $LINEAR_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{"query": "{ viewer { name } }"}' \
     https://api.linear.app/graphql
```

**3. "Repository not detected"**
- Set `GITHUB_REPO` environment variable
- Ensure you're in a git repository
- Check git remote configuration

### Debug Mode

Enable verbose logging:

```lua
require('todo-mcp').setup({
  integrations = {
    external = {
      enabled = true,
      debug = true  -- Enables verbose logging
    }
  }
})
```

### Performance Optimization

For large codebases:

```lua
require('todo-mcp').setup({
  integrations = {
    external = {
      enabled = true,
      batch_size = 10,     -- Limit concurrent requests
      rate_limit_ms = 200, -- Delay between requests  
      cache_ttl = 300      -- Cache external data for 5 minutes
    }
  }
})
```

## Advanced Configuration

### Custom Priority Mapping

```lua
require('todo-mcp.integrations.external').setup({
  priority_mapping = {
    github = {
      high = "priority:urgent",
      medium = "priority:medium", 
      low = "priority:low"
    },
    linear = {
      high = 1,    -- Urgent
      medium = 2,  -- High  
      low = 4      -- Low
    }
  }
})
```

### Webhook Integration

Set up webhooks for real-time sync:

```lua
-- Auto-sync on external changes
vim.api.nvim_create_autocmd("User", {
  pattern = "ExternalIssueChanged",
  callback = function(event)
    local todo_id = event.data.todo_id
    local new_status = event.data.status
    require('todo-mcp.db').update(todo_id, { status = new_status })
  end
})
```

## Contributing

Adding new integrations is straightforward:

1. **Create MCP server:** `mcp-servers/yourservice-server.lua`
2. **Add to integrations:** Update `INTEGRATIONS` table
3. **Add mapping functions:** Priority, status, and tag mapping
4. **Test thoroughly:** Create test cases
5. **Document:** Add to this guide

See `mcp-servers/linear-server.lua` as a reference implementation.

## Security Best Practices

- ✅ Store API tokens in environment variables, not config files
- ✅ Use read-only tokens when possible
- ✅ Rotate tokens regularly
- ✅ Review external permissions
- ✅ Use HTTPS for all API calls
- ❌ Never commit tokens to version control
- ❌ Don't share tokens in issue descriptions