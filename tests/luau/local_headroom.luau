-- How many more top-level locals a Luau file can take before the compiler runs out of registers
-- (Luau allows 200 live locals). `lune run tests/luau/local_headroom -- <file> <min>` fails when the
-- room left is under <min> (code review N9: RaceController keeps room for Phase 4).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local args = {}
for _, a in process.args do
	if a ~= "--" then table.insert(args, a) end
end
local src = fs.readFile(args[1])
local need = tonumber(args[2]) or 0
local lo, hi = 0, 250
while lo < hi do
	local mid = (lo + hi + 1) // 2
	local extra = {}
	for k = 1, mid do table.insert(extra, "local _pad" .. k .. " = os.clock()") end -- (not constants: those take no register)
	if pcall(luau.compile, src .. "\n" .. table.concat(extra, "\n") .. "\nprint(_pad1)") then lo = mid else hi = mid - 1 end
end
print(`{args[1]}: room for {lo} more top-level locals (need {need})`)
if lo < need then process.exit(1) end
