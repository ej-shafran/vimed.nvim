local command = require("vimed.commands.make-commands")
local command_utils = require("vimed.commands.command-utils")
local utils = require("vimed.utils")
local state = require("vimed._state")

local M = {}

M.dired_command_map = {}

---[COMMAND - dired-do-redisplay]
M.redisplay = function()
	command.redisplay()
end
M.dired_command_map["dired-do-redisplay"] = M.redisplay

---[COMMAND - +dired/quit-all]
M.quit = function()
	if not utils.is_vimed() then
		return
	end

	local buf_count = utils.count_buffers()
	if buf_count > 0 then
		vim.cmd.bd()
	else
		vim.cmd.q()
	end
end
M.dired_command_map["+dired/quit-all"] = M.quit

---[COMMAND - dired-up-directory]
M.back = function()
	if not utils.is_vimed() then
		return
	end

	local cwd = vim.fn.getcwd() --[[@as string]]
	local dir = vim.fs.dirname(cwd)
	vim.cmd.e(dir)
end
M.dired_command_map["dired-up-directory"] = M.back

---[COMMAND - dired-find-file]
M.enter = function()
	if not utils.is_vimed() then
		return
	end

	local path = command_utils.cursor_path()
	if path == nil then
		return
	end

	vim.cmd.e(path)
end
M.dired_command_map["dired-find-file"] = M.enter

---[COMMAND - dired-create-directory]
M.create_dir = command.basic(function(param)
	local dirname = param.fargs and param.fargs[1] or vim.fn.input({
		prompt = "Create directory: ",
	})

	vim.fn.mkdir(dirname, "p")
end)
M.dired_command_map["dired-create-directory"] = M.create_dir

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
M.dired_command_map["dired-unmark-all-marks"] = M.unmark_all

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
M.dired_command_map["dired-toggle-marks"] = M.toggle_marks

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
M.dired_command_map["dired-mark-subdir-files"] = M.mark_subdir_files

---[COMMAND - dired-goto-file]
M.goto_file = command.basic(function(param)
	local cwd = vim.fn.getcwd()
	local file = param.fargs and param.fargs[1] or vim.fn.input({
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
M.dired_command_map["dired-goto-file"] = M.goto_file

---[COMMAND - dired-flag-backup-files]
M.flag_backup_files = command.basic(function()
	for _, line in pairs(state.lines) do
		local path = line.path
		if path:match("~$") ~= nil then
			state.flags[path] = "D"
		end
	end
end)
M.dired_command_map["dired-flag-backup-files"] = M.flag_backup_files

---[COMMAND - dired-change-marks]
M.change_marks = command.basic(function(param)
	if not param.fargs then
		vim.notify("Change (old mark): ")
	end
	local from = param.fargs and param.fargs[1] or vim.fn.getcharstr()
	if from == "" or #from > 1 then
		return false
	end

	if not param.fargs or not param.fargs[2] then
		vim.notify("Change " .. from .. " marks to (new mark): ")
	end
	local to = param.fargs and param.fargs[2] or vim.fn.getcharstr()
	if to == "" then
		return false
	elseif #to > 2 then
		vim.notify("Cannot create a multi-character mark", vim.log.levels.ERROR)
	end

	for file, flag in pairs(state.flags) do
		if flag == from then
			state.flags[file] = to
		end
	end
end)
M.dired_command_map["dired-change-marks"] = M.change_marks

---[COMMAND - dired-unmark-all-files]
M.unmark_files = command.basic(function(param)
	if not param.fargs then
		vim.notify("Remove marks (<CR> means all): ")
	end
	local target = param.fargs and vim.fn.char2nr(param.fargs[1]) or vim.fn.getchar()
	local target_str = vim.fn.nr2char(target)
	if target_str == "" then
		return false
	end

	for file, flag in pairs(state.flags) do
		if param.bang or target == vim.fn.char2nr("\n") or target == vim.fn.char2nr("\r") or target_str == flag then
			state.flags[file] = nil
		end
	end
end)
M.dired_command_map["dired-unmark-all-files"] = M.unmark_files

---[COMMAND - dired-unmark-backward]
M.unmark_backward = command.basic(function()
	local r = unpack(vim.api.nvim_win_get_cursor(0))
	local header_lines = state.hide_details and 1 or 2
	if r - 1 > header_lines and r - 1 < #state.lines then
		local line = state.lines[r - 1 - header_lines]
		state.flags[line.path] = nil
		return r - 1
	else
		return 1
	end
end)
M.dired_command_map["dired-unmark-backward"] = M.unmark_backward

---[COMMAND - browse-url-of-dired-file]
M.browse_url = function()
	if not utils.is_vimed() then
		return
	end

	local path = command_utils.cursor_path()

	if path == nil then
		vim.notify("No file on this line")
		return
	end

	vim.notify(utils.command({ "open", vim.fn.shellescape(path) }))
end
M.dired_command_map["browse-url-of-dired-file"] = M.browse_url

---[COMMAND - dired-diff]
---@param param CommandParam
M.diff = function(param)
	if not utils.is_vimed() then
		return
	end

	param = param or {}

	local path = command_utils.cursor_path()

	if path == nil then
		vim.notify("No file under cursor")
		return false
	end

	local filename = vim.fs.basename(path)
	local target = param.fargs and param.fargs[1]
		or vim.fn.input({
			prompt = "Diff " .. filename .. " with: ",
			completion = "file",
		})

	local target_file = io.open(target, "rb")
	if target_file == nil then
		vim.notify("No match")
		return false
	end
	target_file:close()

	vim.cmd.e(filename)
	vim.cmd("vert diffsplit " .. target)
end
M.dired_command_map["dired-diff"] = M.diff

---[COMMAND - dired-next-marked-file]
M.next_marked_file = command.cursor_to_marked_file(function(r)
	return { r + 1, #state.lines }, { 1, r - 1 }
end)
M.dired_command_map["dired-next-marked-file"] = M.next_marked_file

---[COMMAND - dired-prev-marked-file]
M.prev_marked_file = command.cursor_to_marked_file(function(r)
	return { r - 1, 1, -1 }, { #state.lines, r + 1, -1 }
end)
M.dired_command_map["dired-prev-marked-file"] = M.prev_marked_file

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
M.dired_command_map["dired-prev-dirline"] = M.prev_dirline

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
M.dired_command_map["dired-next-dirline"] = M.next_dirline

---[COMMAND - dired-sort-toggle-or-edit]
M.toggle_sort = command.toggle("sort_by_time")
M.dired_command_map["dired-sort-toggle-or-edit"] = M.toggle_sort

---[COMMAND - dired-hide-details-mode]
M.toggle_hide_details = command.toggle("hide_details")
M.dired_command_map["dired-hide-details-mode"] = M.toggle_hide_details

---[COMMAND - dired-unmark]
M.unmark = command.mark(nil)
M.dired_command_map["dired-unmark"] = M.unmark

---[COMMAND - dired-mark]
M.mark = command.mark("*")
M.dired_command_map["dired-mark"] = M.mark

---[COMMAND - dired-flag-file-deletion]
M.flag_file_deletion = command.mark("D")
M.dired_command_map["dired-flag-file-deletion"] = M.flag_file_deletion

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
		prompt = {
			operation = "Change mode of",
		},
	},
})
M.dired_command_map["dired-do-chmod"] = M.chmod

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
M.dired_command_map["dired-do-compress"] = M.compress

---[COMMAND - dired-do-compress-to]
M.compress_to = command.act_on_files(function(files, _, morearg)
	local target = morearg or vim.fn.input({
		prompt = "Compress to: ",
		completion = "file",
	})

	if target == "" then
		return
	end

	local base_cmd = nil
	for pattern, value in pairs(state.compress_files_alist) do
		local re = vim.regex(pattern) --[[@as any]]
		if re:match_str(target) ~= nil then
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
M.dired_command_map["dired-do-compress-to"] = M.compress_to

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
		prompt = {
			operation = "Change Owner of",
		},
		completion = "user",
	},
})
M.dired_command_map["dired-do-chown"] = M.chown

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
M.dired_command_map["dired-do-load"] = M.load

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
		prompt = {
			flag = "*",
			operation = "Change Timestamp of",
			suffix = " to (default now): ",
		},
		completion = "shellcmd",
	},
})
M.dired_command_map["dired-do-touch"] = M.touch

---[COMMAND - dired-do-print]
M.print = command.act_on_files(function(files, input)
	if input == "" then
		return
	end

	local cmd = { input }
	vim.list_extend(
		cmd,
		vim.tbl_map(function(path)
			return vim.fs.basename(path)
		end, files)
	)

	vim.notify(utils.command(cmd))
end, {
	input = {
		prompt = {
			flag = "*",
			operation = "Print",
			suffix = " with: ",
		},
		completion = "shellcmd",
		default = "lpr",
	},
})
M.dired_command_map["dired-do-print"] = M.print

---[COMMAND - dired-copy-filename-as-kill]
M.yank = command.act_on_files(function(files)
	local files_str = vim.fn.join(vim.tbl_map(vim.fs.basename, files), " ") --[[@as string]]
	vim.fn.setreg("+", files_str)
	vim.notify(files_str)
end, {})
M.dired_command_map["dired-copy-filename-as-kill"] = M.yank

---[COMMAND - dired-upcase]
M.upcase = command.confirm_each_file(string.upper, { action = "Rename upcase" })
M.dired_command_map["dired-upcase"] = M.upcase

---[COMMAND - dired-downcase]
M.downcase = command.confirm_each_file(string.lower, { action = "Rename downcase" })
M.dired_command_map["dired-downcase"] = M.downcase

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
M.dired_command_map["dired-do-rename-regexp"] = M.rename_regexp

---[COMMAND - dired-do-copy-regexp]
M.copy_regexp = command.with_regexp(function(file, target)
	utils.copy_file(file, target)
	state.flags[target] = "C"
end, {
	name = "Copy",
	operation = "from",
	replace = true,
})
M.dired_command_map["dired-do-copy-regexp"] = M.copy_regexp

---[COMMAND - dired-do-symlink-regexp]
M.symlink_regexp = command.with_regexp(function(file, target)
	vim.notify(utils.command({ "ln", "-s", file, target }))
end, { name = "SymLink", operation = "from", replace = true })
M.dired_command_map["dired-do-symlink-regexp"] = M.symlink_regexp

---[COMMAND - dired-do-hardlink-regexp]
M.hardlink_regexp = command.with_regexp(function(file, target)
	vim.notify(utils.command({ "ln", file, target }))
end, { name = "HardLink", operation = "from", replace = true })
M.dired_command_map["dired-do-hardlink-regexp"] = M.hardlink_regexp

---[COMMAND - dired-do-rename]
M.rename = command.create_files(utils.rename_file, {
	input = {
		operation = "Rename",
		multi_operation = "Move",
		suffix = " to: ",
	},
})
M.dired_command_map["dired-do-rename"] = M.rename

---[COMMAND - dired-do-copy]
M.copy = command.create_files(utils.copy_file, {
	input = {
		operation = "Copy",
		suffix = " to: ",
	},
	flag = "C",
})
M.dired_command_map["dired-do-copy"] = M.copy

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
M.dired_command_map["dired-do-symlink"] = M.symlink

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
M.dired_command_map["dired-do-hardlink"] = M.hardlink

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
M.dired_command_map["dired-do-shell-command"] = M.shell_command

---[COMMAND - dired-do-async-shell-command]
M.async_shell_command = command.execute(function(files, input)
	local commands = utils.parse_command_input(files, input)

	return commands, true
end, {
	input = {
		operation = "& on",
	},
})
M.dired_command_map["dired-do-async-shell-command"] = M.async_shell_command

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
M.dired_command_map["dired-do-flagged-delete"] = M.flagged_delete

---[COMMAND - dired-do-delete]
M.delete = command.delete_files(command_utils.target_files, "No file on this line")
M.dired_command_map["dired-do-delete"] = M.delete

---[COMMAND - dired-mark-executables]
M.mark_executables = command.mark_via_filter(function(entry)
	return not entry.permissions.is_dir and entry.permissions.user.execute
end, { flag = "*", kind = "executable" })
M.dired_command_map["dired-mark-executables"] = M.mark_executables

---[COMMAND - dired-mark-symlinks]
M.mark_symlinks = command.mark_via_filter(function(entry)
	return entry.link ~= nil
end, { flag = "*", kind = "symbolic link" })
M.dired_command_map["dired-mark-symlinks"] = M.mark_symlinks

---[COMMAND - dired-mark-directories]
M.mark_directories = command.mark_via_filter(function(entry)
	return entry.permissions.is_dir
end, { flag = "*", kind = "directory file" })
M.dired_command_map["dired-mark-directories"] = M.mark_directories

---[COMMAND - dired-mark-files-regexp]
M.mark_regexp = command.mark_via_filter(utils.matches_input_regex, {
	flag = "*",
	kind = "matching file",
	input = {
		prompt = "Mark files (regexp): ",
		completion = "file",
	},
})
M.dired_command_map["dired-mark-files-regexp"] = M.mark_regexp

---[COMMAND - dired-flag-files-regexp]
M.flag_regexp = command.mark_via_filter(utils.matches_input_regex, {
	flag = "D",
	kind = "matching file",
	input = {
		prompt = "Flag for deletion (regexp): ",
		completion = "file",
	},
})
M.dired_command_map["dired-flag-files-regexp"] = M.flag_regexp

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
M.dired_command_map["dired-mark-extension"] = M.mark_extension

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
M.dired_command_map["dired-mark-sexp"] = M.mark_lua_expression

---[COMMAND - dired-flag-garbage-files]
M.flag_garbage_files = command.mark_via_filter(function(entry)
	local re = vim.regex(state.garbage_files_regex) --[[@as any]]
	return re:match_str(vim.fs.basename(entry.path))
end, { flag = "D", kind = "matching file" })
M.dired_command_map["dired-flag-garbage-files"] = M.flag_garbage_files

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
M.dired_command_map["dired-mark-files-containing-regexp"] = M.mark_files_containing_regexp

---[COMMAND - dired-mark-omitted]
M.mark_omitted = command.mark_via_filter(function(entry)
	for _, extension in ipairs(state.omit_extensions) do
		if entry.path:sub(-#extension) == extension then
			return true
		end
	end

	local re = vim.regex(state.omit_files_regex) --[[@as any]]
	return re:match_str(vim.fs.basename(entry.path))
end, { flag = "*", kind = "matching files" })
M.dired_command_map["dired-mark-omitted"] = M.mark_omitted

---[COMMAND - dired-do-find-regexp]
M.find_regexp = function()
	vim.notify("TODO: dired-do-find-regexp", vim.log.levels.ERROR)
end
M.dired_command_map["dired-do-find-regexp"] = M.find_regexp

---[COMMAND - dired-maybe-insert-subdir]
M.maybe_insert_subdir = function()
	vim.notify("TODO: dired-maybe-insert-subdir", vim.log.levels.ERROR)
end
M.dired_command_map["dired-maybe-insert-subdir"] = M.maybe_insert_subdir

---[COMMAND - dired-do-find-regexp-and-replace]
M.find_regexp_and_replace = function()
	vim.notify("TODO: dired-do-find-regexp-and-replace", vim.log.levels.ERROR)
end
M.dired_command_map["dired-do-find-regexp-and-replace"] = M.find_regexp_and_replace

M.dired_command_map["dired-flag-auto-save-files"] = "UNPLANNED"
M.dired_command_map["dired-git-info-mode"] = "UNPLANNED"
M.dired_command_map["dired-clean-directory"] = "UNPLANNED"
M.dired_command_map["dired-do-byte-compile"] = "UNPLANNED"
M.dired_command_map["dired-toggle-read-only"] = "UNPLANNED"
M.dired_command_map["dired-toggle-read-only"] = "UNPLANNED"

---Prompts for the name of a Dired command, and runs the Vimed alternative.
---
---@param param CommandParam
M.from_dired = function(param)
	if not utils.is_vimed() then
		return
	end

	local result = param.fargs and param.fargs[1]
		or vim.fn.input({
			prompt = "Enter a Dired command: ",
			completion = "customlist,VimedDiredCommandCompletion",
		})

	if M.dired_command_map[result] == nil then
		vim.notify("Not a recognized Dired command")
		return
	elseif M.dired_command_map[result] == "UNPLANNED" then
		vim.notify(
			"\n"
				.. result
				.. " is not planned as a feature of Vimed.\n"
				.. "If you find yourself needing it, please file a GitHub Issue or, better yet, a Pull Request.",
			vim.log.levels.ERROR
		)
		return
	end

	pcall(M.dired_command_map[result])
end

return M
