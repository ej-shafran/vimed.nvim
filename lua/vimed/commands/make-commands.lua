---@alias PromptOpts {operation: string, flag: string, suffix: string?, multi_operation: string?}
---@alias CommandParam { name: string, args: string, fargs: string[], bang: boolean, line1: integer, line2: integer, range: integer, count: integer, smods: table }

local utils = require("vimed.utils")
local state = require("vimed._state")
local command_utils = require("vimed.commands.command-utils")

local M = {}

---Creates a basic command, who's logic isn't necessarily shared with other commands.
---The callback function is only called in Vimed mode.
---It is passed the parameter which is passed into any Vim command (see `:help lua-guide-commands-create`).
---The return value of the callback is used to handle the redisplaying of the Vimed buffer:
---+ If `false` is returned, the buffer isn't redisplayed
---+ If an `integer` is returned, the buffer is redisplayed and the cursor placed on the line of the returned integer
---Otherwise, the buffer is redisplayed and the cursor is unchanged.
---
---@param logic fun(param: CommandParam): integer|nil|false the command's logic, see above
function M.basic(logic)
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local r = logic(param)

		if r ~= false then
			command_utils.redisplay(r)
		end
	end
end

---Creates a command which toggles a certain key within the `_state` module, and redisplays the Vimed buffer.
---The key should be one which has a `boolean` value.
---
---@param state_key string
function M.toggle(state_key)
	return function()
		if not utils.is_vimed() then
			return
		end

		state[state_key] = not state[state_key]
		command_utils.redisplay()
	end
end

---Creates a command that marks either the file under the cursor or every file within the visual selection,
---depending on the mode, and redisplays the Vimed buffer.
---
---@param flag VimedFlag|nil the flag to use when marking
function M.mark(flag)
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

			command_utils.redisplay()
		else
			local path, r = command_utils.cursor_path()
			if path == nil then
				return
			end

			local basename = vim.fs.basename(path)
			if flag == nil or basename ~= "." and basename ~= ".." then
				state.flags[path] = flag
			end
			command_utils.redisplay(r + 1)
		end
	end
end

---Creates a command which acts on either the target files (see `command_utils.target_files`).
---The callback is passed the array of file pathnames, and optionally the user's input, if the `input` option is set.
---The `input` option calls to `vim.fn.input` unless an argument was passed in to the command.
---
---If the `confirm` option is set, the command will ask for user confirmation. If the command is called with a `!`, no confirmation is requested.
---If the user doesn't confirm, the command returns without having an effect.
---The `confirm` and `input` options are mutually exclusive.
---
---@param logic fun(files: string[], input: string?, moreargs: string?): integer|nil|false the callback which does some action to the files
---@param opts { input: { prompt: PromptOpts?, completion: string?, default: string? } } | { confirm: PromptOpts? } options which alter the command, see `command_utils.prompt_for_files` for more details
function M.act_on_files(logic, opts)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = nil
		if opts.input ~= nil then
			input = param.fargs and param.fargs[1]
				or vim.fn.input({
					prompt = command_utils.prompt_for_files(
						files,
						vim.tbl_extend("force", { suffix = " to: ", flag = "*" }, opts.input.prompt)
					),
					completion = opts.input.completion or "file",
					default = opts.input.default,
				})
		end

		if opts.confirm ~= nil then
			local choice = param.bang and 1
				or vim.fn.confirm(command_utils.prompt_for_files(files, opts.confirm), "&Yes\n&No")

			if choice ~= 1 then
				return
			end
		end

		local r = logic(files, input, param.fargs and param.fargs[1])

		if r ~= false then
			command_utils.redisplay(r)
		end
	end
end

---Creates a command which does some action on the target file (see `command_utils.target_files`) which creates new files.
---The callback is called for each one of the target files, with the target file and a `target` specified by user input or the command's first argument.
---If there is more than one target file, the command asks for confirmation to create a new directory with the user input (or command argument).
---If the user confirms, the command will create the directory.
---The callback will then be called with each target file, and that file's name appended to the new directory.
---The command can be called with a `!` at the end to create the directory without asking for confirmation.
---
---@param logic fun(src: string, trg: string)
---@param opts { input: PromptOpts?, flag: string }
function M.create_files(logic, opts)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local target = param.fargs and param.fargs[1]
			or vim.fn.input({
				prompt = command_utils.prompt_for_files(files, vim.tbl_extend("force", { flag = "*" }, opts.input)),
				completion = "file",
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
			local choice = param.bang and 1 or vim.fn.confirm("Create destination dir `" .. target .. "`?", "&Yes\n&No") --[[@as integer]]
			if choice ~= 1 then
				return
			end

			vim.fn.mkdir(target, "p")

			for _, file in ipairs(files) do
				local file_path = vim.fs.normalize(target .. "/" .. vim.fs.basename(file))
				logic(file, file_path)
				state.flags[file_path] = opts.flag
			end
		end

		command_utils.redisplay()
	end
end
---Taken from [compile-mode.nvim](https://github.com/ej-shafran/compile-mode.nvim/blob/8889a8b3768f35de6192a9f272a840b9f8e276b7/lua/compile-mode/init.lua#L59-L78)
---
---If `fname` has a window open, do nothing.
---Otherwise, split a new window (and possibly buffer) open for that file, respecting `config.split_vertically`.
---
---@param fname string
---@param vertical boolean
---@return integer bufnr the identifier of the buffer for `fname`
local function split_unless_open(fname, vertical)
	local bufnum = vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
	local winnum = vim.fn.bufwinnr(bufnum)

	if winnum == -1 then
		if vertical then
			vim.cmd.vsplit(fname)
		else
			vim.cmd.split(fname)
		end
	end

	return vim.fn.bufnr(vim.fn.expand(fname) --[[@as any]]) --[[@as integer]]
end

---@diagnostic disable-next-line: undefined-field
local buf_set_opt = vim.api.nvim_buf_set_option

---Creates a command which asks for user input (or joins the arguments passed to the command into a string) and runs it as a shell command.
---The `parse` callback is used to determine the way in which the command input should be parsed (allowing for Dired command syntax).
---It returns a `command` array of commands to run and an `is_async` flag which determines what should be done with command output.
---If `is_async` is true, the command output will be written to a buffer named "Async Shell Result". Otherwise, it will be printed using `vim.notify`.
---
---@param parse fun(files: string[], input: string): string[], boolean
---@param opts { input: PromptOpts }
---@return function
function M.execute(parse, opts)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input
		if param.args then
			input = param.args
		else
			input = vim.fn.input({
				prompt = command_utils.prompt_for_files(
					files,
					vim.tbl_extend("force", { flag = "*", suffix = ": " }, opts.input)
				),
				completion = "shellcmd",
			})
		end
		if input == "" then
			return
		end

		local commands, is_async = parse(files, input)

		if is_async then
			local acc = ""
			for _, cmd in ipairs(commands) do
				acc = acc .. utils.command(cmd)
			end

			local bufnr = split_unless_open("Async Shell Result", param.smods and param.smods.vertical or false)

			buf_set_opt(bufnr, "modifiable", true)
			vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, vim.fn.split(acc, "\n") --[[@as table]])
			buf_set_opt(bufnr, "modifiable", false)
			buf_set_opt(bufnr, "filetype", "vimed-async-shell")
			vim.api.nvim_create_autocmd("ExitPre", {
				group = vim.api.nvim_create_augroup("vimed-async-shell", {}),
				callback = function()
					vim.api.nvim_buf_delete(bufnr, { force = true })
				end,
			})
		else
			for _, cmd in ipairs(commands) do
				local result = utils.command(cmd)
				vim.notify(result)
			end
		end
	end
end

---Creates a command which deletes specified files, after confirmation.
---The `get_files` callback determines the files to delete.
---The `if_none` parameter is printed using `vim.notify` if no files (`nil` or empty array) are returned.
---The command can be called with a `!` at the end to delete without asking for confirmation.
---
---@param get_files fun(): string[]|nil
---@param if_none string
---@return function
function M.delete_files(get_files, if_none)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local files = get_files()
		if files == nil or #files == 0 then
			vim.notify(if_none)
			return
		end

		local choice = param.bang and 1
			or vim.fn.confirm(
				command_utils.prompt_for_files(files, {
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

		command_utils.redisplay()
	end
end

---Creates a command that acts on "dirlines", i.e. lines that have directories in them.
---The logic callback is called with the last line, the current line, and the amount of lines in the beginning of the Vimed buffer that are not files or directories.
---It returns an integer specifying the line to move the cursor to, and a boolean specifying whether the motion would be "out of bounds", i.e. greater than the last dirline or before the first dirline.
---
---@param logic fun(last: integer, current: integer, offset: integer): integer, boolean
function M.dirline(logic)
	return function()
		if not utils.is_vimed() then
			return
		end

		local last_dirline = #state.lines
		for i = last_dirline, 1, -1 do
			local line = state.lines[i]
			if line.permissions.is_dir then
				last_dirline = i
				break
			end
		end

		local offset = state.hide_details and 1 or 2
		local current = unpack(vim.api.nvim_win_get_cursor(0))
		local last = last_dirline + offset

		local line, out_of_bounds = logic(last, current, offset)

		if out_of_bounds then
			vim.notify("No more subdirectories")
		end

		vim.api.nvim_win_set_cursor(0, { line, 0 })
	end
end

---Creates a command that does some transformation over each target file (see `command_utils.target_files`) and asks for confirmation before each one.
---The command can be called with a `!` to do the action without confirmation.
---
---@param transform fun(filename: string): string
---@param opts { action: string }
---@return function
function M.confirm_each_file(transform, opts)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		for _, file in ipairs(files) do
			local filename = vim.fs.basename(file)
			local transformed = transform(filename)
			local choice = param.bang and 1
				or vim.fn.confirm(
					opts.action .. " '" .. filename .. "' to '" .. transformed .. "'?",
					"&Yes\n&No\n&Quit"
				)
			if choice == 3 then
				break
			end

			if choice == 1 then
				local transformed_filename = vim.fs.normalize(vim.fs.dirname(file) .. "/" .. transformed)
				os.rename(file, transformed_filename)
				state.flags[transformed_filename] = state.flags[file]
				state.flags[file] = nil
			end
		end

		command_utils.redisplay()
	end
end

---Creates a command that marks all files matching some filter.
---The `filter` callback is called with each `FsEntry` and with the user input (or arguments passed into the command) after it's been passed through the `opts.input.process` function.
---Note that the input is passed even if it's an empty string, unlike some other command creation functions.
---
---@param filter fun(entry: FsEntry, input: any?): boolean
---@param opts { flag: string, kind: string, input: { prompt: string, completion: string?, process: fun(raw: string): any }? }
function M.mark_via_filter(filter, opts)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local input = nil
		if opts.input then
			input = param.args and param.args
				or vim.fn.input({
					prompt = opts.input.prompt,
					completion = opts.input.completion,
				})
			if opts.input.process then
				input = opts.input.process(input)
			end
		end

		local count = 0
		for _, line in ipairs(state.lines) do
			if state.flags[line.path] ~= opts.flag and filter(line, input) then
				state.flags[line.path] = opts.flag
				count = count + 1
			end
		end

		local suffix = count == 1 and "" or "s"
		vim.notify(count .. " " .. opts.kind .. suffix .. " marked")

		command_utils.redisplay()
	end
end

---Creates a command that does some logic for each file that matches a certain regex, taken from user input (or the arguments passed into the function, joined into a string, starting from the second argument if `opts.repl` is set or the very first argument otherwise).
---Each of the actions is confirmed by the user. The command can be called with a `!` to do the action without confirmation.
---If `opts.repl` is set, either the first argument of the command or user input is used to determine the `target` parameter of the `logic` callback.
---
---@param logic fun(file: string, target: string?): boolean|nil
---@param opts { name: string, operation: string, replace: boolean? }
---@return function
function M.with_regexp(logic, opts)
	---@param param CommandParam
	return function(param)
		if not utils.is_vimed() then
			return
		end

		param = param or {}

		local regex_raw
		if param.args then
			if opts.replace then
				regex_raw = vim.fn.join({ table.unpack(param.fargs, 2) })
			else
				regex_raw = param.args
			end
		else
			regex_raw = vim.fn.input({
				prompt = opts.name .. " " .. opts.operation .. " (regexp): ",
			})
		end

		if regex_raw == "" then
			return
		end
		local re = vim.regex(regex_raw) --[[@as any]]

		local all_files = command_utils.target_files() or {}
		local files = vim.tbl_filter(function(file)
			return re:match_str(file)
		end, all_files)

		local repl = nil
		if opts.replace then
			repl = vim.fn.input({
				prompt = opts.name .. " to: ", --TODO: add default
			})
			if repl == "" then
				return
			end
		end

		local count = 0
		for _, file in ipairs(files) do
			if repl ~= nil then
				local target = vim.fn.substitute(vim.fs.basename(file), regex_raw, repl, "")
				local choice = param.bang and 1
					or vim.fn.confirm(
						opts.name .. " '" .. vim.fs.basename(file) .. "' to '" .. target .. "'?",
						"&Yes\n&No\n&Quit"
					)
				if choice == 3 then
					break
				end

				if choice == 1 then
					local target_file = vim.fs.normalize(vim.fs.dirname(file) .. "/" .. target)
					logic(file, target_file)
					count = count + 1
				end
			else
				logic(file)
				count = count + 1
			end
		end

		if #all_files == #files then
			vim.notify(opts.name .. ": " .. count .. " files done")
		else
			vim.notify(opts.name .. ": " .. #all_files - count .. " of " .. #all_files .. " files skipped")
		end

		command_utils.redisplay()
	end
end

---Creates a command that moves the cursor to the nearest marked file in some direction.
---The diretion is specified by the returned values of the `logic` callback - the first value is the start, end, and step of the first direction to search in, and the second value is the same for the "wraparound" direction.
---
---@param logic fun(index: integer): { [1]: integer, [2]: integer, [3]: integer? }, { [1]: integer, [2]: integer, [3]: integer? }
function M.cursor_to_marked_file(logic)
	return function()
		if not utils.is_vimed() then
			return
		end

		local r = unpack(vim.api.nvim_win_get_cursor(0))
		local header_lines = state.hide_details and 1 or 2
		local direction, wrap = logic(r - header_lines)

		for i = direction[1], direction[2], direction[3] or 1 do
			local line = state.lines[i]
			if state.flags[line.path] ~= nil then
				vim.api.nvim_win_set_cursor(0, { i + header_lines, 0 })
				return
			end
		end

		for i = wrap[1], wrap[2], wrap[3] or 1 do
			local line = state.lines[i]
			if state.flags[line.path] ~= nil then
				vim.notify("(Wraparound for next marked file)")
				vim.api.nvim_win_set_cursor(0, { i + header_lines, 0 })
				return
			end
		end

		vim.notify("No next marked file")
	end
end

return M
