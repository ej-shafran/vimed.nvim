---@alias VimedKeymaps table<"n"|"x"|"v"|"V", table<string, string|fun()>?>
---
local commands = require("vimed.api.commands")

local M = {}

---@type VimedKeymaps
M.default_keymaps = {
	n = {
		D = commands.delete,
		J = commands.goto_file,
		M = commands.chmod,
		R = commands.rename,
		U = commands.unmark_all,
		d = commands.flag_file_deletion,
		m = commands.mark,
		o = commands.toggle_sort,
		q = commands.quit,
		r = commands.redisplay,
		t = commands.toggle_marks,
		u = commands.unmark,
		x = commands.flagged_delete,
		["<CR>"] = commands.enter,
		["-"] = commands.back,
		["^"] = commands.back,
		["."] = commands.toggle_hidden,
		["+"] = commands.create_dir,
		["!"] = commands.shell_command,
		["X"] = commands.shell_command,
		["&"] = commands.async_shell_command,
	},
	x = {
		d = commands.flag_file_deletion,
		u = commands.unmark,
		m = commands.mark,
	},
}

---@param config_maps VimedKeymaps
function M.setup_keymaps(config_maps)
	for mode, tbl in pairs(config_maps) do
		for lhs, rhs in pairs(tbl) do
			if rhs ~= nil then
				vim.keymap.set(mode, lhs, rhs, { buffer = 0 })
			end
		end
	end
end

return M
