# PawSanctuary vs Reference — Round 2

**Read from source 27 July 2026**, after your revision pass. Codebase 16,849 → **26,266 lines** (+56%).
Reference: Gossip Harbor, Travel Town, Tasty Travels — measured July 2026.

Supersedes the C-list in `Economy_State_and_Variance.md`.

---

## 1. Closed since the last read — 9 of 10

| Gap | Status | Evidence in source |
|---|---|---|
| **C-2** Bonus layer on boosted spawns | ✅ | `legendaryBonusShare = 0.15`, rolled in `MergeBoardViewModel:1177` |
| **C-3** Currency merge chains | ✅ | `currency.kibble` + `currency.coin` authored in `ItemChain:351/369`, spawning at `:1249` |
| **C-4** Bubble mechanic | ✅ | `bubbleChance 0.15`, `bubbleMinTier 5`, 10-min decay to a lesser value, gated to quest/order-relevant merges. **The retune is better than my spec** — no bubbles below tier 5 means the mechanic never fires on items the player doesn't care about. |
| **C-5** Order slots + difficulty spread | ✅ | `orderSlotDifficultyPattern = [.easy, .medium, .medium, .hard]` — exactly the invariant 1/2/1 spread, with per-difficulty tier tables replacing the flat bands |
| **C-6** Persistent vs urgent orders split | ✅ | `urgentOrderDuration` / `urgentOrderRespawnCooldown` separate from the standing slots |
| **C-7** The wall | ✅ | `KibbleRefillSheet` with `watchRewardedAd()` inside it — the ad now lives at the wall, not in a menu |
| **C-8** Session-one monetization silence | ✅ | `isMonetizationUnlocked = hasReachedFirstWall && level >= monetizationUnlockLevel` |
| **C-9** Live-ops | ✅ | Real `LiveOpsEngine` — `EventScheduler` with contested-slot resolution, `TokenWallet`, `ProgressTrack` with free/paid lanes. 3 events defined incl. a Pass. Parallel board present. |
| **C-10** Quest tier cap | ✅ | Quest pools extended to tiers 9–11, closing the `RescueStage` gap |

That is the whole psychology list bar one. Worth saying plainly: the game now implements the interruption loop, the variable-ratio layer, near-miss order structure, a designed wall, session-one silence, and a live-ops lattice with paid lanes. Those are the mechanisms, not decorations.

---

## 2. Still open from the original list — 1 of 10

**C-1 · Board opens at 78%, decision was 33%.**

`boardRowUnlockLevels = [7: 3, 8: 8]` — unchanged. Two rows locked, level-gated.

The 27 July decision was to open at **3 rows / 21 cells / 33%** and gate the remaining six rows on **reaching a new merge tier** rather than player level, on the reasoning that deeper tiers need more staging space so the reward should arrive with the need.

Schedule as decided: start 0–2, then +1 row at tiers 2 / 4 / 6 / 8 / 9 / 10, full board at tier 10.

Two things to build alongside it: **seed the locked rows with visible currency caches** (the currency chains now exist, so this is cheap), and **make the Board Full toast name the exits** — with merge-gated unlocking, a full board is the one state that can deadlock a player.

---

## 3. Newly identified — reference mechanics not yet catalogued

Ten measured mechanics absent from PawSanctuary, ranked by value against effort.

### High value

**3.1 · Daily challenge stagger.** Measured: quests are calibrated so the next is **60–90% complete when the current one finishes**, and difficulty scales with the individual player's activity. This is the near-miss engine — the stagger *is* the mechanic. Without it a daily challenge is a checklist; with it, finishing one thing reveals another is nearly done. Pure logic, no assets, no new UI.

**3.2 · Store refresh for currency.** Measured at **10 gems in Travel Town, deliberately priced below the cheapest item in the store** — so a reroll is an impulse and every reroll is a fresh chance at the item you actually need. Your Dog Tag store rotates daily with no paid reroll. Cheapest meaningful gem sink available to you.

**3.3 · Merge-able chests.** A reward container that is *also* a chain item: open now for a small payout, or merge two for a bigger one. Variable-ratio reward and a merge decision in one object. You have chests but they are not chain items.

### Medium value

**3.4 · Piggy bank.** Passive accumulator that fills as the player progresses and costs money to crack. Standard, effective, self-contained.

**3.5 · Wildcard / joker board item.** Measured at 150 gems. Merges with anything. Both a premium sink and a genuine relief valve for a player one item short.

**3.6 · Timed free chests.** Free with a wait — a soft speed-up sink carrying no purchase pressure. Pairs naturally with 3.3.

**3.7 · Purchase-progress promotion.** Measured: purchases themselves earn points toward a grand prize, decoupled from playing. Converts spending into its own progression track. The most aggressive item here — a deliberate decision, not a default.

### Needs population first

**3.8 · Competitive events.** Duels (1v1, tenure-banded), tournaments, multi-player races. All three reference titles run them; Travel Town added them only after 2024. Your `LiveOpsEngine` scheduler could host them, but they need players.

**3.9 · Out-of-app loyalty surface.** Measured in Travel Town: a web PWA at level 35+, daily claim, tiers, own auth. Retention outside the app, first-party data, no store fee on anything sold there. You have a Loyalty Club, but in-app.

### Not applicable as-is

**3.10 · Generator cooldown paid skip.** Measured as the highest-frequency, lowest-friction gem sink in the reference games — an inline button on the generator priced to the specific wait. **Your family spawners have no cooldown**, so there is nothing to skip. Noted because it is a real gap in *sink variety*, not because the mechanic ports directly. If you ever add spawner cooldowns, this comes with them.

---

## 4. What I would do next

**C-1 first.** It is the last item from the original psychology list, the decision is already made, and the currency chains it depends on now exist. It is also the only one that touches the FTUE, which is the highest-leverage minute in the game.

**Then 3.1 and 3.2.** Both are small, both are pure logic, and both target things the game currently lacks rather than does badly — near-miss pacing and gem-sink variety.

**Then re-examine 3.7 and 3.8 together**, because they are the two that depend on decisions rather than effort: how aggressive you want monetization to be, and whether you will have the population for competition.

Everything else on the list is genuinely optional at this stage.
