-- Tests for external system integrations
local helpers = require('tests.helpers')

describe("External Integration", function()
  before_each(function()
    helpers.setup_test_env()
  end)
  
  after_each(function()
    helpers.cleanup_test_env()
  end)
  
  describe("integration availability", function()
    it("should detect available integrations", function()
      local external = require('todo-mcp.integrations.external')
      
      -- Mock MCP server availability
      local mock_mcp = {
        list_servers = function()
          return {
            { name = "github" },
            { name = "linear" }
          }
        end
      }
      
      package.loaded['todo-mcp.mcp'] = mock_mcp
      
      local available = external.get_available_integrations()
      
      assert.is_table(available)
      assert.is_not_nil(available.github)
      assert.is_not_nil(available.linear)
      assert.equals("GitHub Issues", available.github.name)
      assert.equals("Linear", available.linear.name)
    end)
  end)
  
  describe("priority mapping", function()
    it("should map GitHub labels to internal priorities", function()
      local external = require('todo-mcp.integrations.external')
      
      local github_issue = {
        labels = {
          { name = "priority:high" },
          { name = "bug" }
        }
      }
      
      local priority = external.map_external_priority(github_issue, "github")
      assert.equals("high", priority)
    end)
    
    it("should map Linear priorities to internal priorities", function()
      local external = require('todo-mcp.integrations.external')
      
      local linear_issue = {
        priority = 1 -- Urgent in Linear
      }
      
      local priority = external.map_external_priority(linear_issue, "linear")
      assert.equals("high", priority)
    end)
    
    it("should map JIRA priorities to internal priorities", function()
      local external = require('todo-mcp.integrations.external')
      
      local jira_issue = {
        fields = {
          priority = {
            name = "Critical"
          }
        }
      }
      
      local priority = external.map_external_priority(jira_issue, "jira")
      assert.equals("high", priority)
    end)
  end)
  
  describe("status mapping", function()
    it("should map GitHub closed status to done", function()
      local external = require('todo-mcp.integrations.external')
      
      local github_issue = { state = "closed" }
      local status = external.map_external_status(github_issue, "github")
      assert.equals("done", status)
    end)
    
    it("should map Linear 'In Progress' to in_progress", function()
      local external = require('todo-mcp.integrations.external')
      
      local linear_issue = {
        state = { name = "In Progress" }
      }
      
      local status = external.map_external_status(linear_issue, "linear")
      assert.equals("in_progress", status)
    end)
    
    it("should map JIRA 'Done' status to done", function()
      local external = require('todo-mcp.integrations.external')
      
      local jira_issue = {
        fields = {
          status = { name = "Done" }
        }
      }
      
      local status = external.map_external_status(jira_issue, "jira")
      assert.equals("done", status)
    end)
  end)
  
  describe("tag extraction", function()
    it("should extract GitHub labels as tags", function()
      local external = require('todo-mcp.integrations.external')
      
      local github_issue = {
        labels = {
          { name = "bug" },
          { name = "frontend" },
          { name = "priority:high" } -- Should be filtered out
        }
      }
      
      local tags = external.extract_external_tags(github_issue, "github")
      assert.matches("bug", tags)
      assert.matches("frontend", tags)
      assert.does_not_match("priority:high", tags)
    end)
    
    it("should extract JIRA components and issue type as tags", function()
      local external = require('todo-mcp.integrations.external')
      
      local jira_issue = {
        fields = {
          labels = {"backend", "api"},
          issuetype = { name = "Bug" },
          components = {
            { name = "Authentication" },
            { name = "Database" }
          }
        }
      }
      
      local tags = external.extract_external_tags(jira_issue, "jira")
      assert.matches("backend", tags)
      assert.matches("api", tags)
      assert.matches("bug", tags)
      assert.matches("authentication", tags)
      assert.matches("database", tags)
    end)
  end)
  
  describe("todo creation with external metadata", function()
    it("should create todo with external sync metadata", function()
      local db = require('todo-mcp.db')
      local external = require('todo-mcp.integrations.external')
      
      -- Mock successful external creation
      local mock_mcp = {
        call_tool = function(server, tool, args)
          return {
            success = true,
            issue = {
              number = 123,
              url = "https://github.com/test/repo/issues/123",
              id = "issue_123"
            }
          }
        end
      }
      
      package.loaded['todo-mcp.mcp'] = mock_mcp
      
      -- Create a test todo
      local todo_id = db.add("Test external sync", {
        title = "Test external sync",
        priority = "high",
        content = "TODO: Test creating external issue"
      })
      
      local result = external.create_external_issue(todo_id, "github")
      
      assert.is_not_nil(result)
      assert.equals(123, result.number)
      assert.matches("github.com", result.url)
      
      -- Verify metadata was updated
      local todos = db.get_all()
      local updated_todo = nil
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          updated_todo = todo
          break
        end
      end
      
      local metadata = vim.json.decode(updated_todo.metadata)
      assert.equals(123, metadata.issue_number)
      assert.is_not_nil(metadata.github_url)
      assert.is_true(metadata.external_sync)
    end)
  end)
  
  describe("error handling", function()
    it("should handle MCP server errors gracefully", function()
      local external = require('todo-mcp.integrations.external')
      
      -- Mock MCP error
      local mock_mcp = {
        call_tool = function(server, tool, args)
          return nil, "Authentication failed"
        end
      }
      
      package.loaded['todo-mcp.mcp'] = mock_mcp
      
      local db = require('todo-mcp.db')
      local todo_id = db.add("Test error handling", {
        title = "Test error handling"
      })
      
      local result, error = external.create_external_issue(todo_id, "github")
      
      assert.is_nil(result)
      assert.is_not_nil(error)
      assert.matches("Authentication failed", error)
    end)
    
    it("should handle unknown integration gracefully", function()
      local external = require('todo-mcp.integrations.external')
      
      local db = require('todo-mcp.db')
      local todo_id = db.add("Test unknown integration", {
        title = "Test unknown integration"
      })
      
      local result, error = external.create_external_issue(todo_id, "unknown_system")
      
      assert.is_nil(result)
      assert.matches("Unknown integration", error)
    end)
  end)
end)