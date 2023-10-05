local utils = require("vimed.api.utils")
local render = require("vimed.render")

local M = {}

---Reset the cursor to the previous row `r` after re-rendering the screen.
---@param r integer
local function reset_cursor(r)
	local last_line = vim.fn.line("w$")
	if r > last_line then
		r = last_line --[[@as number]]
	end
	vim.api.nvim_win_set_cursor(0, { r, 0 })
end

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
		render.init()
		reset_cursor(r)
	end
end

---[COMMAND]
---Go up one directory level and re-render the Vimed buffer.
function M.back()
	if not utils.is_vimed() then
		return
	end

	local r, _ = unpack(vim.api.nvim_win_get_cursor(0))
	local cwd = vim.fn.getcwd()
	assert(cwd ~= nil, "no cwd")

	local dir = vim.fs.dirname(cwd)
	vim.api.nvim_set_current_dir(dir)
	render.init()
	reset_cursor(r)
end

---[COMMAND]
---Toggle the showing of hidden files.
function M.toggle_hidden()
	if not utils.is_vimed() then
		return
	end

	utils.show_hidden = not utils.show_hidden
	render.render()
end

function M.redisplay()
	if not utils.is_vimed() then
		return
	end

	render.render()
end

return M
