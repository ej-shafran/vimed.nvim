local api = require("vimed.api")
local render = require("vimed.render")
local colors = require("vimed.render.colors")

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
	nmap("-", api.commands.back)
end

function M.setup()
	colors.setup()
	vim.api.nvim_create_user_command("Vimed", M.open_vimed, {})
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "vimed",
		callback = M.setup_keymaps,
	})
end

return M
