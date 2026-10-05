--!strict
-- Horse theme. The engine never uses these words directly (D-007).
-- A car or boat skin replaces this module only.

local ThemePack = {
	id = "horse",
	gameTitle = "Gavel Derby",
	racer = { singular = "Horse", plural = "Horses" },
	pilot = { singular = "Jockey", plural = "Jockeys" },
	gavelAction = "Giddy-up", -- D-022: never whip wording
	currency = { earned = "Green Cash", premium = "Diamonds" },
	stats = {
		speed = "Speed",
		accel = "Acceleration",
		stamina = "Stamina",
		grit = "Grit",
		focus = "Focus",
	},
	windows = { "The Break", "Backstretch", "Final Stretch" },
	botNames = {
		"Thunder Hoof", "Midnight Comet", "Clover Dash", "Sunny Sprinkle", "Rusty Bolt",
		"Maple Flash", "Pebble Prance", "Starlight Skip", "Biscuit Blaze", "Juniper Jet",
		"Copper Kettle", "Misty Meadow", "Rocket Radish", "Velvet Gale", "Pumpkin Spark",
	},
	words = {
		winChance = "Win chance",
		purse = "Win",
		tap = "TAP!",
	},
}

return ThemePack
