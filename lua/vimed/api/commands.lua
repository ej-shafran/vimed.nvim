local utils = require("vimed.api.utils")
local render = require("vimed.render")

local M = {}

---[COMMAND]
---Closes the current Vimed buffer.
function M.quit()
	if not utils.is_vimed() then
		return
	end

	vim.cmd.bp()
end

---[COMMAND]
---If the line under the cursor is a file path, edit that file.
---If the line under the cursor is a directory path, change the current directory to it and re-render the Vimed buffer.
function M.enter()
	if not utils.is_vimed() then
		return
	end

	local r, _ = unpack(vim.api.nvim_win_get_cursor(0))
	if r < 3 then
		return
	end

	local path = utils.lines[r - 2].path
	if vim.fn.isdirectory(path) == 0 then
		vim.cmd.e(path)
	else
		vim.api.nvim_set_current_dir(path)
		M.redisplay()
	end
end

---[COMMAND]
---Go up one directory level and re-render the Vimed buffer.
function M.back()
	if not utils.is_vimed() then
		return
	end

	local cwd = vim.fn.getcwd()
	assert(cwd ~= nil, "no cwd")

	local dir = vim.fs.dirname(cwd)
	vim.api.nvim_set_current_dir(dir)
	M.redisplay()
end

---[COMMAND]
---Toggle the showing of hidden files.
function M.toggle_hidden()
	if not utils.is_vimed() then
		return
	end

	utils.show_hidden = not utils.show_hidden
	M.redisplay()
end

---[COMMAND]
---Re-render the Vimed display.
function M.redisplay()
	if not utils.is_vimed() then
		return
	end

	local r, _ = unpack(vim.api.nvim_win_get_cursor(0))

	render.render()

	local last_line = vim.fn.line("w$") --[[@as number]]
	if r > last_line then
		r = last_line
	end
	vim.api.nvim_win_set_cursor(0, { r, 0 })
end

---[COMMAND]
---Toggle between "date" and "name" sorts.
function M.toggle_sort()
	if not utils.is_vimed() then
		return
	end

	if utils.sort_kind == "date" then
		utils.sort_kind = "name"
	else
		utils.sort_kind = "date"
	end
	M.redisplay()
end

return M
