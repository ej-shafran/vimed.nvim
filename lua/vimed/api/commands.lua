local utils = require("vimed.api.utils")
local render = require("vimed.render")

local M = {}

function M.quit()
	if not utils.is_vimed() then
		return
	end

	vim.cmd.bp()
end

function M.enter()
	local r, _ = unpack(vim.api.nvim_win_get_cursor(0))
	if r < 3 then
		return
	end

	local path = utils.lines[r - 2].path
	if vim.fn.isdirectory(path) == 0 then
		vim.cmd.e(path)
	else
		vim.api.nvim_set_current_dir(path)
		render.init()
	end
end

function M.back()
	local cwd = vim.fn.getcwd()
	assert(cwd ~= nil, "no cwd")

	local dir = vim.fs.dirname(cwd)
	vim.api.nvim_set_current_dir(dir)
	render.init()
end

return M
