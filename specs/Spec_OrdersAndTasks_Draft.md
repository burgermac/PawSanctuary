# PawSanctuary — Order baskets, Smile points, and the Tasty Tasks gap (draft)

**Status: §1, §2 and §4 all IMPLEMENTED — this spec is fully closed out.** Not entered into `PawSanctuary_Alignment_Plan.md`'s D1–D8 decision log — that log is made in the design-authority chat. Third in the reference-review series, after `Spec_PartyBoard_Draft.md` and `Spec_BoardAnimation_Draft.md`.

**§1 (order baskets) shipped 27 Aug 2026** in three commits, each verified on the simulator and left playable:

| | Commit | What landed |
|---|---|---|
| Step 1 | `9c225e8` | Schema v37 — `AdoptionOrder` reshaped to `lines: [OrderLine]`, migration, `OrderBasketTests`. Generation still emitted one line, so behaviour and economy were unchanged. |
| Step 2 | `1e4e6c9` | Multi-line generation tied to slot difficulty; payout summed across lines. |
| Step 3 | `d543fbc` | Per-line slots on the order card with the actionability tint. |

Four design calls were taken before implementation and are recorded in §1a below. §5's open questions 1 and 2 are answered by them; the rest still stand.

## 0. Source material

`ScreenRecording_08-22-2026 21-24-10_1.MP4` (74.6s, 1206×2622 @ 59.2fps) — **Tasty Travels**, player level 104. Note this is a different reference title from the two prior recordings (Gossip Harbor), so conventions differ.

Analysed with `scripts/refvideo.swift`: contact sheet for structure, then native-resolution crops down to 0.12s steps on the order strip, the Golden Smiley claim, a merge, and the Tasty Tasks screen.

---

## 1. Finding — orders are multi-item baskets, not single-item requests

**This is the largest structural gap found so far.**

Each customer order card carries:

- A **reward header**: `+100` of a flower/petal token and `+21000` coins (varies per order — a second card showed `+110 / +22500`, a third `+50 / +10500`).
- **One to three item slots**, each a *specific item at a specific tier*, and **not necessarily the same chain**. Observed: one card wanting a honey jar **and** a nail-polish bottle; another wanting a fruit crate **and** a toy helicopter; a third wanting only a single blue bottle.
- Slot backgrounds encode satisfiability at a glance — **green** where the player can currently fill it, **grey/blue** where they cannot.
- A **footer** with two more currencies (a shell count of 95/105/50, and a mitt count of 4/4/2).
- A **smiley badge showing `+1`** — the Smile points that order pays out (see §2).
- A green ✓ overlay once fulfilled.

Crucially, the requested items sit at **mid-chain tiers**, not chain completions. The info bar during play showed selections like "Classic Toy Box (Lv 3)", "Standard Bundle Box (Lv 5)", "Large Toy Box (Lv 5)", "Standard Toy Chest (Lv 7)", "Crimson Hibiscus (Lv 4)" — orders sample across the whole depth of several chains at once.

### What PawSanctuary has

`AdoptionOrder` (`AnimalSpecies.swift:916`) carries exactly **one** requirement:

```swift
var wantedChainID: ChainID
var wantedTier: Int
var wantedCount: Int      // 1 or 2
var fulfilled: Int = 0
```

`AdoptionBoard.generateOrder` (`AdoptionBoard.swift:75-135`) draws one tier from a difficulty band and sets `count = (tier <= 5 && Int.random(in: 1...3) == 1) ? 2 : 1`. So a PawSanctuary order is always *"bring me one Pup"* or *"bring me two Pups"* — never *"bring me a Pup, a Grooming Brush, and a Nail"*.

### Gap and cost

Moving to baskets means replacing those four fields with a list of order lines, each with its own chain, tier, count and fulfilled counter. That is **a persisted-shape change**, so per the project's working rules it needs a version bump (schema is at v36), a migration, and a `PersistenceTests.swift` case. It also touches:

- `updateAfterMerge` / `updateUrgentOrderAfterMerge` (`AdoptionBoard.swift:196`, `:213`) — currently match a single `wantedChainID`/`wantedTier` pair; would need to scan lines.
- `orderDescription` (`AnimalSpecies.swift:943`) — currently composes one phrase ("a Tabby"); needs to describe a basket.
- `isComplete` / `progressFraction` — currently one ratio; becomes an all-lines-satisfied check.
- The order card UI — one icon becomes a row of one-to-three slots, ideally with the green/grey satisfiability tint, which is a genuinely good affordance worth copying.

**This is not a small change, and it is not additive.** Recommend it be sized as its own task rather than folded into anything else.

## 1a. How §1 was actually built (27 Aug 2026)

**Decisions taken:** baskets may span chains; size is tied to the existing slot difficulty (easy 1 line, medium 1–2, hard 2–3); payout is the summed build cost of every line, so the coins-per-kibble rate is untouched; and it landed as a behaviour-neutral reshape first, then generation, then UI.

**Two things worth carrying forward:**

**Filler lines draw an easier band.** Line 0 takes the slot's own difficulty; further lines take `basketFillerDifficulty` (one step easier). Rolling every line from the slot's own band would roughly triple hard-slot demand — expected cost is ~111 kibble per hard line against ~6 for medium. The filler lines still bite, just not in kibble: a basket forces the player to hold several different items on a crowded board across more than one chain. That is one constant to change if baskets should cost more.

**Measured economy effect**, against the same model immediately before the change:

| | before → after | | before → after |
|---|---|---|---|
| L1 | 0.25 → 0.30 | L35 | 0.97 → **0.99** |
| L5 | 0.40 → 0.46 | L40 | 0.97 → **0.99** |
| L10 | 0.60 → 0.60 | L45 | 1.12 → 1.14 |
| L25 | 0.65 → 0.67 | L55 | 1.28 → 1.30 |

Every band still satisfies the Task 2.5 assertions. L15/L20 dip slightly because 2-line medium orders no longer roll the count-2 multiplier.

**Flagged at the time: L35–40 sat at 0.99 against a "must not have walled yet" bound of 1.00, headroom down from 0.03 to 0.01** — with a warning that "the next thing that adds demand at that band will breach it." **That warning was wrong about the direction, and §2a resolved it**: Smile points added a board-item faucet, which is recirculation (supply), so it *lowered* the ratio to 0.93 and restored the headroom. See §2a.

**The tint means something different here than in the reference, deliberately.** Those games fulfil an order by dragging the item onto it, so a slot lights up when the player *holds* the item. PawSanctuary advances orders only as a side effect of a merge producing the wanted item, so a held item does nothing for an order asking for it. The slot therefore tints on "you could make this next merge" (`MergeBoardViewModel.mergeReadyKeys`: at least two of the tier below, across board and inventory). A literal port would have promised something the game never delivers.

**Left open by this work:** an order asking for tier 0 can never tint ready, because tier 0 comes from a spawner rather than a merge. That is correct under the current rule but may read oddly to a player. Worth a look if easy-slot orders feel inert.

---

## 2. Finding — Smile points ("Golden Smiley")

A second, coarser reward loop layered on top of orders.

**Structure, as observed end to end:**

1. Every order card displays a **smiley badge with a point value** (`+1` observed; per Tim's play knowledge the range is **1–3**, presumably scaling with order difficulty).
2. Completing an order banks those points.
3. A card in the horizontal task strip tracks the running total as **`0/12`**, with the same 1d 7h timer as the other event cards.
4. At **12/12**, a "Golden Smiley" modal appears: a filled progress bar, a gift box at its end, the line *"Complete orders with 😊 to fill the bar and win rich rewards!"*, and a **Claim** button.
5. Claiming **scatters a bundle of board items onto the board** — they fly in along comet-trail arcs and land in free cells, arriving **bubble-wrapped** (see §3).
6. A **"Smile"** celebration banner plays over a darkened, spotlit board — a large golden smiley with gold stars.
7. The counter **resets to 0/12** and the cycle repeats within the timer window.

Per Tim: the awarded bundle is *a random assortment of spawner pieces at various merge states* — i.e. the payout is **board material across a spread of tiers**, not currency. That matters: it refills the board with merge fodder at mixed depths rather than paying out a number.

### Target behaviour — build the Tasty Travels model, not PawSanctuary's current one

This section specifies the intended behaviour. Where it conflicts with how the Milestone Track works today, **the behaviour below wins** — the point is to match the reference, not to minimise the diff.

**S1 — Every order carries a visible Smile value.** Not a hidden roll on a fraction of orders. Each order card shows a smiley badge with its own `+1` / `+2` / `+3`, legible before the player decides which order to chase. The value is part of the order's identity, visible from generation to fulfilment.

**S2 — The value scales with the order's difficulty.** A deeper-tier order is worth more Smiles. Proposed banding against `AdoptionOrder.wantedTier` (numbers are a first cut, not modelled — see §5):

| `wantedTier` | Smile value |
|---|---|
| 0–3 | 1 |
| 4–7 | 2 |
| 8+ | 3 |

**S3 — One threshold, not a ladder.** A single bar filling to 12 (reference value; re-derive for PawSanctuary's order throughput). Not a series of escalating milestones.

**S4 — It cycles.** On reaching the threshold the player claims, the bar **resets to 0/12**, and the loop immediately begins again. This is the defining property and the one most at odds with the current implementation.

**S5 — The payout is board material, rolled at claim time.** A random assortment of items spread across tiers — merge fodder, not currency. Rolled fresh each cycle, so no two claims are identical.

**S6 — Delivery is a scatter onto the board.** Items fly in along arcs and land in free cells **bubble-wrapped**, reusing the existing bubble mechanic (`MergeBoardView.swift:733`, `isActiveBubble(at:)` → `.bubblePop`). A "Smile" celebration beat plays over a dimmed board.

**S7 — The tracker lives in the task strip** as a `0/12` card, alongside the existing cards in `TaskStripView` (`PanelViews.swift:1745`), and taps through to the claim modal.

### What actually carries over — correcting an earlier claim

An earlier read of this called it *"a reskin of built machinery, not new construction."* **Having now read the implementation, that was too optimistic and is withdrawn.** The faucet reuses cleanly; the accumulator does not.

**Reuses cleanly:**

- `RewardKind.boardItem` (`AnimalSpecies.swift:891`) — already carries `payloadID = ChainID`, `payloadTier = tier`, exactly the shape a scattered bundle needs. Phase 2's recirculation rider already uses it, so the grant path is proven.
- The bubble delivery mechanic — already exists, no work.
- `TaskStripView` — one more card.

**Does not fit, and why:**

1. **`ProgressTrack` is monotonic and one-shot.** `advance(trackID:by:)` only ever adds, and claims are recorded by appending the milestone index to `claimedFree` (`LiveOpsEngine.swift:716+`). There is no reset. Running S4's cycle through it would mean, every cycle, both zeroing `progress` and clearing `claimedFree` — i.e. reaching in and contradicting the invariant the type is built around. `ProgressTrack` earns its complexity from multi-milestone ladders with parallel free/paid lanes (Pass, `Spec_Phase6b_Pass.md` §3.5). Golden Smiley has **one** threshold and **no** paid lane, so nearly all of that machinery is dead weight here.

2. **`TrackMilestone.freeRewards` is a static array** authored in `ProgressTrackRegistry.tracks`. S5 needs a bundle **rolled at claim time**. A registry of fixed reward lists cannot express "roll 3–5 items around the player's current depth" without the reward list becoming a function — which is a different type.

3. **`EventTokenRiderProvider` is the wrong faucet shape.** It fires `Double.random(in: 0..<1) < riderFrequency` (0.33) for a flat `tokensPerRider` (20) — an invisible chance of a fixed lump (`EventSystem.swift:494-509`). S1/S2 need a visible, deterministic, per-order value derived from that order's own tier. Worse, `OrderRewardProvider.riders(playerLevel:)` receives **only the player level** — it has no access to the order being generated (`AdoptionBoard.swift:128`), so it *cannot* implement S2 without changing the protocol for every existing provider.

### Proposed shape

**Smile value belongs on the order, not in a rider.** Add `smileValue: Int` to `AdoptionOrder` (`AnimalSpecies.swift:916`), set in `AdoptionBoard.generateOrder` from the S2 banding at the same point `wantedTier` is chosen (`AdoptionBoard.swift:79`). It is displayed data, like `wantedTier` — the order card reads it directly. This sidesteps the `riders(playerLevel:)` signature problem entirely and makes the value visible by construction.

**The accumulator is a small dedicated coordinator, not `ProgressTrack`.** What S3–S5 actually require is: one `Int`, one threshold, a "claim → roll bundle → reset to zero" step, and lifetime cycle-count for telemetry. That is materially less code than bending `ProgressTrack` into cycling, and it leaves `ProgressTrack` doing the one job it was built for. Grant the rolled bundle through the existing `applyRewards(_:)` path (`MergeBoardViewModel.swift:3109`) as `[OrderReward]` of kind `.boardItem`, so delivery, persistence and inventory-full handling all follow rules that already exist.

**Banking the points** hooks the existing order-claim chokepoint — the same place `AdoptionOrder.isClaimed` is set — adding `smileValue` to the counter and checking the threshold.

**Board-full policy is a real open question, not an edge case.** The scatter needs somewhere to land. PawSanctuary already refuses and toasts (`.inventoryFull`) when `retireProducer` has nowhere to go (`MergeBoardViewModel.swift:2396`), and tracks `emptyUnlockedCells`. Options: hold the claim until space exists (safest, and the reference's own timer makes hoarding costly), scatter what fits and bank the rest, or shrink the bundle to available space. **Not decided** — see §5.

**Persistence:** `smileValue` on `AdoptionOrder` and the counter both persist, so this needs a version bump from v36, a migration, and a `PersistenceTests.swift` case. §1's basket change is also a schema change — **if both are taken, land them in one migration rather than two.**

---

### 2a. Shipped as "Smile Points" (27 Aug 2026, `bd6d9d6`)

Built to the S1–S7 behaviours above, with three departures worth recording:

**`smileValue` is computed, not stored.** §2's proposal added a stored field plus a migration. Deriving it from the order's deepest line — which is already persisted — cannot drift from the order it describes and needs no migration at all. Only the banked counter is new state (v39).

**Claiming carries the remainder.** The reference resets to 0/12; banking 59 and then completing a 3-point order would otherwise discard 2 points the player earned.

**The board-full question answered itself.** §5's open question offered hold / partial-scatter / shrink. `grantRecirculatedBoardItem` already places to the board, falls back to inventory, and toasts only if both are full — the same degradation the weekly chests use. No new policy needed.

**The economy model rejected two drafts, which is why it exists.** At the reference's goal of 12, bundles landed ~5×/day and the payout *erased the Phase 3 wall*: L45–L60 fell from 1.14/1.30 to 0.78/0.93. The root cause was not only frequency — `recirculationMaxItemTier` (6) clamps every offset in `[2, 3, 4]` to the same tier past mid-game, so the intended assortment collapsed into three identical 64-kibble items. Fixed with a dedicated lower ceiling (`smileBundleMaxItemTier = 4`) and a goal of 60 (~1 bundle/day). Final curve, all bands passing:

| | before → after |
|---|---|
| L35 / L40 | 0.99 → **0.93** |
| L45 / L50 | 1.14 → **1.08** |
| L55 / L60 | 1.30 → **1.24** |

**This also resolved §1a's flagged headroom problem, by correcting an error in it.** That note predicted Smile points would breach the 1.00 *ceiling* at L35–40. It had the direction backwards: a board-item payout is recirculation — supply, not demand — so it *lowers* the ratio. Headroom there went from 0.01 back to 0.07. The real exposure is the mirror image (a generous board-item faucet erasing the wall), and `TODO.md` now tracks that bound instead.

---

## 3. Finding — merge and reward animations (Tasty Travels)

Two mechanics the Gossip Harbor recordings did not show. Merge choreography itself matches `Spec_BoardAnimation_Draft.md` §1 (converge → glow → new item) and is not re-derived here.

**Bubble-wrapped delivery.** Items that arrive as *rewards* rather than as merge output land inside a translucent glass sphere and must be tapped to open. Observed on the Golden Smiley bundle and on newly produced items. **PawSanctuary already has this** — `MergeBoardView.swift:733` routes `viewModel.isActiveBubble(at: pos)` to a `.bubblePop` sheet. Not a gap; worth noting as an existing match.

**Per-merge currency callout.** Each merge emits a small shell-currency callout (`+1`, `+2`) that drifts up-and-left from the merged cell and fades — the value scaling with the tier reached. Order fulfilment emits a much larger version: the consumed item scales up and dissolves, then an oversized reward icon flies out over a gold starburst with a large numeral ("95"). PawSanctuary awards coins on merge but surfaces no floating callout at the merge site.

---

## 4. Finding — "Tasty Tasks", and where PawSanctuary's equivalent is fragmented

**Structure:**

- A **7-day cycle** — `Day 1`…`Day 7` tabs across the bottom; Day 1 shows ✓ (done), Day 5 is current, Day 7 carries a padlock. Whole screen runs on a 1d 7h timer.
- A **task list** of cumulative-activity goals, each with its own progress and its own reward:
  - "Complete 80 orders" — 62/80 — pays 90 coins + 1 box
  - "Log in for 5 days" ✓
  - "Collect 40 cards" ✓
  - "Spend 5000 Energy" ✓
  - "Merge 2000 times" ✓
- A **shared points bar** above the list, with five milestone thresholds — **100 / 525 / 950 / 1400 / 2090** — each carrying its own reward icon (energy, chest, card pack, a fourth, treasure chest).
- Completing a task **feeds the shared bar**. Measured directly: the counter read **1110** at 61.5s and **1210** at 63.5s — exactly +100 as "Merge 2000 times" flipped to ✓.
- A separate three-slot cutlery row and a cake chest sit at the bottom (a collect-3 side mechanic, not analysed).

### Where PawSanctuary's equivalent lives — all the parts exist, none of them connect

| Tasty Tasks element | PawSanctuary counterpart | Status |
|---|---|---|
| Heterogeneous task list | `QuestCoordinator` — quests + daily challenges, incl. `QuestGoal.spendCurrency` (D6) | Exists |
| Per-task reward | Quest/challenge reward claims | Exists |
| Tiered milestone bar | Weekly goal — bronze/silver/gold | Exists |
| Longer arc above it | Monthly goal — `weeklyGoldCompletions >= monthlyGoalWeeksNeeded` | Exists |
| Points→thresholds engine | Milestone Track / `ProgressTrack` (Phase 6a) | Exists |
| Day-by-day cycle | Daily-challenge daily reset | Partial |
| **Task completion feeding a shared bar** | **— nothing** | **Missing** |

**The gap is one conversion, not a feature.** PawSanctuary's weekly goal keys off `coinsEarnedThisWeek` (`MergeBoardViewModel.swift:789`) — a *currency* accumulator. The milestone track keys off order-attached event tokens. Neither is fed by *completing a task*. So finishing a daily challenge advances nothing above itself.

In Tasty Travels, every task — login, orders, merges, energy spend, card collection — pays into **one bar with one set of escalating rewards**. That single conversion is what turns five unrelated checkboxes into one campaign the player is measurably progressing through, and it is the whole reason the screen reads as a destination rather than a chore list.

**Recommendation:** the cheapest close is to award milestone points on quest/daily-challenge *completion*, into the existing `ProgressTrack`, and surface one tiered bar above the existing task surfaces — rather than building a new "Tasty Tasks" screen. That reuses `QuestCoordinator`, `ProgressTrack`, and the weekly-goal tier UI, and adds one chokepoint plus one bar.

Secondary, cheaper still: the weekly goal's bronze/silver/gold could be re-pointed from `coinsEarnedThisWeek` to that same points pool, so there is one currency of progress rather than two.

### 4a. Shipped as "Care Points" (27 Aug 2026, `2f28a18`)

Built as its **own** bar rather than re-pointing the weekly goal — a deliberate call against this section's secondary suggestion, so the coin economy the weekly chest is tuned against stays untouched.

**Sources and ladder.** Points bank at three chokepoints: `claimQuest` (8/15/30/60 by difficulty), the daily-challenge sweep (25, via `applyQuestRewards` — the sole producer of a `QuestRewards`, so one edit covers all three call sites), and order claims (1, persistent and urgent). Ladder is Bronze 120 / Silver 320 / Gold 520, sharing `checkWeeklyGoalReset`'s boundary rather than carrying its own.

**Rewards are Dog Tags / XP / card packs only — no kibble, no coins.** `EconomySimulation.dailySupply` models the kibble faucet as a fixed `miscKibblePerDay` explicitly covering "login bonus, Loyalty Club, quests, daily challenges, weekly goals", and the coin faucet is tuned against the Sanctuary Map's total cost. Paying either here would understate supply in a model this project keeps deliberately in step with the code. **If kibble or coins are ever wanted in this chest, re-derive `miscKibblePerDay` (or the coin model) first.**

**The reachability tests caught a bad first draft, which is the point of having them.** The initial numbers (120/260/450, orders at 1, quests at 2/4/8/15) failed two ways at once: Gold was *unreachable* — 450 against 420 banked in a full engaged week — and orders alone supplied ~80% of the bar, which would have made it an order counter with the very task surfaces it exists to unify reduced to a rounding error. The fix was to rebalance the **weights**, not just lower the threshold. `CarePointsTests` now asserts three properties against `EconomySimulation`'s own activity assumptions: Gold is reachable in a week but not in two days, Bronze lands early, and orders alone cannot clear Gold.

**Still open from §4:** the reference's Day 1–7 tab structure and per-day task sets were not built — that was the "substantially bigger build" option and remains unaddressed. What shipped is the conversion this section identified as the actual gap, not the whole screen.

---

## 5. Open questions

1. **Basket size distribution** — how often is an order 1 vs. 2 vs. 3 lines, and does it scale with player level? Only three cards were legible in one frame; too small a sample to model from.
2. **Do basket lines span chains** by design, or was the observed mix coincidental? A same-chain-only basket is a much smaller change than a cross-chain one, and reads differently to the player.
3. **Smile point values** — §2's S2 banding (0–3 → 1, 4–7 → 2, 8+ → 3) is a first cut off `wantedTier`, not modelled. The reference's own driver is unknown: order difficulty, basket size and tier depth are all plausible and not determinable from this capture. If §1's baskets land, "difficulty" may need to account for line count, not just tier.
4. **Threshold of 12** — copied from the reference. PawSanctuary runs `adoptionOrderCount = 4 + bonuses` concurrent orders (`MergeBoardViewModel.swift:798`); at an average Smile value of ~1.5 a 12-point bar is roughly 8 orders per cycle. Whether that is the right cadence needs sizing against real order throughput, and whether the threshold scales with level or stays fixed is undecided.
5. **Bundle composition** — how many items, at what tier spread, and weighted how? Options: flat random across unlocked chains, centred on the player's current merge depth, or biased toward chains the board is currently short of. The reference's scatter was too fast to count. This is the single number most likely to break the economy if guessed — it is a direct faucet into board material.
6. **Board-full policy on claim** (§2) — hold the claim, partial-scatter and bank the remainder, or shrink the bundle to fit. Affects whether the cycle can soft-lock a full board.
7. **Is Golden Smiley evergreen or event-scoped?** The reference card carries a 1d 7h timer, so it is a timed instance there, but the cycle resets *within* the window. An evergreen always-on loop is the simpler v1; wrapping it in the existing event calendar can follow.
8. **Tasty Tasks milestone curve** — the observed thresholds (100/525/950/1400/2090) are non-linear with a large first step and a compressed tail. Worth modelling against PawSanctuary's own reward curve rather than copying the numbers.
9. **Order-basket migration sequencing** — does §1 want to land before or after `BoardStateManager` Phase D? Both touch order/merge resolution paths. If §1 and §2 are both taken, they share one schema migration (see §2).

## 6. Suggested next step

§4's conversion (task completion → shared points bar) is the smallest change with the largest structural payoff and touches only existing systems.

§2 (Smile points) is a **new, self-contained coordinator** plus a field on `AdoptionOrder` — moderate, well-bounded, and specified to the reference's behaviour rather than to what is cheapest to bolt onto the Milestone Track. An earlier draft called it a reskin; reading the implementation showed `ProgressTrack` genuinely does not fit a resetting single-threshold cycle, so it is more work than first stated, though still modest.

§1 (order baskets) is the biggest gap and a non-additive schema change; size it on its own. If §1 and §2 both go ahead, land their migrations together.
