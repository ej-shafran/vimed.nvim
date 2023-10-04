local utils = require("vimed.api.utils")
local colors = require("vimed.render.colors")
local NuiLine = require("nui.line")
local NuiText = require("nui.text")

local M = {}

M.buffer = {}

local function clear()
	M.buffer = {}
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
end

local function display()
	local lines = vim.fn.split(utils.command("ls -l"), "\n") --[[@as table]]
	local header = table.remove(lines, 1)
	local path = vim.fn.getcwd()
	assert(path ~= nil, "no cwd")

	utils.dir_contents(path, {
		lines = lines,
		header = header,
	}, utils.parse_ls_l)
	table.insert(M.buffer, NuiLine({ NuiText(path .. ":", colors.DIM_TEXT) }))
	table.insert(M.buffer, NuiLine({ NuiText(header, colors.DIM_TEXT) }))
	for _, line in pairs(lines) do
		local nline = NuiLine()
		nline:append(NuiText(line, colors.NORMAL))
		table.insert(M.buffer, nline)
	end
end

local function flush()
	local undolevels = vim.bo.undolevels
	vim.bo.undolevels = -1
	-- TODO: fancier rendering
	-- vim.api.nvim_buf_set_lines(0, 0, -1, true, M.buffer)
	for i, line in ipairs(M.buffer) do
		line:render(0, -1, i)
	end
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
