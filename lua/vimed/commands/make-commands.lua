---@alias PromptOpts {operation: string, flag: string, suffix: string?, multi_operation: string?}

local utils = require("vimed.utils")
local state = require("vimed._state")
local render = require("vimed.render")
local command_utils = require("vimed.commands.command-utils")

local M = {}

---@param r integer? the row to place the cursor at after rerendering
function M.redisplay(r)
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

---@param logic fun(): integer|nil|false
function M.basic(logic)
	return function()
		if not utils.is_vimed() then
			return
		end

		local r = logic()

		if r ~= false then
			M.redisplay(r)
		end
	end
end

---@param state_key string
---@return function
function M.toggle(state_key)
	return function()
		if not utils.is_vimed() then
			return
		end

		state[state_key] = not state[state_key]
		M.redisplay()
	end
end

--TODO: refactor
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

			M.redisplay()
		else
			local path, r = command_utils.cursor_path()
			if path == nil then
				return
			end

			local basename = vim.fs.basename(path)
			if basename ~= "." and basename ~= ".." then
				state.flags[path] = flag
			end
			M.redisplay(r + 1)
		end
	end
end

---@param logic fun(files: string[], input: string?): integer|nil|false
---@param opts { input: PromptOpts?, confirm: PromptOpts? }
---@param completion string?
---@param default string?
---@return function
function M.act_on_files(logic, opts, completion, default)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = nil
		if opts.input ~= nil then
			input = vim.fn.input({
				prompt = command_utils.prompt_for_files(
					files,
					vim.tbl_extend("force", { suffix = " to: ", flag = "*" }, opts.input)
				),
				completion = completion or "file",
				default = default,
			})
		end

		if opts.confirm ~= nil then
			local choice = vim.fn.confirm(command_utils.prompt_for_files(files, opts.confirm), "&Yes\n&No")
			if choice ~= 1 then
				return
			end
		end

		local r = logic(files, input)

		if r ~= false then
			M.redisplay(r)
		end
	end
end

---@param logic fun(src: string, trg: string)
---@param opts { input: PromptOpts?, flag: string }
function M.create_files(logic, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local target = vim.fn.input({
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

		M.redisplay()
	end
end

---@param parse fun(files: string[], input: string): string[], boolean
---@param opts { input: PromptOpts }
---@return function
function M.execute(parse, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = vim.fn.input({
			prompt = command_utils.prompt_for_files(files, vim.tbl_extend("force", { flag = "*", suffix = ": " }, opts.input)),
			completion = "shellcmd",
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
				local result = utils.command(cmd)
				vim.notify(result)
			end
		end
	end
end

---@param get_files fun(): string[]|nil
---@param if_none string
---@return function
function M.delete_files(get_files, if_none)
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

		M.redisplay()
	end
end

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

---@param transform fun(filename: string): string
---@param opts { action: string }
---@return function
function M.confirm_each_file(transform, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = command_utils.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		for _, file in ipairs(files) do
			local filename = vim.fs.basename(file)
			local transformed = transform(filename)
			local choice =
				vim.fn.confirm(opts.action .. " '" .. filename .. "' to '" .. transformed .. "'?", "&Yes\n&No\n&Quit")
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

		M.redisplay()
	end
end

---@param filter fun(entry: FsEntry, input: any?): boolean
---@param opts { flag: string, kind: string, input: { prompt: string, completion: string?, process: fun(raw: string): any }? }
function M.mark_via_filter(filter, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local input = nil
		if opts.input then
			input = vim.fn.input({
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

		M.redisplay()
	end
end

---@param logic fun(file: string, target: string?): boolean|nil
---@param opts { name: string, operation: string, replace: boolean? }
---@return function
function M.with_regexp(logic, opts)
	return function()
		if not utils.is_vimed() then
			return
		end

		local regex_raw = vim.fn.input({
			prompt = opts.name .. " " .. opts.operation .. " (regexp): ",
		})
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
				local choice = vim.fn.confirm(
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

		M.redisplay()
	end
end

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
