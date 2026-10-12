--!strict
-- Stage 3 of docs/plans/horse-life-and-retention.md (D-064): the clarity pass. One symbol per
-- meaning, one results row, one-line race cards, the Next-thing pill (and Pip's hint), and big
-- panels that never render text under 14 px or buttons under 56 px on a 375 px-high phone.
local fs = require("@lune/fs")
local Advice = require("../../game/src/shared/Advice")
local PanelFit = require("../../game/src/shared/PanelFit")
local PickerText = require("../../game/src/shared/PickerText")
local Market = require("../../game/src/shared/Market")
local Words = require("../../game/src/shared/Words")
local GameConfig = require("../../game/src/shared/GameConfig")

local UI = GameConfig.ui
local T0 = 1_800_000_000

local function luauFiles(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then luauFiles(path, out) elseif string.sub(name, -5) == ".luau" then table.insert(out, path) end
	end
	return out
end

-- Code without its comments (a `--` outside a string starts one).
local function code(src: string): string
	local out = {}
	for _, line in string.split(src, "\n") do
		local inStr: string? = nil
		local cut = #line
		local i = 1
		while i <= #line do
			local c = string.sub(line, i, i)
			if inStr then
				if c == "\\" then i += 1 elseif c == inStr then inStr = nil end
			elseif c == '"' or c == "'" or c == "`" then
				inStr = c
			elseif c == "-" and string.sub(line, i + 1, i + 1) == "-" then
				cut = i - 1
				break
			end
			i += 1
		end
		table.insert(out, string.sub(line, 1, cut))
	end
	return table.concat(out, "\n")
end

local function horse(over: { [string]: any }): any
	local h = { id = "h1", name = "Comet", fed = true, groomed = true, resting = false, stalled = true, stats = {} }
	for k, v in over do h[k] = v end
	return h
end

local function profile(h: any, jobs: any?): any
	return { activeHorse = h.id, horses = { h }, garden = {}, jobs = jobs or { daily = {}, weekly = {}, monthly = {} },
		totals = { races = 10 } }
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- Config ---------------------------------------------------------------------------------------
	check(UI.panelMinText >= 16 and UI.panelButtonPx >= 64 and UI.pickerLineWords <= 5 and UI.toastMaxWords <= 10,
		"ui: panel text 16, panel buttons 64, card lines 5 words, toasts 10 words")
	local NT = GameConfig.nextThing
	check(NT ~= nil and NT.enabled == true and NT.pipHintSeconds == 20 and NT.stillStuds > 0, "nextThing: on, Pip after 20 s")

	-- The Next-thing pill ---------------------------------------------------------------------------
	local GOES = { stable = true, race = true, board = true, starter = true, paddock = true, trailGate = true, vet = true, track = true }
	local function ok(n: any, key: string, go: string?, what: string)
		check(n.key == key and n.go == go, `{what}: {n.key} / {tostring(n.go)}`)
		check(Words.count(n.text) <= 7 and Words.banned(n.text) == nil, `{what}: a few plain words ("{n.text}")`)
		check(n.go == nil or GOES[n.go] == true, `{what}: GO goes somewhere known`)
		check(type(n.icon) == "string" and n.icon ~= "" and type(n.emoji) == "string", `{what}: an icon`)
	end
	ok(Advice.nextThing({ horses = {}, garden = {} }, T0), "starter", "starter", "no horse yet")
	ok(Advice.nextThing(profile(horse({ fed = false, groomed = false })), T0), "feed:h1", "stable", "unfed")
	ok(Advice.nextThing(profile(horse({ groomed = false })), T0), "groom:h1", "stable", "not brushed")
	ok(Advice.nextThing(profile(horse({ cupOpen = true })), T0), "cup:h1", "race", "Cup open")
	local job = { id = "d_race1", text = "Ride in a race", icon = "flag_ready", go = "raceBoard", progress = 0, target = 1, claimed = false }
	ok(Advice.nextThing(profile(horse({}), { daily = { job }, weekly = {}, monthly = {} }), T0), "job:d_race1", "race", "a job (race jobs press RACE!)")
	local done = { id = "d_feed", text = "Feed a horse", icon = "hay", go = "stable", progress = 1, target = 1, claimed = false }
	ok(Advice.nextThing(profile(horse({ fed = false }), { daily = { job }, weekly = { done }, monthly = {} }), T0), "claim", "board", "a prize to claim comes first")
	ok(Advice.nextThing(profile(horse({ trainingReady = true, stats = { speed = 40, accel = 50, stamina = 50, grit = 50 },
		potential = { speed = 80, accel = 60, stamina = 60, grit = 60 } })), T0), "train:h1", "paddock", "training ready")
	ok(Advice.nextThing(profile(horse({})), T0), "race:h1", "race", "ready to race")
	ok(Advice.nextThing(profile(horse({ resting = true })), T0), "spa:h1", "vet", "napping with the Spa open (D-058)")
	local nap = Advice.nextThing(profile(horse({ resting = true, spaToday = 1 })), T0)
	ok(nap, "nap", nil, "napping")
	check(string.find(nap.text, "dreaming of tomorrow", 1, true) ~= nil, "napping: D-058's words, no GO")
	local garden = profile(horse({ resting = true, spaToday = 1 }))
	garden.garden = { { seed = "carrot", ready = true } }
	ok(Advice.nextThing(garden, T0), "crops", "stable", "crops ready")
	-- the active horse, not the first one
	local two = profile(horse({ fed = false }))
	table.insert(two.horses, horse({ id = "h2", name = "Pip Two", fed = true }))
	two.activeHorse = "h2"
	check(Advice.nextThing(two, T0).key == "race:h2", "the pill follows the horse you ride")

	-- A new player races first (AAA Phase 2, D-067): before chores and jobs, for the first races.
	local N = NT.raceFirstUntilRaces
	check(N == 3, "nextThing.raceFirstUntilRaces = 3")
	local fresh = profile(horse({ fed = false, groomed = false }), { daily = { job }, weekly = { done }, monthly = {} })
	fresh.totals.races = 0
	ok(Advice.nextThing(fresh, T0), "race:h1", "race", "a brand-new player: race before feeding, brushing or a prize")
	fresh.totals.races = N - 1
	ok(Advice.nextThing(fresh, T0), "race:h1", "race", "still new")
	fresh.totals.races = N
	ok(Advice.nextThing(fresh, T0), "claim", "board", "after the first races, the usual order")
	local napNew = profile(horse({ resting = true, spaToday = 1 }))
	napNew.totals.races = 0
	ok(Advice.nextThing(napNew, T0), "nap", nil, "a napping horse is never sent to race")

	-- Text colours (D-067): textGood and textWarn pass 4.5:1 on every light card; the bright fills don't.
	local function lum(hex: string): number
		local function ch(i: number): number
			local c = tonumber(string.sub(hex, i, i + 1), 16) / 255
			return if c <= 0.03928 then c / 12.92 else ((c + 0.055) / 1.055) ^ 2.4
		end
		return 0.2126 * ch(1) + 0.7152 * ch(3) + 0.0722 * ch(5)
	end
	local function contrast(a: string, b: string): number
		local la, lb = lum(a), lum(b)
		return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05)
	end
	local uiText = fs.readFile("game/src/client/Ui.luau")
	local function hexOf(name: string): string
		if name == "white" then return "FFFFFF" end -- (Color3.new(1, 1, 1))
		return string.match(uiText, "	" .. name .. " = Color3%.fromHex%(\"(%x+)\"%)") or "000000"
	end
	for _, fg in { "textGood", "textWarn", "ink" } do
		for _, bg in { "paper", "cream", "white", "gold", "sky" } do
			local r = contrast(hexOf(fg), hexOf(bg))
			check(r >= 4.5, `{fg} on {bg}: {math.floor(r * 10) / 10}:1 >= 4.5`)
		end
	end
	for _, bg in { "paper", "cream", "white" } do
		check(contrast(hexOf("plum"), hexOf(bg)) >= 4.5, `plum sublines on {bg} pass 4.5:1`)
	end
	check(contrast(hexOf("green"), hexOf("white")) < 4.5, "bright green is a fill colour, not text")

	-- The phone queue card (D-067): one line, and kind words for the practice slider.
	local QueueView = require("../../game/src/shared/QueueView")
	local qs = QueueView.new(8, 15)
	QueueView.status(qs, true, 3, 12, "dirt", 0)
	QueueView.gate(qs, "dirt", { { name = "Comet", user = 1 }, { name = "Pip" }, { name = "Star" } }, 8, 12, false, 0)
	local qv = QueueView.view(qs, 1, 0)
	check(QueueView.compactLine(qv) == "Race in 12 · 3 riders", `compact line: "{QueueView.compactLine(qv)}"`)
	QueueView.raceTime(qs, "dirt", 3, 1)
	check(QueueView.compactLine(QueueView.view(qs, 1, 1)) == "Race time! GO!", "compact line at race time")
	check(QueueView.warmWord(97, true) == "Perfect!" and QueueView.warmWord(85, false) == "Great!"
		and QueueView.warmWord(10, true) == "Early" and QueueView.warmWord(10, false) == "Late", "warm-up words: never a miss")
	for _, w in { QueueView.warmWord(0, true), QueueView.warmWord(0, false), QueueView.compactLine(qv) } do
		check(Words.banned(w) == nil, `no banned word in "{w}"`)
	end
	-- The tour's race step points at the real RACE! button when it has no GO of its own.
	local Tour = require("../../game/src/shared/Tour")
	check(GameConfig.firstMinute.tourGoOnRace == false and string.find(Tour.text(Tour.STEPS[1], "Comet", true), "RACE!", 1, true) ~= nil
		and Tour.stepId({}) == "race", "the first tour step points at RACE!")
	-- (the race screen is being rebuilt: RaceController, RaceView and Replay join this scan after it)
	local RACE_SCREEN = { ["RaceController.client.luau"] = true, ["RaceView.client.luau"] = true, ["Replay.client.luau"] = true }
	for _, path in luauFiles("game/src/client", {}) do
		local file = string.match(path, "[^/]+$") :: string
		if RACE_SCREEN[file] then continue end
		for n, ln in string.split(code(fs.readFile(path)), string.char(10)) do
			if string.find(ln, "TextColor3", 1, true) then
				for _, pat in { "C%.green[^%w]", "C%.cash[^%w]", "C%.orange[^%w]", "C%.orangeDark[^%w]" } do
					if string.find(ln .. " ", pat) then
						check(false, `{file}:{n}: bright {pat} as text fails contrast (use textGood / textWarn)`)
					end
				end
			end
		end
	end

	-- Pip's hint
	local cfg = { pipHintSeconds = 20 }
	check(not Advice.pipHintDue(100, 100, false, 119, cfg) and Advice.pipHintDue(100, 100, false, 120, cfg), "Pip after 20 s")
	check(not Advice.pipHintDue(100, 110, false, 125, cfg) and Advice.pipHintDue(100, 110, false, 130, cfg), "moving resets Pip's wait")
	check(not Advice.pipHintDue(100, 100, true, 500, cfg), "Pip hints once per suggestion")
	check(Words.toastOk(Advice.PIP_HINT), "Pip's hint is short")

	-- Race cards: one line, at most five words; status and suits in a few words, no numbers -----------
	local longest = 0
	for _, league in { "Rookie", "Bronze", "Silver", "Gold", "Champion" } do
		for _, dist in { "Sprint", "Mile", "Classic", "Marathon" } do
			for _, w in { "Sunny", "Rain", "Wind" } do
				for _, kind in { "race", "cup", "practice", "open" } do
					local c = { league = league, distance = dist, weather = w, course = if dist == "Mile" then "turf" else "dirt",
						cup = kind == "cup", practice = kind == "practice", open = kind == "open" }
					local line = PickerText.cardLine(c)
					longest = math.max(longest, Words.count(line))
					if string.find(line, "\n") or Words.count(line) > UI.pickerLineWords then
						check(false, `card line too long: "{line}"`)
					end
				end
			end
		end
	end
	check(longest >= 3 and longest <= UI.pickerLineWords, `card lines are 3 to {UI.pickerLineWords} words (longest {longest})`)
	for _, c in { { racing = true }, { seconds = 12 }, { riders = 3 }, { riders = 0 } } do
		check(Words.count(PickerText.status(c, false)) <= 2, "status chip: two words at most")
	end
	check(PickerText.status({ seconds = 3 }, true) == "👀 Watch", "another league's card says Watch")
	for _, d in { 5, 0.2, -4, 0 } do
		local s = PickerText.suits(d, false)
		check(Words.count(s) <= 3 and string.find(s, "%d") == nil, `suits: words, no number ("{s}")`)
	end
	check(PickerText.suits(3, true) == "😴 Napping", "a napping horse says Napping")
	for _, src in { fs.readFile("game/src/client/RacePicker.client.luau") } do
		local c = code(src)
		check(string.find(c, "pts", 1, true) == nil and string.find(c, "Loves today's race (+", 1, true) == nil
			and string.find(c, "Ribbons and Green Cash", 1, true) == nil, "no Cup points, rating numbers or ribbon line on the picker")
		check(string.find(c, "PickerText.cardLine(c)", 1, true) ~= nil and string.find(c, "Ui.leagueColors[league]", 1, true) ~= nil,
			"race cards: PickerText's line on the league's colour")
	end

	-- Market: 🌱 family line ---------------------------------------------------------------------------
	check(Market.familyLine(1) == "Family 🌱" and Market.familyLine(3) == "Family 🌱🌱🌱" and Market.familyLine(9) == "Family 🌱🌱🌱",
		"family line in sprouts")

	-- One symbol per meaning ---------------------------------------------------------------------------
	-- ★ only for how you rode (results, replay checkpoints, training rides); ⭐ and ⚡ only as
	-- cosmetic patterns (Tack & Paint).
	local STAR_OK = { ["ResultsText.luau"] = true, ["Replay.client.luau"] = true, ["TrainingRideClient.client.luau"] = true }
	local COSMETIC_OK = { ["Style.luau"] = true, ["Rides.luau"] = true }
	for _, path in luauFiles("game/src", {}) do
		local name = string.match(path, "[^/]+$") :: string
		local c = code(fs.readFile(path))
		if string.find(c, "★", 1, true) and not STAR_OK[name] then check(false, `★ outside riding in {path}`) end
		if (string.find(c, "⭐", 1, true) or string.find(c, "⚡", 1, true)) and not COSMETIC_OK[name] then check(false, `⭐ or ⚡ in {path}`) end
		if string.find(c, "care_star", 1, true) and name ~= "UiAtlas.luau" then check(false, `care_star icon in {path} (❤️ is care)`) end
		if string.find(c, "energy_hoof", 1, true) and name ~= "UiAtlas.luau" then check(false, `old Energy icon in {path} (the horseshoe is energy_shoe)`) end
		if string.find(c, "\"league_\"", 1, true) and name ~= "UiAtlas.luau" then check(false, `starred league badge in {path} (Ui.badge)`) end
	end
	local uiSrc = code(fs.readFile("game/src/client/Ui.luau"))
	check(string.find(uiSrc, "Ui.ENERGY_ICON, Ui.ENERGY_EMOJI = \"energy_shoe\"", 1, true) ~= nil, "Energy is the horseshoe icon")
	local atlas = fs.readFile("game/src/shared/UiAtlas.luau")
	for _, icon in { "energy_shoe", "energy_shoe_empty", "rosette", "sprout", "badge_rookie", "badge_bronze", "badge_silver", "badge_gold", "badge_champion" } do
		check(string.find(atlas, "\t" .. icon .. " = ", 1, true) ~= nil, `atlas has {icon}`)
	end

	-- One results row -----------------------------------------------------------------------------------
	local rc = code(fs.readFile("game/src/client/RaceController.client.luau"))
	check(string.find(rc, "Card.setRide(ResultsText.rowStars(rideReport.stars, rideReport.tripStars, STEER.scale, TRIP_ROW))", 1, true) ~= nil
		and string.find(rc, "ResultsText.gainedLine(horse, rideReport.gain, rideReport.tripGain, STEER.scale)", 1, true) ~= nil
		and string.find(rc, "Good trip", 1, true) == nil and string.find(rc, "if TRIP_ROW then ResultsText.tripLine(", 1, true) ~= nil,
		"the results card has one star row and the taps line (the trip row only with the switch-back)")
	check(GameConfig.results ~= nil and GameConfig.results.tripRow == false, "results.tripRow is off: one row")
	local ResultsText = require("../../game/src/shared/ResultsText")
	check(ResultsText.oneRow(1, 3, 1, true) == "You rode ★☆☆" and ResultsText.tripLine(3, 1) == "Good trip ★★★"
		and ResultsText.tripLine(3, 0) == nil and ResultsText.tripLine(nil, 1) == nil, "the switch-back: the ride row alone plus Good trip")

	-- Stable Board: jobs inline, the pill ---------------------------------------------------------------
	local sb = code(fs.readFile("game/src/client/StableBoard.client.luau"))
	local _, toasts = string.gsub(sb, "Ui%.toast%(", "")
	check(toasts == 1, "the Stable Board toasts only \"Follow the golden hoofprints!\" (week and month jobs are inline)")
	check(string.find(sb, "Advice.nextThing(d,", 1, true) ~= nil and string.find(sb, "Advice.pipHintDue(", 1, true) ~= nil
		and string.find(sb, "localEvent(\"PressRace\"):Fire()", 1, true) ~= nil, "the pill: Advice's one thing, Pip's hint, GO presses RACE!")
	local hud = code(fs.readFile("game/src/client/Hud.client.luau"))
	check(string.find(hud, "localEvent(\"PressRace\").Event:Connect(pressRace)", 1, true) ~= nil, "the Hud presses RACE! for the pill")
	local _, wordButtons = string.gsub(hud, "Ui%.iconButton%(", "")
	check(wordButtons >= 4, "dock buttons are icon + word (Horses, Map, Jobs, More)")

	-- Panels on a 375 px-high phone: text ≥ 14, buttons ≥ 56 ------------------------------------------
	local PANELS = {
		{ "RacePicker", 720, 470, nil }, { "StableBoard", 780, 520, nil }, { "MyHorses", 760, 500, 300 }, { "MarketCard", 420, 350, nil },
	}
	for _, view in { { 667, 375 }, { 812, 375 }, { 568, 320 }, { 1280, 720 }, { 1920, 1080 } } do
		for _, p in PANELS do
			local f = PanelFit.layout(view[1], view[2], p[2], p[3], UI.panelMinText, UI.panelButtonPx, UI, p[4])
			check(f.scale <= 1 and f.scale * UI.panelMinText >= UI.minTextPx - 1e-9 and f.scale * UI.panelButtonPx >= UI.minTouchPx - 1e-9,
				`{p[1]} at {view[1]}x{view[2]}: scale {f.scale} keeps 14 px text and 56 px buttons`)
			check(f.scroll == (f.height * f.scale > view[2] - PanelFit.MARGIN) and f.canvas >= f.height * f.scale,
				`{p[1]} at {view[1]}x{view[2]}: what doesn't fit scrolls`)
			check(f.scrollX == (p[2] * f.scale > view[1] - PanelFit.MARGIN) and f.canvasX >= p[2] * f.scale + PanelFit.MARGIN - 1e-9,
				`{p[1]} at {view[1]}x{view[2]}: too wide scrolls sideways, never cut off`)
			if p[4] then
				check(f.height >= p[4] and (f.height == p[3] or not f.scroll or f.height == p[4]), `{p[1]} at {view[1]}x{view[2]}: gets shorter instead`)
			end
		end
	end
	local big = PanelFit.layout(1920, 1080, 720, 470, UI.panelMinText, UI.panelButtonPx, UI)
	check(big.scale == 1 and not big.scroll, "a big screen shows the panel at full size")
	for _, file in { "RacePicker.client.luau", "StableBoard.client.luau", "HorsesClient.client.luau" } do
		local src = code(fs.readFile("game/src/client/" .. file))
		check(string.find(src, "Ui.fitPanel(", 1, true) ~= nil and string.find(src, "scale.Scale = math.min(1,", 1, true) == nil,
			`{file} fits through Ui.fitPanel (no shrinking under the floor)`)
	end
end
