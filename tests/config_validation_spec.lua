-- Configuration validation tests to catch common issues
describe("todo-mcp configuration validation", function()
	describe("keymap configuration", function()
		it("should have all required keymaps in default config", function()
			-- Reset module state
			package.loaded["todo-mcp"] = nil
			package.loaded["todo-mcp.init"] = nil

			local todo_mcp = require("todo-mcp")
			todo_mcp.setup({})

			local config = todo_mcp.opts
			assert.is_not_nil(config.keymaps, "keymaps config should exist")
			assert.is_not_nil(config.keymaps.toggle, "toggle keymap should exist")
			assert.is_string(config.keymaps.toggle, "toggle keymap should be a string")
			assert.is_not_nil(config.keymaps.add, "add keymap should exist")
			assert.is_not_nil(config.keymaps.delete, "delete keymap should exist")
			assert.is_not_nil(config.keymaps.toggle_done, "toggle_done keymap should exist")
			assert.is_not_nil(config.keymaps.quit, "quit keymap should exist")
		end)

		it("should handle missing keymaps gracefully", function()
			-- Reset module state
			package.loaded["todo-mcp"] = nil
			package.loaded["todo-mcp.init"] = nil

			local todo_mcp = require("todo-mcp")

			-- Test setup with partial keymaps
			assert.has_no_errors(function()
				todo_mcp.setup({
					keymaps = {
						-- Missing toggle keymap
						add = "a",
						delete = "d",
					},
				})
			end)

			-- Should still have toggle from defaults
			assert.is_not_nil(todo_mcp.opts.keymaps.toggle)
		end)

		it("should not set keymaps with nil values", function()
			-- Mock vim.keymap.set to track calls
			local original_set = vim.keymap.set
			local set_calls = {}
			vim.keymap.set = function(mode, lhs, rhs, opts)
				if lhs == nil then
					error("lhs: expected string, got nil")
				end
				table.insert(set_calls, { mode = mode, lhs = lhs })
				return original_set(mode, lhs, rhs, opts)
			end

			-- Should not error with valid config
			assert.has_no_errors(function()
				todo_mcp.setup()
			end)

			-- Restore original
			vim.keymap.set = original_set
		end)
	end)

	describe("UI configuration", function()
		it("should have valid default UI settings", function()
			-- Reset module state
			package.loaded["todo-mcp"] = nil
			package.loaded["todo-mcp.init"] = nil

			local todo_mcp = require("todo-mcp")
			todo_mcp.setup({})

			local config = todo_mcp.opts
			assert.is_table(config.ui, "ui config should be a table")
			assert.is_number(config.ui.width, "width should be a number")
			assert.is_number(config.ui.height, "height should be a number")
			assert.is_string(config.ui.border, "border should be a string")
			assert.is_table(config.ui.style, "style should be a table")
		end)

		it("should have valid style presets", function()
			local views = require("todo-mcp.views")
			local presets = { "minimal", "emoji", "modern", "sections", "compact", "ascii" }

			for _, preset in ipairs(presets) do
				assert.is_not_nil(views.presets[preset], preset .. " preset should exist")
				assert.is_table(views.presets[preset].status_indicators, preset .. " should have status_indicators")
			end
		end)
	end)

	describe("database configuration", function()
		it("should have valid database path", function()
			local config = todo_mcp.opts
			assert.is_string(config.db_path, "db_path should be a string")
			assert.is_not_empty(config.db_path, "db_path should not be empty")
		end)
	end)
end)
