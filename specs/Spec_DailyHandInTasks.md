# Spec — Daily Hand-In Tasks

Written 4 Sep 2026. Supersedes the counted-event daily challenge entirely.

## 0. The deviation this closes

Observed against the three reference titles: their daily task cards name **a
specific item at a specific merge stage**, show **that item's own art**, are
satisfied by **holding the item on the board**, and are closed by a **button the
player presses**, which **consumes the pieces** in exchange for the payout.

PawSanctuary's daily challenges do none of that. They are counted-event goals —
"Complete 6 merges", "Get 3 animals to Ambassador (Tier 9)" — rendered with
`QuestGoal.icon`, which resolves to a generic stage badge (`crown.fill`,
`heart.fill`) or a bare verb glyph (`shuffle`, `house.fill`). Nothing on the card
identifies *which* animal, nothing on the board tells you where the relevant
pieces are, there is no button (they self-complete), and nothing is surrendered.

Confirmed on device 4 Sep 2026: the board renders real illustrated art
(`MergeChain.artImage(forTier:)`, 328 delivered imagesets) while every task and
order card still renders SF Symbols. `artImage` has exactly four call sites —
`CellView`, `ShopView`, `InventoryScreen`, and one tier-progression list. No card
surface calls it.

## 1. Decisions taken (4 Sep 2026)

**D-A. Replace, don't add.** The three `DailyChallenge` slots stop being counted
goals and become hand-in baskets. The daily reset, the streak, and the
all-three-complete bonus survive unchanged. No second daily system is
introduced — the top band has no vertical slack for one (see D-D).

**D-B. One highlight colour.** Every board cell holding an animal that an
unclaimed daily task still wants goes **muted blue**; when a task is fully
stocked, every cell serving that task goes **bright blue**. Per-task colours were
considered and rejected as noise at a 50pt cell.

> **Retuned 4 Sep 2026, after looking at it on device (§9).** The first pass
> shipped `.wanted` at a 0.22-opacity fill with **no ring at all**, and drew a
> ring only for `.stocked`. On screen that is very nearly an ordinary empty
> cell, and the gold spotlight ring — which lands on the same cells often, since
> the spotlight chain is also a chain tasks draw from — visually won. The
> highlight existed and did no work. Both states now carry a real fill *and* a
> real ring.

**D-F. A claimed task leaves the lane.** Added 4 Sep 2026. A claimed task's
creatures are gone and its coins are paid; the card can only say "Handed in", and
keeping it in the horizontal band pushes the orders — the cards that still want
something — further off screen for the rest of the day. The lane renders
`MergeBoardViewModel.unclaimedDailyTasks`. The day's full set stays in the sheet,
and the tray tile still shows the N/3 count, so nothing is lost.

**D-C. The near-miss stagger is dropped for dailies.** This contradicts a
recorded decision — `Gap_Analysis_Round2.md` 3.1 / `Merge2_Reference_Blueprint.md`
§5, which had all three dailies share one anchor goal so finishing one leaves the
next 60–90% done. Three baskets of freely-mixed animals at mixed tiers cannot
share an anchor. Flagged explicitly and overridden on 4 Sep 2026: the reference
titles' own daily tasks do not stagger either, and the stagger still operates on
standing quests and the fixed order-slot difficulty spread. **If dailies ever
need the stagger back, nesting the baskets (task 2 ⊃ task 1) is the way — but
note that claiming task 1 then eats task 2's pieces, so claim order would start
to matter.**

**D-D. The cards ride the existing horizontal band.** They lead the same
`ScrollView` the order lane already owns, ahead of the orders, at
`trayBandHeight`. `Spec_TaskTrayRedesign_Draft.md` §2 measures the board sitting
exactly at its `csW`/`csH` crossover — there is no vertical room for a new row,
and taking any would cost every board cell. Sharing the band costs nothing.

**D-E. Progress is derived, never stored.** A task's fulfilment is computed from
a live board census each render, not accumulated by `update*AfterMerge` hooks.
This is what makes the highlight and the Claim button *correct by construction*
when pieces are merged away, sold, moved to inventory, or consumed by another
task — a stored counter would drift on every one of those.

## 2. Model

```swift
struct DailyTaskLine: Codable, Equatable, Hashable {
    var chainID: ChainID
    var tier: Int
    var count: Int
}

struct DailyChallenge: Identifiable, Codable {
    var id = UUID()
    var lines: [DailyTaskLine]
    var difficulty: QuestDifficulty
    var coinReward: Int
    var isClaimed: Bool = false
}
```

`DailyTaskLine` is deliberately **not** `OrderLine`. `OrderLine.fulfilled` is a
credit-on-merge counter, and daily tasks are credit-on-possession — carrying a
field whose semantics are the opposite of this system's is how two systems drift
into each other.

`progress`/`goal` are gone from `DailyChallenge`. Held counts come from
`MergeBoardViewModel.boardTaskCensus`.

## 3. Census and eligibility

`boardTaskCensus: [ChainTierKey: Int]` counts items in **unlocked board cells
only**. Excluded:

- **Inventory.** The player must hold the creature *on the board* — that is the
  board-space pressure the mechanic exists to create. (`mergeReadyKeys` counts
  inventory because "can I merge this next" genuinely spans both; hand-in does
  not.)
- **Bubbled items** (`BoardItem.bubbledAt != nil`). A bubbled creature is not
  yet the player's to give.

`held(_ line:) = min(census[key] ?? 0, line.count)`.
`isStocked(task) = task.lines.allSatisfy { held($0) >= $0.count }`.

## 4. Generation

Pool: `progression.unlockedAnimalChainIDs` — the animal families the player has
actually unlocked, which is exactly the set their family spawners produce. Same
pool adoption orders draw from.

Per-slot difficulty is fixed easy/medium/hard (mirroring
`orderSlotDifficultyPattern`'s intent — a day can never roll three easy tasks).
Line counts and tiers reuse the order tables so the two demand channels cannot
drift apart in the economy model:

| Daily slot | `OrderDifficulty` band | Lines | Tier band |
|---|---|---|---|
| easy | `.easy` | 1 | 0–1 |
| medium | `.medium` | 1–2 | 2–3 |
| hard | `.hard` | 2–3 | mostly 4–5, tail to 11 |

Every tier is capped by `maxAchievableOrderTier(forPlayerLevel:)`, so an early
player is never asked for a stage they cannot reach. Additional lines draw from
`basketFillerDifficulty`, one band easier — the same reason baskets do it: the
cost of a basket should be board space and attention, not a tripled kibble bill.

Lines are deduplicated by `(chainID, tier)` and merged into one line with a
higher `count`, so a task never lists the same creature twice.

## 5. Reward

**As shipped (post-sweep, §5a):**

```
coinReward = max(dailyTaskCoinFloor, buildCost × coinsPerKibbleOfOrder
                                                × dailyTaskCoinMultiplier)
             × spread          // ±orderCoinSpread, as orders use
```

with `dailyTaskCoinFloor = 150` and `dailyTaskCoinMultiplier = 0.75`.

**As first written**, this section specified pure proportionality
(`orderCoinPayout(lines:) × dailyTaskCoinMultiplier`) at a multiplier of 1.0 —
one dial, deliberately not a hand-authored table. Both halves of that turned out
to be wrong, for reasons §5a records: 1.0 was over budget, and pure
proportionality is what made the easy card pay 10 coins at level 60. The floor is
the hand-authored piece this section wanted to avoid, and it earns its place.

The original reasoning, which still holds:

- It beats selling outright by 2.36× (`coinsPerKibbleOfOrder` 6.5 vs
  `coinsPerKibbleOfSale` 2.75), so handing in is never a trap — the same test
  `orderSellValue` exists to enforce for orders.
- Unlike every other coin faucet in the game, this one **consumes built board
  value** rather than adding to it — the opposite of the failure mode
  `Spec_OrdersAndTasks_Draft.md` §2a records for Smile Points, a board-item
  faucet that erased the Phase 3 wall. **Corrected by §5a:** this section
  originally claimed it "raises the demand/supply ratio," which is wrong. The
  ratio is a *flow* (kibble per day asked for ÷ kibble per day earned) and a
  hand-in drains a *stock*. It cannot move that ratio at all, in either
  direction, and the model has no term for it.
- **Swept 4 Sep 2026 — see §5a. The multiplier moved off 1.0, and not upward.**

## 5a. The sweep (4 Sep 2026)

`EconomySimulation` did not model daily tasks at all, so §5's numbers above were
never checked against anything. Modelling them produced two findings, one of
which reverses §5's own recommendation.

### The channel was ~40% over budget at multiplier 1.0

At the projection level (L45) the Phase 2c coin budget has **523 coins/day** of
room before the Sanctuary Map falls through its 55-day floor. The daily channel
was spending **1,135** — 735 in per-task payouts plus the 400-coin sweep bonus.
The map projection dropped to **52.9 days**, failing
`testMapBuildOutLandsInTheTargetWindow`. There was no headroom to raise the
multiplier; the honest reading was that 1.0 was already too generous.

**Why nothing offsets it.** The model deliberately has **no demand-side term**
for daily tasks. A hand-in destroys board items, which looks like kibble demand,
but PawSanctuary's orders credit on *merge* and never consume: the order pays out
when the item is built, and the item stays on the board. `grossDemand` already
counted that build. Counting it again would double-count and report a wall the
game does not have. The consequence is worth stating plainly, because it is a
property the reference titles do **not** share (their orders consume): **the same
kibble earns twice here** — once as order coins, once as hand-in coins. That is
what makes this faucet pure addition.

What a hand-in really is in this economy is a **sink on the item stock** — a
reason for the board to clear. `Row`/`ratio` is a flow model, so it has nowhere
to express a stock drain, and inventing an overlap fraction to smuggle one in
would be tuning the ratio to taste, which the supply model's own header forbids.

### Strict proportionality made two of the three cards worthless

A task's cost is `2^tier`, and the easy slot always draws tiers 0–1 and the medium
slot tiers 2–3 *regardless of player level*. So under pure build-cost
proportionality:

| | easy | medium | hard | hard's share |
|---|---|---|---|---|
| L1 | 10 | 31 | 65 | 62% |
| L30 | 10 | 44 | 280 | 84% |
| L60 | 10 | 44 | 781 | 94% |

The easy card paid 10 coins at level 60. No multiplier fixes that — doubling it
pays 20. This is structural, not a tuning miss.

### What shipped

`dailyTaskCoinFloor = 150` (a per-task minimum, applied before the spread jitter),
`dailyTaskCoinMultiplier` 1.0 → **0.75**, and `coinsPerAllDailyChallenges`
400 → **0**. The money moved from one invisible lump that only landed on a perfect
day into three visible per-card payouts. The sweep still pays its dog tags, XP and
Care Points.

| | easy | medium | hard | total | hard's share | map (sell-20%) |
|---|---|---|---|---|---|---|
| L1 | 150 | 150 | 150 | 450 | 33% | — |
| L30 | 150 | 150 | 220 | 520 | 42% | — |
| L45 | 150 | 150 | 522 | 822 | 63% | **56.1 days** |
| L60 | 150 | 150 | 596 | 896 | 67% | **55.1 days** |

0.75 rather than the 0.85 first considered: 0.85 lands L45 at 55.4 but pushes
L55–60 to 54.3, under the floor. 0.75 keeps the whole curve inside 55–70.

The floor deliberately **does not bind at the endgame** — at L45 the hard slot's
proportional payout is ~3.5× the floor — so it rescues the early game without
spending budget where the projection is anchored. A test asserts this.

`dailyTaskCostDistribution` enumerates the basket outcomes rather than averaging
them, because the floor binds on *individual* baskets: `E[max(floor, cost)]` is
strictly greater than `max(floor, E[cost])`, and the cheaper approximation would
understate a faucet — the unsafe direction. A test samples the real generator and
checks the model's expected cost against it, so the two cannot drift.

### Still open

Nothing.

## 5b. Board congestion — the stock model (4 Sep 2026)

Closes §5a's one remaining gap. The coin model is a **flow** model and a hand-in
drains a **stock**: cells. `EconomySimulation` now carries a second model beside
the ratio curve that asks how much of the board is spoken for and how much is
left to play in.

### Why v40 is when this became worth modelling

Before v40 nothing made the player *hold* anything. Orders credit on merge and
never consume, so an item's job was done the instant it existed — and merging is
a strict sink (two cells become one), so the board tended to **drain**. A hand-in
task is the first mechanic in the game that requires specific creatures standing
on the board *simultaneously*. That is a genuine claim on cells.

### What the board actually is

| | |
|---|---|
| Capacity | 9×7 = 63 cells; rows 0–2 (21) open from the start, rows 3–8 on `boardRowUnlockTiers` (deepest tier 2/4/6/8/9/10) |
| Family spawners | **15**, one per rewarding map area plus the day-one Canines spawner — derived from `sanctuaryAreas`, not hardcoded |
| Spawner lifetime | **Permanent.** The `chargesRemaining` decrement in `activateProducer` is on the legacy rescue-tier and supply-producer branches; `MergeBoardViewModel.swift:1599` says the family-spawner branch is unlimited. They auto-place on area completion and overflow to storage only if the board is already full |
| Supply producers | 3, auto-placed at L15/20/25, 6 charges then gone — intermittent, counted as an upper bound |
| Off-board stash | 18 item slots (6 + 6 + 6), which the hold requirement cannot use — a task needs the creature *on the board* |

### What daily tasks claim

**Hold: 5.0 cells.** The three baskets' expected line counts (1 + 1.5 + 2.5).
Counted as *items*, so the duplicate-collapse in `generateDailyTask` — two
identical lines becoming one line of count 2 — leaves it unchanged. A test
samples the real generator against this.

**Staging: 3.0 → 6.3 cells** by level. Building one tier-N creature from tier-0
spawns needs at most **N+1** cells at any instant, not 2^N — merging greedily
frees a cell as it goes, the binary-counter bound. Taken over the hard slot only:
a player stages one deep build at a time and the shallower asks sit inside its
shadow.

Together **8.0 → 11.3 cells**: 18% of the endgame board, 29–32% of the 28-cell
early board. Under 40% at every level, and a test holds that line — it is what
regresses if anyone widens `orderBasketLineCounts` or the hard tier band.

### The finding: the tight board is not the daily tasks' fault

Sweeping families owned against capacity finds the squeeze, and it predates v40:

```
L20  fam  7  cap 35  spawners  7  hold 5.0  staging 5.6  |  working 15.4  occupancy 56%
L20  fam 15  cap 35  spawners 15  hold 5.0  staging 5.6  |  working  7.4  occupancy 79%
L5   fam 15  cap 28  spawners 15  hold 5.0  staging 4.0  |  working  4.0  occupancy 86%
```

**Capacity is gated on deepest merge tier; spawner count on map areas bought with
materials.** Those are different currencies, so they can drift apart — and a save
that has pushed the map without deepening its chains is *spawner*-choked, with 15
permanent tiles on a 28-cell board. Daily tasks make that corner tighter by ~9
cells; they do not create it.

A test asserts the **shape** rather than a comfort level: in the worst corner the
spawner claim must exceed the daily-task claim. If daily tasks ever become the
dominant term, that is a v40 regression rather than a pre-existing progression
quirk, and it should fail loudly.

### Deliberately not derived

`familiesOwned` is an **input, not a per-level curve.** Map areas cost
`SanctuaryArea.costs` — *materials*, not coins — and this model does not model the
material faucet. Inventing a families-per-level curve to make the table look
tidier would be exactly the tuning-to-taste the supply model's own header
forbids, so the report sweeps the range instead.

### Still open

Nothing — §5c models the material faucet and answers it. **The corner is
reachable, and it is not a corner.**

## 5c. The material faucet (4 Sep 2026)

Closes §5b's open item. Materials are the game's third currency, alongside kibble
and coins, and the only one that gates *content* rather than pace — map areas,
and therefore family spawners, and therefore how much of the board is permanently
occupied.

`InventoryStore.absorbMaterialItems` cascades the accumulator 2-for-1 without
limit, so the whole economy collapses to one scalar: **tier-0 equivalents**,
where a tier-N material is worth 2^N. That makes the denomination exact rather
than an approximation.

### The faucet

Two real code paths, both counted:

| Source | Rate |
|---|---|
| Quest-claim toolboxes (`claimQuest`: easy 1-in-4, medium 1, hard 2, legendary 3) | weighted by `generateQuest`'s actual d20 roll (45/30/20/5), with its level capping |
| Hard order slot's guaranteed material (`generateOrder`, Task 5.3) | 1 per hard order at `toolboxMaxTier − 2` |

The ambassador-merge toolbox is deliberately **not** counted — it fires on a
top-tier merge, which is days of work, and counting it would flatter the faucet.

### The whole map costs 4,448 units. Here is how long that takes:

```
L1    units/day  12  |  families after 30d  3 · 60d  5  |  all 15 in 370.7 days
L10   units/day  46  |  families after 30d  7 · 60d 11  |  all 15 in  96.6 days
L15   units/day  76  |  families after 30d 10 · 60d 15  |  all 15 in  58.6 days
L20   units/day 130  |  families after 30d 14 · 60d 15  |  all 15 in  34.2 days
L60   units/day 130  |  families after 30d 14 · 60d 15  |  all 15 in  34.2 days
```

### The finding: the two progressions are mismatched by construction

`toolboxMaxTier(forPlayerLevel:)` is `min(5, level / 5 + 1)` — it **saturates at
level 20**, and with it the entire material faucet, which is flat at 130
units/day from L20 to L60. Board capacity, meanwhile, is gated on deepest merge
tier and does not open its last row until tier 10, which `maxAchievableOrderTier`
puts at **level 41+**.

So a player finishes the map — and owns all 15 permanent spawner tiles — roughly
34 days after L20, while the board is still 35 cells. **This is not a corner
case a determined player can contrive; it is the default path.** A test asserts
the mismatch so it fails loudly if either gate moves.

Worst reachable point, L20 at 60 days:

```
L20  fam 15  cap 35  spawners 15  supply 2  hold 5.0  staging 5.6  |  working 7.4  occupancy 79%
```

### This refines §5b's conclusion

§5b said daily tasks are not the congestion problem. That is still true of the
*dominant* claim — spawners are, and they predate v40. But at the tightest
reachable point the honest statement is sharper:

> Producers leave **18** cells. Daily tasks claim **10.6** of them — 59%.
> A pre-v40 player at that same point had 18 working cells; a v40 player has 7.4.

So v40 does not create the squeeze, but it more than halves the working space at
the point where the board is already tightest. A test asserts that majority
share, so it is visible rather than buried.

### Mitigation that already exists

`familySpawnerStorage` is per-species and uncapped — a player can stash spawners
they are not using, and the model's 15-on-board figure is the default, not a
floor. Whether players *discover* that is a UX question this model cannot answer.

### Validation (4 Sep 2026)

The faucet's toolbox terms are the model's least directly observable:
`buildToolboxLot` is private, rolls three chains independently, draws a random
count per chain, and rolls each item's tier off a weighted distribution. A
closed-form test would restate the model's own algebra and pass for whatever
reason the model was wrong.

`ToolboxDropRateTests` instead Monte-Carlo samples the **real**
`claimQuest` → `placeToolbox` → `buildToolboxLot` path and compares:

| Checked | Against |
|---|---|
| Lot value in tier-0 units, at L10 and L45 | `expectedToolboxUnits` |
| Lot shape — three chains, 1–3 items each | the model's composition assumption |
| No material above tier 5 at any level | `buildToolboxLot`'s `min(5, …)` clamp |
| Toolboxes per claim: medium 1, hard 2, legendary 3 | `claimQuest`'s switch |
| The easy quest's 1-in-4 drop | the one random arm |
| Quest difficulty mix 45/30/20/5 | `generateQuest`'s d20 roll |
| Toolboxes per claim under the real mix | `expectedToolboxesPerQuestClaim` |

All seven pass against the live generator — no drift found. The suite was
**mutation-tested** to confirm it is not vacuous: inflating the model's
items-per-chain by 20% fails two of them.

Two levels are sampled deliberately — L10 caps at tier 3, L45 at the chain top —
so a model with the `toolboxMaxTier` cap wrong would pass at one and fail at the
other.

### Still open

**There is no PawSanctuary playtest data**, and that is the honest limit of every
number in §5a–§5c. The only gameplay figure the app records is
`commerce.wallEventsTotal`, a monetization gate counter; every "measured" value
in these specs — `Economy_State_and_Variance.md` included — comes from
reference-title *video capture*, not from this game. The live generator is
therefore the ground truth these tests hold the model to, which catches
model-vs-code drift but **cannot** catch a model that describes the code
correctly and players incorrectly.

Two things only real play can settle:

1. **Do players stash spawners** (`familySpawnerStorage`), or sit on a 79%-full
   board and feel it? §5c's congestion figure assumes the default of leaving all
   15 out.
2. **Is `questClaimsPerDay = 2.0` right?** It is inherited from the Phase 2c coin
   model, and the material faucet scales linearly with it — a real figure of 1.0
   or 4.0 would halve or double every day-count in §5c.

Closing either needs instrumentation the game does not have.

The existing all-three-complete bonus (`coinsPerAllDailyChallenges` 400,
`xpDailyComplete` 30, streak dog tags, `carePointsPerDailySweep`) is unchanged,
but now fires when the third task is **claimed** rather than when the third
counter fills.

## 9. On-device correction (4 Sep 2026)

Both changes here came from playing the shipped build rather than reading it, and
one of them corrects a claim I made when the feature landed.

### The board highlight was shipped, verified, and still not working

I confirmed the highlight on device when the feature landed — but only in its
**`.stocked`** state, on a board where three cells were simultaneously bright
blue. `.wanted` was never looked at, and `.wanted` is the state a player actually
spends the day in: a task is short of something almost all of the time.

At `opacity(0.22)` with no ring, `.wanted` is not distinguishable from an empty
cell at arm's length, and the gold spotlight ring on the same cell wins outright.
So the honest description of what shipped is *"the highlight is implemented and
invisible"*, which is worse than not shipping it, because the code reads as done.

Retuned, and both states verified on device side by side this time:

| | fill | ring |
|---|---|---|
| `.wanted` | 0.38 | 2pt |
| `.stocked` | 0.62 | 3pt |

Two mechanical fixes went with the colour change:

- **The ring is drawn for both states**, and *after* the spotlight ring, so it
  wins the cell when they collide.
- **`strokeBorder`, not `stroke`.** The background group is clipped to its own
  rounded rect, and a centred stroke loses its outer half to that clip — which is
  why the first pass's "2.5pt" ring rendered at about one point. `strokeBorder`
  insets instead, so the width asked for is the width drawn.

**Deliberately no pulse or glow.** A `repeatForever` animation here would run on
every highlighted cell at once, which is exactly the shape of the real-device OOM
`TODO.md` records against the producer shimmer. Colour and edge do the work.

Selection still outranks the task tint in `cellBackground`, so a selected cell
shows yellow rather than blue. That is correct — selection is transient and the
player just caused it.

### Claimed cards stay on screen for no reason

Second issue, same session: a claimed card sat in the horizontal lane for the
rest of the day showing "Handed in". With three dailies plus five order cards in
one scroll, that is a third of the band spent on cards nothing can be done with.
See D-F.

## 6. Claim

`MergeBoardViewModel.claimDailyTask(id:)`:

1. Guard `!isClaimed` and `isStocked`.
2. Remove, per line, exactly `count` matching items in row-major scan order,
   skipping bubbled items. Same approach as `claimAmbassadorQuest()`, which is
   this codebase's existing precedent for surrendering board pieces for coins.
3. `earnCoins(coinReward)`, `grantXP`, `awardCarePoints`.
4. Mark claimed; `recalcBoardIsFull()`; sweep-check; `persist()`.

Removal happens **after** the stock check, and the check re-runs against the live
census at claim time, so a task cannot be claimed on stale state.

## 7. Persistence

Schema **v40**. `dailyChallenges` changes shape incompatibly (`goal` → `lines`).

Migration: **reset the array to `[]`** for every `sourceVersion < 40`.
`checkDailyChallengeReset` regenerates when the array is empty, so a migrated
save gets a fresh set of hand-in tasks the moment it loads.
`dailyChallengeBonusClaimed` is preserved as-is, so a player who already swept
today cannot sweep twice. There is no faithful rewrite available — "complete 6
merges" has no basket that means the same thing — and inventing one would be
worse than one day's partial daily progress on the single upgrade.

## 8. Out of scope

- Adoption orders keep crediting on merge and keep their SF Symbols. Converting
  them is a separate, much larger economy change (every payout number was priced
  on not consuming the item).
- Standing quests are untouched.
- Drag-to-deliver. The Claim button is what was asked for.
