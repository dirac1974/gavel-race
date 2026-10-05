# Auto-clickers, input detection, and anti-macro practice (2026-10-04)

## Question
Does Roblox prohibit auto-clickers, what can a game detect about input, how common are mobile auto-tappers, and how do timing games defend against macros?

## Short answer
No Roblox rule names auto-clickers, so it's up to us. A game can't tell a physical tap from an injected or automated one. Defend by design (timing that changes every stride, scored on the server) and by quiet statistics on timing consistency, not by input inspection.

## Evidence (all checked 2026-10-04)
- **Policy.** [Community Standards](https://about.roblox.com/community-standards) ban "Using or sharing exploits to help yourself or others gain an unfair advantage"; the [Terms of Use](https://en.help.roblox.com/hc/en-us/articles/115004647846-Roblox-Terms-of-Use) are silent on input automation; Roblox's [2025 enforcement update](https://devforum.roblox.com/t/an-update-on-automated-action-against-modified-clients/3640609) targets modified clients. Whether an auto-tapper is an "exploit" is unconfirmed.
- **Detection limits.** [UserInputService](https://create.roblox.com/docs/reference/engine/classes/UserInputService) is client-only; [InputObject](https://create.roblox.com/docs/reference/engine/classes/InputObject) carries Delta, KeyCode, Position, UserInputState, UserInputType, with no timestamp, device id, or synthetic flag.
- **Roblox guidance.** "Assume every piece of data sent from the client has been manipulated"; validate and rate-limit on the server ([security tactics](https://create.roblox.com/docs/scripting/security/security-tactics), [client-server boundary](https://create.roblox.com/docs/scripting/security/client-server-boundary)). Roblox's [server-side detection](https://create.roblox.com/docs/scripting/security/server-side-detection) "Action Cadence" heuristic flags auto-clicker-regular timing and calls it "a signal, not as definitive proof". (Creator Hub pages render client-side; quotes verified against Roblox's creator-docs repo.)
- **Ping.** `Player:GetNetworkPing()` returns round-trip time in seconds (creator-docs repo).
- **Mobile auto-tappers (third-party).** Android: [Auto Clicker – Automatic tap](https://play.google.com/store/apps/details?id=com.truedevelopersstudio.automatictap.autoclicker) has 100M+ installs, rated Everyone, and uses the AccessibilityService API without root; [AG Auto Clicker](https://play.google.com/store/apps/details?id=com.tapassistant.autoclicker) has 10M+ and records and replays taps. Both tap blind on fixed timers. iOS: no App Store auto-tapper found (unconfirmed); [Switch Control](https://support.apple.com/guide/iphone/set-up-and-turn-on-switch-control-iph400b2f114/ios) and [AssistiveTouch](https://support.apple.com/guide/iphone/use-assistivetouch-iph96b21954/ios) can record gestures. No data on how many kids use them.
- **Other games.** osu! bans macros ([rules](https://osu.ppy.sh/wiki/en/Rules)) and measures hit-error spread as [unstable rate](https://osu.ppy.sh/wiki/en/Gameplay/Unstable_rate) (enforcement use unconfirmed). Valve's server-side deep-learning anti-cheat needs no client instrumentation ([GDC 2018](https://www.gdcvault.com/play/1024994/Robocalypse-Now-Using-Deep-Learning)).

## What it means for the game
- Fixed-timer auto-tappers are the common threat on phones; a drifting stride tempo (D-022) defeats them by design.
- Flag on timing consistency against the beat, quietly and with lots of evidence, as Roblox's own heuristic suggests; never on input device.
- Screen-reading bots will still get through; consider capping Green Cash per hour as a backstop (not yet decided).

## Uncertainties
- Whether Roblox moderation treats auto-tappers as exploits.
- How common auto-tappers are among 8–13-year-olds.
- Whether iOS accessibility recordings can loop timed taps.
