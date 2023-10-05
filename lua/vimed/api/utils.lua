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
---@type "name"|"date"
M.sort_kind = "name"
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
	local cmd = "ls -lh"
	if M.show_hidden then
		cmd = cmd .. "a"
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

---@param lhs FsEntry
---@param rhs FsEntry
local function sort_by_name(lhs, rhs)
	local left = vim.fs.dirname(lhs.path)
	local right = vim.fs.dirname(rhs.path)
	return left:lower() < right:lower()
end

local months = {
	"Jan",
	"Feb",
	"Mar",
	"Apr",
	"May",
	"Jun",
	"Jul",
	"Aug",
	"Sep",
	"Oct",
	"Nov",
	"Dec",
}

---@param lhs FsEntry
---@param rhs FsEntry
---@return integer
---@return integer
local function sort_by_month(lhs, rhs)
	local left_index = 0
	for i, month in ipairs(months) do
		if month == lhs.date.month then
			left_index = i
			break
		end
	end
	local right_index = 0
	for i, month in ipairs(months) do
		if month == rhs.date.month then
			right_index = i
			break
		end
	end
	return left_index, right_index
end

---TODO: get this by stating the file
---@param lhs FsEntry
---@param rhs FsEntry
local function sort_by_date(lhs, rhs)
	local left_month, right_month = sort_by_month(lhs, rhs)
	if left_month ~= right_month then
		return left_month > right_month
	end

	local left_day = tonumber(lhs.date.day)
	local right_day = tonumber(rhs.date.day)
	if left_day ~= right_day then
		return left_day > right_day
	end

	local left_hour, left_min = string.match(lhs.date.time, "(%d+):(%d+)")
	local right_hour, right_min = string.match(lhs.date.time, "(%d+):(%d+)")
	left_hour = tonumber(left_hour)
	right_hour = tonumber(right_hour)
	if left_hour ~= right_hour then
		return left_hour > right_hour
	end

	left_min = tonumber(left_min)
	right_min = tonumber(right_min)
	return left_min > right_min
end

---@param sort_fn fun(FsEntry, FsEntry): boolean
local function sort_with_dirs(sort_fn)
	---@param lhs FsEntry
	---@param rhs FsEntry
	return function(lhs, rhs)
		if lhs.permissions.is_dir ~= rhs.permissions.is_dir then
			return lhs.permissions.is_dir
		else
			return sort_fn(lhs, rhs)
		end
	end
end

local sort_by_name_with_dirs = sort_with_dirs(sort_by_name)
local sort_by_date_with_dirs = sort_with_dirs(sort_by_date)

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

	print(M.sort_kind)
	local sort = M.sort_kind == "date" and sort_by_date_with_dirs or sort_by_name_with_dirs
	table.sort(M.lines, sort)
	return M.lines, header
end

return M
