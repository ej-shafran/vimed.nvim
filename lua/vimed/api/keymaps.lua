---@alias VimedKeymaps table<"n"|"x"|"v"|"V", table<string, boolean|{ [1]: string|function, [2]: string? }>>

local commands = require("vimed.api.commands")

local M = {}

---@type VimedKeymaps
M.default_keymaps = {
	n = {
		C = { commands.copy, "Copy" },
		D = { commands.delete, "Delete" },
		J = { commands.goto_file, "Goto File" },
		L = { commands.load, "Load" },
		M = { commands.chmod, "Change Permissions" },
		R = { commands.rename, "Rename" },
		S = { commands.symlink, "Symlink" },
		U = { commands.unmark_all, "Unmark All" },
		d = { commands.flag_file_deletion, "Flag For Deletion" },
		m = { commands.mark, "Mark" },
		o = { commands.toggle_sort, "Toggle Sort Order" },
		q = { commands.quit, "Quit" },
		r = { commands.redisplay, "Redisplay" },
		t = { commands.toggle_marks, "Toggle Marks" },
		u = { commands.unmark, "Unmark" },
		x = { commands.flagged_delete, "Delete Flagged Files" },
		["<CR>"] = { commands.enter, "Edit File" },
		["-"] = { commands.back, "Back" },
		["^"] = { commands.back, "Back" },
		["."] = { commands.toggle_hidden, "Toggle Hidden" },
		["+"] = { commands.create_dir, "Create Directory" },
		["!"] = { commands.shell_command, "Shell Command" },
		["X"] = { commands.shell_command, "Shell Command" },
		["&"] = { commands.async_shell_command, "Async Shell Command" },
		["("] = { commands.toggle_hide_details, "Toggle Hide Details" },
	},
	x = {
		d = { commands.flag_file_deletion, "Flag For Deletion" },
		u = { commands.unmark, "Unmark" },
		m = { commands.mark, "Mark" },
	},
}

---@param config_maps VimedKeymaps
function M.setup_keymaps(config_maps)
	for mode, tbl in pairs(config_maps) do
		for lhs, rhs in pairs(tbl) do
			if type(rhs) ~= "boolean" then
				vim.keymap.set(mode, lhs, rhs[1], { buffer = 0, desc = "Vimed: " .. (rhs[2] or lhs) })
			end
		end
	end
end

return M