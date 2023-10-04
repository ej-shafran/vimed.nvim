-- TODO rewrite this whole file
local M = {}

M.DIM_TEXT = "VimedDimText"
M.DIRECTORY_NAME = "VimedDirectoryName"
M.DOTFILE = "VimedDotfile"
M.FADE_TEXT_1 = "VimedFadeText1"
M.FADE_TEXT_2 = "VimedFadeText2"
M.FILE_NAME = "VimedFileName"
M.FILE_SUID = "VimedFileSuid"
M.FILE_EXECUTABLE = "VimedFileExecutable"
M.NORMAL = "VimedNormal"
M.SIZE = "VimedSize"
M.NORMALBOLD = "VimedNormalBold"
M.USERNAME = "VimedUsername"
M.MONTH = "VimedMonth"
M.DAY = "VimedDay"
M.SYMBOLIC_LINK = "VimedSymbolicLink"
M.BROKEN_LINK = "VimedBrokenLink"
M.SYMBOLIC_LINK_TARGET = "VimedSymbolicLinkTarget"
M.BROKEN_LINK_TARGET = "VimedBrokenLinkTarget"
M.MARKED_FILE = "VimedMarkedFile"
M.COPY_FILE = "VimedCopyFile"
M.MOVE_FILE = "VimedMoveFile"

local function dec_to_hex(n, chars)
	chars = chars or 6
	local hex = string.format("%0" .. chars .. "x", n)
	while #hex < chars do
		hex = "0" .. hex
	end
	return hex
end

---If the given highlight group is not defined, define it.
---@param hl_group_name string The name of the highlight group.
---@param link_to_if_exists table A list of highlight groups to link to, in order of priority. The first one that exists will be used.
---@param background string|nil The background color to use, in hex, if the highlight group
--is not defined and it is not linked to another group.
---@param foreground string? The foreground color to use, in hex, if the highlight group is not defined and it is not linked to another group.
---@param gui table|string? The gui to use, if the highlight group is not defined and it is not linked to another group.
---@return table table? The highlight group values.
local function create_highlight_group(hl_group_name, link_to_if_exists, background, foreground, gui)
	---@diagnostic disable-next-line: undefined-field
	local success, hl_group = pcall(vim.api.nvim_get_hl_by_name, hl_group_name, true)
	if not success or not hl_group.foreground or not hl_group.background then
		for _, link_to in ipairs(link_to_if_exists) do
			---@diagnostic disable-next-line: undefined-field
			success, hl_group = pcall(vim.api.nvim_get_hl_by_name, link_to, true)
			if success then
				local new_group_has_settings = background or foreground or gui
				local link_to_has_settings = hl_group.foreground or hl_group.background
				if link_to_has_settings or not new_group_has_settings then
					vim.cmd("highlight default link " .. hl_group_name .. " " .. link_to)
					return hl_group
				end
			end
		end

		if type(background) == "number" then
			background = dec_to_hex(background)
		end
		if type(foreground) == "number" then
			foreground = dec_to_hex(foreground)
		end

		local cmd = "highlight default " .. hl_group_name
		if background then
			cmd = cmd .. " guibg=#" .. background
		end
		if foreground then
			cmd = cmd .. " guifg=#" .. foreground
		else
			cmd = cmd .. " guifg=NONE"
		end
		if gui then
			cmd = cmd .. " gui=" .. gui
		end
		vim.cmd(cmd)

		return {
			background = background and tonumber(background, 16) or nil,
			foreground = foreground and tonumber(foreground, 16) or nil,
		}
	end
	return hl_group
end

local faded_highlight_group_cache = {}
---@param hl_group_name string
---@param fade_percentage number
---@return string
M.get_faded_highlight_group = function(hl_group_name, fade_percentage)
	assert(fade_percentage >= 0 and fade_percentage <= 1)

	local key = hl_group_name .. "_" .. tostring(math.floor(fade_percentage * 100))
	if faded_highlight_group_cache[key] then
		return faded_highlight_group_cache[key]
	end

	---@diagnostic disable-next-line: undefined-field
	local normal = vim.api.nvim_get_hl_by_name("Normal", true)
	---@diagnostic disable-next-line: undefined-field
	if type(normal.foreground) ~= "number" then
		---@diagnostic disable-next-line: undefined-field
		if vim.api.nvim_get_option("background") == "dark" then
			normal.foreground = 0xffffff
		else
			normal.foreground = 0x000000
		end
	end
	if type(normal.background) ~= "number" then
		---@diagnostic disable-next-line: undefined-field
		if vim.api.nvim_get_option("background") == "dark" then
			normal.background = 0x000000
		else
			normal.background = 0xffffff
		end
	end
	local foreground = dec_to_hex(normal.foreground)
	local background = dec_to_hex(normal.background)

	---@diagnostic disable-next-line: undefined-field
	local hl_group = vim.api.nvim_get_hl_by_name(hl_group_name, true)
	if type(hl_group.foreground) == "number" then
		foreground = dec_to_hex(hl_group.foreground)
	end
	if type(hl_group.background) == "number" then
		background = dec_to_hex(hl_group.background)
	end

	local gui = {}
	if hl_group.bold then
		table.insert(gui, "bold")
	end
	if hl_group.italic then
		table.insert(gui, "italic")
	end
	if hl_group.underline then
		table.insert(gui, "underline")
	end
	if hl_group.undercurl then
		table.insert(gui, "undercurl")
	end
	if #gui > 0 then
		gui = table.concat(gui, ",") --[[@as table]]
	else
		gui = nil
	end

	local f_red = tonumber(foreground:sub(1, 2), 16)
	local f_green = tonumber(foreground:sub(3, 4), 16)
	local f_blue = tonumber(foreground:sub(5, 6), 16)

	local b_red = tonumber(background:sub(1, 2), 16)
	local b_green = tonumber(background:sub(3, 4), 16)
	local b_blue = tonumber(background:sub(5, 6), 16)

	local red = (f_red * fade_percentage) + (b_red * (1 - fade_percentage))
	local green = (f_green * fade_percentage) + (b_green * (1 - fade_percentage))
	local blue = (f_blue * fade_percentage) + (b_blue * (1 - fade_percentage))

	local new_foreground = string.format("%s%s%s", dec_to_hex(red, 2), dec_to_hex(green, 2), dec_to_hex(blue, 2))

	create_highlight_group(key, {}, hl_group.background, new_foreground, gui)
	faded_highlight_group_cache[key] = key
	return key
end

M.setup = function()
	-- TODO add customization
	create_highlight_group(M.DIM_TEXT, {}, nil, "505050")
	create_highlight_group(M.DIRECTORY_NAME, {}, nil, "9370DB", "bold")
	create_highlight_group(M.DOTFILE, {}, nil, "626262")
	create_highlight_group(M.FADE_TEXT_1, {}, nil, "626262")
	create_highlight_group(M.FADE_TEXT_2, {}, nil, "444444")
	create_highlight_group(M.SIZE, {}, nil, "306844")
	create_highlight_group(M.USERNAME, {}, nil, "87CEFA", "bold")
	create_highlight_group(M.MONTH, {}, nil, "696969", "bold")
	create_highlight_group(M.DAY, {}, nil, "778899", "bold")
	create_highlight_group(M.FILE_NAME, {}, "NONE", "NONE")
	create_highlight_group(M.FILE_SUID, {}, "ff6666", "000000", "bold")
	create_highlight_group(M.NORMAL, { "Normal" })
	create_highlight_group(M.NORMALBOLD, {}, nil, "ffffff", "bold")
	create_highlight_group(M.SYMBOLIC_LINK, {}, nil, "33ccff", "bold")
	create_highlight_group(M.SYMBOLIC_LINK_TARGET, {}, "5bd75b", "000000", "bold")
	create_highlight_group(M.BROKEN_LINK, {}, "2e2e1f", "ff1a1a", "bold")
	create_highlight_group(M.BROKEN_LINK_TARGET, {}, "2e2e1f", "ff1a1a", "bold")
	create_highlight_group(M.FILE_EXECUTABLE, {}, nil, "5bd75b", "bold")
	create_highlight_group(M.MARKED_FILE, {}, nil, "a8b103", "bold")
	create_highlight_group(M.COPY_FILE, {}, nil, "ff8533", "bold")
	create_highlight_group(M.MOVE_FILE, {}, nil, "ff3399", "bold")
end

return M
