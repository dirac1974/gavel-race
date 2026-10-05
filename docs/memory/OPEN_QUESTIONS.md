# Open questions for David

Since D-009 the team decides and David reviews (`REVIEW_QUEUE.md`). Only questions the team truly can't answer go here.

1. ~~**Running-order board during the race.**~~ Decided provisionally in D-055 (debate 011, 4/4): hidden for riders from the gate to the finish, a slim place-and-name board for spectators, and no win % or purse anywhere. You asked for the in-race board in D-030, so this is first in the review queue; `GameConfig.hud.riderBoardInRace = true` brings it back for riders.
2. ~~Sick horses and the vet~~: David (2026-10-05): skip sick horses. The wellness clinic stays (D-039).
3. ~~Diamond store~~: David (2026-10-05): build it. Done as D-050. **To switch packs on:** create three developer products in the Creator Dashboard (Giddy-Up → Monetization → Developer Products): "50 Diamonds" 50 R$, "100 Diamonds" 100 R$, "250 Diamonds" 250 R$; turn off price optimization; put the three product ids in `game/src/shared/DiamondProducts.luau` (or give the API key the developer-product scope and the team will do it).
4. ~~**Sound and voice.**~~ Answered 2026-10-05: up to 2,000 ElevenLabs credits. Voice lines are done (29 credits); sound effects need **Sound Effects** access turned on for the ElevenLabs API key (docs/audio/AUDIO_PLAN.md, "Blocked").
