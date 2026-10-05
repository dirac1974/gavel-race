# Roblox world structure: servers, plots, data, policy

Brief by `roblox-researcher`, 2026-10-04, for the world workshop. Fan wikis are third-party and were read through the Fandom API. Player caps come from Roblox's public games API on that date.

## 1. Platform facts
- **Server size:** set per place on the Creator Dashboard ([Players.MaxPlayers](https://create.roblox.com/docs/reference/engine/classes/Players)). Voice chat only works at 100 or fewer ([voice chat](https://create.roblox.com/docs/chat/voice-chat)). The docs give no hard cap; 700-player servers were a closed beta (DevForum, unconfirmed). Typical caps: Horse Valley 16, Wild Horse Islands 20, Horse Life 30.
- **Teleports:** `TeleportAsync` plus a reserved server. Access codes "remain valid indefinitely", and a new server starts if none is running. One call moves at most 50 players. Teleport data is visible to the client, so keep anything secure in DataStores ([guide](https://create.roblox.com/docs/projects/teleport), [API](https://create.roblox.com/docs/reference/engine/classes/TeleportService)).
- **Data limits:** 4 MB per key, one key per player, prefer `UpdateAsync`. Each server gets 60 + 40 × players reads (and the same writes) per minute, so 1,260 at 30 players. Per key: 25 MB/min read, 4 MB/min write ([limits](https://create.roblox.com/docs/cloud-services/data-stores/error-codes-and-limits)). Estimate: one key holds thousands of horses.
- **Plots:** Roblox has no built-in plot feature, so the game builds them itself. Per-player streaming can help with loading ([streaming](https://create.roblox.com/docs/workspace/streaming)).

## 2. Competitors
- **[Wild Horse Islands](https://wild-horse-islands.fandom.com/wiki/Private_Island/Stable_Island)** (Happy Acres): 28 islands on separate servers, catching with single-use lassos, breeding between players. Each player has a private island that can be public, friends-only or locked, with market stalls. Food comes from NPCs, crops and wild pickups. There is a trading hub and a separate race hub.
- **[Horse Life](https://horse-life-wiki-roblox.fandom.com/wiki/Gameplay_Overview)** (Sonar Studios): tame with food or lassos, build on a plot placed in the shared map. Races every 15 minutes with 3–15 riders. Trading has its own world. Sells Robux "Capsules" (loot boxes).
- **[Horse Valley](https://horse-valley-2-roblox.fandom.com/wiki/Ranch)**: each player has a ranch in the shared server. Horses have hunger, thirst, hygiene and energy needs; the vet restores needs for 25 diamonds. Race entry fees were turned off, reportedly over a gambling flag (unconfirmed).

## 3. Policy
- **Under-16 audience:** needs Kids/Select eligibility. That means a Minimal or Mild rating, an ID-verified creator with 2-step verification, and 250 plays from highly engaged players in 60 days. Social hangouts and free-form drawing are not allowed; building with 3D assets doesn't count as drawing ([Kids & Select](https://create.roblox.com/docs/production/publishing/kids-and-select), [content maturity](https://create.roblox.com/docs/production/promotion/content-maturity)).
- **Chat:** must use `TextChatService`. All player text, horse names included, goes through the filter, and signs need at least a 1-minute rate limit ([guidelines](https://create.roblox.com/docs/chat/guidelines)). Since January 2026, players without an age check can't chat, and checked players chat only with neighbouring age bands ([newsroom](https://about.roblox.com/newsroom/2026/01/roblox-age-checks-required-to-chat)). Preset messages work across all ages.
- **Trading:** gate trading of paid items with `IsPaidItemTradingAllowed` ([PolicyService](https://create.roblox.com/docs/reference/engine/classes/PolicyService)). Real-money and off-platform trading is banned ([Community Standards](https://about.roblox.com/community-standards)).
- **Paid random items** (eggs, luck boosts, combining items): show odds that add up to 100% before purchase, and gate with `ArePaidRandomItemsRestricted` ([policy](https://create.roblox.com/docs/production/monetization/paid-random-items)).
- **Homes:** a hangout with private spaces like bedrooms is 18+ only. Under-13s may be blocked from private servers.

## What this means for Giddy-Up
- A 20–30 player hub with stable plots inside it. Races stay in the hub; only Stakes and Derby Day might use reserved servers. Stable visits default to friends-only.
- One save key per player, with horses stored as small records.
- Plan for players who can't chat: preset messages and emotes, filtered names, no drawing. Stables should be barns, not bedrooms.
- Nothing random bought with Robux (breeding boosts, eggs) without odds and the PolicyService gate. No race entry fees. Food is earned in game.
