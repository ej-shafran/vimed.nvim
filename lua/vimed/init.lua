---@alias VimedKeymaps { n: table<string, string|fun()>?, x: table<string, string|fun()>? }
---@alias Config { styles: GroupStyles?, keymaps: VimedKeymaps?, hijack_netrw: boolean? }

local api = require("vimed.api")
local render = require("vimed.render")
local hls = require("vimed.render.highlights")

local M = {}

function M.open_vimed()
	if not api.utils.is_vimed() then
		render.init()
	end
end

---@param lhs string
---@param rhs string|function
local function nmap(lhs, rhs)
	vim.keymap.set("n", lhs, rhs, { buffer = 0 })
end

local function xmap(lhs, rhs)
	vim.keymap.set("x", lhs, rhs, { buffer = 0 })
end

---@param config_maps VimedKeymaps
function M.setup_keymaps(config_maps)
	nmap("q", api.commands.quit)
	nmap("<CR>", api.commands.enter)
	nmap("-", api.commands.back)
	nmap("^", api.commands.back)
	nmap(".", api.commands.toggle_hidden)
	nmap("+", api.commands.create_dir)
	nmap("r", api.commands.redisplay)
	nmap("o", api.commands.toggle_sort)
	nmap("d", api.commands.flag_file_deletion)
	nmap("x", api.commands.flagged_delete)
	nmap("u", api.commands.unmark)
	nmap("m", api.commands.mark)
	nmap("U", api.commands.unmark_all)
	nmap("D", api.commands.delete)
	nmap("t", api.commands.toggle_marks)
	nmap("J", api.commands.goto_file)
	nmap("M", api.commands.chmod)

	xmap("d", api.commands.flag_file_deletion)
	xmap("u", api.commands.unmark)
	xmap("m", api.commands.mark)

	if config_maps.n then
		for key, val in pairs(config_maps.n) do
			nmap(key, val)
		end
	end

	if config_maps.x then
		for key, val in pairs(config_maps.n) do
			xmap(key, val)
		end
	end
end

local function create_cmd(name, cmd)
	vim.api.nvim_buf_create_user_command(0, name, cmd, {})
end

function M.setup_commands()
	create_cmd("VimedQuit", api.commands.quit)
	create_cmd("VimedEnter", api.commands.enter)
	create_cmd("VimedBack", api.commands.back)
	create_cmd("VimedToggleHidden", api.commands.toggle_hidden)
	create_cmd("VimedCreateDir", api.commands.create_dir)
	create_cmd("VimedRedisplay", api.commands.redisplay)
	create_cmd("VimedToggleSort", api.commands.toggle_sort)
	create_cmd("VimedFlagFileDeletion", api.commands.flag_file_deletion)
	create_cmd("VimedFlaggedDelete", api.commands.flagged_delete)
	create_cmd("VimedUnmark", api.commands.unmark)
	create_cmd("VimedMark", api.commands.mark)
	create_cmd("VimedUnmarkAll", api.commands.unmark_all)
	create_cmd("VimedDelete", api.commands.delete)
	create_cmd("VimedToggleMarks", api.commands.toggle_marks)
	create_cmd("VimedGotoFile", api.commands.goto_file)
	create_cmd("VimedChmod", api.commands.chmod)
end

---@param config Config
function M.setup(config)
	hls.setup(vim.tbl_extend("force", hls.default_styles, config.styles or {}))

	vim.api.nvim_create_user_command("Vimed", M.open_vimed, {})

	vim.api.nvim_create_autocmd("FileType", {
		pattern = "vimed",
		callback = function()
			vim.cmd.setlocal("nonumber norelativenumber")
			M.setup_keymaps(config.keymaps or {})
			M.setup_commands()
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
