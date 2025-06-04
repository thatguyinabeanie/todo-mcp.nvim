#!/usr/bin/env lua

--[[
GitHub Issues MCP Server for todo-mcp.nvim
Connects todos to GitHub issues via REST API

Requirements:
- GITHUB_TOKEN environment variable (personal access token)
- Repository access permissions

Usage:
In mcp-config.json:
{
  "servers": {
    "github": {
      "command": "lua",
      "args": ["mcp-servers/github-server.lua"],
      "env": {
        "GITHUB_TOKEN": "your_personal_access_token"
      }
    }
  }
}

The server will automatically detect the GitHub repository from the current
git directory's origin remote. If you need to override this, you can set:
  "GITHUB_REPO": "owner/repo"
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

local ok_http, http = pcall(require, 'socket.http')
if not ok_http then
  io.stderr:write("Error: Missing LuaSocket. Install with: luarocks install luasocket\n")
  os.exit(1)
end

local ok_ltn12, ltn12 = pcall(require, 'ltn12')
if not ok_ltn12 then
  io.stderr:write("Error: Missing LTN12 (part of LuaSocket). Install with: luarocks install luasocket\n")
  os.exit(1)
end

-- GitHub API configuration
local GITHUB_API = "https://api.github.com"
local GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
local GITHUB_REPO = os.getenv("GITHUB_REPO")

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

-- GitHub API helpers
local function github_request(endpoint, method, data)
  if not GITHUB_TOKEN then
    return nil, "GITHUB_TOKEN environment variable not set"
  end

  local url = GITHUB_API .. endpoint
  local payload = data and json.encode(data) or nil

  local response_body = {}
  local _, status = http.request({
    url = url,
    method = method or "GET",
    headers = {
      ["Accept"] = "application/vnd.github+json",
      ["Authorization"] = "Bearer " .. GITHUB_TOKEN,
      ["X-GitHub-Api-Version"] = "2022-11-28",
      ["User-Agent"] = "todo-mcp-nvim/1.0",
      ["Content-Type"] = payload and "application/json" or nil,
      ["Content-Length"] = payload and tostring(#payload) or nil
    },
    source = payload and ltn12.source.string(payload) or nil,
    sink = ltn12.sink.table(response_body)
  })

  local response_text = table.concat(response_body)

  if status >= 400 then
    local error_data = json.decode(response_text) or {}
    return nil, "GitHub API error " .. status .. ": " .. (error_data.message or "Unknown error")
  end

  return json.decode(response_text)
end

-- Auto-detect repository from git remote
local function detect_repository()
  if GITHUB_REPO then
    return GITHUB_REPO
  end

  -- Try to get from git remote
  local handle = io.popen("git remote get-url origin 2>/dev/null")
  if handle then
    local remote_url = handle:read("*line")
    handle:close()

    if remote_url then
      -- Parse GitHub URL patterns
      -- HTTPS: https://github.com/owner/repo.git
      local owner, repo = remote_url:match("github%.com[:/]([^/]+)/([^/%.]+)")
      if owner and repo then
        -- Remove .git suffix if present
        repo = repo:gsub("%.git$", "")
        return owner .. "/" .. repo
      end
      
      -- SSH: git@github.com:owner/repo.git
      owner, repo = remote_url:match("git@github%.com:([^/]+)/([^/%.]+)")
      if owner and repo then
        -- Remove .git suffix if present
        repo = repo:gsub("%.git$", "")
        return owner .. "/" .. repo
      end
    end
  end

  -- Fallback: try to detect from current directory name and git config
  handle = io.popen("basename $(git rev-parse --show-toplevel) 2>/dev/null")
  if handle then
    local repo_name = handle:read("*line")
    handle:close()
    
    if repo_name then
      -- Try to get GitHub username from git config
      handle = io.popen("git config --get user.name 2>/dev/null")
      if handle then
        local username = handle:read("*line")
        handle:close()
        
        if username then
          io.stderr:write("Warning: Could not detect GitHub repo from remote. Using fallback: " .. username .. "/" .. repo_name .. "\n")
          return username .. "/" .. repo_name
        end
      end
    end
  end

  return nil
end

-- Get repository labels
local function get_labels(repo)
  local endpoint = "/repos/" .. repo .. "/labels"
  return github_request(endpoint)
end

-- Get repository milestones
local function get_milestones(repo)
  local endpoint = "/repos/" .. repo .. "/milestones"
  return github_request(endpoint)
end

-- Create GitHub issue from todo
local function create_issue(todo_data)
  local repo = detect_repository()
  if not repo then
    return nil, "Could not detect GitHub repository. Set GITHUB_REPO environment variable."
  end

  -- Extract context from metadata
  local metadata = todo_data.metadata and json.decode(todo_data.metadata) or {}
  local context = metadata.context or {}

  -- Build issue body with context
  local body_parts = {
    todo_data.content or todo_data.title,
    "",
    "## Context",
    ""
  }

  if todo_data.file_path then
    local line_ref = todo_data.line_number and ("#L" .. todo_data.line_number) or ""
    table.insert(body_parts, "- **File:** [`" .. todo_data.file_path .. line_ref .. "`](" ..
                 "https://github.com/" .. repo .. "/blob/main/" .. todo_data.file_path .. line_ref .. ")")
  end

  if context.git_branch then
    table.insert(body_parts, "- **Branch:** `" .. context.git_branch .. "`")
  end

  if context.filetype then
    table.insert(body_parts, "- **Language:** " .. context.filetype)
  end

  if todo_data.tags then
    table.insert(body_parts, "- **Tags:** " .. todo_data.tags)
  end

  table.insert(body_parts, "")
  table.insert(body_parts, "_Issue created from todo-mcp.nvim_")

  -- Build labels array
  local labels = {}

  -- Add priority label
  if todo_data.priority then
    table.insert(labels, "priority:" .. todo_data.priority)
  end

  -- Add type label based on original TODO tag
  if metadata.original_tag then
    local tag_labels = {
      TODO = "enhancement",
      FIXME = "bug",
      FIX = "bug",
      HACK = "technical debt",
      PERF = "performance",
      NOTE = "documentation"
    }
    local label = tag_labels[metadata.original_tag]
    if label then
      table.insert(labels, label)
    end
  end

  -- Add context-based labels
  if context.tags then
    for tag in context.tags:gmatch("[^,]+") do
      table.insert(labels, tag:gsub("^%s*(.-)%s*$", "%1"))
    end
  end

  local issue_data = {
    title = todo_data.title or "TODO from code",
    body = table.concat(body_parts, "\n"),
    labels = labels
  }

  local endpoint = "/repos/" .. repo .. "/issues"
  return github_request(endpoint, "POST", issue_data)
end

-- Update GitHub issue
local function update_issue(issue_number, updates, repo)
  repo = repo or detect_repository()
  if not repo then
    return nil, "Could not detect GitHub repository"
  end

  local endpoint = "/repos/" .. repo .. "/issues/" .. issue_number
  return github_request(endpoint, "PATCH", updates)
end

-- Close/reopen issue based on status
local function update_issue_status(issue_number, status, repo)
  local state_map = {
    todo = "open",
    in_progress = "open",
    done = "closed"
  }

  local updates = {
    state = state_map[status] or "open"
  }

  -- Add comment for status changes
  if status == "in_progress" then
    local comment_data = {
      body = "🚧 Started working on this issue (updated from todo-mcp.nvim)"
    }
    local comment_endpoint = "/repos/" .. (repo or detect_repository()) .. "/issues/" .. issue_number .. "/comments"
    github_request(comment_endpoint, "POST", comment_data)
  elseif status == "done" then
    local comment_data = {
      body = "✅ Completed (updated from todo-mcp.nvim)"
    }
    local comment_endpoint = "/repos/" .. (repo or detect_repository()) .. "/issues/" .. issue_number .. "/comments"
    github_request(comment_endpoint, "POST", comment_data)
  end

  return update_issue(issue_number, updates, repo)
end

-- Search issues by title/content
local function search_issues(query, repo)
  repo = repo or detect_repository()
  if not repo then
    return nil, "Could not detect GitHub repository"
  end

  local search_query = query .. " repo:" .. repo
  local endpoint = "/search/issues?q=" .. search_query:gsub(" ", "+")

  return github_request(endpoint)
end

-- MCP method handlers
local function handle_list_tools()
  return {
    tools = {
      {
        name = "create_github_issue",
        description = "Create a GitHub issue from a todo item",
        inputSchema = {
          type = "object",
          properties = {
            title = { type = "string", description = "Issue title" },
            content = { type = "string", description = "Issue description" },
            priority = { type = "string", enum = {"high", "medium", "low"} },
            tags = { type = "string", description = "Comma-separated tags" },
            file_path = { type = "string", description = "Source file path" },
            line_number = { type = "number", description = "Source line number" },
            metadata = { type = "string", description = "JSON metadata" },
            repo = { type = "string", description = "Repository (owner/repo), optional" }
          },
          required = {"title"}
        }
      },
      {
        name = "update_github_issue",
        description = "Update a GitHub issue status",
        inputSchema = {
          type = "object",
          properties = {
            issue_number = { type = "number", description = "GitHub issue number" },
            status = { type = "string", enum = {"todo", "in_progress", "done"} },
            repo = { type = "string", description = "Repository (owner/repo), optional" }
          },
          required = {"issue_number", "status"}
        }
      },
      {
        name = "search_github_issues",
        description = "Search GitHub issues",
        inputSchema = {
          type = "object",
          properties = {
            query = { type = "string", description = "Search query" },
            repo = { type = "string", description = "Repository (owner/repo), optional" }
          },
          required = {"query"}
        }
      },
      {
        name = "get_github_repo_info",
        description = "Get GitHub repository information",
        inputSchema = {
          type = "object",
          properties = {
            repo = { type = "string", description = "Repository (owner/repo), optional" }
          }
        }
      }
    }
  }
end

local function handle_call_tool(params)
  local tool_name = params.name
  local args = params.arguments

  -- Check configuration before processing any tool calls
  if not GITHUB_TOKEN then
    return { 
      error = "GitHub integration not configured. Please set GITHUB_TOKEN environment variable.",
      code = "configuration_error"
    }
  end

  if tool_name == "create_github_issue" then
    local result, err = create_issue(args)
    if err then
      return { error = err }
    end

    return {
      success = true,
      issue = {
        number = result.number,
        title = result.title,
        url = result.html_url,
        state = result.state,
        labels = result.labels
      }
    }

  elseif tool_name == "update_github_issue" then
    local result, err = update_issue_status(args.issue_number, args.status, args.repo)
    if err then
      return { error = err }
    end

    return { success = true, updated = result }

  elseif tool_name == "search_github_issues" then
    local result, err = search_issues(args.query, args.repo)
    if err then
      return { error = err }
    end

    return {
      total_count = result.total_count,
      issues = result.items
    }

  elseif tool_name == "get_github_repo_info" then
    local repo = args.repo or detect_repository()
    if not repo then
      return { error = "Could not detect repository" }
    end

    local repo_info = github_request("/repos/" .. repo)
    local labels = get_labels(repo)
    local milestones = get_milestones(repo)

    return {
      repository = repo,
      info = repo_info,
      labels = labels,
      milestones = milestones
    }

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

    local ok_decode, request = pcall(json.decode, line)
    if not ok_decode then
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
          name = "github-server",
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