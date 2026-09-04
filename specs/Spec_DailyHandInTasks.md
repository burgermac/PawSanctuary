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

`coinReward = orderCoinPayout(lines:) × dailyTaskCoinMultiplier`, priced off the
same `coinsPerKibbleOfOrder` rate, with the same ±`orderCoinSpread` jitter.

`dailyTaskCoinMultiplier` starts at **1.0** — one dial, deliberately not a
hand-authored table.

Why this is defensible, and what still needs checking:

- It beats selling outright by 2.36× (`coinsPerKibbleOfOrder` 6.5 vs
  `coinsPerKibbleOfSale` 2.75), so handing in is never a trap — the same test
  `orderSellValue` exists to enforce for orders.
- Unlike every other coin faucet in the game, this one **consumes built board
  value**. It raises the demand/supply ratio rather than lowering it, which is
  the opposite of the failure mode `Spec_OrdersAndTasks_Draft.md` §2a records
  for Smile Points (a board-item faucet that erased the Phase 3 wall).
- **Open:** the multiplier has not been swept through `EconomySimulation`. It is
  one constant in `AnimalSpecies.swift` with the other tuning numbers; §4 of the
  Kibble Drive spec's method applies here too. Playtesting, not guesswork.

The existing all-three-complete bonus (`coinsPerAllDailyChallenges` 400,
`xpDailyComplete` 30, streak dog tags, `carePointsPerDailySweep`) is unchanged,
but now fires when the third task is **claimed** rather than when the third
counter fills.

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
