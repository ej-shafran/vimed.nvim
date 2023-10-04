local vimed = require("vimed")

vim.api.nvim_create_user_command("Vimed", vimed.open_vimed, {})
vim.api.nvim_create_autocmd("FileType", {
	pattern = "vimed",
	callback = vimed.setup_keymaps,
})
