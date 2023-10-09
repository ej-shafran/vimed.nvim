---@alias Config { styles: GroupStyles?, keymaps: VimedKeymaps?, hijack_netrw: boolean?, keep_line_numbers: boolean?, compress_files_alist: table<string, string>?, garbage_files_regex: string? }

local commands = require("vimed.api.commands")
local utils = require("vimed.api.utils")
local render = require("vimed.render")
local hls = require("vimed.render.highlights")
local keymaps = require("vimed.api.keymaps")
local state = require("vimed._state")

local M = {}

local function cmd(name, command)
	vim.api.nvim_buf_create_user_command(0, name, command, {})
end

function M.open_vimed()
	if not utils.is_vimed() then
		render.init()
	end
end

---@param config Config
function M.setup(config)
	state.compress_files_alist =
		vim.tbl_extend("force", state.default_compress_files_alist, config.compress_files_alist or {})
	if config.garbage_files_regex ~= nil then
		state.garbage_files_regex = config.garbage_files_regex
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

			cmd("VimedAsyncShellCommand", commands.async_shell_command)
			cmd("VimedBack", commands.back)
			cmd("VimedChmod", commands.chmod)
			cmd("VimedChown", commands.chown)
			cmd("VimedCompress", commands.compress)
			cmd("VimedCompressTo", commands.compress_to)
			cmd("VimedCopy", commands.copy)
			cmd("VimedCopyRegexp", commands.copy_regexp)
			cmd("VimedCreateDir", commands.create_dir)
			cmd("VimedDelete", commands.delete)
			cmd("VimedDowncase", commands.downcase)
			cmd("VimedEnter", commands.enter)
			cmd("VimedFlagBackupFiles", commands.flag_backup_files)
			cmd("VimedFlagFileDeletion", commands.flag_file_deletion)
			cmd("VimedFlagGarbageFiles", commands.flag_garbage_files)
			cmd("VimedFlaggedDelete", commands.flagged_delete)
			cmd("VimedGotoFile", commands.goto_file)
			cmd("VimedHardlink", commands.hardlink)
			cmd("VimedHardlinkRegexp", commands.hardlink_regexp)
			cmd("VimedLoad", commands.load)
			cmd("VimedMark", commands.mark)
			cmd("VimedMarkDirectories", commands.mark_directories)
			cmd("VimedMarkExecutables", commands.mark_executables)
			cmd("VimedMarkExtension", commands.mark_extension)
			cmd("VimedMarkLuaExpression", commands.mark_lua_expression)
			cmd("VimedMarkRegexp", commands.mark_regexp)
			cmd("VimedMarkSubdirFiles", commands.mark_subdir_files)
			cmd("VimedMarkSymlinks", commands.mark_symlinks)
			cmd("VimedNextDirline", commands.next_dirline)
			cmd("VimedPrevDirline", commands.prev_dirline)
			cmd("VimedQuit", commands.quit)
			cmd("VimedRedisplay", commands.redisplay)
			cmd("VimedRename", commands.rename)
			cmd("VimedShellCommand", commands.shell_command)
			cmd("VimedSymlink", commands.symlink)
			cmd("VimedSymlinkRegexp", commands.symlink_regexp)
			cmd("VimedToggleHidden", commands.toggle_hidden)
			cmd("VimedToggleHideDetails", commands.toggle_hide_details)
			cmd("VimedToggleMarks", commands.toggle_marks)
			cmd("VimedToggleSort", commands.toggle_sort)
			cmd("VimedTouch", commands.touch)
			cmd("VimedUnmark", commands.unmark)
			cmd("VimedUnmarkAll", commands.unmark_all)
			cmd("VimedUpcase", commands.upcase)
			cmd("VimedYank", commands.yank)

			keymaps.setup(vim.tbl_deep_extend("force", keymaps.default_keymaps, config.keymaps or {}))
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
