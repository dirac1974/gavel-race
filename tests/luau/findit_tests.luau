--!strict
-- Find it (fun-and-return phase 1, D-075): every place on the Map with a "what to do here" line,
-- GO (walk near, a trip far, never while in line or racing), "New!" pointer pacing, the queue card's
-- line names, the five-item phone dock and the wiring that ties them to the client.
local fs = require("@lune/fs")
local FindIt = require("../../game/src/shared/FindIt")
local WorldLayout = require("../../game/src/shared/WorldLayout")
local QueueView = require("../../game/src/shared/QueueView")
local DockLayout = require("../../game/src/shared/DockLayout")
local PanelFit = require("../../game/src/shared/PanelFit")
local Words = require("../../game/src/shared/Words")
local GameConfig = require("../../game/src/shared/GameConfig")

local CFG = GameConfig.findIt
local UI = GameConfig.ui

local function code(path: string): string
	local out = {}
	for _, line in string.split(fs.readFile(path), "\n") do
		local cut = string.find(line, "--", 1, true)
		table.insert(out, if cut then string.sub(line, 1, cut - 1) else line)
	end
	return table.concat(out, "\n")
end

local function has(src: string, s: string): boolean
	return string.find(src, s, 1, true) ~= nil
end

local function count(src: string, s: string): number
	local n, i = 0, 1
	while true do
		local a, b = string.find(src, s, i, true)
		if not a then return n end
		n += 1
		i = (b :: number) + 1
	end
end

-- Kid copy: at most `max` words, no wagering or hurt word.
local function copyOk(text: string, max: number): boolean
	return Words.count(text) <= max and Words.banned(text) == nil
end

local function profile(over: { [string]: any }?): any
	local p = {
		horses = { { id = "h1", name = "Comet", resting = false, spaToday = 0, trainingReady = false, stalled = true } },
		activeHorse = "h1", totals = { races = 0 }, flags = {}, style = { shelfSeen = "Rookie" }, bestLeague = "Rookie",
	}
	for k, v in over or {} do p[k] = v end
	return p
end

return function(check: (boolean, string) -> (), _close: (number, number, number) -> boolean)
	-- The Map: every place, a 5 × 3 grid, a short "what to do" line -------------------------------------
	do
		local tiles = FindIt.tiles()
		check(#tiles == 14 and #WorldLayout.MAP == 14, "14 places on the Map (the 💞 Foal Barn is 14th, D-080)")
		local ids, maxRow, ok = {}, 0, true
		for k, t in tiles do
			if ids[t.id] then ok = false end
			ids[t.id] = true
			maxRow = math.max(maxRow, t.row)
			if t.col < 1 or t.col > CFG.map.columns or t.label == nil or t.label == "" or t.emoji == nil or t.emoji == "" then ok = false end
			if (t.row - 1) * CFG.map.columns + t.col ~= k then ok = false end
			if not copyOk(t.label, 2) then ok = false end
		end
		check(ok and maxRow == 3 and CFG.map.columns == 5, "tiles in a 5 × 3 grid, one each, each with a word and an icon")
		-- Every place the inventory found missing is on it now.
		for _, id in { "paddock", "trainingGround", "market", "feedStore", "barnBuilder", "tackShop", "raceBoard", "visit", "stable", "track", "plaza", "vet", "trailGate" } do
			check(ids[id] == true, `the Map has {id}`)
		end
		check(WorldLayout.MAP_LABELS.paddock == "Training" and WorldLayout.MAP_LABELS.trainingGround == "Riding Ring"
			and WorldLayout.MAP_LABELS.vet == "Vet & Spa" and WorldLayout.MAP_LABELS.visit == "Visit barns", "the spec's tile names")
		-- What to do here: 2 words or fewer, facts only.
		local hintsOk = true
		for _, t in tiles do
			local h = FindIt.hint(t.id, profile())
			if h == "" or not copyOk(h, CFG.map.hintWords) or string.find(h, "%d") then hintsOk = false end
		end
		check(hintsOk and CFG.map.hintWords == 2, "every tile says what to do there in 2 words or fewer")
		local three = profile({ horses = { { id = "a" }, { id = "b" }, { id = "c" } } })
		check(FindIt.hint("stable", three) == "3 horses" and FindIt.hint("stable", profile()) == "Your barn", "My Stable: how many horses")
		local nap = profile({ horses = { { id = "h1", name = "Comet", resting = true, spaToday = 0 } } })
		check(FindIt.hint("vet", nap) == "Spa today" and FindIt.hint("vet", profile()) == "Check-ups", "Vet & Spa: \"Spa today\" for a napping horse")
		local spent = profile({ horses = { { id = "h1", resting = true, spaToday = GameConfig.spa.perDay } } })
		check(FindIt.hint("vet", spent) == "Check-ups", "no Spa line once today's Spa is used")
		check(FindIt.hint("barnBuilder", profile({ bestLeague = "Bronze" })) == "New shelf" and FindIt.hint("barnBuilder", profile()) == "Build things",
			"Barn Builder: \"New shelf\" when a new shelf opened")
		-- The panel fits a 667 × 375 phone at the floors, without scrolling.
		local w, h = FindIt.panelSize()
		check(w == 5 * 116 + 4 * 8 + 32 and h == 64 + 3 * 96 + 2 * 8 + 8, `Map panel {w} × {h}`)
		local fit = PanelFit.layout(667, 375, w, h, 16, 64, UI)
		check(not fit.scroll and fit.scale * 16 >= UI.minTextPx - 1e-9 and fit.scale * 64 >= UI.minTouchPx - 1e-9,
			`the Map fits a 667 × 375 phone (scale {fit.scale})`)
		check(CFG.map.tileW >= 64 and CFG.map.tileH >= 64 and CFG.map.hintPx >= 16 and CFG.map.wordPx >= 16, "tiles and words at the floors")
	end

	-- Trips: the server takes every place but the barns list; Barn Builder arrives at Feed & Seed -------
	do
		local ok = true
		for _, id in WorldLayout.MAP do
			if WorldLayout.isTravelDest(id) == (id == "visit") then ok = false end
			local x, z = WorldLayout.arrival(id, 3)
			local B = WorldLayout.BOUNDS
			if x < B.x0 or x > B.x1 or z < B.z0 or z > B.z1 then ok = false end
		end
		check(ok, "every Map place but Visit barns is a trip, and every arrival is in bounds")
		check(not WorldLayout.isTravelDest("nowhere") and not WorldLayout.isTravelDest(nil) and not WorldLayout.isTravelDest(5),
			"Travel refuses anything else")
		local ax, az = WorldLayout.arrival("barnBuilder")
		local fx, fz = WorldLayout.arrival("feedStore")
		check(ax == fx and az == fz, "Barn Builder: you arrive at Feed & Seed")
		local px, pz = WorldLayout.arrival("paddock")
		local qx, qz = WorldLayout.arrival("plaza")
		check(px ~= qx or pz ~= qz, "Training has its own arrival (not Fair Street's)")
		local ss = code("game/src/server/StableService.server.luau")
		check(has(ss, "if not WorldLayout.isTravelDest(dest) then return end"), "the server checks every trip against WorldLayout.isTravelDest")
	end

	-- GO: walk near, trip far, open; never a trip in line, nothing while racing ----------------------------
	do
		local W = CFG.goTo.walkMaxStuds
		local near = FindIt.goPlan("vet", W, {})
		local far = FindIt.goPlan("vet", W + 1, {})
		check(near.how == "walk" and near.open and near.label == "GO ▶", "near: hoofprints, and it opens on arrival")
		check(far.how == "teleport" and far.open and far.label == "Take me ▶", "far: the trip, then it opens")
		check(FindIt.goPlan("vet", nil, {}).how == "teleport", "no character yet: the trip")
		local line = FindIt.goPlan("vet", W * 10, { inLine = true })
		check(line.how == "walk" and not line.open, "in a race line: hoofprints only, never a trip")
		check(FindIt.goPlan("market", W * 10, { training = true }).how == "walk", "on a training ride: hoofprints only")
		local racing = FindIt.goPlan("vet", 5, { racing = true, inLine = true })
		check(racing.how == "wait" and not racing.open and racing.label == "After your race!", "racing: nothing moves")
		check(FindIt.goPlan("board", 9999, { inLine = true }).how == "open" and FindIt.goPlan("pick", nil, {}).how == "open"
			and FindIt.goPlan("visit", 9999, {}).how == "open", "panels just open (Jobs, Pick, the Book, Visit barns)")
		check(FindIt.goPlan("board", 1, { racing = true }).how == "wait", "not even a panel while racing")
		check(W == 120 and CFG.goTo.fadeSeconds == 0.3, "walkMaxStuds 120, a 0.3 s fade")
		for _, l in { near.label, far.label, racing.label } do check(copyOk(l, 6), `GO copy: "{l}"`) end
	end

	-- "New!" pointers: one at a time, at most one per 3 minutes, never on the tour, busy or after a race -
	do
		local P = CFG.pointers
		local calm = { sinceRace = 9999 }
		check(P.gapSeconds == 180 and P.afterRaceSeconds >= 120, "at most one per 3 min; never within 120 s of a race")
		check(FindIt.pointerDue(profile(), calm, nil, 0) == nil, "a brand-new player: nothing yet")
		local three = profile({ totals = { races = 3 } })
		local first = FindIt.pointerDue(three, calm, nil, 1000)
		check(first ~= nil and first.id == "pick" and first.go == "pick", "after 3 races: Pick your own race")
		check(FindIt.pointerDue(three, calm, 1000, 1000 + P.gapSeconds - 1) == nil, "never two within gapSeconds")
		check(FindIt.pointerDue(three, calm, 1000, 1000 + P.gapSeconds) ~= nil, "the next one after the gap")
		check(FindIt.pointerDue(three, { touring = true }, nil, 0) == nil, "never during the tour")
		check(FindIt.pointerDue(three, { busy = true }, nil, 0) == nil, "never in line, racing or riding")
		check(FindIt.pointerDue(three, { resultsOpen = true }, nil, 0) == nil, "never on the results card")
		check(FindIt.pointerDue(three, { sinceRace = P.afterRaceSeconds - 1 }, nil, 0) == nil, "never right after a race (hard rule 3)")
		check(FindIt.pointerDue(three, { sinceRace = nil }, nil, 0) ~= nil, "no race yet this session: fine")
		local seen = profile({ totals = { races = 3 }, flags = { seen_pick = true } })
		local nxt = FindIt.pointerDue(seen, calm, nil, 0)
		check(nxt == nil or nxt.id ~= "pick", "a seen pointer never shows again")
		local napping = profile({ totals = { races = 0 }, horses = { { id = "h1", resting = true, spaToday = 0 } } })
		local spa = FindIt.pointerDue(napping, calm, nil, 0)
		check(spa ~= nil and spa.id == "spa" and spa.go == "vet", "a napping horse: Spa Day at the Vet")
		-- Everyone at 99 races, one by one as each is seen: every pointer shows once, in order.
		local p = profile({ totals = { races = 99 }, horses = { { id = "h1", resting = true, spaToday = 0, trainingReady = true } } })
		local order = {}
		for _ = 1, 20 do
			local q = FindIt.pointerDue(p, calm, nil, 0)
			if not q then break end
			table.insert(order, q.id)
			p.flags[FindIt.seenKey(q.id)] = true
		end
		check(#order == #FindIt.POINTERS and order[1] == "spa", `every pointer once: {table.concat(order, ", ")}`)
		local copy, places = true, true
		for _, q in FindIt.POINTERS do
			if not copyOk(q.text, 6) or string.sub(q.text, 1, 5) ~= "New! " then copy = false end
			if not FindIt.SEEN_IDS[q.id] then copy = false end
			if not (FindIt.PANELS[q.go] or table.find(WorldLayout.MAP, q.go)) then places = false end
			if q.go == "tackShop" then places = false end -- the 💎 shop is never pointed at (D-050)
		end
		check(copy and FindIt.SEEN_IDS.howRacing == true, "pointer copy: \"New! …\", 6 words or fewer; each one can be saved as seen")
		check(places, "every pointer goes to a place or a panel, never the 💎 shop")
		check(FindIt.ringAlpha(P.ringSeconds + 0.01, false) == nil and FindIt.ringAlpha(1, true) == 1 and P.ringHz <= 3,
			"the gold ring: ringSeconds long, at most 3 flashes a second, still under Reduced Motion")
		check(math.abs((FindIt.ringAlpha(0, false) :: number) - (FindIt.ringAlpha(1 / P.ringHz, false) :: number)) < 1e-9, "the ring pulses at ringHz")
		local set = code("game/src/server/SettingsService.server.luau")
		check(has(set, "if typeof(value) ~= \"string\" or not FindIt.SEEN_IDS[value]") and has(set, "seenCount[player]"),
			"the server only saves known seen ids, in their own bucket (never dropped by another setting's limit)")
		-- (code review B1) a kept pointer re-checks the gates each time it would show: dropped unseen.
		check(FindIt.pointerOk({ sinceRace = 9999 }) and not FindIt.pointerOk({ sinceRace = P.afterRaceSeconds - 1 })
			and not FindIt.pointerOk({ busy = true }) and not FindIt.pointerOk({ resultsOpen = true }) and not FindIt.pointerOk({ touring = true }),
			"the pointer gates: never in line, racing, on results, on the tour or right after a race")
		local sbp = code("game/src/client/StableBoard.client.luau")
		check(has(sbp, "if FindIt.pointerOk(ctx) then return pointer end") and count(sbp, "not FindIt.pointerOk(buildCtx(") == 2,
			"a kept pointer is re-gated when it would show again, while it shows, and at its GO")
	end

	-- The queue card names the line and why ------------------------------------------------------------
	do
		check(QueueView.lineTitle("Bronze|race") == "🟠 Bronze race line" and QueueView.lineWhy("Bronze|race", "Comet") == "Horses like Comet race here",
			"a league race line and why")
		check(QueueView.lineTitle("Silver|cup") == "🏆 Silver Cup line" and QueueView.lineWhy("Silver|cup") == "Only Cup horses", "the Cup line")
		check(QueueView.lineTitle("Open|practice") == "🎈 Open Practice line" and QueueView.lineWhy("Open|practice", nil, true) == "Anyone! Horses all equal",
			"Open Practice")
		check(QueueView.lineTitle("Rookie|practice") == "🎈 Rookie Practice line", "a league's own Practice line")
		check(QueueView.lineTitle(nil) == "" and QueueView.lineTitle("junk") == "" and QueueView.lineTitle("Bronze|jump") == "",
			"no line, no name")
		check(QueueView.lineShort("Gold|race") == "🟡 Gold line" and QueueView.lineShort("Gold|cup") == "🏆 Cup line"
			and QueueView.lineShort("Open|practice") == "🎈 Practice line", "the phone row's short names")
		local copy = true
		for _, league in GameConfig.leagueOrder do
			for _, kind in { "race", "cup", "practice" } do
				local key = league .. "|" .. kind
				for _, t in { QueueView.lineTitle(key), QueueView.lineWhy(key, "Comet", true), QueueView.lineWhy(key, nil, false), QueueView.lineShort(key),
					QueueView.joinWord(league, kind) } do
					if t == "" or not copyOk(t, 6) then copy = false end
				end
			end
			if not QueueView.LEAGUE_DOT[league] then copy = false end
		end
		check(copy, "every line name and why: 6 words or fewer, kid words")
		check(QueueView.joinWord("Bronze", "race") == "Join Bronze line" and QueueView.joinWord("Bronze", "practice") == "Join Practice line",
			"the picker's Join names the line")
		-- The phone row: the short name and the riders (the seconds stay in the ring).
		local s = QueueView.new(8, 15)
		QueueView.status(s, true, 3, 12, "dirt", 0)
		QueueView.gate(s, "dirt", { { name = "A" }, { name = "B" }, { name = "C" } }, 8, 12, false, 0)
		local v = QueueView.view(s, nil, 0)
		check(QueueView.compactLine(v, "🟠 Bronze line") == "🟠 Bronze line · 3 riders" and QueueView.compactLine(v) == "Race in 12 · 3 riders",
			`compact row: "{QueueView.compactLine(v, "🟠 Bronze line")}"`)
		local rs = code("game/src/server/RaceService.server.luau")
		check(count(rs, "markLine(") >= 8 and has(rs, "player:SetAttribute(\"LineKey\", key)"), "the server names your line (LineKey, LineHorse)")
		local card = code("game/src/client/QueueCard.client.luau")
		check(count(card, ":FireServer(") == 1 and has(card, "QueueView.lineTitle(key)") and has(card, "HowRacing.open()")
			and has(card, "HowRacing.maybeAuto()"), "the card: line name and why, ❓, the strip once by itself; still one remote call")
		local how = code("game/src/client/HowRacing.luau")
		for _, caption in { "Join a line", "Riders fill the gate", "Bots fill spots at 0" } do
			check(has(how, "\"" .. caption .. "\"") and copyOk(caption, 6), `strip picture: "{caption}"`)
		end
		check(has(how, "FireServer(\"seen\", \"howRacing\")") and has(how, "FindIt.seen(d.flags, \"howRacing\")") and CFG.howRacing.autoOnce,
			"the strip shows by itself once, saved in the profile")
	end

	-- The dock: five items on a phone, one LayoutOrder each, 🔀 Pick -------------------------------------
	do
		local seen, unique = {}, true
		for _, v in DockLayout.ORDER do
			if seen[v] then unique = false end
			seen[v] = true
		end
		check(unique and DockLayout.ORDER.map ~= DockLayout.ORDER.book, "every dock slot has its own LayoutOrder (Map and Book no longer share 4)")
		check(UI.dockPhoneItems == 5 and DockLayout.isPhone(true, 667, 375, UI), "the five-item phone dock")
		local floor = DockLayout.floor(UI)
		check(floor * (UI.pickStripPx :: number) >= UI.minTouchPx - 1e-9 and floor * DockLayout.BUTTON_PX >= UI.minTouchPx - 1e-9,
			"Pick and every dock button stay at the 56 px floor")
		local room = 667 - 24 - GameConfig.touchLayout.movementColumn
		check(DockLayout.phoneWidth(UI) * floor <= room, `the phone dock fits beside Hop and Gallop ({DockLayout.phoneWidth(UI) * floor} <= {room})`)
		local hud = code("game/src/client/Hud.client.luau")
		check(has(hud, "pickBtn.Activated:Connect(pressPick)") and has(hud, "OpenRacePicker:Fire()") and has(hud, "Ui.iconButton(raceSlot, \"\", \"🔀\", \"Pick\""),
			"🔀 Pick opens the picker without joining")
		check(has(hud, "local list = if FIVE then { cashSlot, horsesSlot } else"), "More holds Cash and Horses (Ride, Book too); Map and Jobs stay")
		-- (UI/UX must-fix 1) narrow phones move Jobs, then Map, into More, and the dock clears Hop and Gallop.
		local MC = GameConfig.touchLayout.movementColumn
		for _, vx in { 568, 640, 667, 740 } do
			local moves = DockLayout.phoneMoves(vx, UI, MC)
			check(DockLayout.phoneRendered(UI, moves) <= vx - 24 - MC + 1e-9, `phone dock at {vx} px fits ({DockLayout.phoneRendered(UI, moves)} px, moved: {table.concat(moves, ",")})`)
		end
		check(#DockLayout.phoneMoves(667, UI, MC) == 0 and #DockLayout.phoneMoves(740, UI, MC) == 0, "667 and 740 px keep all five")
		check(table.concat(DockLayout.phoneMoves(640, UI, MC), ",") == "jobs" and table.concat(DockLayout.phoneMoves(568, UI, MC), ",") == "jobs,map",
			"640 px moves Jobs; 568 px moves Jobs then Map (the 3-item dock)")
		check(DockLayout.phoneRendered(UI, DockLayout.phoneMoves(568, UI, MC)) <= 368, "568 × 320: the dock is 368 px or less")
		-- (code review B2) the portrait's tap never sinks a thumbstick drag.
		check(has(hud, "portraitTap.Active = false") and has(hud, "<= (UIc.portraitTapMovePx or 10)") and has(hud, "horseHit.Visible = not touch")
			and UI.portraitTapMovePx == 10, "the portrait: a tap opens My Horses, a drag still walks")
		check(has(hud, "raceBtn.TextScaled = true") and has(hud, "raceFit.MinTextSize, raceFit.MaxTextSize = 18, 30")
			and has(hud, "racePad.PaddingBottom = UDim.new(0, if raceSub.Visible then 22 else 5)"), "RACE! text scales 18-30 px above its sub-line")
		check(has(code("game/src/server/StableService.server.luau"), "if player:GetAttribute(\"InLine\") or player:GetAttribute(\"TrainingRide\") then"),
			"the server refuses trips from a line or a training ride")
		check(has(code("game/src/client/HorseBookClient.client.luau"), "ORDER.book") and has(code("game/src/client/RideClient.client.luau"), "ORDER.ride"),
			"the Book and Ride take their order from DockLayout")
	end

	-- GO wiring: Tour, Advice pill, Stable Board, Map tiles; every feature registers its open --------------
	do
		local reg = {
			{ "CareClient.client.luau", "GoTo.register(\"feedShop\"" }, { "BarnBuilder.client.luau", "GoTo.register(\"barnBuilder\"" },
			{ "StyleShop.client.luau", "GoTo.register(\"tackShop\"" }, { "PaddockClient.client.luau", "GoTo.register(\"train\"" },
			{ "PaddockClient.client.luau", "GoTo.register(\"vet\"" }, { "HorsesClient.client.luau", "GoTo.register(\"market\"" },
			{ "WorldClient.client.luau", "GoTo.register(\"visit\"" },
		}
		for _, r in reg do check(has(code("game/src/client/" .. r[1]), r[2]), `{r[1]} registers {r[2]}`) end
		local go = code("game/src/client/GoTo.luau")
		local opened = true
		for place, id in { raceBoard = "picker", feedStore = "feedShop", barnBuilder = "barnBuilder", tackShop = "tackShop", vet = "vet",
			market = "market", paddock = "train", trainingGround = "train", board = "board" } do
			if not has(go, place .. " = \"" .. id .. "\"") then opened = false end
		end
		check(opened, "GO opens the shop, the Train menu, the vet, the corral, the picker, the board")
		check(has(go, "FindIt.goPlan(place, dist, state())") and has(go, "player:GetAttribute(\"InLine\") == true"), "GoTo follows FindIt.goPlan (in line: hoofprints)")
		check(has(go, "return not racing() and not RaceState.shopClosed(0)") and has(go, "if calm() then GoTo.open(id) end"),
			"a walk opens on arrival only in a calm moment (not in line, racing, riding or on results)")
		check(has(go, "picker = \"PressPick\"") and has(code("game/src/client/Hud.client.luau"), "localEvent(\"PressPick\").Event:Connect(pressPick)"),
			"GO to the picker goes through 🔀 Pick (its reason window)")
		check(has(code("game/src/client/HorsesClient.client.luau"), ".shopClosed(GameConfig.findIt.pointers.afterRaceSeconds) then return end"),
			"the Market's GO never opens a listing around a race (hard rule 3)")
		check(has(code("game/src/client/StyleShop.client.luau"), "if not gui.Enabled and not RaceState.shopClosed(DiamondProducts.afterRaceSeconds) then open() end"),
			"the Tack & Paint tile keeps the 💎 door shut around races (D-050)")
		local sb = code("game/src/client/StableBoard.client.luau")
		check(has(sb, "GoTo.place(go, nil, { toast = false })") and has(sb, "FindIt.pointerDue(d, ctx, lastPointerAt, os.clock())")
			and has(sb, "localEvent(\"PointAt\"):Fire(p.ring, p.go)"), "Stable Board and pill GO through GoTo; pointers ring the dock")
		check(has(code("game/src/client/GrownUps.client.luau"), "GoTo.place(go)"), "the tour's GO goes through GoTo")
		check(has(code("game/src/client/WorldClient.client.luau"), "GoTo.place(dest)"), "Map tiles go through GoTo")
	end

	-- The Fair Street signpost: code-built, an arm per place ----------------------------------------------
	do
		local S = CFG.signpost
		local ok = S.enabled and #S.arms >= 6
		for _, key in S.arms do
			if not WorldLayout.MAP_LABELS[key] or not (key == "stable" or WorldLayout.places[WorldLayout.MAP_ALIAS[key] or key]) then ok = false end
		end
		check(ok, "the signpost has 6 arms, each a Map place")
		local ws = code("game/src/server/WorldScene.luau")
		check(has(ws, "buildSignpost(f)") and not has(ws, "placeModel(m, \"fair_signpost\""), "the signpost is parts and SurfaceGuis (no uploads)")
		local px, pz = S.x, WorldLayout.STREET_Z + S.zOffset
		local ax, az = WorldLayout.arrival("plaza")
		check(px > ax and math.abs(pz - az) <= WorldLayout.STREET_WIDTH / 2, "in front of a new player on Fair Street, on the street")
		check(math.sqrt((px - (WorldLayout.STREET_X0 + 75)) ^ 2 + (pz - WorldLayout.STREET_Z) ^ 2) > 22 + 4, "clear of the fountain and its benches")
	end
end
