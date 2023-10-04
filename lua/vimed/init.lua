local api = require("vimed.api")
local render = require("vimed.render")

local M = {}

function M.open_vimed()
	if not api.utils.is_vimed() then
		render.init()
	end
end

function M.setup_keymaps()
	---@param lhs string
	---@param rhs string|function
	local function nmap(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, { buffer = 0 })
	end

	nmap("q", api.commands.quit)
	nmap("<CR>", api.commands.enter)
end

return M
