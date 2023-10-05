local M = {}

---@alias HighlightStyle { background: string?, foreground: string?, gui: string? }

---@alias GroupStyles
---| { link_count: HighlightStyle?, size: HighlightStyle?, group: HighlightStyle?, owner: HighlightStyle?, month: HighlightStyle?, day: HighlightStyle?, time: HighlightStyle?, file_name: HighlightStyle?, header: HighlightStyle?, dir_name: HighlightStyle?, total: HighlightStyle?, perm_dir: HighlightStyle?, perm_read: HighlightStyle?, perm_write: HighlightStyle?, perm_group: HighlightStyle?, }

M.groups = {
	perm_dir = "VimedPermDir",
	perm_read = "VimedPermRead",
	perm_write = "VimedPermWrite",
	perm_execute = "VimedPermExecute",
	link_count = "VimedLinkCount",
	group = "VimedGroup",
	owner = "VimedOwner",
	size = "VimedSize",
	month = "VimedMonth",
	day = "VimedDay",
	time = "VimedTime",
	file_name = "VimedFileName",
	dir_name = "VimedDirName",
	header = "VimedHeader",
	total = "VimedTotal",
}

---@type GroupStyles
M.default_styles = {
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

---@param styles GroupStyles
function M.setup(styles)
	for key, value in pairs(styles) do
		if not value then
			value = {}
		end

		create_hlgroup(M.groups[key], value.background, value.foreground, value.gui)
	end
end

return M