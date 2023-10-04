local M = {}

---@alias Date
---| { month: string, day: string, time: string }

---@alias FsEntry
---| { permissions: string, link_count: string, owner: string, group: string, size: string, date: Date, path: string }

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

---@param line string
---@param path string
---@return FsEntry
function M.parse_ls_l(line, path)
	local sections = vim.fn.split(line) --[[@as table]]
	return {
		permissions = sections[1],
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

---@alias DirContents
---| { header: string, lines: string[] }

---Get dir contents (in `ls -l` format)
---@param buffer table
---@param get_dir_contents fun(): DirContents
---@param parse_line fun(string, string): FsEntry
---@return string[]
function M.dir_contents(buffer, get_dir_contents, parse_line)
	local path = vim.fn.getcwd()
	assert(path ~= nil, "no cwd")
	table.insert(buffer, path .. ":")

	local contents = get_dir_contents()
	table.insert(buffer, contents.header)

	---@type FsEntry[]
	local line_tables = {}
	for _, line in ipairs(contents.lines) do
		table.insert(buffer, line)
		table.insert(line_tables, parse_line(line, path))
	end

	M.lines = line_tables
	return contents.lines
end

---Whether the current buffer is a Vimed buffer.
---@return boolean
function M.is_vimed()
	return vim.bo.filetype == "vimed"
end

return M
