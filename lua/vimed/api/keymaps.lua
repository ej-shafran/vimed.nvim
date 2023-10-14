---@alias VimedKeymaps table<"n"|"x"|"v"|"V", table<string, "which_key_ignore"|false|{ [1]: string|function, [2]: string? }>>

local commands = require("vimed.api.commands")

local M = {}

---@type VimedKeymaps
M.default_keymaps = {
	n = {
		C = { commands.copy, "Copy" },
		D = { commands.delete, "Delete" },
		H = { commands.hardlink, "Hard Link" },
		J = { commands.goto_file, "Goto File" },
		L = { commands.load, "Load" },
		M = { commands.chmod, "Change Permissions" },
		O = { commands.chown, "Change Owner" },
		P = { commands.print, "Print" },
		R = { commands.rename, "Rename" },
		S = { commands.symlink, "Symlink" },
		T = { commands.touch, "Change Timestamp" },
		U = { commands.unmark_all, "Unmark All" },
		Y = { commands.yank, "Yank File Name" },
		Z = { commands.compress, "Compress Or Uncompress" },
		a = { commands.enter, "Edit File" },
		c = { commands.compress_to, "Compress To" },
		d = { commands.flag_file_deletion, "Flag For Deletion" },
		m = { commands.mark, "Mark" },
		o = { commands.toggle_sort, "Toggle Sort Order" },
		q = { commands.quit, "Quit" },
		r = { commands.redisplay, "Redisplay" },
		t = { commands.toggle_marks, "Toggle Marks" },
		u = { commands.unmark, "Unmark" },
		x = { commands.flagged_delete, "Delete Flagged Files" },
		["!"] = { commands.shell_command, "Shell Command" },
		["%&"] = { commands.flag_garbage_files, "Flag Garbage Files" },
		["%C"] = { commands.copy_regexp, "Copy By Regex" },
		["%H"] = { commands.hardlink_regexp, "Hardlink By Regex" },
		["%R"] = { commands.rename_regexp, "Rename By Regex" },
		["%S"] = { commands.symlink_regexp, "Symlink By Regex" },
		["%d"] = { commands.flag_regexp, "Flag For Deletion by Regex" },
		["%g"] = { commands.mark_files_containing_regexp, "Mark Files Containing Regexp" },
		["%l"] = { commands.downcase, "Rename Downcase" },
		["%m"] = { commands.mark_regexp, "Mark Files Using Regex" },
		["%r"] = { commands.rename_regexp, "Rename By Regex" },
		["%u"] = { commands.upcase, "Rename Uppercase" },
		["&"] = { commands.async_shell_command, "Async Shell Command" },
		["("] = { commands.toggle_hide_details, "Toggle Hide Details" },
		["*!"] = { commands.unmark_all, "Unmark All" },
		["*%"] = { commands.mark_regexp, "Mark Files Using Regex" },
		["*("] = { commands.mark_lua_expression, "Mark Files By Lua Expression" },
		["**"] = { commands.mark_executables, "Mark Executables" },
		["*."] = { commands.mark_extension, "Mark Files By Extension" },
		["*/"] = { commands.mark_directories, "Mark Directories" },
		["*?"] = { commands.unmark_files, "Unmark All Files" },
		["*@"] = { commands.mark_symlinks, "Mark Symbolic Links" },
		["*c"] = { commands.change_marks, "Change Marks" },
		["*m"] = { commands.mark, "Mark" },
		["*s"] = { commands.mark_subdir_files, "Mark Subdir Files" },
		["*t"] = { commands.toggle_marks, "Toggle Marks" },
		["*u"] = { commands.unmark, "Unmark" },
		["*<C-n>"] = { commands.next_marked_file, "Next Marked File" },
		["*<C-p>"] = { commands.prev_marked_file, "Previous Marked File" },
		["*<Del>"] = { commands.unmark_backward, "Unmark Backwards" },
		["+"] = { commands.create_dir, "Create Directory" },
		["-"] = { commands.back, "Back" },
		["."] = { commands.toggle_hidden, "Toggle Hidden" },
		["<"] = { commands.prev_dirline, "Previous Dir Line" },
		["<CR>"] = { commands.enter, "Edit File" },
		[">"] = { commands.next_dirline, "Next Dir Line" },
		["X"] = { commands.shell_command, "Shell Command" },
		["^"] = { commands.back, "Back" },
		["~"] = { commands.flag_backup_files, "Flag Backup Files" },
	},
	x = {
		d = { commands.flag_file_deletion, "Flag For Deletion" },
		u = { commands.unmark, "Unmark" },
		m = { commands.mark, "Mark" },
		["*u"] = { commands.unmark, "Unmark" },
		["*m"] = { commands.mark, "Mark" },
	},
}

---@param config_maps VimedKeymaps
---@param which_key_support boolean?
function M.setup(config_maps, which_key_support)
	if which_key_support then
		require("which-key").register({
			["*"] = {
				name = "mark",
			},
			["%"] = {
				name = "regex",
			},
		}, { buffer = 0 })
	end

	for mode, tbl in pairs(config_maps) do
		if which_key_support then
			require("which-key").register(tbl, { mode = mode, buffer = 0 })
		else
			for lhs, rhs in pairs(tbl) do
				if rhs ~= false then
					vim.keymap.set(
						mode,
						lhs,
						rhs[1],
						{ buffer = 0, desc = "Vimed: " .. (rhs[2] or lhs), noremap = true }
					)
				end
			end
		end
	end
end

return M
