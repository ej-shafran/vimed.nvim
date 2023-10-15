local a = require("plenary.async")
local tests = a.tests
local describe = tests.describe
local it = tests.it

describe("Initial test", function()
	it("can be required", function()
		require("vimed")
	end)
end)
