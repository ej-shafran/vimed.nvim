---@alias Date { month: string, day: string, time: string, }
---@alias UserPermissions { read: boolean, write: boolean, execute: boolean }
---@alias Permissions { is_dir: boolean, user: UserPermissions, group: UserPermissions, owner: UserPermissions }

---@alias FsEntry
---| { permissions: Permissions, link_count: string, owner: string, group: string, size: string, date: Date, path: string, link: string? }

---@alias DirContents
---| { header: string, lines: string[] }

local M = {}

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
function M.parse_ls_line(line, path)
	local sections = vim.fn.split(line) --[[@as table]]
	local path_section = vim.fn.join(vim.list_slice(sections, 9), " ") --[[@as string]]
	local file_path = path_section:match('"([^"]*)"')
	local link = path_section:match('-> "([^"]*)"')
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
		path = path .. "/" .. file_path,
		link = link,
	}
end

---Get count of buffers that aren't the current Vimed buffer.
---@return integer
function M.count_buffers()
	local buf_count = 0
	local current_buffer = vim.api.nvim_get_current_buf()
	local cwd = vim.fn.getcwd()
	local bufinfos = vim.fn.getbufinfo({ bufloaded = true, buflisted = true }) --[[@as table]]

	for _, bufinfo in ipairs(bufinfos) do
		if bufinfo.name ~= cwd and bufinfo.bufnr ~= current_buffer then
			buf_count = buf_count + 1
		end
	end

	return buf_count
end

---@param source string
---@param target string
function M.copy_file(source, target)
	local source_file = io.open(source, "rb")
	if not source_file then
		return
	end

	local target_file = io.open(target, "wb")
	if not target_file then
		source_file:close()
		return
	end

	local content = source_file:read("*a")
	target_file:write(content)

	source_file:close()
	target_file:close()
end

return M
