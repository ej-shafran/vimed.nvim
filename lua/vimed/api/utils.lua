-- local NuiText = require("nui.text")

local M = {}

M.show_hidden = false

---@return string
function M.get_command()
	local cmd = "ls -lh"
	if M.show_hidden then
		cmd = cmd .. "a"
	end
	return cmd
end

---@alias Date { month: string, day: string, time: string, }
---@alias UserPermissions { read: boolean, write: boolean, execute: boolean }
---@alias Permissions { is_dir: boolean, user: UserPermissions, group: UserPermissions, owner: UserPermissions }

---@alias FsEntry
---| { permissions: Permissions, link_count: string, owner: string, group: string, size: string, date: Date, path: string }

---@alias DirContents
---| { header: string, lines: string[] }

---@type FsEntry[]
M.lines = {}

---Run a shell command and get its output as a string.
---@param cmd string command to run
---@return string
function M.command(cmd)
	local handle = io.popen(cmd)
	assert(handle ~= nil, "`popen` failed")
	local result = handle:read("*a")
	handle:close()
	return result
end

local function parse_user_permissions(read, write, exec)
	return {
		read = read == "r",
		write = write == "w",
		execute = exec == "x",
	}
end

---@param permissions string
---@return Permissions
function M.parse_permissions(permissions)
	local perm_table = {}
	for c in string.gmatch(permissions, ".") do
		table.insert(perm_table, c)
	end

	local raw_is_dir = perm_table[1]
	local is_dir = raw_is_dir == "d"

	local u_read, u_write, u_exec = unpack(perm_table, 2, 4)
	local o_read, o_write, o_exec = unpack(perm_table, 5, 7)
	local g_read, g_write, g_exec = unpack(perm_table, 8, 10)

	return {
		is_dir = is_dir,
		user = parse_user_permissions(u_read, u_write, u_exec),
		owner = parse_user_permissions(o_read, o_write, o_exec),
		group = parse_user_permissions(g_read, g_write, g_exec),
	}
end

---@param line string
---@param path string
---@return FsEntry
function M.parse_ls_l(line, path)
	local sections = vim.fn.split(line) --[[@as table]]
	return {
		permissions = M.parse_permissions(sections[1]),
		link_count = sections[2],
		owner = sections[3],
		group = sections[4],
		size = sections[5],
		date = {
			month = sections[6],
			day = sections[7],
			time = sections[8],
		},
		path = path .. "/" .. sections[9],
	}
end

---@param command string
---@param path string
---@return FsEntry[], string
function M.dir_contents(command, path)
	local lines = vim.fn.split(M.command(command), "\n") --[[@as table]]
	local header = table.remove(lines, 1)
	---@type FsEntry[]
	M.lines = {}
	for _, line in ipairs(lines) do
		table.insert(M.lines, M.parse_ls_l(line, path))
	end
	return M.lines, header
end

---Whether the current buffer is a Vimed buffer.
---@return boolean
function M.is_vimed()
	return vim.bo.filetype == "vimed"
end

return M
