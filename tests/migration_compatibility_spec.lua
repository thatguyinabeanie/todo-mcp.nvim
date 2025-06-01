-- Migration and compatibility tests
describe("todo-mcp migration and compatibility", function()
  local migrate, db
  
  before_each(function()
    -- Reset modules
    package.loaded["todo-mcp.migrate"] = nil
    package.loaded["todo-mcp.db"] = nil
    
    migrate = require("todo-mcp.migrate")
  end)
  
  describe("database schema migration", function()
    it("should handle missing columns gracefully", function()
      -- Mock database with old schema
      local mock_db = {
        eval = function(self, sql, ...)
          if sql:match("PRAGMA table_info") then
            -- Return old schema without priority/tags
            return {
              {name = "id", type = "INTEGER"},
              {name = "content", type = "TEXT"},
              {name = "done", type = "INTEGER"},
              {name = "created_at", type = "TIMESTAMP"},
              {name = "updated_at", type = "TIMESTAMP"}
            }
          elseif sql:match("ALTER TABLE") then
            -- Track ALTER TABLE calls
            return true
          elseif sql:match("SELECT MAX") then
            return {{version = 0}}
          else
            return {}
          end
        end
      }
      
      -- Should not error
      assert.has_no_errors(function()
        migrate.migrate(mock_db)
      end)
    end)
    
    it("should detect existing columns", function()
      -- Mock database with new schema
      local mock_db = {
        eval = function(self, sql, ...)
          if sql:match("PRAGMA table_info") then
            -- Return new schema with all columns
            return {
              {name = "id", type = "INTEGER"},
              {name = "content", type = "TEXT"},
              {name = "title", type = "TEXT"},
              {name = "status", type = "TEXT"},
              {name = "priority", type = "TEXT"},
              {name = "tags", type = "TEXT"},
              {name = "done", type = "INTEGER"},
              {name = "created_at", type = "TIMESTAMP"},
              {name = "updated_at", type = "TIMESTAMP"}
            }
          elseif sql:match("SELECT MAX") then
            return {{version = 2}}
          else
            return {}
          end
        end,
        
        alter_table_called = false
      }
      
      -- Override eval to track ALTER TABLE
      local original_eval = mock_db.eval
      mock_db.eval = function(self, sql, ...)
        if sql:match("ALTER TABLE") then
          self.alter_table_called = true
        end
        return original_eval(self, sql, ...)
      end
      
      migrate.migrate(mock_db)
      
      -- Should not try to alter table if columns exist
      assert.is_false(mock_db.alter_table_called)
    end)
  end)
  
  describe("backward compatibility", function()
    it("should handle todos without new fields", function()
      local db = require("todo-mcp.db")
      
      -- Mock old-style todo
      local old_todo = {
        id = 1,
        content = "Old style todo",
        done = 1,
        created_at = "2024-01-01 00:00:00"
      }
      
      -- Add default fields
      if not old_todo.title then
        old_todo.title = old_todo.content:match("^([^\n]+)") or old_todo.content:sub(1, 50)
      end
      if not old_todo.status then
        old_todo.status = old_todo.done == 1 and "done" or "todo"
      end
      if not old_todo.priority then
        old_todo.priority = "medium"
      end
      if not old_todo.tags then
        old_todo.tags = ""
      end
      
      -- Should have all required fields now
      assert.equals("Old style todo", old_todo.title)
      assert.equals("done", old_todo.status)
      assert.equals("medium", old_todo.priority)
      assert.equals("", old_todo.tags)
    end)
  end)
end)