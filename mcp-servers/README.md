# MCP Servers for todo-mcp.nvim

These are standalone MCP (Model Context Protocol) servers that integrate todo-mcp.nvim with external issue tracking systems.

## Available Servers

### GitHub Issues Server (`github-server.lua`)
Connects todos to GitHub issues via REST API.

### JIRA Server (`jira-server.lua`)
Connects todos to JIRA issues via REST API.

### Linear Server (`linear-server.lua`)
Connects todos to Linear issues via GraphQL API.

## Dependencies

All MCP servers require the following Lua libraries:

```bash
# Install using LuaRocks
luarocks install dkjson      # JSON parsing
luarocks install luasocket   # HTTP client and utilities
```

## Setup

1. Install dependencies:
   ```bash
   luarocks install dkjson luasocket
   ```

2. Configure your MCP client (e.g., in `mcp-config.json`):
   ```json
   {
     "servers": {
       "github": {
         "command": "lua",
         "args": ["path/to/mcp-servers/github-server.lua"],
         "env": {
           "GITHUB_TOKEN": "your_personal_access_token",
           "GITHUB_REPO": "owner/repo"
         }
       }
     }
   }
   ```

3. Each server requires specific environment variables:
   - **GitHub**: `GITHUB_TOKEN`, `GITHUB_REPO` (optional)
   - **JIRA**: `JIRA_URL`, `JIRA_EMAIL`, `JIRA_API_TOKEN`
   - **Linear**: `LINEAR_API_KEY`

## Features

All servers support:
- Creating issues from todos
- Updating issue status
- Searching issues
- Two-way synchronization

## Error Handling

The MCP servers are designed to be graceful and optional:

- **Missing dependencies**: Servers display helpful installation messages
- **Missing configuration**: Servers start normally but return configuration errors for tool calls
- **Optional by design**: Servers only activate when explicitly configured by the user

Example error responses:
```json
{
  "error": "GitHub integration not configured. Please set GITHUB_TOKEN environment variable.",
  "code": "configuration_error"
}
```

## Development

These servers are standalone Lua scripts that communicate via JSON-RPC over stdin/stdout following the MCP protocol specification.