--!strict
-- Diamond packs (D-050): Roblox developer products. 1 Diamond = 1 Robux in every pack (no
-- bigger-pack bonus). Product ids come from the Creator Dashboard (Monetization → Developer
-- Products for the Giddy-Up experience); 0 = not set up yet, and the shop says so.
-- Our own spending caps sit on top of Roblox's parental controls.

local DiamondProducts = {}

DiamondProducts.packs = {
	{ name = "50 Diamonds", diamonds = 50, robux = 50, productId = 0 },
	{ name = "100 Diamonds", diamonds = 100, robux = 100, productId = 0 },
	{ name = "250 Diamonds", diamonds = 250, robux = 250, productId = 0 },
}

DiamondProducts.caps = { dayRobux = 250, monthRobux = 1000 }
DiamondProducts.afterRaceSeconds = 120 -- no Diamond prompts for this long after your race

return DiamondProducts
