# PawSanctuary — Gameplay Psychology Gap Analysis

**Compared against:** Gossip Harbor, Travel Town, Tasty Travels (measured July 2026)
**Basis:** GDD v3.0, TODO.md, and direct read of the codebase — KibbleEngine, AdoptionBoard, EventSystem, AdProvider, StoreManager, SubObjectSystem, ItemChain, and the spawn/merge core of MergeBoardViewModel.

This is not a feature-parity audit. It looks specifically at the mechanisms that make players come back and spend, and asks which of them are absent, weak, or built in a way that will fight you later.

---

## Headline

**You have built more game than any of the three reference titles have in several areas, and the fundamentals are closer to the measured data than I expected.** Board geometry, regen rate, cap behaviour, ad reward size and the four-currency structure are all within a rounding error of the published games — some of them exactly right.

The gaps are not missing *features*. They are missing **pressure**. PawSanctuary is generous, warm and well-engineered, and it currently has no moment where the player wants something they cannot have. Every retention mechanic in the three reference games is built around that moment.

There is also one outright economy break (§B) that needs fixing regardless of any design philosophy.

---

## A. What's already right — do not touch

| System | PawSanctuary | Measured reference | Verdict |
|---|---|---|---|
| Board | 9 × 7 = 63, level-gated rows | 7 × 9 = 63 in all three | **Exact match** |
| Energy regen | 1 per 120 s | 1 per 120 s | **Exact match** |
| Energy cap | 100 → 150 at L10 | ~100, barely scales | **Match** |
| Cap behaviour | Regen clamps to cap; ads/exchange exceed it | Identical — rewards bank above cap | **Match** |
| Ad reward | +25, 4/day, 09:00 UTC reset | +25, 3/day | **Match**, marginally more generous |
| Currencies | Kibble / Dog Tags / Coins / Stars | Energy / gems / coins / stars | **Match** |
| Cards | 54 across 6 albums, dupes → Stars → Star Shop, jokers, trading | Same structure, larger | **Match**, and trading is more developed |
| Sub-objects + pity timers | 20% drop, 4 rarities, 30/60 pity | Variable-ratio layer | **Match in spirit** |
| Meta progression | 15 areas × 4 upgrade tiers, 12 bonus fields | Building → level → task | **Deeper than reference** |
| Daily/weekly layer | Login streak, 3 dailies, quests, spotlight, weekly/monthly goals, Loyalty Club | Comparable | **Match** |
| Superpowers | 15 unique, passive + active | **Nothing equivalent exists** | **Genuine differentiator** |
| Content depth | 225 named tiers, 15 sub-chains | Comparable | **Match** |

Two things deserve specific credit. **Superpowers solve a problem the reference games have and don't address** — they reward developing every family rather than specialising, which is a real answer to late-game breadth. And the **limitless material accumulator** is the correct call; individual material items on a 63-cell board would have been a clutter disaster.

---

## B. The economy break — fix this first, independent of everything else

**`spawnTier = min(spawnMultiplier - 1, maxTier)` at `cost = spawnMultiplier`.**

| Multiplier | Kibble cost | Tier index produced | Base-spawn equivalent | Effective rate |
|---|---|---|---|---|
| ×1 | 1 | 0 | 1 | 1.0× — neutral |
| ×2 | 2 | 1 | 2 | 1.0× — neutral |
| ×4 | 4 | 3 | 8 | **2.0× better** |
| ×8 | 8 | 7 | **128** | **16.0× better** |

At ×8 a player converts 8 kibble into an item that costs 128 kibble to build by merging. That unlocks at level 20 and never goes away.

**The measured reference behaviour is exactly neutral at every multiplier level** — ×16 costs 16 energy and yields a tier-5 item, which is precisely what 16 base taps would produce. That neutrality is the whole reason the mechanic is safe to give away: it can't be arbitraged in either direction. It sells taps and board space, never progress.

Your version sells progress at a 16× discount. Three consequences:

1. **Levels 1–19 and 20+ are different games.** Everything before the ×8 unlock is priced 16× higher than everything after.
2. **The merge chain above tier 7 becomes the only real content.** Tiers 0–6 are purchasable outright.
3. **You cannot tune the economy while this is in place** — any curve you set is invalidated at level 20.

I suspect this wasn't an accident. The 15-tier chain is brutal on paper (tier 14 = 2¹⁴ = 16,384 base spawns), and the multiplier is doing the work of making late tiers reachable. **That's the right problem, solved in the wrong place** — see §C-6.

---

## C. The psychology gaps, ranked by retention impact

### C-1. There is no wall — and the wall is the mechanic

**Your GDD states as a monetization principle: "no hard energy walls."**

This is the single most consequential divergence, and it's a philosophical choice rather than an oversight, so it deserves a straight argument rather than a bug report.

Every retention mechanism in all three reference games is built on one insight: **energy depletion is an interruption, not a failure.** A failed match-3 level closes the loop and gives the player permission to stop. Running out of energy leaves the order half-finished, the event timer running, and the board exactly as it was. That open loop is what brings people back six to ten times a day.

Right now `.noKibble` fires a toast and opens `KibbleRefillSheet`. The plumbing exists. What's missing is the *design* of that moment. In the reference games, hitting zero is the highest-value event in the session:

- The rewarded ad is offered **there**, not from a menu — this is why my first search for ads found nothing
- The escalating gem ladder is offered there
- The bundle offer is offered there
- The session ends with something visibly unfinished

**"No hard walls" and "the wall is the retention mechanic" are not reconcilable.** You can be generous *about how much energy you give* — the reference games are, roughly 400 free-or-cheap energy per day — while still making the moment of running out matter. Generosity is a dial on supply. The wall is a structural feature.

### C-2. Live-ops is effectively absent

`EventSystem` is complete infrastructure with **one defined event, expired since June 15**. There is currently nothing time-boxed in the game.

The reference games run **four to six concurrent events**, at horizons from four minutes to twenty-nine days, permanently. That lattice is the retention engine — no session ever ends with nothing pending. Gossip Harbor stands up four simultaneously the moment the player hits level 5.

What exists in `EventDefinition`: an ID, dates, and coin milestones. What's missing: token wallets, parallel-board instances, progress tracks with free/paid lanes, reward tables, timed orders, purchase-progress promotions. These are the eight primitives from the blueprint, and the current `EventDefinition` implements roughly one of them.

**This is the largest single gap by retention impact.** Everything else on this list is a refinement; this is a missing organ.

### C-3. Order rewards are fixed fields, not riders

```swift
rewardDogTags: Int
rewardCoins: Int
rewardCardPack: CardPackType?
```

The blueprint flagged this as the most important interface in the codebase, and the reference data confirmed it hard: a single Tasty Travels order at L102 carried **four different reward types simultaneously**, changing every few days as events rotated.

Because these are fixed fields, every future live-ops feature that wants to attach to order completion requires a code change to `AdoptionBoard` and `AdoptionOrder`. That's the tax that makes running six concurrent events impossible.

Should be a list:

```swift
struct OrderReward { let kind: RewardKind; let amount: Int }
var rewards: [OrderReward]
```

with active systems injecting into it. This is a small refactor now and a large one after five events exist.

### C-4. No bonus layer on boosted spawns

Measured, and it inverted my expectations: **bonus spawns ("Lucky!", "Legendary!") fire only on boosted taps.** Zero events in 33 seconds at ×1; twelve to fifteen in 35 seconds at ×4.

The mechanism is subtle and worth stating plainly: gating bonuses behind the multiplier pushes players to burn energy in larger chunks, and larger chunks reach zero faster. **The bonus layer is an accelerant on the out-of-energy moment, dressed as a reward.** The player experiences generosity while their session shortens.

PawSanctuary has a variable-ratio layer — the 20% sub-object drop with pity timers — but it's flat across multipliers and unconnected to the spend rate. It rewards *playing*, not *spending faster*.

### C-5. Currency doesn't spawn on the board

All three reference games spawn **energy and coins as merge chains on the board**. `Coin (Lvl 1)` collects 1; `Coin (Lvl 3)` collects 7. `ChainCategory` in PawSanctuary has `animal, spawner, supply, tool, material, subObject, powerUp` — no currency case.

Three things this does that nothing else does:

- **Uncapped energy storage.** Energy held as board items ignores the meter cap entirely. This is why reference players comfortably sit at 3–5× their cap. Your cap is a real ceiling on banked energy; theirs isn't.
- **Visible owed reward.** A returning player sees energy sitting on the board waiting. Gossip Harbor pre-seeds the *locked* portion of the board with ~210 energy the player can see but not yet reach.
- **A strategic decision using a mechanic they already know** — merge coins up for a better rate, or collect now for liquidity. Cheap depth.

### C-6. No recirculation path

A tier-14 item is 2¹⁴ = 16,384 base spawns. Endgame reference players demonstrably don't build top-tier items from tier-1 taps — a tier-12 item costs more energy than a level-102 player's entire bar. The exponential gets absorbed by **recirculation**: standing board inventory, items paid as order rewards, chest contents, event payouts, and items bought outright.

By my model, endgame recirculation runs ~97%. Only about 3% of what an order needs comes from fresh taps.

PawSanctuary has almost none of these. Orders pay currency and card packs, never *items*. There are no chests containing board items. The shop sells producers, not items. **The spawn multiplier is currently doing all the recirculation work by itself**, which is why it had to be non-neutral — and why fixing §B without adding recirculation would make the game unplayable rather than better.

**These two changes must ship together.**

### C-7. Session profile mismatch

The GDD targets **5–15 minute sessions**. The measured reference profile is **2–4 minutes, 6–10 times a day**.

This isn't a small tuning difference. Session length drives energy cap, regen rate, order pacing, notification cadence, and — critically — **the number of out-of-energy moments per day**, which is the number of offer impressions. A 15-minute session model produces perhaps two wall events a day. A 3-minute model produces six to eight.

At a 100 cap and 1-per-120s regen, your actual mechanics already imply short sessions: 100 kibble at ×1 is 100 taps, which is a few minutes, not fifteen. **The stated design target and the implemented economy already disagree.** The economy is right; the target should move.

### C-8. Order structure: two slots, uniform tier roll

Reference: **four concurrent orders with a deliberate 1 easy / 2 medium / 1 hard spread**, invariant. A player at any tenure always has exactly one thing finishable right now and exactly one long-horizon goal.

PawSanctuary: minimum 2 orders, tier drawn from a flat 10-sided roll across tiers 0–14, capped by level. That produces runs where all active orders are trivial, and runs where all are out of reach. The structured spread exists precisely to prevent both.

### C-9. Auto-replacing 15-minute orders remove stakes

Orders expire silently and regenerate. Nothing is ever lost, so nothing is ever urgent — and a player who returns after two hours finds the board exactly as they left it with no consequence.

The reference structure separates these: **long-lived orders** as the persistent goal (no timer at all, or many hours), plus **separate short timed events** that carry the urgency and real rewards. Merging both roles into one 15-minute auto-replacing slot means the persistent goal never persists and the urgent thing is never urgent.

### C-10. No session-one monetization posture

There is no `hasEverPurchased`, no first-purchase offer trigger, no starter-offer gating.

The measured leader shows **nothing** in session one — no offer, no ad, no store push — across 26 minutes and five levels, then fires the first offer at the first genuine wall around day 2–3. The purchase then protects accumulated progress rather than buying past an obstacle.

PawSanctuary's shop is available immediately with 12 products. Not aggressive, but undesigned: there's no concept of *when* a player becomes monetizable.

### C-11. The energy price ladder runs backwards

`DogTagKibbleExchange`: 40→100, 80→240, 120→480 tags-to-kibble. That's **2.5 / 3.0 / 4.0 kibble per tag — a bulk discount.**

Measured reference: **10 → 20 → 40 gems for the same 100 energy, resetting daily.** An escalating price for an identical good, rationing roughly 320 cheap energy per day before the rate goes flat.

Yours rewards buying in bulk. Theirs caps how much cheap energy anyone can absorb in a day, which protects the pacing curve from being bought outright. Yours is more player-friendly and strictly worse at defending the economy.

### C-12. "Dog Tags/Coins never buy board advantages"

Stated as a principle, and it closes off the **highest-converting purchase path in the reference games**: buying the specific item you're blocked on. Travel Town sells board items at 9/18/70 gems with stock limits, plus a 10-gem store reroll. Gossip Harbor sells them directly from the chain viewer at 14 gems with a "SEE IN STORE" button.

This is a values decision, not an oversight, and I'm not going to argue you out of it. But name the cost: you're forgoing the conversion mechanism that fires at the exact moment of highest intent, and it's also a recirculation channel (§C-6). If you keep the principle, recirculation has to come entirely from order rewards and chests.

---

## D. Alignment checklist

Ordered by dependency, then retention impact. **[CODE]** / **[CONTENT]** / **[DECISION]** tags indicate what each needs from you.

### Tier 1 — Economy integrity (do these together, before any tuning)

- [ ] **1.1 [DECISION]** Decide whether the spawn multiplier should be energy-neutral. Recommended: yes. Neutral means `cost = 2^tierIndex`, i.e. ×1→tier 0 at 1 kibble, ×2→tier 1 at 2, ×4→tier 2 at 4, ×8→tier 3 at 8.
- [ ] **1.2 [CODE]** Implement neutral multiplier pricing. Single change in `activateProducer` — decouple `spawnTier` from `spawnMultiplier - 1`.
- [ ] **1.3 [CODE]** Add recirculation before or with 1.2, or the game becomes unplayable. Minimum viable set:
  - Orders occasionally pay **board items**, not just currency
  - Chests/rewards contain board items
  - Sub-object power-ups include a "spawn tier N item" effect
- [ ] **1.4 [CODE]** Re-tune the 15-tier chain against the neutral economy. Expect to need generator-tier progression (new families spawning at higher base tiers) rather than one universal tier-0 spawner.
- [ ] **1.5 [CODE]** Reverse the Dog Tag → Kibble ladder to escalate within a day and reset daily, rather than discount by volume.

### Tier 2 — The wall (the highest retention return in this list)

- [ ] **2.1 [DECISION]** Resolve "no hard energy walls" against "the wall is the retention mechanic." Recommended framing: keep generosity high on *supply*, make the *moment* of depletion designed.
- [ ] **2.2 [CODE]** Rebuild `KibbleRefillSheet` as the designed wall moment: rewarded ad first (free, capped), then the escalating kibble ladder, then the bundle. This is where the ad belongs — not in a menu.
- [ ] **2.3 [CODE]** Ensure hitting zero leaves something visibly unfinished — surface the nearest incomplete order or event on the refill sheet.
- [ ] **2.4 [CODE]** Add `hasEverPurchased` and first-purchase offer gating. Suppress all monetization surfaces in session one.

### Tier 3 — Live-ops engine (largest structural work, largest retention payoff)

- [ ] **3.1 [CODE]** Extend `EventSystem` from coin-milestones-only to the primitive set: token wallet, progress track (supporting parallel free/paid lanes), reward table, timer service, offer hook.
- [ ] **3.2 [CODE]** Convert `AdoptionOrder` rewards from fixed fields to a `[OrderReward]` list with injection from active systems. **Do this before 3.3** — everything attaches here.
- [ ] **3.3 [CODE]** Add rider injection so active events attach payloads to order completion and merges.
- [ ] **3.4 [CODE]** Build one **parallel-board event** — separate board, own chains, own energy pool. Highest-revenue event type in the genre and the most expensive to build.
- [ ] **3.5 [CODE]** Build a **pass** (free + paid track). Cheap once progress tracks support parallel lanes.
- [ ] **3.6 [CONTENT]** Author enough `EventDefinition` entries for a rolling 90-day calendar. Infrastructure without a calendar is the state you're in now.
- [ ] **3.7 [DECISION]** Commit to a live-ops cadence you can actually sustain solo. A lattice you can't feed is worse than a smaller one you can.

### Tier 4 — Board psychology

- [ ] **4.1 [CODE]** Add a `currency` case to `ChainCategory`; implement kibble and coin merge chains that spawn on the board.
- [ ] **4.2 [CODE]** Pre-seed locked board rows with visible, unreachable kibble caches released on unlock.
- [ ] **4.3 [CODE]** Gate a bonus layer ("Lucky!"/"Legendary!") to boosted spawns only, scaling with multiplier.
- [ ] **4.4 [CODE]** Add a bubble/locked-item mechanic: on merge, with probability *p*, the output is encased — openable by ad (capped), by premium currency, or by waiting. Must decay into a lesser reward, never nothing.

### Tier 5 — Order system

- [ ] **5.1 [CODE]** Move from 2 slots to 4, with a fixed 1 easy / 2 medium / 1 hard difficulty spread replacing the uniform tier roll.
- [ ] **5.2 [CODE]** Split order roles: long-lived persistent orders (no timer or many hours) + a separate short timed-order event carrying the urgency.
- [ ] **5.3 [CODE]** Make at least one slot pay meta-progression materials, so the map economy has a dedicated bottleneck.

### Tier 6 — Alignment and polish

- [ ] **6.1 [DECISION]** Move the stated session target from 5–15 min to 2–4 min × 6–10/day, or explain why the economy should be retuned to match 15 minutes. The implemented economy already assumes short sessions.
- [ ] **6.2 [DECISION]** Revisit "Dog Tags/Coins never buy board advantages" now that its cost is explicit. If kept, over-invest in order-reward and chest recirculation to compensate.
- [ ] **6.3 [CODE]** Real ad SDK — this is now load-bearing rather than optional, because 2.2 puts the ad at the wall.
- [ ] **6.4 [CODE]** Enable Push Notifications capability. The scheduling logic is done and notifications are the mechanism that converts the wall into a return visit.

---

## E. What I'd do first

If you only did three things:

1. **2.2 — rebuild the refill sheet as the designed wall moment.** Smallest code change on this list with the largest retention return, and it makes the existing ad system load-bearing instead of decorative.
2. **3.2 — convert order rewards to a rider list.** Small now, painful later, and it unblocks the entire live-ops tier.
3. **1.2 + 1.3 together — neutral multiplier plus recirculation.** Not optional; the current arbitrage invalidates any economy tuning you attempt.

Everything in Tier 3 is genuinely large. It's also the difference between a complete game and a game people play for two years — and it's the part your competitors invest in most heavily.

---

*Companion to Phase1_Structural_Blueprint.md (superseded in parts — see Findings_26July.md), Phase2_Economy_Model.xlsx, and Findings_26July.md.*
