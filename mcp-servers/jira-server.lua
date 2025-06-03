#!/usr/bin/env lua

--[[
JIRA MCP Server for todo-mcp.nvim
Connects todos to JIRA issues via REST API v3

Requirements:
- JIRA_URL environment variable (e.g., https://company.atlassian.net)
- JIRA_EMAIL environment variable
- JIRA_API_TOKEN environment variable (personal API token)

Usage:
In mcp-config.json:
{
  "servers": {
    "jira": {
      "command": "lua",
      "args": ["mcp-servers/jira-server.lua"],
      "env": {
        "JIRA_URL": "https://yourcompany.atlassian.net",
        "JIRA_EMAIL": "your.email@company.com",
        "JIRA_API_TOKEN": "your_api_token"
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

local ok, mime = pcall(require, 'mime')
if not ok then
  io.stderr:write("Error: Missing MIME library (part of LuaSocket). Install with: luarocks install luasocket\n")
  os.exit(1)
end

-- JIRA API configuration
local JIRA_URL = os.getenv("JIRA_URL")
local JIRA_EMAIL = os.getenv("JIRA_EMAIL") 
local JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")

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

-- JIRA API helpers
local function jira_request(endpoint, method, data)
  if not JIRA_URL or not JIRA_EMAIL or not JIRA_API_TOKEN then
    return nil, "JIRA environment variables not set (JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN)"
  end
  
  local url = JIRA_URL .. "/rest/api/3" .. endpoint
  local payload = data and json.encode(data) or nil
  
  -- Create basic auth header
  local auth_string = JIRA_EMAIL .. ":" .. JIRA_API_TOKEN
  local auth_encoded = mime.b64(auth_string)
  
  local response_body = {}
  local _, status = http.request({
    url = url,
    method = method or "GET",
    headers = {
      ["Accept"] = "application/json",
      ["Authorization"] = "Basic " .. auth_encoded,
      ["Content-Type"] = payload and "application/json" or nil,
      ["Content-Length"] = payload and tostring(#payload) or nil
    },
    source = payload and ltn12.source.string(payload) or nil,
    sink = ltn12.sink.table(response_body)
  })
  
  local response_text = table.concat(response_body)
  
  if status >= 400 then
    local error_data = json.decode(response_text) or {}
    local error_msg = "JIRA API error " .. status
    if error_data.errorMessages then
      error_msg = error_msg .. ": " .. table.concat(error_data.errorMessages, ", ")
    end
    return nil, error_msg
  end
  
  return json.decode(response_text)
end

-- Get JIRA projects
local function get_projects()
  return jira_request("/project")
end

-- Get issue types for a project
local function get_issue_types(project_key)
  local endpoint = "/issue/createmeta?projectKeys=" .. project_key .. "&expand=projects.issuetypes"
  return jira_request(endpoint)
end

-- Get JIRA priorities
local function get_priorities()
  return jira_request("/priority")
end

-- Create JIRA issue from todo
local function create_issue(todo_data)
  -- Get project info first
  local projects = get_projects()
  if not projects or #projects == 0 then
    return nil, "No JIRA projects found or no access"
  end
  
  -- Use first accessible project or specified project
  local project_key = todo_data.project_key or projects[1].key
  local project_id = nil
  
  for _, project in ipairs(projects) do
    if project.key == project_key then
      project_id = project.id
      break
    end
  end
  
  if not project_id then
    return nil, "Project not found: " .. project_key
  end
  
  -- Get issue types for this project
  local meta_response = get_issue_types(project_key)
  if not meta_response or not meta_response.projects or #meta_response.projects == 0 then
    return nil, "Could not get issue types for project: " .. project_key
  end
  
  local issue_types = meta_response.projects[1].issuetypes
  local issue_type_id = nil
  
  -- Find appropriate issue type (prefer Task, Story, or Bug)
  local preferred_types = {"Task", "Story", "Bug", "Sub-task"}
  for _, preferred in ipairs(preferred_types) do
    for _, issue_type in ipairs(issue_types) do
      if issue_type.name == preferred then
        issue_type_id = issue_type.id
        break
      end
    end
    if issue_type_id then break end
  end
  
  -- Fallback to first available issue type
  if not issue_type_id and #issue_types > 0 then
    issue_type_id = issue_types[1].id
  end
  
  if not issue_type_id then
    return nil, "No suitable issue type found"
  end
  
  -- Extract context from metadata
  local metadata = todo_data.metadata and json.decode(todo_data.metadata) or {}
  local context = metadata.context or {}
  
  -- Build description with context
  local description_parts = {
    todo_data.content or todo_data.title,
    "",
    "h3. Context",
    ""
  }
  
  if todo_data.file_path then
    table.insert(description_parts, "* *File:* " .. todo_data.file_path)
    
    if todo_data.line_number then
      table.insert(description_parts, "* *Line:* " .. todo_data.line_number)
    end
  end
  
  if context.git_branch then
    table.insert(description_parts, "* *Branch:* " .. context.git_branch)
  end
  
  if context.filetype then
    table.insert(description_parts, "* *Language:* " .. context.filetype)
  end
  
  if todo_data.tags then
    table.insert(description_parts, "* *Tags:* " .. todo_data.tags)
  end
  
  table.insert(description_parts, "")
  table.insert(description_parts, "_Issue created from todo-mcp.nvim_")
  
  -- Map priority
  local priority_map = {
    high = "High",
    medium = "Medium", 
    low = "Low"
  }
  
  local jira_priority = priority_map[todo_data.priority] or "Medium"
  
  -- Build issue data
  local issue_data = {
    fields = {
      project = {
        key = project_key
      },
      summary = todo_data.title or "TODO from code",
      description = {
        type = "doc",
        version = 1,
        content = {
          {
            type = "paragraph",
            content = {
              {
                type = "text",
                text = table.concat(description_parts, "\n")
              }
            }
          }
        }
      },
      issuetype = {
        id = issue_type_id
      }
    }
  }
  
  -- Add priority if supported
  local priorities = get_priorities()
  if priorities then
    for _, priority in ipairs(priorities) do
      if priority.name == jira_priority then
        issue_data.fields.priority = { id = priority.id }
        break
      end
    end
  end
  
  -- Add labels based on context
  local labels = {}
  if metadata.original_tag then
    table.insert(labels, string.lower(metadata.original_tag))
  end
  
  if context.tags then
    for tag in context.tags:gmatch("[^,]+") do
      table.insert(labels, tag:gsub("^%s*(.-)%s*$", "%1"):gsub("[^%w%-_]", ""):lower())
    end
  end
  
  if #labels > 0 then
    issue_data.fields.labels = labels
  end
  
  return jira_request("/issue", "POST", issue_data)
end

-- Get available transitions for an issue
local function get_issue_transitions(issue_key)
  local endpoint = "/issue/" .. issue_key .. "/transitions"
  return jira_request(endpoint)
end

-- Find appropriate transition for status
local function find_status_transition(transitions, target_status)
  if not transitions or not transitions.transitions then
    return nil
  end
  
  local status_map = {
    todo = {"To Do", "Open", "Backlog"},
    in_progress = {"In Progress", "In Development", "In Review"},
    done = {"Done", "Closed", "Resolved", "Complete"}
  }
  
  local target_names = status_map[target_status] or {}
  
  for _, transition in ipairs(transitions.transitions) do
    for _, name in ipairs(target_names) do
      if transition.to and transition.to.name and 
         transition.to.name:lower() == name:lower() then
        return transition
      end
    end
  end
  
  return nil
end

-- Update JIRA issue
local function update_issue(issue_key, updates)
  local endpoint = "/issue/" .. issue_key
  
  local update_data = {
    fields = {}
  }
  
  -- Handle status transitions separately
  if updates.status then
    local transitions = get_issue_transitions(issue_key)
    local target_transition = find_status_transition(transitions, updates.status)
    
    if target_transition then
      local transition_result = jira_request(endpoint .. "/transitions", "POST", {
        transition = { id = target_transition.id }
      })
      
      if not transition_result then
        return nil, "Failed to transition issue status"
      end
    end
  end
  
  -- Handle other field updates
  for field, value in pairs(updates) do
    if field ~= "status" then
      update_data.fields[field] = value
    end
  end
  
  if next(update_data.fields) then
    return jira_request(endpoint, "PUT", update_data)
  end
  
  return { success = true }
end

-- Search JIRA issues
local function search_issues(jql_query, max_results)
  max_results = max_results or 50
  
  local endpoint = "/search"
  local query_data = {
    jql = jql_query,
    maxResults = max_results,
    fields = {"summary", "description", "status", "priority", "assignee", "created", "updated"}
  }
  
  return jira_request(endpoint, "POST", query_data)
end

-- Get issue details
local function get_issue(issue_key)
  local endpoint = "/issue/" .. issue_key
  return jira_request(endpoint)
end

-- MCP method handlers
local function handle_list_tools()
  return {
    tools = {
      {
        name = "create_jira_issue",
        description = "Create a JIRA issue from a todo item",
        inputSchema = {
          type = "object",
          properties = {
            title = { type = "string", description = "Issue summary" },
            content = { type = "string", description = "Issue description" },
            priority = { type = "string", enum = {"high", "medium", "low"} },
            tags = { type = "string", description = "Comma-separated tags" },
            file_path = { type = "string", description = "Source file path" },
            line_number = { type = "number", description = "Source line number" },
            metadata = { type = "string", description = "JSON metadata" },
            project_key = { type = "string", description = "JIRA project key (optional)" },
            issue_type = { type = "string", description = "JIRA issue type (optional)" }
          },
          required = {"title"}
        }
      },
      {
        name = "update_jira_issue",
        description = "Update a JIRA issue status or fields",
        inputSchema = {
          type = "object",
          properties = {
            issue_key = { type = "string", description = "JIRA issue key (e.g., PROJ-123)" },
            status = { type = "string", enum = {"todo", "in_progress", "done"} },
            summary = { type = "string", description = "Updated summary" },
            priority = { type = "string", enum = {"high", "medium", "low"} }
          },
          required = {"issue_key"}
        }
      },
      {
        name = "search_jira_issues",
        description = "Search JIRA issues using JQL",
        inputSchema = {
          type = "object",
          properties = {
            jql = { type = "string", description = "JQL query string" },
            max_results = { type = "number", description = "Maximum results to return" }
          },
          required = {"jql"}
        }
      },
      {
        name = "get_jira_issue",
        description = "Get detailed information about a specific JIRA issue",
        inputSchema = {
          type = "object",
          properties = {
            issue_key = { type = "string", description = "JIRA issue key (e.g., PROJ-123)" }
          },
          required = {"issue_key"}
        }
      },
      {
        name = "get_jira_projects",
        description = "Get available JIRA projects",
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
  
  if tool_name == "create_jira_issue" then
    local result, err = create_issue(args)
    if err then
      return { error = err }
    end
    
    return {
      success = true,
      issue = {
        key = result.key,
        id = result.id,
        summary = args.title,
        url = JIRA_URL .. "/browse/" .. result.key,
        self = result.self
      }
    }
    
  elseif tool_name == "update_jira_issue" then
    local result, err = update_issue(args.issue_key, args)
    if err then
      return { error = err }
    end
    
    return { success = true, updated = result }
    
  elseif tool_name == "search_jira_issues" then
    local result, err = search_issues(args.jql, args.max_results)
    if err then
      return { error = err }
    end
    
    return {
      total = result.total,
      issues = result.issues
    }
    
  elseif tool_name == "get_jira_issue" then
    local result, err = get_issue(args.issue_key)
    if err then
      return { error = err }
    end
    
    return { issue = result }
    
  elseif tool_name == "get_jira_projects" then
    local result, err = get_projects()
    if err then
      return { error = err }
    end
    
    return { projects = result }
    
  else
    return { error = "Unknown tool: " .. tool_name }
  end
end

-- Main MCP message loop
local function main()
  if not JIRA_URL or not JIRA_EMAIL or not JIRA_API_TOKEN then
    io.stderr:write("Error: JIRA environment variables not set\n")
    io.stderr:write("Required: JIRA_URL, JIRA_EMAIL, JIRA_API_TOKEN\n")
    os.exit(1)
  end
  
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
          name = "jira-server",
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