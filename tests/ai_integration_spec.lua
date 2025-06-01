-- Tests for AI-powered features
local helpers = require('tests.helpers')

describe("AI Integration", function()
  before_each(function()
    helpers.setup_test_env()
  end)
  
  after_each(function()
    helpers.cleanup_test_env()
  end)
  
  describe("context detection", function()
    it("should detect file structure patterns", function()
      local ai_context = require('todo-mcp.ai.context')
      
      local context = ai_context.analyze_file_structure("/src/components/UserProfile.tsx")
      
      assert.equals("tsx", context.file_type)
      assert.equals("presentation", context.architectural_layer)
      assert.is_true(context.naming_patterns.test_file == nil) -- Not a test file
    end)
    
    it("should identify test files", function()
      local ai_context = require('todo-mcp.ai.context')
      
      local context = ai_context.analyze_file_structure("/tests/auth.test.js")
      
      assert.equals("js", context.file_type)
      assert.is_true(context.naming_patterns.test_file)
    end)
    
    it("should detect code patterns from surrounding lines", function()
      local ai_context = require('todo-mcp.ai.context')
      
      local surrounding_lines = {
        "function authenticateUser(req, res, next) {",
        "  if (!req.headers.authorization) {",
        "    throw new Error('Missing auth header');",
        "  }",
        "  // More auth logic",
        "}"
      }
      
      local context = ai_context.analyze_code_context(
        "// TODO: Add rate limiting",
        surrounding_lines
      )
      
      assert.is_true(context.code_patterns.function_definition)
      assert.is_true(context.code_patterns.error_handling)
      assert.is_true(context.code_patterns.security_related)
    end)
  end)
  
  describe("priority estimation", function()
    it("should estimate high priority for security issues", function()
      local ai_estimation = require('todo-mcp.ai.estimation')
      
      local todo_data = {
        text = "TODO: Fix SQL injection vulnerability in user login"
      }
      
      local context_data = {
        code_analysis = {
          code_patterns = { security_related = true },
          complexity_indicators = { complexity_level = "medium" }
        }
      }
      
      local estimation = ai_estimation.estimate_priority(todo_data, context_data)
      
      assert.equals("high", estimation.level)
      assert.is_true(estimation.score > 6)
      assert.matches("security", estimation.reasoning:lower())
    end)
    
    it("should estimate lower priority for documentation tasks", function()
      local ai_estimation = require('todo-mcp.ai.estimation')
      
      local todo_data = {
        text = "TODO: Add JSDoc comments to helper functions"
      }
      
      local context_data = {
        code_analysis = {
          code_patterns = {},
          complexity_indicators = { complexity_level = "low" }
        }
      }
      
      local estimation = ai_estimation.estimate_priority(todo_data, context_data)
      
      assert.equals("low", estimation.level)
      assert.is_true(estimation.score < 4)
    end)
  end)
  
  describe("effort estimation", function()
    it("should estimate large effort for system rewrites", function()
      local ai_estimation = require('todo-mcp.ai.estimation')
      
      local todo_data = {
        text = "TODO: Rewrite authentication system to use OAuth2"
      }
      
      local context_data = {
        code_analysis = {
          complexity_indicators = { complexity_level = "high" }
        }
      }
      
      local estimation = ai_estimation.estimate_effort(todo_data, context_data)
      
      assert.is_true(estimation.level == "large" or estimation.level == "xl")
      assert.is_true(estimation.story_points >= 8)
      assert.is_true(estimation.hours_estimate.min >= 16)
    end)
    
    it("should estimate small effort for simple fixes", function()
      local ai_estimation = require('todo-mcp.ai.estimation')
      
      local todo_data = {
        text = "TODO: Fix typo in error message"
      }
      
      local context_data = {
        code_analysis = {
          complexity_indicators = { complexity_level = "low" }
        }
      }
      
      local estimation = ai_estimation.estimate_effort(todo_data, context_data)
      
      assert.is_true(estimation.level == "small" or estimation.level == "xs")
      assert.is_true(estimation.story_points <= 3)
      assert.is_true(estimation.hours_estimate.max <= 4)
    end)
  end)
  
  describe("enhanced todo tracking", function()
    it("should enhance TODO with AI insights when enabled", function()
      -- Create a test file with a security-related TODO
      local test_file = helpers.create_test_file("auth.js", {
        "function validateToken(token) {",
        "  // TODO: Add token expiration check",
        "  return jwt.verify(token, secret);",
        "}"
      })
      
      vim.cmd("edit " .. test_file)
      vim.api.nvim_win_set_cursor(0, {2, 0})
      
      -- Enable AI enhancement
      local tc_integration = require('todo-mcp.integrations.todo-comments')
      tc_integration.config.ai_enhanced = true
      
      local todo_comment = tc_integration.get_todo_at_cursor()
      local todo_id = tc_integration.track_todo(todo_comment)
      
      local db = require('todo-mcp.db')
      local todos = db.get_all()
      
      local tracked_todo = nil
      for _, todo in ipairs(todos) do
        if todo.id == todo_id then
          tracked_todo = todo
          break
        end
      end
      
      assert.is_not_nil(tracked_todo)
      
      local metadata = vim.json.decode(tracked_todo.metadata)
      assert.is_not_nil(metadata.ai_estimation)
      assert.is_true(metadata.ai_enhanced)
      
      -- Should detect security context and boost priority
      assert.is_true(tracked_todo.priority == "high" or tracked_todo.priority == "medium")
    end)
  end)
  
  describe("batch analysis", function()
    it("should analyze multiple TODOs and suggest improvements", function()
      local db = require('todo-mcp.db')
      
      -- Add some test TODOs
      db.add("Fix critical security bug", {
        title = "Fix critical security bug",
        priority = "low", -- Incorrectly prioritized
        content = "TODO: Fix SQL injection in login endpoint"
      })
      
      db.add("Update documentation", {
        title = "Update documentation", 
        priority = "high", -- Incorrectly prioritized
        content = "TODO: Add comments to utility functions"
      })
      
      local ai_analyzer = require('todo-mcp.ai.analyzer')
      local results = ai_analyzer.batch_reprioritize({}, { min_confidence = 50 })
      
      assert.is_number(results.analyzed)
      assert.is_true(results.analyzed >= 2)
      
      -- Should find at least one priority change
      assert.is_true(results.reprioritized >= 1)
      
      if #results.priority_changes > 0 then
        local change = results.priority_changes[1]
        assert.is_not_nil(change.old_priority)
        assert.is_not_nil(change.new_priority)
        assert.is_number(change.confidence)
      end
    end)
  end)
end)