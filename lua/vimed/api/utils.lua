local M = {}

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

---Whether the current buffer is a Vimed buffer.
---@return boolean
function M.is_vimed()
	return vim.bo.filetype == "vimed"
end

return M
