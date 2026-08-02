# Merge-2 Reference Blueprint

**Theme-neutral architecture, gameplay psychology, and measured reference values**
Version 2.0 · 26 July 2026

> **This supersedes `Phase1_Structural_Blueprint.md`.** That document was written before the measurement phase and roughly ten of its claims were subsequently contradicted by observation. It should not be read as current. Everything here has been reconciled against the July 2026 capture data from Gossip Harbor, Travel Town and Tasty Travels.

**Sources:** ~27 minutes of Gossip Harbor from cold install through level 5; deep-game capture from Travel Town (L46) and Tasty Travels (L102–103); ~90 screenshots; controlled A/B tests on spawn distribution and bonus rates; published help documentation; third-party industry analysis.

Values are tagged **[M]** measured, **[F]** fitted between measured anchors, or **[A]** assumed with no supporting data.

---

## PART I — WHY THESE GAMES WORK

Structure without the psychology is a feature list. This section is the part worth internalising; everything in Part II is machinery serving it.

### 1. Interruption, not failure

**The single most important property in the genre.**

A failed match-3 level closes the loop. It resolves, it gives the player permission to stop, and the natural next thought is "I'll try again later."

Running out of energy resolves nothing. The order sits half-finished, the event timer keeps running, the board is exactly as it was left. The loop stays open.

Everything else in this document exists to protect that property. There is **no fail state anywhere in a well-built merge-2 game** — no losing, no penalty, no reset. Only delay. A delay is much harder to walk away from than a loss, and it is the reason these games sustain six to ten sessions a day where match-3 sustains two.

*Design test: if any system in your game can make a player feel they lost something, it is fighting the core mechanic.*

### 2. No session ceiling

Match-3 self-limits — you run out of lives, and there is a hard maximum on how much progress money can buy in one sitting.

Merge has no such ceiling. A player who wants to spend four hours and $200 can. This is the structural reason merge-2 out-earns match-3 per player, and it is why the genre only took off once the spend-rate ceiling was removed (see §14, Power Boost).

### 3. Variable-ratio reward, everywhere

Fixed rewards are satisfying once. Variable rewards are compulsive indefinitely. Reference implementations layer them densely:

- Bubbled merge outputs
- Chest contents
- Bonus spawns on boosted taps
- Card pack contents
- Store slot rotation
- Sub-object / power-up drops

Every one of these routes through a weighted reward table. Build one table primitive and use it everywhere.

### 4. The bonus layer is an accelerant dressed as a reward

**[M]** Bonus spawns ("Lucky!", "Legendary!") fire *only on boosted taps* — zero events in 33 seconds at ×1, twelve to fifteen in 35 seconds at ×4.

The mechanism is worth stating plainly because it is not obvious: gating bonuses behind the multiplier pushes players to burn energy in larger chunks. Larger chunks reach zero faster. **The player experiences generosity while their session shortens.**

This is the most elegant single mechanic found across the three games.

### 5. Near-miss engineering

Daily challenge quests are deliberately calibrated so the next one is 60–90% complete when the current one finishes. Difficulty scales with the individual player's activity.

The stagger *is* the mechanic. Without it, a daily challenge is a checklist. With it, finishing one thing reveals that another is nearly done.

The same logic drives the fixed order-difficulty spread (§10): always exactly one thing finishable right now, always exactly one out of reach.

### 6. Endowed progress and sunk cost

Card albums, first-discovery collections, the meta build-out and cosmetic tracks all serve one purpose: accumulating something the player would lose by leaving.

Note the asymmetry in album rewards **[M]**: set rewards ramp 100 → 500 energy, and the album grand prize is 250 gems + 800 energy + a wildcard. The value is concentrated at completion. The last few cards are worth far more than the first thirty, which is exactly when a player will pay.

### 7. Permanent partial completion

**[M]** Four to six concurrent events at horizons from four minutes to twenty-nine days, layered so no session ever ends with nothing pending.

This is the real answer to "how does a lean meta retain players." Not one event at a time — a lattice. The player is always slightly behind on something, and being slightly behind is a much stronger return driver than being finished.

### 8. Spending as its own progression track

**[M]** Card packs drop from any purchase above a threshold. Purchase-progress promotions award points for buying, independent of playing.

The effect is that a paying player has a second progression bar that only money advances. It converts a transaction into an achievement.

### 9. Buy belief before asking for money

**[M]** The segment leader shows **nothing** in session one — no offer, no ad, no store push — across 26 minutes and five levels. By level 5 it has opened a 33-day album, two timed events, a starter badge and a piggy bank, and pushes none of them.

The reasoning: a player who has not yet *wanted* anything has nothing to convert, and a purchase prompt in session one reframes the whole game as a shop before they have decided they like it.

**[M]** A fresh account that does hit the wall is quoted a price it cannot afford (100 energy for 80 gems with zero gems held). That is a wall dressed as an offer. The intended effect is "come back later," not "buy now."

### 10. Ration the discount rather than hiding it

**[M]** Energy price escalates within a day and resets: 10 → 20 → 40 gems for an identical 100 energy, with chest tiers interleaved at 24 and 48.

Roughly 320 energy per day is available at favourable rates; past that the price is flat and honest. Nobody is deceived. Critically, it also **caps how much cheap energy a whale can absorb per day**, which protects the pacing curve from being bought outright.

Compare with a volume discount, which does the opposite — it rewards bulk absorption and lets money flatten the curve.

### 11. Make the purchase playable

**[M]** A purchased energy chest does not credit energy. It goes to a holding slot, the player places it on the board, and it becomes a **spawner** producing mergeable energy items totalling 100.

Three effects: buying energy also costs board space; the purchase takes taps and time to realise, so it is *played* rather than credited; and the resulting board items are an **uncapped energy store**.

That last point matters more than it looks. **The energy cap does not cap energy — it only caps the meter.** Energy held as board items ignores it entirely, which is why reference players comfortably sit at three to five times their nominal cap.

### 12. Give energy away to keep them collecting

**[M]** The card album returns ~4,350 energy over 33 days against maybe 1,000–1,500 spent buying gap-filler cards. **The album pays the player.**

It is not a monetization sink. It is a **retention faucet** that makes purchases attractive indirectly, because packs drop from spending. The album is the *reason to buy*, not the thing bought.

---

## PART II — ARCHITECTURE

### 13. Locked design constraints

| Constraint | Value | Consequence |
|---|---|---|
| Theme | Abstract slots | Maps onto any theme at the end |
| Meta depth | Lean | Meta exists to unlock generators and set a forever goal. Retention burden falls on live-ops. |
| Session profile | 6–10/day, 2–4 min | Low cap, fast regen, board re-enterable in seconds, many wall events per day |
| Binding scarcity | Energy | Board space is generous in the mature game — but see §15 for the early game |
| Revenue | IAP-led | Rewarded video is a retention instrument, ~5–10% of revenue |
| Monetization posture | Mirror the leader | No monetization surface in session one |

**Notation:** `ENERGY`, `GEM` (hard), `COIN` (soft), `PART` (meta gate — note **[M]** reference games use *three* distinct part types, not one), `STAR` (duplicate conversion), `XP` (levels, decoupled from currency), `TOKEN.<event>`.

### 14. Core loop

```
Spend ENERGY at generator → item spawns (tier 1)
    → merge pairs upward
    → first discovery? → GEM + collection entry
    → fulfil ORDER → COIN / PART / event riders / items
    → spend on META node → unlocks new generator
    → back to board
```

Three properties this must hold:

1. **The loop closes back onto the board.** A meta reward that doesn't change the board is a dead end.
2. **Never more than one action from a payoff.** With 2–4 minute sessions, a loop taking three sessions to complete once reads as stalled.
3. **No fail state anywhere.**

### 15. Board

**[M] 7 columns × 9 rows = 63 tiles.** Confirmed independently in all three games. Single screen, no scrolling.

**[M] The board opens ~30% unlocked and expands with level.** This corrects the earlier assumption that space is never a constraint. "Board Full" fires during the tutorial in the segment leader.

The reasoning is good: twenty open tiles is legible to a new player, sixty-three is noise. Every unlocked row is a felt reward costing nothing to produce, and **[M]** the locked area is pre-seeded with visible energy caches (10/20/30/50/100) the player can see but not yet reach — an owed reward in plain sight.

"Space is never the binding constraint" applies to the **mature** game, not the first hour.

**Inventory:** uncapped off-board storage. Capping it reintroduces space as a binding constraint through the back door.

### 16. Generators

**[M] A base generator spawns tier 1 on every tap.** 32 consecutive taps produced 32 tier-1 items. There is no probabilistic tier ladder. Energy per tier-1 equivalent is exactly **1.00**.

**[M]** Some generators are multi-tap (several taps per item) — effectively tier-1 generators at a higher energy price.

**[M] Recharge cooldowns span an order of magnitude** — 2m44s to 30m in one session. This is a deliberate class system: fast common generators, slow premium ones. The 30-minute generators serve the return-visit role.

**[M] Recharge is directly purchasable** — an inline gem button on the generator itself, priced to the specific wait. Highest-frequency, lowest-friction gem sink in the game, and it only exists because the cooldown exists.

**Progression comes from unlocking new chains with their own generators**, not from existing generators spawning higher tiers. Roughly one new generator every two player levels **[M]**.

### 17. Power Boost — and why neutrality is the design

**[M] Exactly energy-neutral at every level:**

| Boost | Energy/tap | Item produced | Spawns' worth | Energy per equivalent |
|---|---|---|---|---|
| ×1 | 1 | tier 1 | 1 | 1.00 |
| ×2 | 2 | tier 2 | 2 | 1.00 |
| ×4 | 4 | tier 3 | 4 | 1.00 |
| ×8 | 8 | tier 4 | 8 | 1.00 |
| ×16 | 16 | tier 5 | 16 | 1.00 |

**Neutrality is what makes it safe to give away.** Priced below neutral, a payer converts money into meta progress at a discount and the forever goal collapses. Priced above neutral, it is a tax informed players refuse. Neutral is unarbitrageable in both directions.

What it actually sells: **taps and board tiles.** Sixteen energy buys a tier-5 item either way; the boost delivers it in one action on one tile instead of sixteen actions on sixteen tiles.

**The ceiling matters more than the neutrality.** Maximum boost tops out at tier 5. A tier-12 item still costs 2,048 energy — 128 taps *even at full boost*. Boost compresses the bottom five tiers and leaves the top of the chain exactly as expensive. It solves tedium, not cost, which is why it can never be the endgame answer — and why §19 must exist.

The "removed the spending ceiling" claim is about **tapping throughput**, not efficiency. A whale holding 20,000 energy cannot tap 20,000 times; at ×16 they need 1,250.

### 18. Merge chains

**[M] Chains run 8 to 14 tiers.** Longest observed: 14.

Strictly pairwise, same-chain, same-tier. Cost to build tier *n* from scratch = 2ⁿ⁻¹ base spawns.

**[M] The chain viewer and the discovery collection are the same UI** — a grid showing discovered tiers, `?` for undiscovered, and a "Generated by:" footer. One screen doing the work of a progress map, a crafting reference and a completion drive. Surface the tier number in the item name; it converts an opaque exponential into a legible ladder.

**[M]** Mid-tier items are purchasable with hard currency directly from the chain viewer (14 gems observed, with a "see in store" affordance).

### 19. Recirculation — the term that makes the exponential survivable

A tier-12 item is 2,048 energy, more than a level-102 player's entire bar. Endgame players demonstrably do not build top-tier items from tier-1 taps.

**The exponential is absorbed by recirculation:**

- Standing board inventory (a deep-game board holds dozens of mid-tier items)
- **Items paid as order rewards** — orders return items, not only currency
- Chest contents
- Event payouts
- Items bought outright with hard currency

Back-solved from the constraint that the game is demonstrably playable at L46 and L102, recirculation runs **0% early to ~97% at endgame** **[F]**.

**The design consequence is the important part: the late game is not an energy game. It is an inventory-and-events game.** Energy binds for roughly the first forty levels; after that the binding constraint is item flow from rewards. This is why a lean-meta merge game without live-ops dies in the mid-game rather than at launch.

### 20. Orders

**Four concurrent slots** with an invariant difficulty spread:

| Slot | Difficulty | Target | Pays |
|---|---|---|---|
| 1 | Easy | Within one session | `COIN` |
| 2–3 | Medium | 2–3 sessions | `COIN` |
| 4 | Hard | 1–2 days | `PART` |

**[M]** The segment leader opens with **2 slots**, expanding to 4 by level 4.

When a slot clears, a new order of the *same difficulty class* replaces it. The distribution never varies. Always one thing finishable now, always one long-horizon goal.

**Reward riders — the most important interface in the codebase.**

**[M]** A single Tasty Travels order at L102 carried four reward types simultaneously — base coins plus two event currencies plus an item — changing every few days as events rotated.

```
Order.rewards = [ {type, amount}, … ]   // a list, never fixed fields
```

Nearly every live-ops feature attaches here. Fixed fields mean every future event requires touching order logic.

**Separate the two roles.** Long-lived orders carry the persistent goal; short timed-order *events* carry urgency. Merging both into one short auto-replacing slot means the persistent goal never persists and the urgent thing is never urgent.

### 21. Currency graph

```
regen ──► ENERGY ──► generator taps ──► items ──► ORDERS ──► COIN + PART ──► META
ads ────►    ▲                                        │
gifts ──►    │                                        └──► items (recirculation)
board ──►    │
IAP ────► GEM ──┴──► energy · board items · store refresh · bubble pop · cooldown skip
```

**The rule that holds the economy together: `GEM` must never purchase `COIN` or `PART` directly.** The only sanctioned path from money to meta progress is `GEM → ENERGY → orders → COIN/PART`, rate-limited by order availability and generator cooldowns. Break it and a whale buys the entire meta in a week.

**[M] Three distinct part types**, not one. Each gates a subset of meta steps, giving independent pacing dials per building.

**[M] Currency spawns on the board as merge chains.** `Coin (Lvl 1)` collects 1; `Coin (Lvl 3)` collects 7; energy items likewise. Present in all three games. This makes the board a faucet as well as a sink, provides uncapped storage, and creates a genuine decision — merge up for a better rate, or collect now for liquidity.

**[M] XP is a separate currency** driving levels, decoupled from coins. Lets you retune currency flow without disturbing the level curve.

### 22. Energy

| Parameter | Value | Source |
|---|---|---|
| Regen interval | **1 per 2:00** | **[M]** confirmed in two titles, stated in-game |
| Cap, L1–3 | **100** | **[M]** |
| Cap, L46 | **still 100** | **[M]** — caps barely scale |
| Cap, L102 (different title) | ~1,600 | **[M]** |
| Cost per tap | **1** | **[M]** all three |
| Over-cap | Rewards bank above cap; regen pauses | **[M]** |

**Passive regen is a minor faucet in the mature game.** With a cap near 100 and a 2-minute tick, regen contributes a few hundred energy a day, while a single L46 order pays 15,000 coins with energy riders, chests and event payouts attached. **Supply is dominated by rewards.**

The cap's job is narrow: stop idle stockpiling in the meter and force the player to open the app. It is not the supply constraint — and board-held energy bypasses it entirely.

### 23. Sinks

| Sink | Currency | Note |
|---|---|---|
| Generator taps | `ENERGY` | Primary |
| Meta upgrades | `COIN` + 3 × `PART` | **[M]** ~290,000 coins per endgame task, tuned to drain the player almost exactly |
| Energy purchase | `GEM` | Daily escalating ladder — §24 |
| Cooldown skip | `GEM` | Inline on the generator |
| Bubble pop | `GEM` | **[M]** 32 gems, mid-tier |
| Store items | `GEM` | **[M]** 9 / 18 / 70 gems, stock-limited |
| Store refresh | `GEM` | **[M]** 10 gems — priced below the cheapest item, deliberately |
| Splitter / wildcard | `GEM` | **[M]** 50 / 150 gems |
| Album cards | `ENERGY` | **[M]** 25 / 35 / 50 by rarity — high-rarity only |

**Bubble:** on merge, with probability *p*, the output is encased. Opened by rewarded video (capped ~3/day) or gems, and **decays into a lesser reward** if left. Converts a moment of success into a decision at the instant the player feels good. It must decay into *something* — punishing non-payment breaks §1.

### 24. The wall — the designed moment

**[M] The complete relief ladder, in the order a blocked player meets it:**

| Step | Energy | Cost | Gems/energy |
|---|---|---|---|
| Rewarded video ×3 | 25 each | free | — |
| Energy Pack #1 | 100 | 10 gems | 0.100 |
| Energy Pack #2 | 100 | 20 gems | 0.200 |
| Energy Chest #1 | ~120 | 24 gems | 0.200 |
| Energy Pack #3+ | 100 | 40 gems | 0.400 |
| Energy Chest #2+ | ~120 | 48 gems | 0.400 |

Free per day: **75 energy**. Free-plus-discounted before the rate goes flat: **395 energy**. Resets daily.

**This is where the ad lives.** Not in a menu, not on the energy button — inside the out-of-energy dialog, side by side with the gem purchase, as the free alternative.

**Two calibration rules, both derived from observation:**

1. **Ad reward = 25% of the volume in the cheapest paid pack** (25 energy vs 100-for-10-gems)
2. **Daily ad allowance < one full energy bar** (75 vs 100)

At L46 an order costs ~137 energy, so one ad buys ~18% of a single order. It softens the wall without advancing the player.

### 25. Offer architecture

| Trigger | Fires | Posture |
|---|---|---|
| First purchase | Once, at the **first genuine wall** (~day 2–3) | Deliberately over-generous |
| Contextual | At the wall | The daily ladder above |
| Rotating daily | Once per 24h | Above average purchase; contains otherwise-unobtainable items |
| Event-registered | Event start / milestone | Event-scoped |
| Progression | Level or node milestone | Sized to the wall just hit |

**[M]** The out-of-energy bundle ($7.99 for 850 energy + 150 gems + a card pack) sits at ~157 energy per dollar — the flat tier. It is not a discount; it is a convenience purchase that also carries gems and a pack.

**Player state to record from first launch** (cannot be backfilled): rolling average purchase value, purchase count, days since last purchase, current wall.

### 26. Live-ops framework

Given a lean meta, **live-ops is the retention strategy.** Build primitives, express events as configuration.

**Eight primitives:** scheduler (with overlap/priority resolution — a real problem at six concurrent events) · token wallet · progress track (parallel free/paid lanes) · reward table · rider injection · parallel board instance · timer service · offer hook.

**Event catalogue observed [M]:**

| Horizon | Types |
|---|---|
| Minutes | Timed order, reward-box window, generator surge |
| Daily | Daily challenge (staggered, activity-scaled), spend-quota quests |
| 3–4 days | Milestone track, **parallel board** (own board, chains, energy, offers — highest revenue, most expensive), vanity/decoration track |
| Weeks | Pass (free + paid), purchase-progress promotion, card album (33 days) |
| Competitive | Duels (1v1 banded), tournaments, multi-player races |

**[M]** Live-ops does not phase in gradually — four concurrent events land together at level 5 in the segment leader.

**Note the spend quota:** "Spend 50 Gems" appears as a daily-challenge task. It converts the retention system into a monetization one at zero UI cost, and it is the most aggressive item in the daily layer. Worth a deliberate decision.

### 27. Collections

**A. First-discovery** — every item, first time created, awards `GEM` and fills a grid slot. Completion drive baked into the core loop at near-zero economy cost. Merge this UI with the chain viewer (§18).

**B. Card albums [M]** — 135–162 cards across 15–18 sets of 9, running 22–33 days. Rarity 1★–5★. Duplicates → `STAR` → Star Shop. Packs drop from gameplay *and from any purchase above a threshold*. Set rewards ramp 100 → 500 energy; album completion pays 800 energy + 250 gems + wildcard + avatar.

**Net: the album returns more energy than it consumes.** It is a retention faucet, not a sink (§12).

### 28. FTUE

**[M]** Measured minute-by-minute from cold install:

| Time | Event |
|---|---|
| 0:50 | Cinematic — story **before** any gameplay |
| 1:45 | First board, guided first tap |
| 2:10 | First order completed |
| 5:00 | Meta screen, first customisation choice |
| 7:00 | Level 2 — first hard currency granted |
| 13:00 | Store first reachable |
| 17:00 | Order slots expand; first event currency |
| 20:00 | Day rollover |

**Hard rules:**
- Energy effectively unlimited for the first ~10 minutes — the player must reach the loop-closing payoff before meeting the wall
- Order slots unlock one at a time
- **No monetization surface at all in session one**
- Nothing may be lost, expire or fail
- **One new system per session** thereafter — twelve systems over twenty minutes, strictly sequential

### 29. Other mechanics worth having

- **Sell** — any item, tier-scaled. Universal pressure valve; nothing is ever dead weight.
- **Chores** — named tasks costing soft currency and paying XP. A second use for coins, parallel to orders.
- **Merge-able chests** — a reward container that is also a chain item. Open now for a small payout or merge two for a bigger one.
- **Timed free chests** — free with a wait. A soft speed-up sink with no purchase pressure.
- **Cosmetic choice** — colour/theme selection with no currency cost. An ownership device, not a sink.
- **Piggy bank** — passive accumulator, paid to crack.
- **Loyalty layer** — out-of-app daily claim, gated by level. Retention outside the app, first-party data, no store fee.

---

## PART III — BUILD ORDER

```
1  Board · item registry (data-driven) · merge resolution · inventory
2  Generators · cooldowns · ENERGY cap/regen/overflow
3  Order slots (2→4) · REWARD RIDER LIST ◄── build as a list from day one
   COIN · PART ×3 · XP · meta tree · node → generator unlock
4  Recirculation: items as order rewards, chest items, purchasable board items
5  GEM + all sinks · store · bubble · Power Boost (neutral) · first-discovery collection
6  Player-state tracking ◄── start collecting immediately, cannot be backfilled
   The wall: ad → escalating ladder → bundle · notifications · FTUE
7  Live-ops primitives (all eight) · ship one timed-order event
──────── CONCEPT COMPLETE ────────
8+ Daily challenge · milestone track · parallel board · pass · album ·
   vanity track · splitter/wildcard · Star Shop · social · competitive
```

**Three things expensive to retrofit:** reward riders as a list; chains and generators as data, not code; player-state history from first launch.

---

## APPENDIX — Measured reference values

| Value | Measured | Source |
|---|---|---|
| Energy regen | 1 per 2:00 | 2 titles, stated in-game |
| Energy cap L1–3 / L46 / L102 | 100 / 100 / ~1,600 | 3 titles |
| Energy per tap | 1 | 3 titles |
| Spawn distribution | 100% tier 1 (32/32) | Controlled count |
| Power Boost | ×N → N energy → tier for N spawns | Confirmed by user |
| Bonus spawns | ×1: 0 events / ×4: 12–15 | Controlled A/B, 33s each |
| Board | 7 × 9 = 63 | 3 titles |
| Board unlocked at start | ~30% | FTUE |
| Order slots | 2 early → 4 by L4 | FTUE |
| Order payouts | 2–36 coins (L1–4) → 14,500–46,000 (L102) | 2 titles |
| Chain depth | 8–14 tiers | 2 titles |
| Generator recharge | 2m44s – 30m | 1 title |
| Gem ladder | 80/$1.99 → 8,000/$99.99, exactly 2.0× | Store |
| Energy ladder | 3 ads @25 → 10 → 20 → 40 gems/100, daily reset | Wall capture |
| Ad reward | 25 energy, 3/day, at the wall | Wall capture |
| Bubble pop | 32 gems | Screenshot |
| Store refresh | 10 gems | Screenshot |
| Album | 135 cards / 15 sets; sets ramp 100→500 energy | 6 of 15 sets |
| Card prices | 25 / 35 / 50 energy by rarity | Album |
| Building | 7 levels × 3–4 steps, coins + 3 part types | 2 titles |
| Endgame meta cost | ~290,000 coins per task | 1 title |
| Concurrent events | 4 at L5 → 6+ at L102 | 2 titles |

---

*Companion to `Phase2_Economy_Model.xlsx` (quantitative model), `Findings_26July.md` (measurement detail and corrections log), and `PawSanctuary_Gap_Analysis.md` (application).*
