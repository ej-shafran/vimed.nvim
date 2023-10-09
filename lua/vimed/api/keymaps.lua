---@alias VimedKeymaps table<"n"|"x"|"v"|"V", table<string, boolean|{ [1]: string|function, [2]: string? }>>

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
		["<CR>"] = { commands.enter, "Edit File" },
		["~"] = { commands.flag_backup_files, "Flag Backup Files" },
		["-"] = { commands.back, "Back" },
		["^"] = { commands.back, "Back" },
		["."] = { commands.toggle_hidden, "Toggle Hidden" },
		["+"] = { commands.create_dir, "Create Directory" },
		["!"] = { commands.shell_command, "Shell Command" },
		["X"] = { commands.shell_command, "Shell Command" },
		["&"] = { commands.async_shell_command, "Async Shell Command" },
		["("] = { commands.toggle_hide_details, "Toggle Hide Details" },
		["<"] = { commands.prev_dirline, "Previous Dir Line" },
		[">"] = { commands.next_dirline, "Next Dir Line" },
		["%u"] = { commands.upcase, "Rename Uppercase" },
		["%l"] = { commands.downcase, "Rename Downcase" },
		["%m"] = { commands.mark_regexp, "Mark Files Using Regex" },
		["*u"] = { commands.unmark, "Unmark" },
		["*m"] = { commands.mark, "Mark" },
		["*t"] = { commands.toggle_marks, "Toggle Marks" },
		["%r"] = { commands.rename_regexp, "Rename By Regex" },
		["%R"] = { commands.rename_regexp, "Rename By Regex" },
		["%C"] = { commands.copy_regexp, "Copy By Regex" },
		["*s"] = { commands.mark_subdir_files, "Mark Subdir Files" },
		["*!"] = { commands.unmark_all, "Unmark All" },
		["**"] = { commands.mark_executables, "Mark Executables" },
		["*@"] = { commands.mark_symlinks, "Mark Symbolic Links" },
		["*/"] = { commands.mark_directories, "Mark Directories" },
		["*%"] = { commands.mark_regexp, "Mark Files Using Regex" },
		["*."] = { commands.mark_extension, "Mark Files By Extension" },
		["*("] = { commands.mark_lua_expression, "Mark Files By Lua Expression" },
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
function M.setup(config_maps)
	for mode, tbl in pairs(config_maps) do
		for lhs, rhs in pairs(tbl) do
			if type(rhs) ~= "boolean" then
				vim.keymap.set(mode, lhs, rhs[1], { buffer = 0, desc = "Vimed: " .. (rhs[2] or lhs) })
			end
		end
	end
end

return M
