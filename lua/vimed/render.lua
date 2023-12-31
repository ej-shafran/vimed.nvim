local state = require("vimed._state")
local hls = require("vimed.highlights")
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
	local text = NuiText("  " .. path .. ":", hls.groups.header)
	table.insert(buffer, NuiLine({ text }))
end

---@param buffer any[]
---@param total string
local function display_total(buffer, total)
	local text = NuiText("  " .. total, hls.groups.total)
	table.insert(buffer, NuiLine({ text }))
end

---@param nline any
---@param path string
---@return string?
local function display_flag(nline, path)
	local flag = state.flags[path]

	local hlgroup = nil
	if flag == "D" then
		hlgroup = hls.groups.delete_flagged
	elseif flag ~= nil then
		hlgroup = hls.groups.marked
	end

	nline:append((flag or " ") .. " ", hlgroup)
	return hlgroup
end

---@param nline any
---@param permissions UserPermissions
---@param hlgroup string?
local function display_user_permissions(nline, permissions, hlgroup)
	if permissions.read then
		nline:append("r", hlgroup or hls.groups.perm_read)
	else
		nline:append("-", hlgroup)
	end

	if permissions.write then
		nline:append("w", hlgroup or hls.groups.perm_write)
	else
		nline:append("-", hlgroup)
	end

	if permissions.execute then
		nline:append("x", hlgroup or hls.groups.perm_execute)
	else
		nline:append("-", hlgroup)
	end
end

---@param nline any
---@param permissions Permissions
---@param hlgroup string?
local function display_permissions(nline, permissions, hlgroup)
	if permissions.is_dir then
		nline:append("d", hlgroup or hls.groups.perm_dir)
	else
		nline:append("-", hlgroup)
	end

	display_user_permissions(nline, permissions.user, hlgroup)
	display_user_permissions(nline, permissions.group, hlgroup)
	display_user_permissions(nline, permissions.owner, hlgroup)
	nline:append(" ", hlgroup)
end

---@param nline any
---@param link_count string
---@param hlgroup string?
local function display_link_count(nline, link_count, hlgroup)
	nline:append(string.format("%3s", link_count), hlgroup or hls.groups.link_count)
	nline:append(" ", hlgroup)
end

---@param nline any
---@param group string
---@param hlgroup string?
local function display_group(nline, group, hlgroup)
	nline:append(group, hlgroup or hls.groups.group)
	nline:append(" ", hlgroup)
end

---@param nline any
---@param owner string
---@param hlgroup string?
local function display_owner(nline, owner, hlgroup)
	nline:append(owner, hlgroup or hls.groups.owner)
	nline:append(" ", hlgroup)
end

---@param nline any
---@param size string
---@param hlgroup string?
local function display_size(nline, size, hlgroup)
	nline:append(string.format("%4s", size), hlgroup or hls.groups.size)
	nline:append(" ", hlgroup)
end

---@param nline any
---@param date Date
---@param hlgroup string?
local function display_date(nline, date, hlgroup)
	nline:append(string.format("%3s", date.month), hlgroup or hls.groups.month)
	nline:append(" ", hlgroup)
	nline:append(string.format("%2s", date.day), hlgroup or hls.groups.day)
	nline:append(" ", hlgroup)
	nline:append(string.format("%5s", date.time), hlgroup or hls.groups.time)
	nline:append(" ", hlgroup)
end

---@param nline any
---@param path string
---@param hlgroup string?
local function display_path(nline, path, hlgroup)
	local name = vim.fs.basename(path)

	if vim.fn.isdirectory(path) ~= 0 then
		nline:append(name, hlgroup or hls.groups.dir_name)
		return
	end

	local extension = vim.fn.fnamemodify(name, ":e")

	nline:append(vim.fn.fnamemodify(name, ":r"), hlgroup or hls.groups.file_name)

	if extension ~= "" then
		nline:append("." .. extension, hlgroup or hls.groups.extension)
	end
end

---@param nline any
---@param link string
---@param hlgroup string?
local function display_link(nline, link, hlgroup)
	if link == nil then
		return
	end
	local hl = hls.groups.file_name
	if vim.fn.isdirectory(link) ~= 0 then
		hl = hls.groups.dir_name
	end

	nline:append(" -> ", hlgroup)
	nline:append(link, hlgroup or hl)
end

local function display()
	local path = vim.fn.getcwd()
	assert(path ~= nil, "no cwd")

	local entries, header = state.dir_contents(path)
	display_header(M.buffer, path)
	if not state.hide_details then
		display_total(M.buffer, header)
	end
	for _, entry in pairs(entries) do
		local nline = NuiLine()

		local hlgroup = display_flag(nline, entry.path)
		if not state.hide_details then
			display_permissions(nline, entry.permissions, hlgroup)
			display_link_count(nline, entry.link_count, hlgroup)
			display_group(nline, entry.group, hlgroup)
			display_owner(nline, entry.owner, hlgroup)
			display_size(nline, entry.size, hlgroup)
			display_date(nline, entry.date, hlgroup)
		end
		display_path(nline, entry.path, hlgroup)
		display_link(nline, entry.link, hlgroup)

		table.insert(M.buffer, nline)
	end

	table.insert(M.buffer, NuiLine())
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
	local path = vim.fn.expand("%:p")
	if vim.fn.isdirectory(path) == 0 then
		path = vim.fs.dirname(path)
	end
	-- remove a trailing space
	path = vim.fn.substitute(path, "\\(.\\)/$", "\\1", "") --[[@as string]]

	local bufnr = vim.fn.bufnr(path --[[@as any]]) --[[@as integer]]
	if bufnr < 0 then
		vim.api.nvim_buf_set_name(0, path)
	else
		vim.api.nvim_set_current_buf(bufnr)
		if vim.fn.bufname(bufnr) ~= path then
			vim.api.nvim_buf_set_name(bufnr, path)
		end
	end

	vim.bo.filetype = "vimed"
	vim.bo.buftype = "acwrite"
	vim.api.nvim_set_current_dir(path)
	M.render()
end

return M
