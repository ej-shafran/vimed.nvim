local command = require("vimed.api.make-commands")
local utils = require("vimed.api.utils")
local state = require("vimed._state")

local M = {}

---[COMMAND - dired-do-redisplay]
M.redisplay = command.redisplay

---[COMMAND - +dired/quit-all]
M.quit = command.basic(function()
	local bufcount = utils.count_buffers()
	if bufcount > 0 then
		vim.cmd.bp()
	else
		vim.cmd.q()
	end

	return false
end)

---[COMMAND - dired-up-directory]
M.back = command.basic(function()
	local cwd = vim.fn.getcwd() --[[@as string]]
	local dir = vim.fs.dirname(cwd)
	vim.api.nvim_set_current_dir(dir)
end)

---[COMMAND - dired-find-file]
M.enter = command.basic(function()
	local path = command.cursor_path()
	if path == nil then
		return false
	end

	if vim.fn.isdirectory(path) == 0 then
		vim.cmd.e(path)
		return false
	else
		vim.api.nvim_set_current_dir(path)
	end
end)

---[COMMAND - dired-create-directory]
M.create_dir = command.basic(function()
	local dirname = vim.fn.input({
		prompt = "Create directory: ",
	})

	vim.fn.mkdir(dirname, "p")
end)

---[COMMAND - dired-unmark-all-marks]
M.unmark_all = command.basic(function()
	local file_count = 0
	local cwd = vim.fn.getcwd()
	for path, _ in pairs(state.flags) do
		if vim.fs.dirname(path) == cwd then
			state.flags[path] = nil
			file_count = file_count + 1
		end
	end

	vim.notify(file_count .. " marks removed")
end)

---[COMMAND - dired-toggle-marks]
M.toggle_marks = command.basic(function()
	for _, line in pairs(state.lines) do
		local path = line.path
		if state.flags[path] == "*" then
			state.flags[path] = nil
		elseif not state.flags[path] then
			state.flags[path] = "*"
		end
	end
end)

---[COMMAND - dired-mark-subdir-files]
M.mark_subdir_files = command.basic(function()
	for _, line in pairs(state.lines) do
		local path = line.path
		local filename = vim.fs.basename(path)
		if filename ~= "." and filename ~= ".." then
			if state.flags[path] == "*" then
				state.flags[path] = nil
			elseif not state.flags[path] then
				state.flags[path] = "*"
			end
		end
	end
end)

---[COMMAND - dired-goto-file]
M.goto_file = command.basic(function()
	local cwd = vim.fn.getcwd()
	local file = vim.fn.input({
		prompt = "Goto file: ",
		completion = "file",
	})

	if not file then
		return false
	end

	file = vim.fs.normalize(cwd .. "/" .. file)
	local header_lines = state.hide_details and 1 or 2
	for i, line in pairs(state.lines) do
		if line.path == file then
			vim.api.nvim_win_set_cursor(0, { i + header_lines, 0 })
			break
		end
	end

	return false
end)

---[COMMAND - dired-flag-backup-files]
M.flag_backup_files = command.basic(function()
	for _, line in pairs(state.lines) do
		local path = line.path
		if path:match("~$") ~= nil then
			state.flags[path] = "D"
		end
	end
end)

---[COMMAND - dired-change-marks]
M.change_marks = command.basic(function()
	vim.notify("Change (old mark): ")
	local from = vim.fn.getcharstr()
	if from == "" then
		return false
	end

	vim.notify("Change " .. from .. " marks to (new mark): ")
	local to = vim.fn.getcharstr()
	if to == "" then
		return false
	end

	for file, flag in pairs(state.flags) do
		if flag == from then
			state.flags[file] = to
		end
	end
end)

---[COMMAND - dired-unmark-all-files]
M.unmark_files = command.basic(function()
	vim.notify("Remove marks (<CR> means all): ")
	local target = vim.fn.getchar()
	local target_str = vim.fn.nr2char(target)
	if target_str == "" then
		return false
	end

	for file, flag in pairs(state.flags) do
		if target == vim.fn.char2nr("\n") or target == vim.fn.char2nr("\r") or target_str == flag then
			state.flags[file] = nil
		end
	end
end)


---[COMMAND - dired-next-marked-file]
M.next_marked_file = command.cursor_to_marked_file(function(r)
	return { r + 1, #state.lines }, { 1, r - 1 }
end)

---[COMMAND - dired-prev-marked-file]
M.prev_marked_file = command.cursor_to_marked_file(function(r)
	return { r - 1, 1, -1 }, { #state.lines, r + 1, -1 }
end)

---[COMMAND - dired-prev-dirline]
M.prev_dirline = command.dirline(function(last, current, offset)
	if current > last then
		return last, false
	elseif current <= offset + 1 then
		return offset + 1, true
	else
		return current - 1, false
	end
end)

---[COMMAND - dired-next-dirline]
M.next_dirline = command.dirline(function(last, current, offset)
	if current >= last then
		return last, true
	elseif current < offset + 1 then
		return offset + 1, false
	else
		return current + 1, false
	end
end)

---[COMMAND]
M.toggle_hidden = command.toggle("show_hidden")

---[COMMAND - dired-sort-toggle-or-edit]
M.toggle_sort = command.toggle("sort_by_time")

---[COMMAND - dired-hide-details-mode]
M.toggle_hide_details = command.toggle("hide_details")

---[COMMAND - dired-unmark]
M.unmark = command.mark(nil)

---[COMMAND - dired-mark]
M.mark = command.mark("*")

---[COMMAND - dired-flag-file-deletion]
M.flag_file_deletion = command.mark("D")

---[COMMAND - dired-do-chmod]
M.chmod = command.act_on_files(function(files, input)
	if input == "" then
		return
	end

	local cmd = { "chmod", input }
	vim.list_extend(cmd, files)
	vim.notify(utils.command(cmd))
end, {
	input = {
		operation = "Change mode of",
	},
})

---[COMMAND - dired-do-compress]
M.compress = command.act_on_files(function(files)
	for _, file in ipairs(files) do
		local cmd, should_delete, target = utils.compress_command(file)

		vim.notify(utils.command(cmd))
		if should_delete then
			vim.fn.delete(file)
			if target ~= nil then
				state.flags[target] = state.flags[file]
			end
			state.flags[file] = nil
		end
	end
end, {
	confirm = {
		operation = "Compress or uncompress",
		suffix = "?",
		flag = "*",
	},
})

---[COMMAND - dired-do-compress-to]
M.compress_to = command.act_on_files(function(files)
	local target = vim.fn.input({
		prompt = "Compress to: ",
		completion = "file",
	})

	if target == "" then
		return
	end

	local base_cmd = nil
	for pattern, value in pairs(state.compress_files_alist) do
		if target:match(pattern) ~= nil then
			base_cmd = value
			break
		end
	end

	local extension = vim.fn.fnamemodify(target, ":e")
	if base_cmd == nil then
		vim.notify("No compression rule found for `." .. extension .. "`")
		return false
	end

	local cmd = base_cmd:gsub("%%i", vim.fn.join(vim.tbl_map(vim.fs.basename, files), " "))
	cmd = cmd:gsub("%%o", target)

	vim.notify(utils.command(cmd))
end, {})

---[COMMAND - dired-do-chown]
M.chown = command.act_on_files(function(files, input)
	if input == "" then
		return
	end

	local cmd = { "chown", input }
	vim.list_extend(cmd, files)
	utils.command(cmd)
end, {
	input = {
		operation = "Change Owner of",
	},
}, "user")

---[COMMAND - dired-do-load]
M.load = command.act_on_files(function(files)
	for _, file in ipairs(files) do
		vim.cmd.source(file)
	end
end, {
	confirm = {
		operation = "Load",
		suffix = "?",
		flag = "*",
	},
})

---[COMMAND - dired-do-touch]
M.touch = command.act_on_files(function(files, input)
	local cmd = { "touch" }
	vim.list_extend(cmd, files)

	if input ~= "" then
		table.insert(cmd, "--date=" .. input)
	end

	vim.notify(utils.command(cmd))
end, {
	input = {
		operation = "Change Timestamp of",
		suffix = " to (default now): ",
	},
}, "shellcmd")

---[COMMAND - dired-copy-filename-as-kill]
M.yank = command.act_on_files(function(files)
	local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), " ") --[[@as string]]
	vim.fn.setreg("+", files_str)
	vim.notify(files_str)
end, {})

---[COMMAND - dired-upcase]
M.upcase = command.confirm_each_file(string.upper, { action = "Rename upcase" })

---[COMMAND - dired-downcase]
M.downcase = command.confirm_each_file(string.lower, { action = "Rename downcase" })

---[COMMAND - dired-do-rename-regexp]
M.rename_regexp = command.with_regexp(function(file, target)
	utils.rename_file(file, target)
	state.flags[target] = state.flags[file]
	state.flags[file] = nil
end, {
	name = "Rename",
	operation = "from",
	replace = true,
})

---[COMMAND - dired-do-copy-regexp]
M.copy_regexp = command.with_regexp(function(file, target)
	utils.copy_file(file, target)
	state.flags[target] = "C"
end, {
	name = "Copy",
	operation = "from",
	replace = true,
})

---[COMMAND - dired-do-symlink-regexp]
M.symlink_regexp = command.with_regexp(function(file, target)
	vim.notify(utils.command({ "ln", "-s", file, target }))
end, { name = "SymLink", operation = "from", replace = true })

---[COMMAND - dired-do-hardlink-regexp]
M.hardlink_regexp = command.with_regexp(function(file, target)
	vim.notify(utils.command({ "ln", file, target }))
end, { name = "HardLink", operation = "from", replace = true })

---[COMMAND - dired-do-rename]
M.rename = command.create_files(utils.rename_file, {
	input = {
		operation = "Rename",
		multi_operation = "Move",
		suffix = " to: ",
	},
})

---[COMMAND - dired-do-copy]
M.copy = command.create_files(utils.copy_file, {
	input = {
		operation = "Copy",
		suffix = " to: ",
	},
	flag = "C",
})

---[COMMAND - dired-do-symlink]
M.symlink = command.create_files(function(src, trg)
	vim.notify(utils.command({ "ln", "-s", src, trg }))
end, {
	input = {
		operation = "Symlink",
		suffix = " from: ",
	},
	flag = "Y",
})

---[COMMAND - dired-do-hardlink]
M.hardlink = command.create_files(function(src, trg)
	vim.notify(utils.command({ "ln", src, trg }))
end, {
	input = {
		operation = "Hardlink",
		suffix = " from: ",
	},
	flag = "H",
})

---[COMMAND - dired-do-shell-command]
M.shell_command = command.execute(function(files, input)
	local is_async = input:match("&$") ~= nil
	if is_async then
		input = input:gsub("&$", "")
	end

	local commands = utils.parse_command_input(files, input)

	return commands, is_async
end, {
	input = {
		operation = "! on",
	},
})

---[COMMAND - dired-do-async-shell-command]
M.async_shell_command = command.execute(function(files, input)
	local commands = utils.parse_command_input(files, input)

	return commands, true
end, {
	input = {
		operation = "& on",
	},
})

---[COMMAND - dired-do-flagged-delete]
M.flagged_delete = command.delete_files(function()
	---@type string[]
	local files = {}
	for k, v in pairs(state.flags) do
		if v == "D" then
			table.insert(files, k)
		end
	end
	local cwd = vim.fn.getcwd()
	return vim.tbl_filter(function(value)
		return vim.fs.dirname(value) == cwd
	end, files)
end, "(No deletions requested)")

---[COMMAND - dired-do-delete]
M.delete = command.delete_files(command.target_files, "No file on this line")

---[COMMAND - dired-mark-executables]
M.mark_executables = command.mark_via_filter(function(entry)
	return not entry.permissions.is_dir and entry.permissions.user.execute
end, { flag = "*", kind = "executable" })

---[COMMAND - dired-mark-symlinks]
M.mark_symlinks = command.mark_via_filter(function(entry)
	return entry.link ~= nil
end, { flag = "*", kind = "symbolic link" })

---[COMMAND - dired-mark-directories]
M.mark_directories = command.mark_via_filter(function(entry)
	return entry.permissions.is_dir
end, { flag = "*", kind = "directory file" })

---[COMMAND - dired-mark-files-regexp]
M.mark_regexp = command.mark_via_filter(utils.matches_input_regex, {
	flag = "*",
	kind = "matching file",
	input = {
		prompt = "Mark files (regexp): ",
		completion = "file",
	},
})

---[COMMAND - dired-flag-files-regexp]
M.flag_regexp = command.mark_via_filter(utils.matches_input_regex, {
	flag = "D",
	kind = "matching file",
	input = {
		prompt = "Flag for deletion (regexp): ",
		completion = "file",
	},
})

---[COMMAND - dired-mark-extension]
M.mark_extension = command.mark_via_filter(function(entry, input)
	return vim.fs.basename(entry.path):match("." .. input .. "$")
end, {
	flag = "*",
	kind = "matching file",
	input = {
		prompt = "Marking extension: ", --TODO: add default
		completion = "filetype",
		process = function(raw)
			if raw:match("^%.") == nil then
				raw = "." .. raw
			end

			raw = raw:gsub("%.", "%.")
			return raw
		end,
	},
})

---[COMMAND - dired-mark-sexp]
M.mark_lua_expression = command.mark_via_filter(function(entry, func)
	if func == nil then
		return false
	end

	_A = entry
	local ok, result = pcall(func)
	return ok and result
end, {
	flag = "*",
	kind = "matched file",
	input = {
		prompt = "Mark if (lua expression): ",
		completion = "lua",
		process = function(raw)
			local func, err = load(raw)
			if not func then
				vim.notify("Lua interperter error: " .. err, vim.log.levels.ERROR)
				return nil
			else
				return func
			end
		end,
	},
})

---[COMMAND - dired-flag-garbage-files]
M.flag_garbage_files = command.mark_via_filter(function(entry)
	local re = vim.regex(state.garbage_files_regex) --[[@as any]]
	return re:match_str(vim.fs.basename(entry.path))
end, { flag = "D", kind = "matching file" })

---[COMMAND - dired-mark-files-containing-regexp]
M.mark_files_containing_regexp = command.mark_via_filter(function(entry, input)
	if entry.permissions.is_dir or not entry.permissions.user.read then
		return false
	end

	local f = assert(io.open(entry.path, "rb"))
	local content = f:read("*a")
	f:close()

	local re = vim.regex(input) --[[@as any]]
	return re:match_str(content)
end, {
	flag = "*",
	kind = "matching file",
	input = {
		prompt = "Mark files containing (regexp): ",
		completion = "file",
	},
})

return M
