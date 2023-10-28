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
	local S_IFMT = 61440 -- octal 00170000
	local S_IFLNK = 40960 -- octal 0120000
	local stat = assert(vim.loop.fs_lstat(path))
	return vim.fn["and"](stat.mode, S_IFMT) == S_IFLNK
end

local function is_gzip(path)
	vim.fn.system("gzip -t " .. path)
	return vim.api.nvim_get_vvar("shell_error") == 0
end

describe("Vimed Command", function()
	local vimed = require("vimed")

	local function place_in_dir(command, additional)
		return function()
			vimed.setup()
			os.execute("touch temp1 temp2")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp1")
			vim.cmd.normal("Vj")
			vim.cmd.VimedMark()
			vim.cmd(command .. "! dir")
			assert(vim.fn.isdirectory("dir") ~= 0)

			local files = {}
			for name in vim.fs.dir("dir") do
				if additional ~= nil then
					assert(additional("dir/" .. name))
				end

				table.insert(files, name)
			end

			assert(vim.list_contains(files, "temp1"))
			assert(vim.list_contains(files, "temp2"))
		end
	end

	tests.before_each(function()
		if vim.fn.isdirectory("workdir") == 0 then
			vim.fn.mkdir("workdir")
		end
		vim.cmd.cd("workdir")
	end)

	tests.after_each(function()
		vim.cmd.cd("..")
		vim.fn.delete("workdir", "rf")
		vim.cmd("%bd")

		--TODO: maybe find some other way to do this?
		require("vimed._state").flags = {}
		require("vimed._state").hide_details = false
	end)

	-- cmd("DiredToVimed", commands.from_dired)

	describe("VimedAsyncShellCommand", function()
		it("should run a command and place it in a buffer", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")

			vim.cmd.VimedAsyncShellCommand("echo hi, ?")
			assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "hi, temp" })
			vim.cmd("bd!") -- close the result buffer
		end)

		it("should work with special * syntax", function()
			vimed.setup()
			os.execute("touch file1 file2")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("file1")
			vim.cmd.normal("Vj")
			vim.cmd.VimedMark()

			vim.cmd.VimedAsyncShellCommand("echo files: *")
			assert.are.same(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "files: file2 file1" })
			vim.cmd("bd!") -- close the result buffer
		end)
	end)

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

	describe("VimedChangeMarks", function()
		it("should change one mark into another", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			vim.cmd.VimedMark()
			vim.cmd.normal("k")
			local expected = vim.api.nvim_get_current_line():gsub("^.", "D")

			vim.cmd.VimedChangeMarks("*", "D")
			assert.are.same(vim.api.nvim_get_current_line(), expected)
		end)
	end)

	describe("VimedChmod", function()
		it("should change the permissions of a file using chmod syntax", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			vim.cmd.VimedChmod("+x")
			assert.are.same(vim.fn.executable(vim.fn.getcwd() .. "/temp"), 1)
			vim.cmd.VimedChmod("-x")
			assert.are.same(vim.fn.executable(vim.fn.getcwd() .. "/temp"), 0)
		end)
	end)

	describe("VimedChown", function() end) -- TODO

	describe("VimedCompress", function()
		it("should compress and uncompress files", function()
			vimed.setup()
			os.execute("touch temp")

			vimed.open_vimed()
			vim.cmd.VimedGotoFile("temp")

			vim.cmd("VimedCompress!")
			assert.contains(vim.api.nvim_get_current_line(), "temp.gz$")
			assert(is_gzip("temp.gz"))

			vim.cmd("VimedCompress!")
			assert.contains(vim.api.nvim_get_current_line(), "temp$")
			assert(not is_gzip("temp"))
		end)
	end)

	describe("VimedCompressTo", function() end) -- TODO

	describe("VimedCopy", function()
		it("should copy the file under the cursor", function()
			vimed.setup()
			os.execute("echo 'Hello world!' > temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			vim.cmd.VimedCopy("copy")
			local temp = assert(io.open("temp", "rb"))
			local copy = assert(io.open("copy", "rb"))
			local temp_content = temp:read("*a")
			local copy_content = copy:read("*a")
			temp:close()
			copy:close()

			assert.are.same(temp_content, copy_content)
		end)

		it("should place copies in a directory", place_in_dir("VimedCopy"))
	end)

	describe("VimedCopyRegexp", function() end) -- TODO

	describe("VimedCreateDir", function()
		it("should create a directory", function()
			vimed.setup()
			vimed.open_vimed()

			vim.cmd.VimedCreateDir("dir")
			vim.cmd.VimedGotoFile("dir")
			assert.contains(vim.api.nvim_get_current_line(), "dir")
			assert.are_not.same(vim.fn.isdirectory("dir"), 0)
		end)
	end)

	describe("VimedDelete", function()
		it("should delete the file under cursor", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			local expected_lines = #vim.api.nvim_buf_get_lines(0, 0, -1, false) - 1
			vim.cmd.VimedGotoFile("temp")
			vim.cmd("VimedDelete!")
			assert.does_not.contains(vim.api.nvim_get_current_line(), "temp")
			assert.are.same(#vim.api.nvim_buf_get_lines(0, 0, -1, false), expected_lines)
		end)

		it("should delete marked files", function()
			vimed.setup()
			os.execute("touch file1 file2")
			vimed.open_vimed()

			local expected_lines = #vim.api.nvim_buf_get_lines(0, 0, -1, false) - 2
			vim.cmd.VimedToggleMarks()
			vim.cmd("VimedDelete!")
			assert.are.same(#vim.api.nvim_buf_get_lines(0, 0, -1, false), expected_lines)
		end)
	end)

	describe("VimedDiff", function() end) -- TODO

	describe("VimedDowncase", function()
		it("should rename files to lowercase", function()
			vimed.setup()
			os.execute("touch TEMP")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("TEMP")
			vim.cmd("VimedDowncase!")
			assert.contains(vim.api.nvim_get_current_line(), "temp")
		end)
	end)

	describe("VimedEnter", function()
		it("should edit the file under the cursor", function()
			vimed.setup()
			local workdir = vim.fn.getcwd()
			os.execute("mkdir dir")
			os.execute("touch dir/file")

			vimed.open_vimed()
			vim.cmd.VimedGotoFile("dir")
			vim.cmd.VimedEnter()
			assert.are.same(vim.fn.expand("%"), workdir .. "/dir")

			vimed.open_vimed()
			vim.cmd.VimedGotoFile("file")
			vim.cmd.VimedEnter()
			assert.are.same(vim.fn.expand("%"), workdir .. "/dir/file")
		end)
	end)

	describe("VimedFlagBackupFiles", function() end) -- TODO

	-- TODO: add other marking tests, for test refactoring
	describe("VimedFlagFileDeletion", function()
		it("should mark a file with 'D'", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			local expected = vim.api.nvim_get_current_line():gsub("^ ", "D")
			vim.cmd.VimedFlagFileDeletion()
			vim.cmd.normal("k")
			assert.are.same(vim.api.nvim_get_current_line(), expected)
		end)
	end)

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

	describe("VimedHardlink", function()
		it("should create a hard link", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			local stat = assert(vim.loop.fs_lstat("temp"))
			assert(stat.nlink == 1)

			vim.cmd.VimedHardlink("link")
			stat = assert(vim.loop.fs_lstat("temp"))
			assert(stat.nlink > 1)
		end)

		it("should place hard links in a directory", place_in_dir("VimedHardlink"))
	end)

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

	describe("VimedMarkExtension", function()
		it("should mark only a specific extension", function()
			vimed.setup()
			os.execute("touch file1 file2.c file3.ts")
			vimed.open_vimed()

			local lines = vim.api.nvim_buf_get_lines(0, 2, -1, false)
			for i, line in ipairs(lines) do
				if string.find(line, "file3.ts") ~= nil then
					lines[i] = line:gsub("^ ", "*")
				end
			end

			vim.cmd.VimedMarkExtension("ts")
			assert.are.same(lines, vim.api.nvim_buf_get_lines(0, 2, -1, false))
		end)
	end)

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

	describe("VimedRename", function()
		it("should rename a file", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			vim.cmd.VimedRename("renamed")

			assert.are.same(vim.fn.filereadable("temp"), 0)
			assert.are_not.same(vim.fn.filereadable("renamed"), 0)
		end)

		it("should place files in a directory", place_in_dir("VimedRename"))
	end)

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

		it("should place symlinks in directory", place_in_dir("VimedSymlink", is_symlink))
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

	describe("VimedToggleMarks", function()
		it("should mark unmarked files and vice versa", function()
			vimed.setup()
			os.execute("touch file1 file2 file3")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("file1")
			vim.cmd.VimedMark()

			local expected = vim.tbl_map(function(line)
				if line:match("^%*") then
					return line:gsub("^%*", " ")
				else
					return line:gsub("^ ", "*")
				end
			end, vim.api.nvim_buf_get_lines(0, 2, -1, false))

			vim.cmd.VimedToggleMarks()
			for i, line in ipairs(vim.api.nvim_buf_get_lines(0, 2, -1, false)) do
				assert.are.same(expected[i], line)
			end
		end)
	end)

	describe("VimedToggleSort", function() end) -- TODO

	describe("VimedTouch", function()
		it("updates the last modified time of a file", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			local stat = vim.loop.fs_stat("temp")
			assert(stat, "temp exists")
			local original_time = stat.atime.nsec

			vim.cmd.VimedGotoFile("temp")
			vim.cmd.VimedTouch("now")
			stat = vim.loop.fs_stat("temp")
			assert(stat, "temp exists")
			assert(stat.atime.nsec > original_time, "time has increased")
		end)
	end)

	describe("VimedUnmark", function()
		it("should remove any marks from a file", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			local expected = vim.api.nvim_get_current_line()

			vim.cmd.VimedMark()
			vim.cmd.normal("k")
			assert.are_not.same(vim.api.nvim_get_current_line(), expected)

			vim.cmd.VimedUnmark()
			vim.cmd.normal("k")
			assert.are.same(vim.api.nvim_get_current_line(), expected)

			vim.cmd.VimedFlagFileDeletion()
			vim.cmd.normal("k")
			assert.are_not.same(vim.api.nvim_get_current_line(), expected)

			vim.cmd.VimedUnmark()
			vim.cmd.normal("k")
			assert.are.same(vim.api.nvim_get_current_line(), expected)
		end)
	end)

	describe("VimedUnmarkAll", function() end) -- TODO

	describe("VimedUnmarkBackward", function() end) -- TODO

	describe("VimedUnmarkFiles", function() end) -- TODO

	describe("VimedUpcase", function()
		it("should rename files to lowercase", function()
			vimed.setup()
			os.execute("touch temp")
			vimed.open_vimed()

			vim.cmd.VimedGotoFile("temp")
			vim.cmd("VimedUpcase!")
			assert.contains(vim.api.nvim_get_current_line(), "TEMP")
		end)
	end)

	describe("VimedYank", function() end) -- TODO
end)
