# Breeding: consensus (2026-10-12, D-080)

David: "Build the breeding now." Plan: `plan.md` (systems). Votes: `votes-gameplay.md`, `votes-ui-ux.md`, `votes-feel.md`. All three voted CHANGE / AGREE WITH CHANGES; none voted BLOCK. Every change in the vote files is part of the spec. The tech lead settled the splits below.

| Topic | Positions | Ruling |
|---|---|---|
| Young chip vs a foal symbol | gameplay: Young becomes 🌼, 🍼 means foal; UI/UX: 🍼 already means Young, breeding is 💞 | **🍼 stays Young.** A foal *is* a Young horse, so it's one meaning. **Breeding is 💞** (atlas `family` icon). Surprise coat is ❔. No 🌼. |
| Building name | feel: "Foal Barn" (no birth word); UI/UX: "Foaling Barn" | **"💞 Foal Barn"**, in cream and sky blue, the 14th Map tile, hint "Foal soon". |
| Foal start stats | plan 60% of Potential; gameplay caps them | **60%, capped at `breeding.startMax = 50` per stat.** Sim gate: a bred foal plays at least 15 Rookie races and wins 20–30% there. |
| Rolls | gameplay | Coat and Potential are rolled **once on the server at confirm** and stored; a rejoin can't reroll them. |
| Coat display | UI/UX | A 3-row box (swatch, bar, %); the word is always "chance". |
| Flow | UI/UX | Two steps, "Pick two parents" then "Your foal". Waiting copy: "Arrives in 5 races or tomorrow". There's no clock. Naming copies the Starter's step 2 ("🔀 New words", "That's the name!"). |
| Arrival | feel | The foal steps out from behind its parent and nuzzles it. Hearts rise; the foal plays `horse_nicker` at speed 1.45 and the parent answers at 0.9. There's no confetti and nothing birth-like. A Surprise coat gets no spin and no bigger celebration. |
| Foal rig | feel | Body and head ×0.70, legs ×0.92 tall, growing to adult size by 30 races. Never smaller than 0.94 in races. For its first 10 races the foal tags along behind its parent and frolics. |
| First race | gameplay | A one-time "🍼 Comet's foal!" moment on the foal's first race. |
| Genders | all | None in this build (a playtest question for David). |
| Meshy | all | 0 credits. |

**Build order:**
1. The model and sims (in progress).
2. The game flow: Foal Barn, picker, chances, waiting, arrival, naming, foal rig.
3. The Horse Book Family page, with empty state "Two horses can start a family".

Each step gets a code review and a designer consult.
