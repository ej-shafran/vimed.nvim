---@alias Config { styles: GroupStyles?, keymaps: VimedKeymaps?, hijack_netrw: boolean?, keep_line_numbers: boolean? }

local commands = require("vimed.api.commands")
local utils = require("vimed.api.utils")
local render = require("vimed.render")
local hls = require("vimed.render.highlights")
local keymaps = require("vimed.api.keymaps")

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

			cmd("VimedQuit", commands.quit)
			cmd("VimedEnter", commands.enter)
			cmd("VimedBack", commands.back)
			cmd("VimedToggleHidden", commands.toggle_hidden)
			cmd("VimedCreateDir", commands.create_dir)
			cmd("VimedRedisplay", commands.redisplay)
			cmd("VimedToggleSort", commands.toggle_sort)
			cmd("VimedFlagFileDeletion", commands.flag_file_deletion)
			cmd("VimedFlaggedDelete", commands.flagged_delete)
			cmd("VimedUnmark", commands.unmark)
			cmd("VimedMark", commands.mark)
			cmd("VimedUnmarkAll", commands.unmark_all)
			cmd("VimedDelete", commands.delete)
			cmd("VimedToggleMarks", commands.toggle_marks)
			cmd("VimedGotoFile", commands.goto_file)
			cmd("VimedChmod", commands.chmod)
			cmd("VimedRename", commands.rename)
			cmd("VimedShellCommand", commands.shell_command)
			cmd("VimedAsyncShellCommand", commands.async_shell_command)
			cmd("VimedToggleHideDetails", commands.toggle_hide_details)
			cmd("VimedCopy", commands.copy)

			keymaps.setup_keymaps(vim.tbl_deep_extend("force", keymaps.default_keymaps, config.keymaps or {}))
		end,
	})

	if config.hijack_netrw then
		local vimed_group = vim.api.nvim_create_augroup("vimed", { clear = true })

		-- open vimed when opening a directory
		vim.api.nvim_create_autocmd("BufEnter", {
			pattern = "*",
			command = "if isdirectory(expand('%')) && !&modified | execute 'lua require(\"vimed\").open_vimed()' | endif",
			group = vimed_group,
		})

		-- disable file explorer
		vim.api.nvim_create_autocmd("VimEnter", {
			pattern = "*",
			command = "if exists('#FileExplorer') | execute 'autocmd! FileExplorer *' | endif",
			group = vimed_group,
		})
	end
end

return M
