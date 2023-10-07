local utils = require("vimed.api.utils")
local render = require("vimed.render")

local M = {}

---Get the path under the cursor, or `nil` if there isn't one.
---@return string|nil
---@return integer r current row in the buffer
local function cursor_path()
	local r, _ = unpack(vim.api.nvim_win_get_cursor(0))
	if r < 3 then
		return nil, r
	end

	return utils.lines[r - 2].path, r
end

---Get the marked files in the current Vimed buffer.
---@return string[]
local function marked_files()
	local files = {}
	local cwd = vim.fn.getcwd()
	for path, flag in pairs(utils.flags) do
		if flag == "*" and vim.fs.dirname(path) == cwd then
			table.insert(files, path)
		end
	end
	return files
end

---Get count of buffers that aren't the current Vimed buffer.
---@return integer
local function count_buffers()
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

---[COMMAND - +dired/quit-all]
---Closes the current Vimed buffer. If it's the only buffer, equivalent to `:q`.
function M.quit()
	if not utils.is_vimed() then
		return
	end

	local bufcount = count_buffers()
	if bufcount > 0 then
		vim.cmd.bp()
	else
		vim.cmd.q()
	end
end

---[COMMAND - dired-find-file]
---If the line under the cursor is a file path, edit that file.
---If the line under the cursor is a directory path, change the current directory to it and re-render the Vimed buffer.
function M.enter()
	if not utils.is_vimed() then
		return
	end

	local path = cursor_path()
	if path == nil then
		return
	end

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

	local dirname = vim.fn.input({
		prompt = "Create directory: ",
	})

	vim.fn.mkdir(dirname, "p")
	M.redisplay()
end

---Mark either the files within the visual selection or the file under the cursor with `flag`.
---@param flag string|nil the flag to use; if `nil` the files are unmarked.
local function mark(flag)
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
				local basename = vim.fs.basename(path)
				if basename ~= "." and basename ~= ".." then
					utils.flags[path] = flag
				end
			end
		end

		M.redisplay()
	else
		local path, r = cursor_path()
		if path == nil then
			return
		end

		local basename = vim.fs.basename(path)
		if basename ~= "." and basename ~= ".." then
			utils.flags[path] = flag
		end
		M.redisplay(r + 1)
	end
end

---[COMMAND - dired-flag-file-deletion]
---Toggle whether the path(s) under the cursor is flagged to be deleted.
function M.flag_file_deletion()
	if not utils.is_vimed() then
		return
	end

	mark("D")
end

---Prompt user to confirm deletion and delete the files passed in if confirmed.
---*Does not* rerender the Vimed buffer.
---@param files string[]
local function delete_files(files)
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
	if choice ~= 1 then
		return
	end

	for _, path in ipairs(files) do
		vim.fn.delete(path, "rf")
		utils.flags[path] = nil
	end
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
	local cwd = vim.fn.getcwd()
	files = vim.tbl_filter(function(value)
		return vim.fs.dirname(value) == cwd
	end, files)

	delete_files(files)
	M.redisplay()
end

---[COMMAND - dired-do-delete]
---Delete either the marked files or the file under the cursor.
function M.delete()
	if not utils.is_vimed() then
		return
	end

	local files = marked_files()
	if #files == 0 then
		local path = cursor_path()
		if path == nil then
			return
		end

		files = { path }
	end

	delete_files(files)
	M.redisplay()
end

---[COMMAND - dired-unmark]
---Remove flag for the path under the cursor.
function M.unmark()
	if not utils.is_vimed() then
		return
	end

	mark(nil)
end

---[COMMAND - dired-mark]
---Toggle whether the path(s) under the cursor is marked for actions.
function M.mark()
	if not utils.is_vimed() then
		return
	end

	mark("*")
end

---[COMMAND - dired-unmark-all-marks]
---Remove all marks in current Vimed buffer.
function M.unmark_all()
	if not utils.is_vimed() then
		return
	end

	local file_count = 0
	local cwd = vim.fn.getcwd()
	for path, _ in pairs(utils.flags) do
		if vim.fs.dirname(path) == cwd then
			utils.flags[path] = nil
			file_count = file_count + 1
		end
	end

	vim.notify(file_count .. " marks removed")

	M.redisplay()
end

---[COMMAND - dired-toggle-marks]
---Unmark all files marked with "*" and mark all unmarked files with "*".
function M.toggle_marks()
	if not utils.is_vimed() then
		return
	end

	for _, line in pairs(utils.lines) do
		local path = line.path
		if utils.flags[path] == "*" then
			utils.flags[path] = nil
		elseif not utils.flags[path] then
			utils.flags[path] = "*"
		end
	end

	M.redisplay()
end

---[COMMAND - dired-goto-file]
---Select a file and jump to that file's line in the current Vimed buffer.
function M.goto_file()
	if not utils.is_vimed() then
		return
	end

	local cwd = vim.fn.getcwd()
	local file = vim.fn.input({
		prompt = "Goto file: ",
		completion = "file",
	})

	if not file then
		return
	end

	file = vim.fs.normalize(cwd .. "/" .. file)
	for i, line in pairs(utils.lines) do
		if line.path == file then
			vim.api.nvim_win_set_cursor(0, { i + 2, 0 })
			break
		end
	end
end

---[COMMAND - dired-do-chmod]
---Prompt for a mode change and apply it using `chmod` to the marked files, or the file under the cursor if there are none.
function M.chmod()
	if not utils.is_vimed() then
		return
	end

	local files = marked_files()
	if #files == 0 then
		local path = cursor_path()
		if path == nil then
			vim.notify("No files specified")
			return
		end

		files = { path }
	end

	local prompt
	if #files == 1 then
		prompt = "Change mode of " .. vim.fs.basename(files[1]) .. " to: "
	else
		local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), "\n") --[[@as string]]
		prompt = files_str .. "\nChange mode of * [" .. #files .. " files] to: "
	end

	local mode_change = vim.fn.input({
		prompt = prompt,
	})
	if mode_change == "" then
		return
	end

	local cmd = { "chmod", mode_change }
	vim.list_extend(cmd, files)
	os.execute(vim.fn.join(cmd, " "))

	M.redisplay()
end

---[COMMAND - dired-do-rename]
---Prompt for a new name and apply it using `mv` to the marked files, or the file under the cursor if there are none.
function M.rename()
	if not utils.is_vimed() then
		return
	end

	local files = marked_files()
	if #files == 0 then
		local path = cursor_path()
		if path == nil then
			vim.notify("No files specified")
			return
		end
		files = { path }
	end

	local prompt
	if #files == 1 then
		prompt = "Rename " .. vim.fs.basename(files[1]) .. " to: "
	else
		local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), "\n") --[[@as string]]
		prompt = files_str .. "\nMove * [" .. #files .. " files] to: "
	end

	local location = vim.fn.input({
		prompt = prompt,
		completion = "file",
	})
	if location == "" then
		return
	end

	for _, file in ipairs(files) do
		local cmd = { "mv", file, location }
		os.execute(vim.fn.join(cmd, " "))
	end

	M.redisplay()
end

function M.shell_command()
	if not utils.is_vimed() then
		return
	end

	local files = marked_files()
	if #files == 0 then
		local path = cursor_path()
		if path == nil then
			vim.notify("No files specified")
			return
		end

		files = { path }
	end

	local prompt
	if #files == 1 then
		prompt = "! on " .. vim.fs.basename(files[1]) .. ": "
	else
		local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), "\n") --[[@as string]]
		prompt = files_str .. "\n! on * [" .. #files .. " files]: "
	end

	local command = vim.fn.input({
		prompt = prompt,
		completion = "shellcmd",
	})
	if command == "" then
		return
	end

	local is_async = command:match("&$") ~= nil
	if is_async then
		command = command:gsub("&$", "")
	end

	local star = command:match("%s%*%s") or command:match("%s%*$") or command:match("^%*%s")
	if star ~= nil then
		local files_str = vim.fn.join(files, " ") --[[@as string]]
		command = command:gsub("%s%*%s", " " .. files_str .. " ")
		command = command:gsub("%s%*$", " " .. files_str)
		command = command:gsub("^%*%s", files_str .. " ")
		if is_async then
			local result = utils.command(command)

			vim.cmd.split()
			vim.cmd.e("Async Shell Result")
			vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.fn.split(result, "\n") --[[@as table]])
		else
			os.execute(command)
		end
	else
		local acc = ""
		for _, file in ipairs(files) do
			local cmd = command
			local question = cmd:match("%s%?%s") or command:match("%s%?$") or command:match("^%?%s")
			if question ~= nil then
				cmd = cmd:gsub("%s%?%s", " " .. file .. " ")
				cmd = cmd:gsub("%s%?$", " " .. file)
				cmd = cmd:gsub("^%?%s", file .. " ")
			else
				cmd = cmd .. " " .. file
			end

			if is_async then
				local result = utils.command(cmd)
				acc = acc .. result
			else
				os.execute(cmd)
			end
		end

		if is_async then
			vim.cmd.split()
			vim.cmd.e("Async Shell Result")
			vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.fn.split(acc, "\n") --[[@as table]])
		end
	end
end

return M
