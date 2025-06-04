#!/usr/bin/env lua

--[[
Linear MCP Server for todo-mcp.nvim
Connects todos to Linear issues via GraphQL API

Requirements:
- LINEAR_API_KEY environment variable
- Linear team/workspace access

Usage:
In mcp-config.json:
{
  "servers": {
    "linear": {
      "command": "lua",
      "args": ["mcp-servers/linear-server.lua"],
      "env": {
        "LINEAR_API_KEY": "your_api_key"
      }
    }
  }
}
--]]

-- Check for required dependencies
local ok, json = pcall(require, 'dkjson')
if not ok then
  json = nil
  ok, json = pcall(require, 'json')
end
if not ok or not json then
  io.stderr:write("Error: Missing JSON library. Install with: luarocks install dkjson\n")
  os.exit(1)
end

local ok, http = pcall(require, 'socket.http')
if not ok then
  io.stderr:write("Error: Missing LuaSocket. Install with: luarocks install luasocket\n")
  os.exit(1)
end

local ok, ltn12 = pcall(require, 'ltn12')
if not ok then
  io.stderr:write("Error: Missing LTN12 (part of LuaSocket). Install with: luarocks install luasocket\n")
  os.exit(1)
end

-- Linear GraphQL endpoint
local LINEAR_API = "https://api.linear.app/graphql"
local API_KEY = os.getenv("LINEAR_API_KEY")

-- MCP Protocol helpers
local function send_response(id, result)
  local response = {
    jsonrpc = "2.0",
    id = id,
    result = result
  }
  print(json.encode(response))
  io.flush()
end

local function send_error(id, code, message)
  local response = {
    jsonrpc = "2.0",
    id = id,
    error = {
      code = code,
      message = message
    }
  }
  print(json.encode(response))
  io.flush()
end

-- Linear API helpers
local function linear_request(query, variables)
  if not API_KEY then
    return nil, "LINEAR_API_KEY environment variable not set"
  end
  
  local payload = json.encode({
    query = query,
    variables = variables or {}
  })
  
  local response_body = {}
  local _, status = http.request({
    url = LINEAR_API,
    method = "POST",
    headers = {
      ["Content-Type"] = "application/json",
      ["Authorization"] = "Bearer " .. API_KEY,
      ["Content-Length"] = tostring(#payload)
    },
    source = ltn12.source.string(payload),
    sink = ltn12.sink.table(response_body)
  })
  
  if status ~= 200 then
    return nil, "Linear API request failed with status " .. status
  end
  
  local response_text = table.concat(response_body)
  local response_data = json.decode(response_text)
  
  if response_data.errors then
    return nil, "Linear API error: " .. json.encode(response_data.errors)
  end
  
  return response_data.data
end

-- Get user teams and projects
local function get_teams()
  local query = [[
    query {
      teams {
        nodes {
          id
          name
          key
          projects {
            nodes {
              id
              name
              state
            }
          }
        }
      }
    }
  ]]
  
  return linear_request(query)
end

-- Create Linear issue from todo
local function create_issue(todo_data)
  local teams = get_teams()
  if not teams or not teams.teams or not teams.teams.nodes[1] then
    return nil, "No Linear teams found"
  end
  
  local team = teams.teams.nodes[1] -- Use first team
  
  -- Map todo priority to Linear priority
  local priority_map = {
    high = 1,    -- Urgent
    medium = 3,  -- Medium  
    low = 4      -- Low
  }
  
  local query = [[
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue {
          id
          identifier
          title
          url
          state {
            name
          }
        }
      }
    }
  ]]
  
  -- Extract context from metadata
  local metadata = todo_data.metadata and json.decode(todo_data.metadata) or {}
  local context = metadata.context or {}
  
  -- Build description with context
  local description_parts = {
    todo_data.content or todo_data.title,
    "",
    "**Context:**"
  }
  
  if todo_data.file_path then
    table.insert(description_parts, "- File: `" .. todo_data.file_path .. "`")
  end
  
  if todo_data.line_number then
    table.insert(description_parts, "- Line: " .. todo_data.line_number)
  end
  
  if context.git_branch then
    table.insert(description_parts, "- Branch: `" .. context.git_branch .. "`")
  end
  
  if context.filetype then
    table.insert(description_parts, "- File type: " .. context.filetype)
  end
  
  table.insert(description_parts, "")
  table.insert(description_parts, "_Created from todo-mcp.nvim_")
  
  local variables = {
    input = {
      teamId = team.id,
      title = todo_data.title or "TODO from code",
      description = table.concat(description_parts, "\n"),
      priority = priority_map[todo_data.priority] or 3,
      -- Add labels based on tags
      labelIds = {},
    }
  }
  
  -- Add project if available
  if team.projects and team.projects.nodes[1] then
    variables.input.projectId = team.projects.nodes[1].id
  end
  
  return linear_request(query, variables)
end

-- Update Linear issue status
local function update_issue_status(issue_id, status)
  local status_map = {
    todo = "Todo",
    in_progress = "In Progress", 
    done = "Done"
  }
  
  local query = [[
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue {
          id
          state {
            name
          }
        }
      }
    }
  ]]
  
  -- First get workflow states to find the right state ID
  local states_query = [[
    query {
      workflowStates {
        nodes {
          id
          name
          type
        }
      }
    }
  ]]
  
  local states_data = linear_request(states_query)
  if not states_data then
    return nil, "Failed to get workflow states"
  end
  
  local target_state_name = status_map[status] or "Todo"
  local state_id = nil
  
  for _, state in ipairs(states_data.workflowStates.nodes) do
    if state.name == target_state_name then
      state_id = state.id
      break
    end
  end
  
  if not state_id then
    return nil, "Workflow state not found: " .. target_state_name
  end
  
  local variables = {
    id = issue_id,
    input = {
      stateId = state_id
    }
  }
  
  return linear_request(query, variables)
end

-- MCP method handlers
local function handle_list_tools()
  return {
    tools = {
      {
        name = "create_linear_issue",
        description = "Create a Linear issue from a todo item",
        inputSchema = {
          type = "object",
          properties = {
            title = { type = "string", description = "Issue title" },
            content = { type = "string", description = "Issue description" },
            priority = { type = "string", enum = {"high", "medium", "low"} },
            tags = { type = "string", description = "Comma-separated tags" },
            file_path = { type = "string", description = "Source file path" },
            line_number = { type = "number", description = "Source line number" },
            metadata = { type = "string", description = "JSON metadata" }
          },
          required = {"title"}
        }
      },
      {
        name = "update_linear_issue",
        description = "Update a Linear issue status",
        inputSchema = {
          type = "object", 
          properties = {
            issue_id = { type = "string", description = "Linear issue ID" },
            status = { type = "string", enum = {"todo", "in_progress", "done"} }
          },
          required = {"issue_id", "status"}
        }
      },
      {
        name = "get_linear_teams",
        description = "Get available Linear teams and projects",
        inputSchema = {
          type = "object",
          properties = {}
        }
      }
    }
  }
end

local function handle_call_tool(params)
  local tool_name = params.name
  local args = params.arguments
  
  -- Check configuration before processing any tool calls
  if not API_KEY then
    return { 
      error = "Linear integration not configured. Please set LINEAR_API_KEY environment variable.",
      code = "configuration_error"
    }
  end
  
  if tool_name == "create_linear_issue" then
    local result, err = create_issue(args)
    if err then
      return { error = err }
    end
    
    if result and result.issueCreate and result.issueCreate.success then
      local issue = result.issueCreate.issue
      return {
        success = true,
        issue = {
          id = issue.id,
          identifier = issue.identifier,
          title = issue.title,
          url = issue.url,
          state = issue.state.name
        }
      }
    else
      return { error = "Failed to create Linear issue" }
    end
    
  elseif tool_name == "update_linear_issue" then
    local result, err = update_issue_status(args.issue_id, args.status)
    if err then
      return { error = err }
    end
    
    return { success = true, updated = result }
    
  elseif tool_name == "get_linear_teams" then
    local result, err = get_teams()
    if err then
      return { error = err }
    end
    
    return { teams = result.teams.nodes }
    
  else
    return { error = "Unknown tool: " .. tool_name }
  end
end

-- Main MCP message loop
local function main()
  -- Don't exit immediately - respond to MCP protocol messages
  -- Configuration errors will be handled per-request
  
  while true do
    local line = io.read("*line")
    if not line then break end
    
    local ok, request = pcall(json.decode, line)
    if not ok then
      send_error(nil, -32700, "Parse error")
      goto continue
    end
    
    local method = request.method
    local id = request.id
    local params = request.params or {}
    
    if method == "initialize" then
      send_response(id, {
        capabilities = {
          tools = { listChanged = false }
        },
        serverInfo = {
          name = "linear-server",
          version = "1.0.0"
        }
      })
      
    elseif method == "tools/list" then
      send_response(id, handle_list_tools())
      
    elseif method == "tools/call" then
      local result = handle_call_tool(params)
      send_response(id, result)
      
    else
      send_error(id, -32601, "Method not found: " .. (method or "unknown"))
    end
    
    ::continue::
  end
end

-- Run the server
main()