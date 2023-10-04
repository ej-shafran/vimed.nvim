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

---@param nline any
---@param u_permissions UserPermissions
local function render_user_permissions(nline, u_permissions)
	if u_permissions.read then
		nline:append("r", colors.hl.perm_read)
	else
		nline:append("-")
	end

	if u_permissions.write then
		nline:append("w", colors.hl.perm_write)
	else
		nline:append("-")
	end

	if u_permissions.execute then
		nline:append("x", colors.hl.perm_execute)
	else
		nline:append("-")
	end
end

---@param nline any
---@param permissions Permissions
local function render_permissions(nline, permissions)
	if permissions.is_dir then
		nline:append("d", colors.hl.perm_dir)
	else
		nline:append("-")
	end

	render_user_permissions(nline, permissions.user)
	render_user_permissions(nline, permissions.group)
	render_user_permissions(nline, permissions.owner)
end

local function display()
	local lines = vim.fn.split(utils.command("ls -l"), "\n") --[[@as table]]
	local header = table.remove(lines, 1)
	local path = vim.fn.getcwd()
	assert(path ~= nil, "no cwd")

	table.insert(M.buffer, NuiLine({ NuiText(path .. ":", colors.hl.header) }))
	table.insert(M.buffer, NuiLine({ NuiText(header, colors.hl.total) }))

	local line_objs = utils.dir_contents(path, {
		lines = lines,
		header = header,
	}, utils.parse_ls_l)
	for _, line in pairs(line_objs) do
		local nline = NuiLine()
		render_permissions(nline, line.permissions)
		nline:append(" ")
		nline:append(NuiText(line.link_count .. " ", colors.hl.link_count))
		nline:append(NuiText(line.group .. " ", colors.hl.group))
		nline:append(NuiText(line.owner .. " ", colors.hl.owner))
		nline:append(NuiText(line.date.month .. " ", colors.hl.month))
		nline:append(NuiText(line.date.day .. " ", colors.hl.day))
		nline:append(NuiText(line.date.time .. " ", colors.hl.time))

		local file_hl = colors.hl.file_name
		if vim.fn.isdirectory(line.path) ~= 0 then
			file_hl = colors.hl.dir_name
		end
		nline:append(NuiText(vim.fs.basename(line.path), file_hl))

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
