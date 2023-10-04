-- TODO rewrite this whole file
local M = {}

---@alias HighlightStyle { background: string?, foreground: string?, gui: string? }

---@alias HighlightGroups
---| { link_count: HighlightStyle?, group: HighlightStyle?, owner: HighlightStyle?, month: HighlightStyle?, day: HighlightStyle?, time: HighlightStyle?, file_name: HighlightStyle?, header: HighlightStyle?, dir_name: HighlightStyle?, total: HighlightStyle?, perm_dir: HighlightStyle?, perm_read: HighlightStyle?, perm_write: HighlightStyle?, perm_group: HighlightStyle?, }

M.hl = {
	perm_dir = "VimedPermDir",
	perm_read = "VimedPermRead",
	perm_write = "VimedPermWrite",
	perm_execute = "VimedPermExecute",
	link_count = "VimedLinkCount",
	group = "VimedGroup",
	owner = "VimedOwner",
	month = "VimedMonth",
	day = "VimedDay",
	time = "VimedTime",
	file_name = "VimedFileName",
	dir_name = "VimedDirName",
	header = "VimedHeader",
	total = "VimedTotal",
}

---If the given highlight group is not defined, define it.
---@param group_name string
---@param guibg string|nil
---@param guifg string?
---@param gui table|string?
local function create_hlgroup(group_name, guibg, guifg, gui)
	---@diagnostic disable-next-line: undefined-field
	local success, existing = pcall(vim.api.nvim_get_hl_by_name, group_name, true)

	if not success or not existing.foreground or not existing.background then
		local hlgroup = "default " .. group_name

		if guibg then
			hlgroup = hlgroup .. " guibg=" .. guibg
		end

		if guifg then
			hlgroup = hlgroup .. " guifg=" .. guifg
		else
			hlgroup = hlgroup .. " guifg=NONE"
		end

		if gui then
			hlgroup = hlgroup .. " gui=" .. gui
		end

		vim.cmd.highlight(hlgroup)
	end
end

---@param styles HighlightGroups
M.setup = function(styles)
	for key, value in pairs(styles) do
		if not value then
			value = {}
		end
		create_hlgroup(M.hl[key], value.background, value.foreground, value.gui)
	end
end

return M
