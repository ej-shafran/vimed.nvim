local vimed = require("vimed")

vim.api.nvim_create_user_command("Vimed", vimed.hello_world, {})
