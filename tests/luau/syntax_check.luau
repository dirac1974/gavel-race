-- Compiles every Luau file passed as an argument; fails on any syntax error.
-- lune run tests/luau/syntax_check -- $(git ls-files "*.luau")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local bad = 0
for _, path in process.args do
	if path == "--" then continue end
	local ok, err = pcall(luau.compile, fs.readFile(path))
	print((ok and "OK   " or "FAIL ") .. path .. (ok and "" or ("\n  " .. tostring(err))))
	if not ok then bad += 1 end
end
if bad > 0 then process.exit(1) end
