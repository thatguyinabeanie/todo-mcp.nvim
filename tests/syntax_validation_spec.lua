-- Syntax validation tests to catch parsing errors
describe("todo-mcp syntax validation", function()
  describe("Lua file syntax", function()
    it("should have valid syntax in all Lua files", function()
      local function check_lua_syntax(file)
        local f = loadfile(file)
        if not f then
          error("Failed to load " .. file)
        end
        -- Try to parse but not execute
        assert.is_function(f, file .. " should parse as valid Lua")
      end
      
      -- Test all main Lua files
      local files = {
        "lua/todo-mcp/init.lua",
        "lua/todo-mcp/ui.lua",
        "lua/todo-mcp/db.lua",
        "lua/todo-mcp/keymaps.lua",
        "lua/todo-mcp/views.lua",
        "lua/todo-mcp/export.lua",
        "lua/todo-mcp/mcp.lua",
        "lua/todo-mcp/query.lua",
        "lua/todo-mcp/schema.lua",
        "lua/todo-mcp/utils.lua",
        "lua/todo-mcp/pickers.lua",
        "lua/todo-mcp/migrate.lua",
        "lua/todo-mcp/markdown-ui.lua",
        "lua/todo-mcp/frontmatter.lua",
      }
      
      for _, file in ipairs(files) do
        local full_path = vim.fn.expand("~/.local/share/nvim/lazy/todo-mcp.nvim/" .. file)
        if vim.fn.filereadable(full_path) == 1 then
          check_lua_syntax(full_path)
        end
      end
    end)
    
    it("should handle Unicode characters properly", function()
      -- Test Unicode string handling
      local ui = require("todo-mcp.ui")
      
      -- These should not error
      assert.has_no_errors(function()
        local test_strings = {
          string.rep("\u{2593}", 5),  -- ▓
          string.rep("\u{2591}", 5),  -- ░
          "│ test │",
          "╭─╮",
          "╰─╯"
        }
        
        for _, str in ipairs(test_strings) do
          assert.is_string(str)
          assert.is_truthy(#str > 0)
        end
      end)
    end)
    
    it("should not have method call syntax with Unicode", function()
      -- Read ui.lua and check for problematic patterns
      local ui_path = vim.fn.expand("~/.local/share/nvim/lazy/todo-mcp.nvim/lua/todo-mcp/ui.lua")
      if vim.fn.filereadable(ui_path) == 1 then
        local lines = vim.fn.readfile(ui_path)
        
        for i, line in ipairs(lines) do
          -- Check for Unicode characters followed by :method() syntax
          if line:match('["\'][▓░─│╭╮╯╰]["\']%s*:') then
            error("Line " .. i .. " has Unicode character with method syntax: " .. line)
          end
        end
      end
    end)
  end)
  
  describe("help file syntax", function()
    it("should not have duplicate help tags", function()
      local help_path = vim.fn.expand("~/.local/share/nvim/lazy/todo-mcp.nvim/doc/todo-mcp.txt")
      if vim.fn.filereadable(help_path) == 1 then
        local lines = vim.fn.readfile(help_path)
        local tags = {}
        
        for i, line in ipairs(lines) do
          -- Extract help tags (*tag*) - only at start of line or after whitespace
          for tag in line:gmatch("^%*([^*]+)%*") do
            if tags[tag] then
              error("Duplicate tag '" .. tag .. "' found on lines " .. tags[tag] .. " and " .. i)
            end
            tags[tag] = i
          end
          for tag in line:gmatch("%s%*([^*]+)%*") do
            if tags[tag] then
              error("Duplicate tag '" .. tag .. "' found on lines " .. tags[tag] .. " and " .. i)
            end
            tags[tag] = i
          end
        end
      end
    end)
    
    it("should have valid help file structure", function()
      local help_path = vim.fn.expand("~/.local/share/nvim/lazy/todo-mcp.nvim/doc/todo-mcp.txt")
      if vim.fn.filereadable(help_path) == 1 then
        local content = table.concat(vim.fn.readfile(help_path), "\n")
        
        -- Check for required sections
        assert.is_truthy(content:match("%*todo%-mcp%.txt%*"), "Should have main help tag")
        assert.is_truthy(content:match("%*todo%-mcp%-contents%*"), "Should have contents tag")
        assert.is_truthy(content:match("CONTENTS"), "Should have CONTENTS section")
        
        -- Check for common formatting issues
        assert.is_falsy(content:match("\t\t\t\t"), "Should not have excessive tabs")
      end
    end)
  end)
end)