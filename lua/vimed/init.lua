---@alias Config { styles: GroupStyles?, keymaps: VimedKeymaps?, hijack_netrw: boolean?, keep_line_numbers: boolean?, compress_files_alist: table<string, string>?, garbage_files_regex: string?, omit_files_regex: string?, omit_extensions: string[]?, which_key_support: boolean? }

local commands = require("vimed.commands")
local utils = require("vimed.utils")
local render = require("vimed.render")
local hls = require("vimed.highlights")
local keymaps = require("vimed.keymaps")
local state = require("vimed._state")

local M = {}

local flag_list = { "*", "D", "Y", "H", "C" }

local function cmd(name, command, opts)
	vim.api.nvim_buf_create_user_command(0, name, command, opts or {})
end

function M.open_vimed()
	if not utils.is_vimed() then
		render.init()
	end
end

---@param config Config?
function M.setup(config)
	config = config or {}

	state.compress_files_alist =
		vim.tbl_extend("force", state.default_compress_files_alist, config.compress_files_alist or {})
	if config.garbage_files_regex ~= nil then
		state.garbage_files_regex = config.garbage_files_regex
	end
	if config.omit_files_regex then
		state.omit_files_regex = config.omit_files_regex
	end
	if config.omit_extensions then
		state.omit_extensions = config.omit_extensions
	end

	hls.setup(vim.tbl_extend("force", hls.default_styles, config.styles or {}))

	vim.api.nvim_create_user_command("Vimed", M.open_vimed, {})

	-- setup keymaps and commands within Vimed buffers
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "vimed",
		callback = function()
			if not config.keep_line_numbers then
				-- remove linenumbers
				vim.cmd.setlocal("nonumber norelativenumber")
			end

			-- define a VimScript function for getting the completion of dired commands
			vim.api.nvim_exec2([[
			function! VimedDiredCommandCompletion(ArgLead, CmdLine, CursorPos)
				let allCommands = []] .. vim.fn.join(
				vim.tbl_map(function(key)
					return '"' .. key .. '"'
				end, vim.tbl_keys(commands.dired_command_map)),
				", "
			) .. [[]
				return filter(allCommands, 'v:val =~ "^'. a:ArgLead .'"')
			endfunction
			]], {})

			cmd(
				"DiredToVimed",
				commands.from_dired,
				{ nargs = "?", complete = "customlist,VimedDiredCommandCompletion" }
			)

			cmd("VimedAsyncShellCommand", commands.async_shell_command, { nargs = "*", complete = "shellcmd" })
			cmd("VimedBack", commands.back)
			cmd("VimedBrowseURL", commands.browse_url)
			cmd("VimedChangeMarks", commands.change_marks, {
				nargs = "*",
				complete = function()
					return flag_list
				end,
			})
			cmd("VimedChmod", commands.chmod, { nargs = "?", complete = "file" })
			cmd("VimedChown", commands.chown, { nargs = "?", complete = "file" })
			cmd("VimedCompress", commands.compress, { nargs = "?", complete = "file" })
			cmd("VimedCompressTo", commands.compress_to, { nargs = "*", complete = "file" })
			cmd("VimedCopy", commands.copy, { nargs = "?", bang = true, complete = "file" })
			cmd("VimedCopyRegexp", commands.copy_regexp, { nargs = "*", bang = true })
			cmd("VimedCreateDir", commands.create_dir, { nargs = "?" })
			cmd("VimedDelete", commands.delete, { bang = true })
			cmd("VimedDiff", commands.diff, { nargs = "?", complete = "file" })
			cmd("VimedDowncase", commands.downcase, { bang = true })
			cmd("VimedEnter", commands.enter)
			cmd("VimedFlagBackupFiles", commands.flag_backup_files)
			cmd("VimedFlagFileDeletion", commands.flag_file_deletion)
			cmd("VimedFlagGarbageFiles", commands.flag_garbage_files, { nargs = "?", complete = "file" })
			cmd("VimedFlagRegexp", commands.flag_regexp, { nargs = "?", complete = "file" })
			cmd("VimedFlaggedDelete", commands.flagged_delete, { bang = true })
			cmd("VimedGotoFile", commands.goto_file, { nargs = "?", complete = "file" })
			cmd("VimedHardlink", commands.hardlink, { nargs = "?", bang = true, complete = "file" })
			cmd("VimedHardlinkRegexp", commands.hardlink_regexp, { nargs = "*", bang = true, complete = "file" })
			cmd("VimedLoad", commands.load, { bang = true })
			cmd("VimedMark", commands.mark)
			cmd("VimedMarkDirectories", commands.mark_directories)
			cmd("VimedMarkExecutables", commands.mark_executables)
			cmd("VimedMarkExtension", commands.mark_extension, { nargs = "?" })
			cmd("VimedMarkFilesContainingRegexp", commands.mark_files_containing_regexp, { nargs = "*" })
			cmd("VimedMarkLuaExpression", commands.mark_lua_expression, { nargs = "*", complete = "lua" })
			cmd("VimedMarkOmitted", commands.mark_omitted)
			cmd("VimedMarkRegexp", commands.mark_regexp, { nargs = "*" })
			cmd("VimedMarkSubdirFiles", commands.mark_subdir_files)
			cmd("VimedMarkSymlinks", commands.mark_symlinks)
			cmd("VimedNextDirline", commands.next_dirline)
			cmd("VimedNextMarkedFile", commands.next_marked_file)
			cmd("VimedPrevDirline", commands.prev_dirline)
			cmd("VimedPrevMarkedFile", commands.prev_marked_file)
			cmd("VimedPrint", commands.print, { nargs = "?", complete = "shellcmd" })
			cmd("VimedQuit", commands.quit)
			cmd("VimedRedisplay", commands.redisplay)
			cmd("VimedRename", commands.rename, { nargs = "?", bang = true, complete = "file" })
			cmd("VimedShellCommand", commands.shell_command, { nargs = "*", complete = "shellcmd" })
			cmd("VimedSymlink", commands.symlink, { nargs = "?", bang = true, complete = "file" })
			cmd("VimedSymlinkRegexp", commands.symlink_regexp, { nargs = "*", bang = true, complete = "file" })
			cmd("VimedToggleHidden", commands.toggle_hidden)
			cmd("VimedToggleHideDetails", commands.toggle_hide_details)
			cmd("VimedToggleMarks", commands.toggle_marks)
			cmd("VimedToggleSort", commands.toggle_sort)
			cmd("VimedTouch", commands.touch, { nargs = "?" })
			cmd("VimedUnmark", commands.unmark)
			cmd("VimedUnmarkAll", commands.unmark_all)
			cmd("VimedUnmarkBackward", commands.unmark_backward)
			cmd("VimedUnmarkFiles", commands.unmark_files, {
				nargs = "?",
				bang = true,
				complete = function()
					return flag_list
				end,
			})
			cmd("VimedUpcase", commands.upcase, { bang = true })
			cmd("VimedYank", commands.yank)

			keymaps.setup(
				vim.tbl_deep_extend("force", keymaps.default_keymaps, config.keymaps or {}),
				config.which_key_support
			)
		end,
	})

	if config.hijack_netrw then
		local vimed_group = vim.api.nvim_create_augroup("vimed", { clear = true })

		-- open vimed when opening a directory
		vim.api.nvim_create_autocmd("BufEnter", {
			pattern = "*",
			callback = function()
				local bufvar = vim.fn.getbufvar(vim.api.nvim_get_current_buf(), "&modified") --[[@as integer]]
				if vim.fn.isdirectory(vim.fn.expand("%")) ~= 0 and vim.fn.empty(bufvar) ~= 0 then
					M.open_vimed()
				end
			end,
			group = vimed_group,
		})

		-- disable file explorer
		vim.api.nvim_create_autocmd("VimEnter", {
			pattern = "*",
			callback = function()
				if vim.fn.exists("#FileExplorer") then
					vim.cmd("autocmd! FileExplorer *")
				end
			end,
			group = vimed_group,
		})
	end
end

return M
