local a = require("plenary.async")
local tests = a.tests
local describe = tests.describe
local it = tests.it

---Fix type issue
---@type any
local assert = assert

assert:register("assertion", "contains", function(_, arguments)
	local container = arguments[1]
	local containee = arguments[2]
	return string.find(container, containee) ~= nil
end)

describe("Vimed Command", function()
	local vimed = require("vimed")

	tests.before_each(function()
		if vim.fn.isdirectory("workdir") == 0 then
			vim.fn.mkdir("workdir")
		end
		print(vim.inspect(vim.fn.readdir("workdir")))
		vim.cmd.cd("workdir")
		vim.cmd("%bd")
	end)

	tests.after_each(function()
		vim.cmd.cd("..")
		vim.fn.delete("workdir", "rf")
	end)

	-- cmd("DiredToVimed", commands.from_dired)

	describe("VimedAsyncShellCommand", function() end) -- TODO

	describe("VimedBack", function()
		it("should change the cwd", function()
			vimed.setup()
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

	describe("VimedGotoFile", function()
		it("should go to a file", function()
			vimed.setup()
			vim.cmd.e("temp")
			vim.cmd.w()
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")

			assert.contains(vim.api.nvim_get_current_line(), "temp")
		end)

		it("should stay in place if file does not exist", function()
			vimed.setup()
			vimed.open_vimed()

			local expected = vim.api.nvim_get_current_line()
			vim.cmd.VimedGotoFile("noexist")

			assert.are.same(expected, vim.api.nvim_get_current_line())
		end)
	end)

	describe("VimedHardlink", function() end) -- TODO

	describe("VimedHardlinkRegexp", function() end) -- TODO

	describe("VimedLoad", function() end) -- TODO

	describe("VimedMark", function()
		it("should change the current line", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()
			vim.cmd.VimedGotoFile("temp")

			local expected = vim.api.nvim_get_current_line():gsub("^ ", "*")
			vim.cmd.VimedMark()
			-- move one line up - mark moves us down
			vim.cmd.normal("k")

			assert.are.same(expected, vim.api.nvim_get_current_line())
		end)

		it("should leave a marked file unchanged", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()
			vim.cmd.VimedGotoFile("temp")

			vim.cmd.VimedMark()
			vim.cmd.normal("k")

			local expected = vim.api.nvim_get_current_line()
			vim.cmd.VimedMark()
			vim.cmd.normal("k")

			assert.are.same(expected, vim.api.nvim_get_current_line())
		end)
	end)

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

	describe("VimedRedisplay", function()
		it("should render any missing changes", function()
			vimed.setup()
			vimed.open_vimed()
			os.execute("touch temp")

			vim.cmd.normal("G")
			assert.are.same(vim.api.nvim_get_current_line(), "")
			vim.cmd.VimedRedisplay()
			assert.contains(vim.api.nvim_get_current_line(), "temp")
		end)
	end)

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
