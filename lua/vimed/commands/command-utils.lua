local state = require("vimed._state")

local M = {}

---Get the path under the cursor, or `nil` if there isn't one.
---@return string|nil
---@return integer r current row in the buffer
function M.cursor_path()
	local r = unpack(vim.api.nvim_win_get_cursor(0))
	local header_lines = state.hide_details and 1 or 2
	if r < header_lines + 1 or r > header_lines + #state.lines then
		return nil, r
	end

	return state.lines[r - header_lines].path, r
end

---Get either the marked files or the file under the cursor if there aren't any.
---@return string[]|nil
function M.target_files()
	local files = {}
	local cwd = vim.fn.getcwd()
	for path, flag in pairs(state.flags) do
		if flag == "*" and vim.fs.dirname(path) == cwd then
			table.insert(files, path)
		end
	end

	if #files == 0 then
		local path = M.cursor_path()
		if path == nil then
			return
		end

		files = { path }
	end
	return files
end

---Sets the cursor's line in the current window, clamping it to the last window available
function M.set_line(r)
	local last_line = vim.fn.line("w$") --[[@as number]]
	if r > last_line then
		r = last_line
	end
	vim.api.nvim_win_set_cursor(0, { r, 0 })
end

-- ---@alias PromptOpts {operation: string, flag: string, suffix: string?, multi_operation: string?}

---Create a prompt for an operation which can be done on marked files or the file under the cursor.
---@param files string[]
---@param opts PromptOpts
---@return string
function M.prompt_for_files(files, opts)
	local prompt
	if #files == 1 then
		prompt = opts.operation .. " " .. vim.fs.basename(files[1])
	else
		local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), "\n") --[[@as string]]
		prompt = files_str
			.. "\n"
			.. (opts.multi_operation or opts.operation)
			.. " "
			.. opts.flag
			.. " ["
			.. #files
			.. " files]"
	end

	if opts.suffix ~= nil then
		prompt = prompt .. opts.suffix
	end
	return prompt
end

return M
