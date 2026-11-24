# Stored Golden Balls Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completed Golden Balls can no longer enter animal storage, and the ones already there are turned into coins (Trophy slots first) when a save loads.

**Architecture:** Task 1 narrows `InventoryStore.addItem` so a completed sub-object only ever goes to the 6 Supplies slots; the merge-completion code already cashes an item that storage refuses. Task 2 adds an idempotent load-time sweep on `MergeBoardViewModel` that pays out and removes any completed sub-object found in animal storage, reusing the Trophy payout rules. No save-format change.

**Tech Stack:** Swift 6, SwiftUI, XCTest.

**Spec:** `specs/Spec_StoredGoldenBalls.md`

## Global Constraints

- **Work directory:** `/Users/timothyherburger/Documents/Claude/Claude Code/PawSanctuary-worktrees/fix-stored-golden-balls`, on branch `fix/stored-golden-balls` (cut from `origin/main`). Do not switch branches. Never `git add -A` or `git add .`; name files.
- A "completed sub-object" is a `BoardItem` whose chain category is `.subObject` and whose `rarity != nil` (that is how `InventoryStore.addItem` and the existing `trophyFamily(of:)` already tell them apart).
- Tiers 0 to 2 of a sub-object chain (no rarity) still go to animal storage as today.
- Trophy payout: `trophySlotCoins` (100) per slot, `trophyPageBonusCoins` (500) on filling the last of `trophySlotsPerFamily` (5) slots; a ball whose family page is full pays `(item.rarity ?? .speed).coinValue`. Reuse `trophySlotsFilled(for:)`, `nextTrophyPayout(for:)`, `trophyCounts`, `earnCoins(_:)`; do not duplicate the numbers.
- Supplies, the grid, and every other item category are untouched. No schema change, no migration, no new tuning constant.
- No force-unwraps in new code (CLAUDE.md).
- Test command, run from the work directory: `xcodebuild test -project PawSanctuary.xcodeproj -scheme PawSanctuary -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/claude-501/pawsanctuary-dd-stored -only-testing:PawSanctuaryTests/PowerUpSinkTests`, output redirected to a log file, then grep counts and `error:`. The derived-data path must be outside the project folder (a file provider breaks CodeSign). Run the full suite (drop `-only-testing`) once, in Task 2; if only `BoardAnimationSnapshotTests` fails with "No foreground-active UIWindowScene", re-run that class alone before calling it a regression.

## Review Focus

- A completed ball arriving while Supplies is full must pay coins, never vanish and never land in animal storage. Pinned in Task 1.
- A superpower piece or animal in animal storage must not be touched by the sweep. Pinned in Task 2.
- A tier 0 to 2 sub-object in animal storage must survive the sweep. Pinned in Task 2.
- Running the sweep twice must not pay twice. Pinned in Task 2.
- A fresh game with an empty inventory must show no toast and pay nothing. Pinned in Task 2.

---

### Task 1: A completed ball may only be banked in Supplies

**Files:**
- Modify: `PawSanctuary/InventoryStore.swift` (the `.subObject` case of `addItem`, ~line 128)
- Test: `PawSanctuaryTests/PowerUpSinkTests.swift` (reuse `makeViewModel`, `place`, `placeCompleted`-style helpers, `dogSubObjectChain`; existing tests at ~lines 91 and 117 cover the merge-completion fallback and may need their "storage full" setup checked)

**Interfaces:**
- Produces: `InventoryStore.addItem(_:) -> Bool` returns `false` for a completed sub-object when all 6 Supplies slots are full, and never writes it to `inventory`. Task 2 relies on animal storage never receiving a completed ball.

- [ ] **Step 1: Write the failing tests** in `PowerUpSinkTests.swift` under a `// MARK: stored balls` heading:
  - `testCompletedSubObjectIsRefusedWhenSuppliesFullAndNeverEntersAnimalStorage`: fill all 6 `vm.inventoryStore.powerUpInventory` slots with completed balls; `let banked = vm.inventoryStore.addItem(BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .speed))`; assert `banked == false` and `vm.inventoryStore.inventory.compactMap { $0 }.isEmpty`.
  - `testCompletedSubObjectGoesToASuppliesSlotWhenOneIsFree`: one free Supplies slot; `addItem` returns true and that slot holds the ball.
  - `testTierTwoSubObjectStillGoesToAnimalStorageWhenSuppliesFull`: Supplies full; `addItem(BoardItem(chainID: dogSubObjectChain, tier: 2))` returns true and `inventory.compactMap { $0 }.count == 1`.
  - `testCompletingASubObjectWithSuppliesFullPaysCoinsAndLeavesAnimalStorageEmpty`: Supplies full, animal storage empty, merge two tier-2 dog sub-objects as the existing full-storage test does; assert coins rose by the rolled rarity's `coinValue` and animal storage stays empty.

- [ ] **Step 2: Run the new tests; expect the first and fourth to FAIL** (the ball currently spills into animal storage), the other two to pass.

- [ ] **Step 3: Change `addItem`'s `.subObject` case:** after the existing `guard item.rarity != nil else { return addToAnimalInventory(item) }`, return `addToPowerUpInventory(item)` only (drop the `|| addToAnimalInventory(item)`). Update the comment to say a completed ball never spills into animal storage and that callers cash a refused one. Check every `addItem` caller (`MergeBoardViewModel.swift`: `placeOrBankItem`, `addToInventory`, `applyMergeOutcome`, the two storage-send paths, `applyPouchPiece`) still behaves: none should hold a completed ball except `applyMergeOutcome`, which already cashes a refused item. Report anything else you find.

- [ ] **Step 4: Run the tests; expect all `PowerUpSinkTests` PASS**, including the existing full-storage and with-room tests (adjust those two only if their setup assumed the spill, and say so in your report).

- [ ] **Step 5: Commit.**

```bash
git add PawSanctuary/InventoryStore.swift PawSanctuaryTests/PowerUpSinkTests.swift specs/Spec_StoredGoldenBalls.md docs/superpowers/plans/2026-11-24-stored-golden-balls.md
git commit -m "Stop completed Golden Balls spilling into animal storage"
```

---

### Task 2: Sweep stored Golden Balls into coins on load

**Files:**
- Modify: `PawSanctuary/MergeBoardViewModel.swift` (new method beside the Trophy code near `addSelectedPowerUpToTrophy`; one call in `loadGame`, right after `apply(saved)` and only in the `if let saved` branch)
- Test: `PawSanctuaryTests/PowerUpSinkTests.swift`

**Interfaces:**
- Consumes: Task 1 (animal storage never receives new completed balls).
- Produces: `@discardableResult func sweepStoredGoldenBalls() -> Int` on `MergeBoardViewModel` (not private, so tests can call it). It removes every completed sub-object from `inventoryStore.inventory`, in slot order; each one fills its family's next free Trophy slot (incrementing `trophyCounts` and paying `nextTrophyPayout(for:)`), or, when that family's page is full, pays `(rarity ?? .speed).coinValue`; it pays via `earnCoins`, calls `inventoryStore.recalcInventoryOccupied()`, enqueues one toast "Cashed N stored Golden Ball(s): +C coins" (singular/plural correct) only when N > 0, calls `persist()` only when N > 0, and returns the total coins paid (0 when nothing was found).

- [ ] **Step 1: Write the failing tests** (a ball is `BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .speed)`; put them in animal storage with `vm.inventoryStore.inventory[i] = ...`; family helper for the dog is `AnimalSpecies.dog`):
  - `testSweepPaysTrophySlotsInOrderAndClearsStorage`: three dog balls stored; sweep returns `3 * trophySlotCoins`, `vm.trophyCounts["dog"] == 3`, animal storage empty, `vm.coins` rose by the same amount.
  - `testSweepFifthSlotPaysThePageBonus`: five stored dog balls pay `5 * trophySlotCoins + trophyPageBonusCoins`.
  - `testSweepSixthBallPaysItsRarityValue`: six stored dog balls (rarities `.speed` ... all `.speed`); total is the five-ball total plus `SubObjectRarity.speed.coinValue`; `trophyCounts["dog"] == 5`.
  - `testSweepBallWithNoRarityIsLeftAlone`: a tier-3 dog sub-object with `rarity == nil` is not a completed ball; sweep returns 0 and it stays.
  - `testSweepKeepsFamiliesOnSeparatePages`: two dog balls and one cat ball (`AnimalSpecies.cat`, chain `"subobject.cat"`): `trophyCounts["dog"] == 2`, `["cat"] == 1`.
  - `testSweepLeavesAnimalsSuperpowerPiecesAndLowerTiersAlone`: stored animal tile, a tier-2 dog sub-object, and a superpower piece (`BoardItem(chainID: ContentRegistry.superpowerChainID(<a species with an active superpower>), tier: 0)`) all remain; sweep returns 0.
  - `testSweepTwiceDoesNotPayTwice`: stored balls; second `sweepStoredGoldenBalls()` returns 0 and `vm.coins` is unchanged.
  - `testSweepWithEmptyStorageShowsNoToastAndPaysNothing`: returns 0; no toast is enqueued (compare the pending-toast count before and after).
  - `testSweepToastNamesCountAndCoins`: three stored balls; the enqueued toast text contains "3" and the coin total.

- [ ] **Step 2: Run the new tests; expect FAIL** (method does not exist, compile error counts as RED).

- [ ] **Step 3: Implement `sweepStoredGoldenBalls() -> Int`** as specified in Interfaces, using `trophyFamily(of:)` (already in this class) to find each ball's family. Prefer one small shared helper for "pay the next Trophy slot" used by both this and `addSelectedPowerUpToTrophy` if it removes duplication without changing that method's toasts; otherwise reuse `nextTrophyPayout(for:)` and increment `trophyCounts` directly.

- [ ] **Step 4: Call it from `loadGame`** immediately after `apply(saved)` (before `applyOfflineProgress`), inside the `if let saved = GameStore.load()` branch only, never on a fresh start.

- [ ] **Step 5: Run `PowerUpSinkTests`; expect all PASS.** Then run the full suite once and report counts (see Global Constraints for the snapshot-test caveat).

- [ ] **Step 6: Record it.** Add one ticked line to `TODO.md` under "Completed sub-objects had no sink" saying completed balls no longer spill into animal storage and a load-time sweep cashes stored ones, and that the sweep can be deleted once old saves are clean. Commit it separately.

- [ ] **Step 7: Commit code and tests.**

```bash
git add PawSanctuary/MergeBoardViewModel.swift PawSanctuaryTests/PowerUpSinkTests.swift
git commit -m "Cash stored Golden Balls into Trophy slots or coins when a save loads"
git add TODO.md
git commit -m "Record the stored Golden Ball sweep in TODO"
```
