local api = require("vimed.api")
local render = require("vimed.render")
local colors = require("vimed.render.colors")

local M = {}

function M.open_vimed()
	if not api.utils.is_vimed() then
		render.init()
	end
end

function M.setup_keymaps()
	---@param lhs string
	---@param rhs string|function
	local function nmap(lhs, rhs)
		vim.keymap.set("n", lhs, rhs, { buffer = 0 })
	end

	nmap("q", api.commands.quit)
	nmap("<CR>", api.commands.enter)
	nmap("-", api.commands.back)
end

---@alias Config { colors: HighlightGroups? }

---@param config Config
function M.setup(config)
	colors.setup(vim.tbl_extend("force", {
		header = {
			foreground = "#6666ff",
			gui = "bold",
		},
		perm_dir = {
			foreground = "#2222bb",
		},
		perm_read = {
			foreground = "#bbbb22",
		},
		perm_write = {
			foreground = "#bb2222",
		},
		perm_execute = {
			foreground = "#22bb22",
		},
		link_count = {
			foreground = "#ffbb44",
		},
		day = {
			foreground = "#55cc55",
		},
		time = {
			foreground = "#55cc55",
		},
		month = {
			foreground = "#55cc55",
		},
		group = {},
		owner = {},
		size = {
			foreground = "#ffbb44",
		},
		file_name = {},
		dir_name = {
			foreground = "#6666ff",
		},
	}, config.colors or {}))

	vim.api.nvim_create_user_command("Vimed", M.open_vimed, {})
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "vimed",
		callback = function ()
			vim.cmd.setlocal("nonumber norelativenumber")
			M.setup_keymaps()
		end
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
