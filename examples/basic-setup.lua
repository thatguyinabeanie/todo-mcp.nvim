-- Basic lazy.nvim Setup for todo-mcp.nvim
-- Place in: ~/.config/nvim/lua/plugins/todo-mcp.lua

return {
	"thatguyinabeanie/todo-mcp.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"kkharji/sqlite.lua",
	},
	cmd = "TodoMCP",
	keys = {
		{ "<leader>td", "<cmd>TodoMCP<cr>", desc = "Todo List" },
	},
	opts = {},
}
