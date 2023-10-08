local utils = require("vimed.api.utils")
local state = require("vimed._state")
local render = require("vimed.render")

local M = {}

---@param r integer? the row to place the cursor at after rerendering
local function redisplay(r)
	if not utils.is_vimed() then
		return
	end

	if r == nil then
		r = unpack(vim.api.nvim_win_get_cursor(0))
	end

	render.render()

	local last_line = vim.fn.line("w$") --[[@as number]]
	if r > last_line then
		r = last_line
	end
	vim.api.nvim_win_set_cursor(0, { r, 0 })
end

---[COMMAND - dired-do-redisplay]
M.redisplay = redisplay

---Get the path under the cursor, or `nil` if there isn't one.
---@return string|nil
---@return integer r current row in the buffer
local function cursor_path()
	local r = unpack(vim.api.nvim_win_get_cursor(0))
	local header_lines = state.hide_details and 1 or 2
	if r < header_lines + 1 then
		return nil, r
	end

	return state.lines[r - header_lines].path, r
end

---@param logic fun(): integer|nil|false
local function command(logic)
	return function()
		if not utils.is_vimed() then
			return
		end

		local r = logic()

		if r ~= false then
			redisplay(r)
		end
	end
end

---[COMMAND - +dired/quit-all]
M.quit = command(function()
	local bufcount = utils.count_buffers()
	if bufcount > 0 then
		vim.cmd.bp()
	else
		vim.cmd.q()
	end

	return false
end)

---[COMMAND - dired-up-directory]
M.back = command(function()
	local cwd = vim.fn.getcwd() --[[@as string]]
	local dir = vim.fs.dirname(cwd)
	vim.api.nvim_set_current_dir(dir)
end)

---[COMMAND - dired-find-file]
M.enter = command(function()
	local path = cursor_path()
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
M.create_dir = command(function()
	local dirname = vim.fn.input({
		prompt = "Create directory: ",
	})

	vim.fn.mkdir(dirname, "p")
end)

---[COMMAND - dired-unmark-all-marks]
M.unmark_all = command(function()
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
M.toggle_marks = command(function()
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
M.goto_file = command(function()
	local cwd = vim.fn.getcwd()
	local file = vim.fn.input({
		prompt = "Goto file: ",
		completion = "file",
	})

	if not file then
		return false
	end

	file = vim.fs.normalize(cwd .. "/" .. file)
	for i, line in pairs(state.lines) do
		if line.path == file then
			vim.api.nvim_win_set_cursor(0, { i + 2, 0 })
			break
		end
	end

	return false
end)

---@param state_key string
---@return function
local function toggle_command(state_key)
	return function()
		if not utils.is_vimed() then
			return
		end

		state[state_key] = not state[state_key]
		redisplay()
	end
end

---[COMMAND]
M.toggle_hidden = toggle_command("show_hidden")

---[COMMAND - dired-sort-toggle-or-edit]
M.toggle_sort = toggle_command("sort_by_time")

---[COMMAND - dired-hide-details-mode]
M.toggle_hide_details = toggle_command("hide_details")

local function mark_command(flag)
	return function()
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
			local header_lines = state.hide_details and 1 or 2
			for r = line_start, line_end do
				if r >= header_lines + 1 then
					local path = state.lines[r - header_lines].path
					local basename = vim.fs.basename(path)
					if basename ~= "." and basename ~= ".." then
						state.flags[path] = flag
					end
				end
			end

			redisplay()
		else
			local path, r = cursor_path()
			if path == nil then
				return
			end

			local basename = vim.fs.basename(path)
			if basename ~= "." and basename ~= ".." then
				state.flags[path] = flag
			end
			redisplay(r + 1)
		end
	end
end

---[COMMAND - dired-unmark]
M.unmark = mark_command(nil)

---[COMMAND - dired-mark]
M.mark = mark_command("*")

---[COMMAND - dired-flag-file-deletion]
M.flag_file_deletion = mark_command("D")

---Get either the marked files or the file under the cursor if there aren't any.
---@return string[]|nil
local function target_files()
	local files = {}
	local cwd = vim.fn.getcwd()
	for path, flag in pairs(state.flags) do
		if flag == "*" and vim.fs.dirname(path) == cwd then
			table.insert(files, path)
		end
	end

	if #files == 0 then
		local path = cursor_path()
		if path == nil then
			return
		end

		files = { path }
	end
	return files
end

---@alias PromptOpts {operation: string, flag: string, suffix: string?, multi_operation: string?}

---Create a prompt for an operation which can be done on marked files or the file under the cursor.
---@param files string[]
---@param opts PromptOpts
---@return string
local function prompt_for_files(files, opts)
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

---@param logic fun(files: string[], input: string?): integer|nil|false
---@param opts { input: { prompt: PromptOpts, completion: string? }?, confirm: { prompt: PromptOpts }? }
---@return function
local function files_command(logic, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = nil
		if opts.input ~= nil then
			input = vim.fn.input({
				prompt = prompt_for_files(files, opts.input.prompt),
				completion = opts.input.completion,
			})
			if input == "" then
				return
			end
		end

		if opts.confirm ~= nil then
			local choice = vim.fn.confirm(prompt_for_files(files, opts.confirm.prompt), "&Yes\n&No")
			if choice ~= 1 then
				return
			end
		end

		local r = logic(files, input)

		if r ~= false then
			redisplay(r)
		end
	end
end

---[COMMAND - dired-do-chmod]
M.chmod = files_command(function(files, input)
	local cmd = { "chmod", input }
	vim.list_extend(cmd, files)
	os.execute(vim.fn.join(cmd, " "))
end, {
	input = {
		prompt = {
			operation = "Change mode of",
			suffix = " to: ",
			flag = "*",
		},
		completion = "file",
	},
})

---[COMMAND - dired-do-rename]
M.rename = files_command(function(files, input)
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
		prompt = {
			operation = "Rename",
			multi_operation = "Move",
			suffix = " to: ",
			flag = "*",
		},
		completion = "file",
	},
})

---[COMMAND - dired-do-load]
M.load = files_command(function(files)
	for _, file in ipairs(files) do
		vim.cmd.source(file)
	end
end, {
	confirm = {
		prompt = {
			operation = "Load",
			suffix = "?",
			flag = "*",
		},
	},
})

---@param logic fun(src: string, trg: string)
---@param opts { input: { prompt: PromptOpts, completion: string? }, flag: string }
local function create_files_command(logic, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local target = vim.fn.input({
			prompt = prompt_for_files(files, opts.input.prompt),
			completion = opts.input.completion,
		})
		if target == "" then
			return
		end

		local cwd = vim.fn.getcwd()
		target = vim.fs.normalize(cwd .. "/" .. target)
		if #files == 1 then
			logic(files[1], target)
			state.flags[target] = opts.flag
		else
			local choice = vim.fn.confirm("Create destination dir `" .. target .. "`?", "&Yes\n&No") --[[@as integer]]
			if choice == 1 then
				vim.fn.mkdir(target, "p")

				for _, file in ipairs(files) do
					local file_path = vim.fs.normalize(target .. "/" .. vim.fs.basename(file))
					logic(file, file_path)
					state.flags[file_path] = opts.flag
				end
			end
		end

		redisplay()
	end
end

---[COMMAND - dired-do-copy]
M.copy = create_files_command(utils.copy_file, {
	input = {
		prompt = {
			operation = "Copy",
			suffix = " to: ",
			flag = "*",
		},
		completion = "file",
	},
	flag = "C",
})

---[COMMAND - dired-do-symlink]
M.symlink = create_files_command(function(src, trg)
	os.execute(vim.fn.join({ "ln", "-s", src, trg }, " "))
end, {
	input = {
		prompt = {
			operation = "Symlink",
			suffix = " from: ",
			flag = "*",
		},
		completion = "file",
	},
	flag = "Y",
})

---[COMMAND - dired-do-hardlink]
M.hardlink = create_files_command(function(src, trg)
	os.execute(vim.fn.join({ "ln", src, trg }, " "))
end, {
	input = {
		prompt = {
			operation = "Hardlink",
			suffix = " from: ",
			flag = "*",
		},
		completion = "file",
	},
	flag = "H",
})

---@param parse fun(files: string[], input: string): string[], boolean
---@param opts { input: { prompt: PromptOpts, completion: string? } }
---@return function
local function execute_command(parse, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = vim.fn.input({
			prompt = prompt_for_files(files, opts.input.prompt),
			completion = opts.input.completion,
		})
		if input == "" then
			return
		end

		local commands, is_async = parse(files, input)

		if is_async then
			local acc = ""
			for _, cmd in ipairs(commands) do
				acc = acc .. utils.command(cmd)
			end
			vim.cmd.split()
			vim.cmd.e("Async Shell Result")
			vim.api.nvim_buf_set_lines(0, 0, -1, true, vim.fn.split(acc, "\n") --[[@as table]])
		else
			for _, cmd in ipairs(commands) do
				os.execute(cmd)
			end
		end
	end
end

---Parse a user-entered shell command to inline the selected files into it, using dired syntax.
---@param input string
---@param files string[]
---@return string[]
local function parse_command_input(files, input)
	local commands = {}
	if input:match("%s%*%s") or input:match("%s%*$") or input:match("^%*%s") ~= nil then
		local files_str = vim.fn.join(files, " ") --[[@as string]]
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
M.shell_command = execute_command(function(files, input)
	local is_async = input:match("&$") ~= nil
	if is_async then
		input = input:gsub("&$", "")
	end

	local commands = parse_command_input(files, input)

	return commands, is_async
end, {
	input = {
		prompt = {
			operation = "! on",
			suffix = ": ",
			flag = "*",
		},
		completion = "shellcmd",
	},
})

---[COMMAND - dired-do-async-shell-command]
M.async_shell_command = execute_command(function(files, input)
	local commands = parse_command_input(files, input)

	return commands, true
end, {
	input = {
		prompt = {
			operation = "& on",
			suffix = ": ",
			flag = "*",
		},
		completion = "shellcmd",
	},
})

---@param get_files fun(): string[]|nil
---@param if_none string
---@return function
local function delete_files_command(get_files, if_none)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = get_files()
		if files == nil or #files == 0 then
			vim.notify(if_none)
			return
		end

		local choice = vim.fn.confirm(
			prompt_for_files(files, {
				operation = "Delete",
				flag = "D",
			}),
			"&Yes\n&No"
		) --[[@as integer]]
		if choice ~= 1 then
			return
		end

		for _, path in ipairs(files) do
			vim.fn.delete(path, "rf")
			state.flags[path] = nil
		end

		redisplay()
	end
end

---[COMMAND - dired-do-flagged-delete]
M.flagged_delete = delete_files_command(function()
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
M.delete = delete_files_command(target_files, "No file on this line")

return M
