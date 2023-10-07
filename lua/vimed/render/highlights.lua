local M = {}

---@alias HighlightStyle { background: string?, foreground: string?, gui: string? }

---@alias GroupStyles
---| { link_count: HighlightStyle?, size: HighlightStyle?, group: HighlightStyle?, owner: HighlightStyle?, month: HighlightStyle?, day: HighlightStyle?, time: HighlightStyle?, file_name: HighlightStyle?, header: HighlightStyle?, dir_name: HighlightStyle?, total: HighlightStyle?, perm_dir: HighlightStyle?, perm_read: HighlightStyle?, perm_write: HighlightStyle?, perm_group: HighlightStyle?, delete_flagged: HighlightStyle?, marked: HighlightStyle? }

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
	delete_flagged = "VimedDeleteFlagged",
	marked = "VimedMarked",
}

---@type GroupStyles
M.default_styles = {
	header = {
		foreground = "#4b8bf4",
		gui = "bold",
	},
	perm_dir = {
		foreground = "#4f8ff4",
	},
	perm_read = {
		foreground = "#dda85b",
	},
	perm_write = {
		foreground = "#f4768e",
	},
	perm_execute = {
		foreground = "#73dac9",
	},
	link_count = {
		foreground = "#ff9e64",
	},
	day = {
		foreground = "#93dc9e",
	},
	time = {
		foreground = "#93dc9e",
	},
	month = {
		foreground = "#93dc9e",
	},
	group = {},
	owner = {},
	size = {
		foreground = "#ff9e64",
	},
	file_name = {},
	dir_name = {
		foreground = "#4786f3",
	},
	delete_flagged = {
		foreground = "#e47482",
		background = "#462d3a",
	},
	marked = {
		background = "#2d292c",
		foreground = "#dda055",
	},
}

---If the given highlight group is not defined, define it.
---@param group_name string
---@param styles HighlightStyle
local function create_hlgroup(group_name, styles)
	---@diagnostic disable-next-line: undefined-field
	local success, existing = pcall(vim.api.nvim_get_hl_by_name, group_name, true)

	if not success or not existing.foreground or not existing.background then
		local hlgroup = "default " .. group_name

		if styles.background then
			hlgroup = hlgroup .. " guibg=" .. styles.background
		end

		if styles.foreground then
			hlgroup = hlgroup .. " guifg=" .. styles.foreground
		else
			-- hlgroup = hlgroup .. " guifg=NONE"
		end

		if styles.gui then
			hlgroup = hlgroup .. " gui=" .. styles.gui
		end

		if not styles.background and not styles.gui and not styles.foreground then
			hlgroup = hlgroup .. " guifg=NONE"
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

		create_hlgroup(M.groups[key], value)
	end
end

return M
