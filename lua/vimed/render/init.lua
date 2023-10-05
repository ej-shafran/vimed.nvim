local utils = require("vimed.api.utils")
local colors = require("vimed.render.colors")
local NuiLine = require("nui.line")
local NuiText = require("nui.text")

local M = {}

---@type any[]
M.buffer = {}

local function clear()
	M.buffer = {}
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})
end

---@param buffer any[]
---@param path string
local function display_header(buffer, path)
	local text = NuiText(path .. ":", colors.hl.header)
	table.insert(buffer, NuiLine({ text }))
end

---@param buffer any[]
---@param total string
local function display_total(buffer, total)
	local text = NuiText(total, colors.hl.total)
	table.insert(buffer, NuiLine({ text }))
end

---@param nline any
---@param permissions UserPermissions
local function display_user_permissions(nline, permissions)
	if permissions.read then
		nline:append("r", colors.hl.perm_read)
	else
		nline:append("-")
	end

	if permissions.write then
		nline:append("w", colors.hl.perm_write)
	else
		nline:append("-")
	end

	if permissions.execute then
		nline:append("x", colors.hl.perm_execute)
	else
		nline:append("-")
	end
end

---@param nline any
---@param permissions Permissions
local function display_permissions(nline, permissions)
	if permissions.is_dir then
		nline:append("d", colors.hl.perm_dir)
	else
		nline:append("-")
	end

	display_user_permissions(nline, permissions.user)
	display_user_permissions(nline, permissions.group)
	display_user_permissions(nline, permissions.owner)
	nline:append(" ")
end

---@param nline any
---@param link_count string
local function display_link_count(nline, link_count)
	nline:append(string.format("%2s", link_count), colors.hl.link_count)
	nline:append(" ")
end

---@param nline any
---@param group string
local function display_group(nline, group)
	nline:append(group, colors.hl.group)
	nline:append(" ")
end

---@param nline any
---@param owner string
local function display_owner(nline, owner)
	nline:append(owner, colors.hl.owner)
	nline:append(" ")
end

---@param nline any
---@param size string
local function display_size(nline, size)
	nline:append(string.format("%4s", size), colors.hl.size)
	nline:append(" ")
end

---@param nline any
---@param date Date
local function display_date(nline, date)
	nline:append(date.month, colors.hl.month)
	nline:append(" ")
	nline:append(date.day, colors.hl.day)
	nline:append(" ")
	nline:append(date.time, colors.hl.time)
	nline:append(" ")
end

---@param nline any
---@param path string
local function display_path(nline, path)
	local hl = colors.hl.file_name
	if vim.fn.isdirectory(path) ~= 0 then
		hl = colors.hl.dir_name
	end

	nline:append(vim.fs.basename(path), hl)
end

local function display()
	local path = vim.fn.getcwd()
	assert(path ~= nil, "no cwd")

	local entries, header = utils.dir_contents(utils.get_command(), path)
	display_header(M.buffer, path)
	display_total(M.buffer, header)
	for _, entry in pairs(entries) do
		local nline = NuiLine()

		display_permissions(nline, entry.permissions)
		display_link_count(nline, entry.link_count)
		display_group(nline, entry.group)
		display_owner(nline, entry.owner)
		display_size(nline, entry.size)
		display_date(nline, entry.date)
		display_path(nline, entry.path)

		table.insert(M.buffer, nline)
	end
end

local function flush()
	local undolevels = vim.bo.undolevels
	vim.bo.undolevels = -1
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
