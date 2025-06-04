-- Advanced Setup with Full Integrations using lazy.nvim
-- Place in: ~/.config/nvim/lua/plugins/todo-mcp.lua

return {
	-- Main plugin
	{
		"thatguyinabeanie/todo-mcp.nvim",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"kkharji/sqlite.lua",
			"folke/todo-comments.nvim",
		},
		cmd = "TodoMCP",
		event = "VeryLazy", -- Load after startup for status line
		keys = {
			-- Complete keybindings
			{ "<leader>t", group = "todo" },
			{ "<leader>td", "<cmd>TodoMCP toggle<cr>", desc = "Toggle Todo List" },
			{ "<leader>ta", "<cmd>TodoMCP add<cr>", desc = "Add Todo" },
			{
				"<leader>tA",
				function()
					require("todo-mcp.ui").add_todo_with_options()
				end,
				desc = "Add Todo with Options",
			},
			{ "<leader>ts", "<cmd>TodoMCP search<cr>", desc = "Search Todos" },
			{ "<leader>tS", "<cmd>TodoMCP style<cr>", desc = "Cycle Visual Style" },
			{ "<leader>ti", "<cmd>TodoImport<cr>", desc = "Import TODO Comments" },

			-- Export submenu
			{ "<leader>te", group = "export" },
			{ "<leader>tem", "<cmd>TodoMCP export markdown<cr>", desc = "Export to Markdown" },
			{ "<leader>tej", "<cmd>TodoMCP export json<cr>", desc = "Export to JSON" },
			{ "<leader>tey", "<cmd>TodoMCP export yaml<cr>", desc = "Export to YAML" },
			{ "<leader>tea", "<cmd>TodoMCP export all<cr>", desc = "Export All Formats" },

			-- Config submenu
			{ "<leader>tc", group = "config" },
			{ "<leader>tcp", "<cmd>TodoMCP config project<cr>", desc = "Edit Project Config" },
			{ "<leader>tcg", "<cmd>TodoMCP config global<cr>", desc = "Edit Global Config" },
			{ "<leader>tcs", "<cmd>TodoMCP setup project<cr>", desc = "Run Setup Wizard" },

			-- External integrations
			{ "<leader>tx", group = "external" },
			{
				"<leader>txg",
				function()
					local external = require("todo-mcp.integrations.external")
					external.create_external_issue(nil, "github")
				end,
				desc = "Create GitHub Issue",
			},
			{
				"<leader>txs",
				function()
					local external = require("todo-mcp.integrations.external")
					external.sync_from_external()
				end,
				desc = "Sync from External",
			},
		},
		opts = {
			-- UI Configuration
			ui = {
				width = 100,
				height = 40,
				border = "rounded",
				style = {
					preset = "modern",
					priority_style = "emoji",
					layout = "priority_sections",
					show_metadata = true,
					show_timestamps = "relative",
				},
				floating_preview = true,
				status_line = true,
			},

			-- Database Configuration
			db = {
				project_relative = true,
				project_dir = ".todo-mcp",
				name = "todos.db",
			},

			-- Export Configuration
			export = {
				directory = "exports",
				confirm = true,
				formats = { "markdown", "json", "yaml" },
			},

			-- Picker Configuration
			picker = "telescope", -- Prefer telescope for LazyVim

			-- Integrations
			integrations = {
				todo_comments = {
					enabled = true,
					auto_import = true,
					keywords = {
						TODO = { priority = "medium" },
						FIXME = { priority = "high" },
						HACK = { priority = "low" },
						PERF = { priority = "medium" },
						NOTE = { priority = "low" },
					},
				},
				external = {
					enabled = true,
					auto_sync = true,
					default_integration = "github",
					sync_interval = 300, -- 5 minutes
				},
				ai = {
					enabled = true,
					auto_analyze = true,
					min_confidence = 70,
					context_lines = 15,
				},
			},

			-- Project Configuration
			project = {
				auto_setup = true,
				ignore_patterns = { "*.db", "*.db-*", "exports/" },
				share_with_team = false,
			},

			-- Keymaps (inside todo list)
			keymaps = {
				add = "a",
				delete = "d",
				toggle_done = "<CR>",
				quit = "q",
			},
		},
		config = function(_, opts)
			require("todo-mcp").setup(opts)

			-- Set up autocommands
			local group = vim.api.nvim_create_augroup("TodoMCP", { clear = true })

			-- Auto-refresh on git branch change
			vim.api.nvim_create_autocmd("User", {
				pattern = "GitSignsUpdate",
				group = group,
				callback = function()
					local ui = require("todo-mcp.ui")
					if ui.state.win and vim.api.nvim_win_is_valid(ui.state.win) then
						ui.refresh()
					end
				end,
			})

			-- Daily reminder
			vim.api.nvim_create_autocmd("VimEnter", {
				group = group,
				callback = function()
					vim.defer_fn(function()
						local stats = require("todo-mcp.query").stats()
						if stats.active > 0 then
							vim.notify(
								string.format("You have %d active todos", stats.active),
								vim.log.levels.INFO,
								{ title = "Todo Reminder" }
							)
						end
					end, 3000)
				end,
			})
		end,
	},

	-- Lualine integration
	{
		"nvim-lualine/lualine.nvim",
		optional = true,
		opts = function(_, opts)
			local function todo_status()
				local ok, stats = pcall(function()
					return require("todo-mcp.query").stats()
				end)
				if not ok or not stats or stats.total == 0 then
					return ""
				end

				local icon = stats.completion_rate == 100 and "✓" or "󰄵"
				local color = stats.completion_rate == 100 and "green" or stats.active > 5 and "red" or "yellow"

				return {
					string.format("%s %d/%d", icon, stats.completed, stats.total),
					color = { fg = color },
				}
			end

			table.insert(opts.sections.lualine_x, 1, todo_status)
			return opts
		end,
	},

	-- Dashboard integration
	{
		"nvimdev/dashboard-nvim",
		optional = true,
		opts = function(_, opts)
			local todo_button = {
				action = "TodoMCP toggle",
				desc = " Todo List",
				icon = "󰄵 ",
				key = "t",
			}

			table.insert(opts.config.center, 5, todo_button)
			return opts
		end,
	},

	-- Telescope extension
	{
		"nvim-telescope/telescope.nvim",
		optional = true,
		dependencies = {
			"thatguyinabeanie/todo-mcp.nvim",
		},
		keys = {
			{
				"<leader>st",
				function()
					require("telescope").extensions.todo_mcp.todos()
				end,
				desc = "Search Todos (Telescope)",
			},
		},
		opts = {
			extensions = {
				todo_mcp = {
					-- Custom telescope options for todo picker
					theme = "dropdown",
					previewer = true,
					initial_mode = "normal",
				},
			},
		},
		config = function(_, opts)
			require("telescope").setup(opts)
			pcall(require("telescope").load_extension, "todo_mcp")
		end,
	},

	-- Noice integration for better notifications
	{
		"folke/noice.nvim",
		optional = true,
		opts = {
			routes = {
				{
					filter = {
						event = "notify",
						any = {
							{ find = "Todo added" },
							{ find = "Todo deleted" },
							{ find = "Visual style changed" },
						},
					},
					view = "mini",
				},
			},
		},
	},
}
