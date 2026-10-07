--!strict
-- Stage 3 of docs/plans/horse-life-and-retention.md (D-064): the copy test. Reads every toast in
-- the game's source (Ui.toast, Profiles.notify, IntegrityNote and the (ok, message) returns the
-- services pass on to toasts) and checks each is at most ui.toastMaxWords words with no banned
-- word (hard rule 1, D-058). Literals joined with `..` read as one message, with one word for
-- each name or number spliced in; a format's %s or %d is one word too.
local fs = require("@lune/fs")
local Words = require("../../game/src/shared/Words")
local GameConfig = require("../../game/src/shared/GameConfig")

local ROOT = "game/src"

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			luauFiles(path, out)
		elseif string.sub(name, -5) == ".luau" then
			table.insert(out, path)
		end
	end
	return out
end

-- The string literals in `code` with their spans: { text, from, to }.
local function literals(code: string): { { any } }
	local out = {}
	local i = 1
	while i <= #code do
		local c = string.sub(code, i, i)
		if c == "-" and string.sub(code, i, i + 1) == "--" then
			break -- a comment to the end of the line (the call text never has `--` inside a string here)
		elseif c == '"' or c == "'" then
			local j = i + 1
			local buf = {}
			while j <= #code do
				local d = string.sub(code, j, j)
				if d == "\\" then
					table.insert(buf, string.sub(code, j + 1, j + 1))
					j += 2
				elseif d == c then
					break
				else
					table.insert(buf, d)
					j += 1
				end
			end
			table.insert(out, { table.concat(buf), i, j })
			i = j + 1
		else
			i += 1
		end
	end
	return out
end

-- Messages: literals joined by `..` (with "X" for each spliced value) are one message.
local function messages(code: string): { string }
	local lits = literals(code)
	local out = {}
	local cur: string? = nil
	local lastTo = 0
	for _, lit in lits do
		local text, from, to = lit[1], lit[2], lit[3]
		local gap = string.sub(code, lastTo + 1, from - 1)
		local joined = cur ~= nil and string.match(gap, "^%s*%.%.") ~= nil
		local before = string.sub(code, 1, from - 1)
		if joined then
			-- `"a" .. x .. "b"`: the spliced value's word was added after "a" (below)
			cur = (cur :: string) .. text
		else
			if cur then table.insert(out, cur) end
			cur = text
			-- `x .. "b"`: a value spliced in front
			if string.match(before, "%.%.%s*$") then cur = "X " .. text end
		end
		lastTo = to
		local after = string.sub(code, to + 1)
		if string.match(after, "^%s*%.%.%s*[%w_%(]") and not string.match(after, "^%s*%.%.%s*[\"']") then
			cur = (cur :: string) .. " X"
		end
	end
	if cur then table.insert(out, cur) end
	return out
end

-- An icon name, a reason code or an emoji alone is not a message.
local function isMessage(text: string): boolean
	if string.match(text, "^[%l%d_]*$") then return false end
	return Words.count(text) > 0
end

local TRIGGERS = { "Ui%.toast%(", "Profiles%.notify%(", "IntegrityNote:FireClient%(", "^%s*return [%w_]+, ", "^%s*return [%w_]+, string%.format" }

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	local max = GameConfig.ui.toastMaxWords
	check(max ~= nil and max <= 10, "ui.toastMaxWords is at most 10")
	local limit = max or 10
	-- Words itself
	check(Words.count("Comet loved your treat! +1 ❤️") == 5, "Words.count skips emoji")
	check(Words.banned("Place your bet") == "bet", "Words.banned finds a wagering word")
	check(Words.banned("Comet is sore") == "sore", "Words.banned finds a hurt word")
	check(Words.banned("Better luck, Stakeholder") == nil, "Words.banned matches whole words")
	check(not Words.toastOk("one two three four five six seven eight nine ten eleven"), "11 words is too long")

	local seen, checked = {}, 0
	for _, path in luauFiles(ROOT, {}) do
		local isShared = string.find(path, "/shared/") ~= nil
		local isServer = string.find(path, "/server/") ~= nil
		local lines = string.split(fs.readFile(path), "\n")
		local k = 1
		while k <= #lines do
			local line = lines[k]
			local hit = false
			for t, pat in TRIGGERS do
				if string.find(line, pat) then
					-- returns only count in shared and server modules, where they become toasts
					if t >= 4 and not (isShared or isServer) then continue end
					hit = true
				end
			end
			if hit then
				-- a call that continues on the next lines
				local code = line
				local depth = select(2, string.gsub(code, "%(", "")) - select(2, string.gsub(code, "%)", ""))
				local j = k
				while (depth > 0 or string.match(code, "%.%.%s*$")) and j < #lines and j < k + 4 do
					j += 1
					code ..= " " .. lines[j]
					depth = select(2, string.gsub(code, "%(", "")) - select(2, string.gsub(code, "%)", ""))
				end
				for _, msg in messages(code) do
					if isMessage(msg) and not seen[msg] then
						seen[msg] = true
						checked += 1
						local ok, why = Words.toastOk(msg, limit)
						check(ok, `{path}:{k}: "{msg}" {why or ""}`)
					end
				end
			end
			k += 1
		end
	end
	check(checked >= 100, `the copy test read {checked} messages (expected at least 100)`)
end
