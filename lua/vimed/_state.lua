local utils = require("vimed.api.utils")

local M = {}

---@type boolean
M.show_hidden = false
---@type boolean
M.sort_by_time = false
---@type boolean
M.hide_details = false
---@type FsEntry[]
M.lines = {}
---@type table<string, "D"|"*"|"C"|"Y">
M.flags = {}

M.default_compress_files_alist = {
	["%.tar%.gz$"] = "tar -cf - %i | gzip -c9 > %o",
	["%.tar%.bz2$"] = "tar -cf - %i | bzip2 -c9 > %o",
	["%.tar%.xz$"] = "tar -cf - %i | xz -c9 > %o",
	["%.tar%.zst$"] = "tar -cf - %i | zstd -19 -o %o",
	["%.zip$"] = "zip %o -r --filesync %i",
}
---@type table<string, string>
M.compress_files_alist = {}

---@type string
M.garbage_files_regex = "\\.\\(aux\\|bak\\|dvi\\|log\\|orig\\|rej\\|toc\\)$"

---Get the `ls` command to run.
---@return string
local function run_command()
	local cmd = "ls --group-directories-first -lhHQ"
	if M.show_hidden then
		cmd = cmd .. " -a"
	end
	if M.sort_by_time then
		cmd = cmd .. " --sort=time"
	end
	return utils.command(cmd)
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
		table.insert(M.lines, utils.parse_ls_line(line, path))
	end

	return M.lines, header
end

return M
