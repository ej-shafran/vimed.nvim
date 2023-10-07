local utils = require("vimed.api.utils")
local render = require("vimed.render")

local M = {}

---[COMMAND - +dired/quit-all]
---Closes the current Vimed buffer.
function M.quit()
	if not utils.is_vimed() then
		return
	end

	vim.cmd.bp()
end

---[COMMAND - dired-find-file]
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

---[COMMAND - dired-up-directory]
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

---[COMMAND - dired-do-redisplay]
---Re-render the Vimed display.
---@param r integer? row to place cursor at
function M.redisplay(r)
	if not utils.is_vimed() then
		return
	end

	if r == nil then
		r, _ = unpack(vim.api.nvim_win_get_cursor(0))
	end

	render.render()

	local last_line = vim.fn.line("w$") --[[@as number]]
	if r > last_line then
		r = last_line
	end
	vim.api.nvim_win_set_cursor(0, { r, 0 })
end

---[COMMAND - dired-sort-toggle-or-edit]
---Toggle between "date" and "name" sorts.
function M.toggle_sort()
	if not utils.is_vimed() then
		return
	end

	utils.sort_by_time = not utils.sort_by_time
	M.redisplay()
end

---[COMMAND - dired-create-directory]
---Prompt for a directory name and create it.
function M.create_dir()
	if not utils.is_vimed() then
		return
	end

	vim.ui.input({
		prompt = "Create directory: ",
	}, function(dirname)
		vim.fn.mkdir(dirname, "p")
		M.redisplay()
	end)
end

local function mark(flag)
	if not utils.is_vimed() then
		return
	end

	local mode = vim.fn.mode() --[[@as string]]
	if mode:lower() == "v" then
		vim.cmd.normal("")

		local vstart = vim.fn.getpos("'<")
		local vend = vim.fn.getpos("'>")
		assert(vstart ~= nil)
		assert(vend ~= nil)

		local line_start = vstart[2]
		local line_end = vend[2]
		for r = line_start, line_end do
			if r >= 3 then
				local path = utils.lines[r - 2].path
				utils.flags[path] = flag
			end
		end

		M.redisplay()
	else
		local r, _ = unpack(vim.api.nvim_win_get_cursor(0))
		if r < 3 then
			return
		end

		local path = utils.lines[r - 2].path
		utils.flags[path] = flag
		M.redisplay(r + 1)
	end
end

---[COMMAND - dired-flag-file-deletion]
---Toggle whether the path(s) under the cursor is flagged to be deleted.
function M.flag_file_deletion()
	mark("D")
end

---[COMMAND - dired-do-flagged-delete]
---Delete all files that are flagged for deletion.
function M.flagged_delete()
	if not utils.is_vimed() then
		return
	end

	---@type string[]
	local files = {}
	for k, v in pairs(utils.flags) do
		if v == "D" then
			table.insert(files, k)
		end
	end

	local prompt
	if #files < 1 then
		vim.notify("(No deletions requested)")
		return
	elseif #files == 1 then
		prompt = "Delete " .. vim.fs.basename(files[1])
	else
		local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), "\n") --[[@as string]]
		prompt = files_str .. "\nDelete D [" .. #files .. " files]"
	end
	local choice = vim.fn.confirm(prompt, "&Yes\n&No") --[[@as integer]]
	if choice == 1 then
		for _, path in ipairs(files) do
			vim.fn.delete(path)
		end
	end

	M.redisplay()
end

---[COMMAND - dired-unmark]
---Remove flag for the path under the cursor.
function M.unmark()
	mark(nil)
end

---[COMMAND - dired-mark]
---Toggle whether the path(s) under the cursor is marked for actions.
function M.mark()
	mark("*")
end

return M
