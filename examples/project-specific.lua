-- Project-Specific Setup using lazy.nvim
-- For managing todos within a specific project
-- Place in: ~/.config/nvim/lua/plugins/todo-mcp.lua

return {
	"thatguyinabeanie/todo-mcp.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"kkharji/sqlite.lua",
		"folke/todo-comments.nvim",
	},
	cmd = "TodoMCP",
	keys = {
		-- Project-focused keybindings
		{ "<leader>pt", group = "project todos" },
		{ "<leader>ptd", "<cmd>TodoMCP toggle<cr>", desc = "Project Todos" },
		{
			"<leader>pta",
			function()
				-- Add todo with current file context
				local file = vim.fn.expand("%:.")
				local line = vim.fn.line(".")
				vim.ui.input({
					prompt = string.format("Todo (%s:%d): ", file, line),
				}, function(content)
					if content then
						require("todo-mcp").add(content, {
							file_path = vim.fn.expand("%:p"),
							line_number = line,
							priority = "medium",
						})
						vim.notify("Todo added with file context", vim.log.levels.INFO)
					end
				end)
			end,
			desc = "Add Todo Here",
		},
		{ "<leader>pts", "<cmd>TodoMCP search<cr>", desc = "Search Project Todos" },
		{
			"<leader>ptr",
			function()
				-- Generate project report
				local export = require("todo-mcp.export")
				export.export_markdown(vim.fn.getcwd() .. "/TODO.md")
			end,
			desc = "Generate TODO.md",
		},
		{ "<leader>pti", "<cmd>TodoImport<cr>", desc = "Import Code TODOs" },
	},
	opts = {
		-- Store todos in project directory
		db = {
			project_relative = true,
			project_dir = ".todo-mcp",
			name = "project-todos.db",
		},
		-- Compact UI for focused work
		ui = {
			width = 70,
			height = 25,
			border = "single",
			style = {
				preset = "compact",
				layout = "priority_sections",
				show_timestamps = "relative",
				done_style = "hide", -- Hide completed todos
			},
		},
		-- Export to project docs
		export = {
			directory = function()
				-- Create docs directory if needed
				local docs_dir = vim.fn.getcwd() .. "/docs"
				vim.fn.mkdir(docs_dir, "p")
				return docs_dir
			end,
			confirm = false, -- Don't confirm for project exports
		},
		-- Enable code integration
		integrations = {
			todo_comments = {
				enabled = true,
				auto_import = true, -- Auto-import TODO comments
				keywords = {
					TODO = { priority = "medium" },
					FIXME = { priority = "high" },
					HACK = { priority = "low" },
					BUG = { priority = "high" },
					OPTIMIZE = { priority = "medium" },
				},
			},
			external = {
				enabled = true,
				default_integration = "github", -- Auto-detect from git
			},
		},

		-- Project-specific settings
		project = {
			auto_setup = true,
			share_with_team = true, -- Include in version control
			ignore_patterns = { "*.db-*" }, -- Only ignore DB backups
		},
	},
	config = function(_, opts)
		require("todo-mcp").setup(opts)

		-- Auto-import on project open
		vim.api.nvim_create_autocmd("VimEnter", {
			callback = function()
				vim.defer_fn(function()
					-- Only in git repositories
					local is_git = vim.fn.system("git rev-parse --git-dir 2>/dev/null")
					if vim.v.shell_error == 0 then
						local pickers = require("todo-mcp.pickers")
						pickers.import_from_todo_comments()
					end
				end, 1000)
			end,
		})

		-- Add project-specific commands
		vim.api.nvim_create_user_command("TodoReport", function()
			local reporting = require("todo-mcp.enterprise.reporting")
			reporting.generate_report({
				format = "markdown",
				output = vim.fn.getcwd() .. "/docs/todo-report.md",
				include_completed = true,
				group_by = "priority",
			})
		end, { desc = "Generate detailed todo report" })

		vim.api.nvim_create_user_command("TodoSync", function()
			local external = require("todo-mcp.integrations.external")
			external.sync_from_external()
			vim.notify("Synced with external issue tracker", vim.log.levels.INFO)
		end, { desc = "Sync with GitHub/Jira/Linear" })
	end,
}
