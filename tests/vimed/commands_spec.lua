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

---@param path string
---@return boolean islink whether the file at `path` is a symbolic link
local function is_symlink(path)
	local stat = assert(vim.loop.fs_stat(path))
	local S_IFLNK = 40960 -- octal 0120000
	return vim.fn["and"](stat.mode, S_IFLNK) ~= 0
end

describe("Vimed Command", function()
	local vimed = require("vimed")

	tests.before_each(function()
		if vim.fn.isdirectory("workdir") == 0 then
			vim.fn.mkdir("workdir")
		end
		print(vim.inspect(vim.fn.readdir("workdir")))
		vim.cmd.cd("workdir")
	end)

	tests.after_each(function()
		vim.cmd.cd("..")
		vim.fn.delete("workdir", "rf")
		vim.cmd("%bd")

		--TODO: maybe find some other way to do this?
		require("vimed._state").flags = {}
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
		it("should mark the current line", function()
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

		it("should mark a visual selection", function()
			vimed.setup()
			os.execute("touch temp1 temp2")
			vimed.open_vimed()
			local expected = vim.api.nvim_buf_get_lines(0, 2, -2, false)
			for i = 1, #expected do
				expected[i] = expected[i]:gsub("^ ", "*")
			end

			vim.cmd.normal("GkVk")
			vim.cmd.VimedMark()
			local recieved = vim.api.nvim_buf_get_lines(0, 2, -2, false)
			for i = 1, #recieved do
				assert.are.same(recieved[i], expected[i])
			end
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

	describe("VimedMarkDirectories", function()
		it("should mark directories, and only directories", function()
			vimed.setup()
			os.execute("mkdir dir1 dir2")
			os.execute("touch file1 file2")
			vimed.open_vimed()

			local expected = vim.api.nvim_buf_get_lines(0, 2, 3, false)
			for i = 1, #expected do
				expected[i] = expected[i]:gsub("^ ", "*")
			end

			vim.cmd.VimedMarkDirectories()
			local recieved = vim.api.nvim_buf_get_lines(0, 2, 3, false)
			for i = 1, #recieved do
				assert.are.same(recieved[i], expected[i])
			end
		end)
	end)

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

	describe("VimedSymlink", function()
		it("should create a symbolic link", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			vim.cmd.VimedSymlink("link")
			vim.cmd.VimedGotoFile("link")

			local line = vim.api.nvim_get_current_line()
			assert.contains(line, "link")
			assert.contains(line, " -> ")
			assert.contains(line, "temp")

			-- check that file is symbolic link
			assert(is_symlink("link"))
		end)

		it("should place symlinks in directory for multiple files", function()
			vimed.setup()
			os.execute("touch temp1 temp2")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp1")
			vim.cmd.normal("Vj")
			vim.cmd.VimedMark()
			vim.cmd("VimedSymlink! dir")
			assert(vim.fn.isdirectory("dir"))

			local files = {}
			for name in vim.fs.dir("dir") do
				assert(is_symlink(name))

				table.insert(files, name)
			end

			assert(vim.list_contains(files, "temp1"))
			assert(vim.list_contains(files, "temp2"))
		end)
	end)

	describe("VimedSymlinkRegexp", function() end) -- TODO

	describe("VimedToggleHidden", function() end) -- TODO

	describe("VimedToggleHideDetails", function()
		it("should show just the necessary details", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedToggleHideDetails()
			vim.cmd.VimedGotoFile("temp")
			assert.are.same(vim.api.nvim_get_current_line(), "  temp")
		end)
	end)

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
