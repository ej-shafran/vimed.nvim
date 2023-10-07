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

function M.setup_keymaps()
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
	nmap("D", api.commands.delete_file)

	xmap("d", api.commands.flag_file_deletion)
	xmap("u", api.commands.unmark)
	xmap("m", api.commands.mark)
end

---@alias Config { styles: GroupStyles? }

---@param config Config
function M.setup(config)
	hls.setup(vim.tbl_extend("force", hls.default_styles, config.styles or {}))

	vim.api.nvim_create_user_command("Vimed", M.open_vimed, {})
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "vimed",
		callback = function()
			vim.cmd.setlocal("nonumber norelativenumber")
			M.setup_keymaps()
		end,
	})

	local vimed_group = vim.api.nvim_create_augroup("dired", { clear = true })

	-- open vimed when opening a directory
	vim.api.nvim_create_autocmd("BufEnter", {
		pattern = "*",
		command = "if isdirectory(expand('%')) && !&modified | execute 'lua require(\"vimed\").open_vimed()' | endif",
		group = vimed_group,
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		pattern = "*",
		command = "if exists('#FileExplorer') | execute 'autocmd! FileExplorer *' | endif",
		group = vimed_group,
	})

	vim.api.nvim_create_autocmd("VimEnter", {
		pattern = "*",
		command = "if exists('#NERDTreeHijackNetrw') | exe 'au! NERDTreeHijackNetrw *' | endif",
		group = vimed_group,
	})
	vim.cmd([[if exists('#FileExplorer') | execute 'autocmd! FileExplorer *' | endif]])
end

return M
