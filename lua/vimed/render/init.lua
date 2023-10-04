local utils = require("vimed.api.utils")

local M = {}

M.buffer = {}

local function clear()
	M.buffer = {}
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
end

local function display()
	local lines = vim.fn.split(utils.command("ls -l"), "\n") --[[@as table]]
	local header = table.remove(lines, 1)
	M.buffer = utils.dir_contents({
		lines = lines,
		header = header,
	}, utils.parse_ls_l)
end

local function flush()
	local undolevels = vim.bo.undolevels
	vim.bo.undolevels = -1
	-- TODO: fancier rendering
	vim.api.nvim_buf_set_lines(0, 0, -1, true, M.buffer)
	vim.bo.undolevels = undolevels
	vim.bo.modified = false
end

function M.render()
	vim.bo.modifiable = true
	clear()
	display()
	flush()
	vim.bo.modifiable = false
end

function M.init()
	local path = vim.fn.expand("%")
	if vim.fn.isdirectory(path) == 0 then
		path = vim.fs.dirname(path)
	end

	vim.cmd.enew()
	vim.bo.filetype = "vimed"
	vim.bo.buftype = "acwrite"
	vim.bo.bufhidden = "wipe"

	vim.api.nvim_set_current_dir(path)
	M.render()
end

return M
