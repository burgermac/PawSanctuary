# PawSanctuary — Economy State & Variance vs Reference

**Read directly from the codebase, 27 July 2026, after Phases 2 / 2b / 2c** (commits `a36faed`, `f646ae9`, `ff20b88`).
Reference titles: Gossip Harbor, Travel Town, Tasty Travels — measured July 2026.

This document exists because the GDD drifted five times across the economy work. **Where this and the GDD disagree, this is right** — every number below was read from source today.

---

## PART 1 — Where the economy actually stands

### The core identity

```
Kibble cost of a tier-n item  =  2^n        (neutral pricing, Phase 2)
Order pays                    =  6.50 coins per kibble of build cost
Selling pays                  =  2.75 coins per kibble of build cost
```

Everything else derives from those three lines. Both coin channels and the spawn price are all denominated in the same unit — the kibble an item costs to build — which is why the ratios hold at every tier and why a re-sweep of the tier distribution can't invalidate them.

### Energy (Kibble)

| Constant | Value |
|---|---|
| Regen | 1 per **120 s** |
| Cap | **100**, → **150** at player level 10 |
| Starting | 20 |
| Cost per spawn | `2^tier` — ×1→1, ×2→2, ×4→4, ×8→8 |
| Ads | **4/day × 25 kibble**, resets 09:00 UTC |
| Dog Tag → Kibble | **15 / 30 / 60 tags** per 100 kibble, escalating within the day, resets daily |
| Sanctuary Pass | +20/day, ×1.5 on claimed kibble rewards |
| Daily login (7-day) | 5 / 10 / 5 / 15 / 10 / 20 / 15 |
| Loyalty Club (L20+, 7-day) | 25 / 15 / 30 / 20 / 40 / 15 / 50 |

**Measured daily supply: ~695 (cap 100) · ~745 (cap 150) · ~800 with Pass.**

### Chains and the board

| Constant | Value |
|---|---|
| Board | 9 rows × 7 cols = **63 cells**; rows 7–8 locked until levels 3 and 8 |
| Chain depth | **12 tiers** (index 0–11), 15 families, 180 authored names |
| Top-tier cost | **2,048 kibble** |
| Spawn multiplier | 1/2/4/8 → tier 0/1/2/3, priced `2^tier` — **exactly neutral** |
| Sub-object drop | 20% base, +45pp max from area upgrades |
| Sub-object chain | 4 tiers; **only tier 3 is usable**; effect rolled by rarity at that point |
| Power-up table | Speed Burst 60% · Map Supplies 25% · **Board Item Grant 10%** · High-Tier Drop 5% |

### Coins

| Source | Value |
|---|---|
| **Order fulfilment** | `6.5 × 2^tier × count`, ±10% spread |
| **Selling** | `2.75 × 2^tier` — tier 0 → 3 coins, tier 11 → **5,632** |
| Ambassador trio exchange | combined sell value × **1.25** |
| Ambassador merge | 500 |
| All three daily challenges | 400 |
| Quest claims | 50 / 150 / 400 / 1,000 |
| Album completions | 6,250 total across six |
| Weekly goals | Bronze 2,500 · Silver 6,000 · Gold 12,000 |
| **Sink: Sanctuary Map** | **291,900 coins**, 61 entries (80 → 35,000) |

**Projected full map build-out: ~60 days engaged play.**

### Recirculation

| Dial | Value |
|---|---|
| Order board-item reward | 1 order in **3**, at `wantedTier − 3` |
| Board Item Grant (power-up) | `deepest − 2`, **capped at tier 6** |
| Dog Tag store | 3 slots, daily rotation, stock 1, tiers `deepest−4 … deepest−1`, 15 + 18/tier |

### The wall curve — the output that matters

| Band | Max order tier | Demand / supply | Reading |
|---|---|---|---|
| L1–30 | 2 → 6 | 0.09 → 0.56 | Comfortable |
| L31–40 | 9 | 0.83 | Tightening |
| **L41–50** | **10** | **1.02** | **First genuine wall** |
| L51+ | 11 | 1.18 | Persistent, not punitive |

---

## PART 2 — Variance vs the three reference titles

### A. Matched — no action needed

| Dimension | Reference | PawSanctuary |
|---|---|---|
| Board size | 7 × 9 = 63 | 9 × 7 = 63 ✓ |
| Energy regen | 1 per 120 s | 1 per 120 s ✓ |
| Energy cap | ~100, barely scales | 100 → 150 ✓ |
| Cap behaviour | Regen clamps; rewards bank above | Identical ✓ |
| Spawn distribution | 100% base tier | 100% at selected tier ✓ |
| Boost pricing | **Exactly neutral** | **Exactly neutral** ✓ |
| Chain depth | 8–14 tiers | 12 ✓ |
| Ad reward size | 25 energy | 25 ✓ |
| Energy purchase ladder | Escalates daily, resets | 15/30/60 tags, resets ✓ |
| Meta structure | building → level → task, 3 part types | 15 areas × 4 upgrades, 3 materials ✓ |
| Order reward mechanism | Extensible rider list | `[OrderReward]` ✓ |
| Wall placement | First genuine scarcity ~L41–50 | Ratio crosses 1.00 at L41–50 ✓ |

**Thirteen of the economy's load-bearing properties now match measured reference behaviour.** That is the answer to "where do things stand": the economy itself is sound and modelled. What remains is almost entirely *presentation* and *live-ops*, not arithmetic.

### B. Intentionally different — decided, not drifted

| Dimension | Reference | PawSanctuary | Why |
|---|---|---|---|
| Coin channels | Orders only | **Orders + selling**, orders 2.4× better | Decided 27 July. Selling stays useful as instant liquidity; orders stay the efficient path. |
| Superpowers | None | 15, one per family | Genuine differentiator — rewards breadth over specialising |
| Material storage | Board items | Limitless accumulator | Correct call; materials on a 63-cell board would be clutter |
| Board unlocked at start | ~30% | 78% (49/63) | Diverges; see C-1 |
| Max boost | ×16 → tier 5 | ×8 → tier 4 | Shallower, consistent with a 12-tier chain |

### C. Remaining gaps — with the phase that closes each

**C-1 · Board opens too generously — DECIDED 27 July, unlock by merge tier.** Reference opens ~30% unlocked; you open 78% (rows 7–8 locked until levels 3 and 8). Twenty open tiles is legible to a new player, sixty-three is noise, and every unlocked row is a free felt reward.

**Decision:** open at **3 rows / 21 cells / 33%**, and gate the remaining six rows on **reaching a new merge tier** rather than player level. Deeper tiers need more space to stage merges, so a merge-tier trigger delivers the space at the moment the need appears; level-gating pays out on XP accumulation, which correlates only loosely. It also rewards the core action directly rather than a proxy for it.

| Trigger | Rows open | Cells | % |
|---|---|---|---|
| Start | 0–2 | 21 | 33% |
| Reach tier 2 | +3 | 28 | 44% |
| Reach tier 4 | +4 | 35 | 56% |
| Reach tier 6 | +5 | 42 | 67% |
| Reach tier 8 | +6 | 49 | 78% |
| Reach tier 9 | +7 | 56 | 89% |
| Reach tier 10 | +8 | 63 | 100% |

Full board at tier 10; tier 11 stays pure prestige.

**Deadlock risk to design against:** a full board cannot merge, and if merging is the only unlock path the player is stuck. The 18-slot inventory, selling, and the "Board Full" toast all mitigate — but the toast currently only states the problem. It must point at the exit.

**Also seed the locked rows with visible currency caches** (measured in the reference at 10/20/30/50/100 energy). The locked region should read as a reward the player can see and cannot yet reach, not as absence. This couples C-1 to C-3 — the caches *are* currency merge-chain items, so board expansion and currency-on-board are one piece of work.

**Source caveat:** the reference games' unlock *trigger* was inferred, not measured. Progressive unlocking was observed directly; attributing it to player level was an assumption. The seeded caches and the ~30% opening were measured.

*Phase 4.*

**C-2 · No bonus layer on boosted spawns.** Measured: bonus spawns fire **only** on boosted taps (0 events at ×1 vs 12–15 at ×4 in 33s). This is the accelerant that pushes players to burn energy in larger chunks — generosity that shortens sessions. You have a variable-ratio layer (20% sub-object + pity) but it is flat across multipliers. *Phase 4.*

**C-3 · No currency merge chains on the board.** All three references spawn energy and coins as board items — an uncapped energy store, a visible owed reward on return, and a real merge decision. `ChainCategory.currency` exists (Phase 1) with no chains authored. *Phase 4.*

**C-4 · No bubble mechanic.** Probability *p* on merge encases the output; opened by ad, currency, or waiting; decays to a lesser reward. Converts a success into a decision at the moment the player feels good. *Phase 4.*

**C-5 · Order structure.** Reference runs 4 slots with an invariant 1 easy / 2 medium / 1 hard spread — always one thing finishable now, always one out of reach. You run a 2-slot minimum with a probabilistic band table, so runs of all-trivial or all-unreachable orders are possible. *Phase 5.*

**C-6 · Orders are 15-minute auto-replacing.** Reference separates long-lived persistent orders (the goal) from short timed events (the urgency). Merging both roles means the persistent goal never persists and the urgent thing is never urgent. *Phase 5.*

**C-7 · The wall is undesigned.** `.noKibble` fires a toast and opens a sheet. Reference makes depletion the highest-value moment in the session: ad offered *there*, escalating ladder, bundle, and something visibly unfinished on screen. Your ad is menu-driven, which is why it is currently invisible. *Phase 3.*

**C-8 · No session-one monetization posture.** Reference shows nothing across 26 minutes and five levels. Your shop is available immediately. *Phase 3 — D7 already decided.*

**C-9 · Live-ops is absent.** One expired event. Reference runs 4–6 concurrent at horizons from four minutes to twenty-nine days — the lattice that means no session ends with nothing pending. **Largest remaining gap by retention impact.** *Phase 6.*

**C-10 · `RescueStage` caps quest goals at tier 8 of 11.** Legacy 9-stage enum still driving `QuestCoordinator` at 17 sites, so the top three stages can never be a quest objective. Improved by the 15→12 reduction, not fixed. *Phase 5.*

---

## PART 3 — Honest assessment

**The economy is no longer the uncertain part.** Three phases of modelling replaced guesswork with a derived system: one identity (`2^tier`), two rates (6.5 and 2.75), and a simulation that fails the build if the curve drifts. Thirteen properties match measured reference behaviour, and the four defects found along the way — the 16× multiplier arbitrage, the self-funding kibble faucet, the silent migration corruption, and the trio-exchange trap that destroyed 16,850 coins per use — are all closed.

**What remains is presentation and live-ops.** Every C-item above is about *when the player is shown something* or *what is happening this week* — not about whether the numbers are right. That is a materially different kind of risk than what you had a week ago, and a much more tractable one.

**The one thing I would not defer:** C-7 and C-9 together. The wall is where the economy becomes visible to the player, and live-ops is what gives the wall something to be urgent about. A correctly-tuned economy with no wall and no events is a game that is fair and quiet — and quiet is the failure mode this genre punishes hardest.
