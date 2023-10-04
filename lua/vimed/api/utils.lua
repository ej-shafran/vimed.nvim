-- local NuiText = require("nui.text")

local M = {}

---@alias FsEntry
---| { path: string }

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

---Render dir contents into `buffer`, while updating the `utils` data.
---@param path string
---@param contents DirContents
---@param parse_line fun(string, string): FsEntry
function M.dir_contents(path, contents, parse_line)
	---@type FsEntry[]
	M.lines = {}
	for _, line in ipairs(contents.lines) do
		table.insert(M.lines, parse_line(line, path))
	end
end

---Whether the current buffer is a Vimed buffer.
---@return boolean
function M.is_vimed()
	return vim.bo.filetype == "vimed"
end

return M
