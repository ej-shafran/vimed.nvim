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
	os.execute(vim.fn.join(cmd, " "))
end, {
	input = {
		operation = "Change mode of",
	},
})

---[COMMAND - dired-do-chown]
M.chown = command.act_on_files(function(files, input)
	if input == "" then
		return
	end

	local cmd = { "chown", input }
	vim.list_extend(cmd, files)
	os.execute(vim.fn.join(cmd, " "))
end, {
	input = {
		operation = "Change Owner of",
	},
}, "user")

---[COMMAND - dired-do-rename]
M.rename = command.act_on_files(function(files, input)
	if input == "" then
		return
	end

	if #files == 1 and vim.fn.filereadable(input) then
		local choice = vim.fn.confirm("Overwrite " .. input .. "?", "&Yes\n&No")
		if choice ~= 1 then
			return
		end
	end

	for _, file in ipairs(files) do
		local cmd = { "mv", file, input }
		os.execute(vim.fn.join(cmd, " "))
	end
end, {
	input = {
		operation = "Rename",
		multi_operation = "Move",
	},
})

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

	os.execute(vim.fn.join(cmd, " "))
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
	os.execute(vim.fn.join({ "ln", "-s", src, trg }, " "))
end, {
	input = {
		operation = "Symlink",
		suffix = " from: ",
	},
	flag = "Y",
})

---[COMMAND - dired-do-hardlink]
M.hardlink = command.create_files(function(src, trg)
	os.execute(vim.fn.join({ "ln", src, trg }, " "))
end, {
	input = {
		operation = "Hardlink",
		suffix = " from: ",
	},
	flag = "H",
})

---Parse a user-entered shell command to inline the selected files into it, using dired syntax.
---@param input string
---@param files string[]
---@return string[]
local function parse_command_input(files, input)
	local commands = {}
	if input:match("%s%*%s") or input:match("%s%*$") or input:match("^%*%s") ~= nil then
		--[[@as string]]
		input = input:gsub("%s%*%s", " " .. files_str .. " ")
		input = input:gsub("%s%*$", " " .. files_str)
		input = input:gsub("^%*%s", files_str .. " ")
		commands = { input }
	else
		for _, file in ipairs(files) do
			local cmd = input

			if cmd:match("%s%?%s") or cmd:match("%s%?$") or cmd:match("^%?%s") ~= nil then
				cmd = cmd:gsub("%s%?%s", " " .. file .. " ")
				cmd = cmd:gsub("%s%?$", " " .. file)
				cmd = cmd:gsub("^%?%s", file .. " ")
			else
				cmd = cmd .. " " .. file
			end

			table.insert(commands, cmd)
		end
	end
	return commands
end

---[COMMAND - dired-do-shell-command]
M.shell_command = command.execute(function(files, input)
	local is_async = input:match("&$") ~= nil
	if is_async then
		input = input:gsub("&$", "")
	end

	local commands = parse_command_input(files, input)

	return commands, is_async
end, {
	input = {
		operation = "! on",
	},
})

---[COMMAND - dired-do-async-shell-command]
M.async_shell_command = command.execute(function(files, input)
	local commands = parse_command_input(files, input)

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

return M
