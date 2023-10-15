local a = require("plenary.async")
local tests = a.tests
local describe = tests.describe
local it = tests.it

---Fix type issue
---@type any
local assert = assert

local function script_path()
	return debug.getinfo(2, "S").source:sub(2):match("(.*/)"):match("(.*/)")
end
describe("Vimed Commands", function()
	local vimed = require("vimed")

	tests.before_each(function()
		vim.api.nvim_set_current_dir(vim.fs.dirname(script_path()))

		local rand = math.random(10000)
		vim.fn.mkdir("workdir/" .. tostring(rand), "p")
		vim.api.nvim_set_current_dir("workdir/" .. tostring(rand))
	end)

	-- cmd("DiredToVimed", commands.from_dired)

	describe("VimedAsyncShellCommand", function() end) -- TODO

	describe("VimedBack", function()
		it("should change the cwd", function()
			vimed.setup({})
			vimed.open_vimed()

			local target = vim.fs.dirname(vim.fn.getcwd() --[[@as string]])

			vim.cmd.VimedBack()
			assert.are.same(target, vim.fn.getcwd())
		end)
	end)

	describe("VimedBrowseURL", function() end) -- TODO

	describe("VimedChangeMarks", function() end) -- TODO

	describe("VimedChmod", function() end) -- TODO

	describe("VimedChown", function() end) -- TODO

	describe("VimedCompress", function() end) -- TODO

	describe("VimedCompressTo", function() end) -- TODO

	describe("VimedCopy", function() end) -- TODO

	describe("VimedCopyRegexp", function() end) -- TODO

	describe("VimedCreateDir", function() end) -- TODO

	describe("VimedDelete", function() end) -- TODO

	describe("VimedDiff", function() end) -- TODO

	describe("VimedDowncase", function() end) -- TODO

	describe("VimedEnter", function() end) -- TODO

	describe("VimedFlagBackupFiles", function() end) -- TODO

	describe("VimedFlagFileDeletion", function() end) -- TODO

	describe("VimedFlagGarbageFiles", function() end) -- TODO

	describe("VimedFlagRegexp", function() end) -- TODO

	describe("VimedFlaggedDelete", function() end) -- TODO

	describe("VimedGotoFile", function() end) -- TODO

	describe("VimedHardlink", function() end) -- TODO

	describe("VimedHardlinkRegexp", function() end) -- TODO

	describe("VimedLoad", function() end) -- TODO

	describe("VimedMark", function() end) -- TODO

	describe("VimedMarkDirectories", function() end) -- TODO

	describe("VimedMarkExecutables", function() end) -- TODO

	describe("VimedMarkExtension", function() end) -- TODO

	describe("VimedMarkFilesContainingRegexp", function() end) -- TODO

	describe("VimedMarkLuaExpression", function() end) -- TODO

	describe("VimedMarkOmitted", function() end) -- TODO

	describe("VimedMarkRegexp", function() end) -- TODO

	describe("VimedMarkSubdirFiles", function() end) -- TODO

	describe("VimedMarkSymlinks", function() end) -- TODO

	describe("VimedNextDirline", function() end) -- TODO

	describe("VimedNextMarkedFile", function() end) -- TODO

	describe("VimedPrevDirline", function() end) -- TODO

	describe("VimedPrevMarkedFile", function() end) -- TODO

	describe("VimedPrint", function() end) -- TODO

	describe("VimedQuit", function() end) -- TODO

	describe("VimedRedisplay", function() end) -- TODO

	describe("VimedRename", function() end) -- TODO

	describe("VimedShellCommand", function() end) -- TODO

	describe("VimedSymlink", function() end) -- TODO

	describe("VimedSymlinkRegexp", function() end) -- TODO

	describe("VimedToggleHidden", function() end) -- TODO

	describe("VimedToggleHideDetails", function() end) -- TODO

	describe("VimedToggleMarks", function() end) -- TODO

	describe("VimedToggleSort", function() end) -- TODO

	describe("VimedTouch", function() end) -- TODO

	describe("VimedUnmark", function() end) -- TODO

	describe("VimedUnmarkAll", function() end) -- TODO

	describe("VimedUnmarkBackward", function() end) -- TODO

	describe("VimedUnmarkFiles", function() end) -- TODO

	describe("VimedUpcase", function() end) -- TODO

	describe("VimedYank", function() end) -- TODO
end)
