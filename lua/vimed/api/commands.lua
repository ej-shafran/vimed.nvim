local utils = require("vimed.api.utils")

local M = {}

function M.quit()
	if not utils.is_vimed() then
		return
	end

	vim.cmd.bp()
end

return M
