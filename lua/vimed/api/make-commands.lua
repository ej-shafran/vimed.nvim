---@alias PromptOpts {operation: string, flag: string, suffix: string?, multi_operation: string?}

local utils = require("vimed.api.utils")
local state = require("vimed._state")
local render = require("vimed.render")

local M = {}

---Get the path under the cursor, or `nil` if there isn't one.
---@return string|nil
---@return integer r current row in the buffer
function M.cursor_path()
	local r = unpack(vim.api.nvim_win_get_cursor(0))
	local header_lines = state.hide_details and 1 or 2
	if r < header_lines + 1 then
		return nil, r
	end

	return state.lines[r - header_lines].path, r
end

---Get either the marked files or the file under the cursor if there aren't any.
---@return string[]|nil
function M.target_files()
	local files = {}
	local cwd = vim.fn.getcwd()
	for path, flag in pairs(state.flags) do
		if flag == "*" and vim.fs.dirname(path) == cwd then
			table.insert(files, path)
		end
	end

	if #files == 0 then
		local path = M.cursor_path()
		if path == nil then
			return
		end

		files = { path }
	end
	return files
end

-- ---@alias PromptOpts {operation: string, flag: string, suffix: string?, multi_operation: string?}

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
			local path, r = M.cursor_path()
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
---@return function
function M.act_on_files(logic, opts, completion)
	return function()
		if not utils.is_vimed() then
			return
		end

		local files = M.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = nil
		if opts.input ~= nil then
			input = vim.fn.input({
				prompt = prompt_for_files(files, vim.tbl_extend("force", { suffix = " to: ", flag = "*" }, opts.input)),
				completion = completion or "file",
			})
		end

		if opts.confirm ~= nil then
			local choice = vim.fn.confirm(prompt_for_files(files, opts.confirm), "&Yes\n&No")
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

		local files = M.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local target = vim.fn.input({
			prompt = prompt_for_files(files, vim.tbl_extend("force", { flag = "*" }, opts.input)),
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

		local files = M.target_files()
		if files == nil then
			vim.notify("No files specified")
			return
		end

		local input = vim.fn.input({
			prompt = prompt_for_files(files, vim.tbl_extend("force", { flag = "*", suffix = ": " }, opts.input)),
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
				os.execute(cmd)
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

		M.redisplay()
	end
end

return M
