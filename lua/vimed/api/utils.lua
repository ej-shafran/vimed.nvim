---@alias Date { month: string, day: string, time: string, }
---@alias UserPermissions { read: boolean, write: boolean, execute: boolean }
---@alias Permissions { is_dir: boolean, user: UserPermissions, group: UserPermissions, owner: UserPermissions }

---@alias FsEntry
---| { permissions: Permissions, link_count: string, owner: string, group: string, size: string, date: Date, path: string }

---@alias DirContents
---| { header: string, lines: string[] }

local M = {}

---@type boolean
M.show_hidden = false
---@type boolean
M.sort_by_time = false
---@type FsEntry[]
M.lines = {}

---Whether the current buffer is a Vimed buffer.
---@return boolean
function M.is_vimed()
	return vim.bo.filetype == "vimed"
end

---Run a shell command and get its output as a string.
---@param cmd string|table either a full string of the command or a table to be joined with spaces
---@return string
function M.command(cmd)
	local cmd_string
	if type(cmd) == "table" then
		cmd_string = vim.fn.join(cmd, " ") --[[@as string]]
	else
		cmd_string = cmd
	end

	local handle = io.popen(cmd_string)
	assert(handle ~= nil, "`popen` failed")
	local result = handle:read("*a")
	handle:close()
	return result
end

---Get the `ls` command to run.
---@return string
local function run_command()
	local cmd = "ls --group-directories-first -lh"
	if M.show_hidden then
		cmd = cmd .. " -a"
	end
	if M.sort_by_time then
		cmd = cmd .. " --sort=time"
	end
	return M.command(cmd)
end

---Get a user/group's `UserPermissions` object from a `rwx` string.
---@param read string
---@param write string
---@param exec string
---@return UserPermissions
local function parse_user_permissions(read, write, exec)
	return {
		read = read == "r",
		write = write == "w",
		execute = exec == "x",
	}
end

---Get a full `Permissions` object from a `drwxrwxrwx` string.
---@param permissions string
---@return Permissions
local function parse_permissions(permissions)
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

---Get an `FsEntry` object from a line of `ls -l` output.
---@param line string
---@param path string
---@return FsEntry
local function parse_ls_line(line, path)
	local sections = vim.fn.split(line) --[[@as table]]
	return {
		permissions = parse_permissions(sections[1]),
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

---Get a list of `FsEntry` objects and a header string from a directory path.
---@param path string
---@return FsEntry[], string
function M.dir_contents(path)
	local lines = vim.fn.split(run_command(), "\n") --[[@as table]]
	local header = table.remove(lines, 1)

	---@type FsEntry[]
	M.lines = {}
	for _, line in ipairs(lines) do
		table.insert(M.lines, parse_ls_line(line, path))
	end

	return M.lines, header
end

return M
