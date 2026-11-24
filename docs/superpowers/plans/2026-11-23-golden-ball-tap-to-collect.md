# Golden Ball Tap-to-Collect Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A completed sub-object tile (Golden Ball) left on the board grid can be tapped, or sent to storage, to collect coins instead of sitting there forever.

**Architecture:** One new method on `MergeBoardViewModel`, `collectCompletedSubObject(at:)`, modelled on the existing `collectCurrencyItem(at:)` (same guards, toast, sound, persist). It is called from the board tap handler and from the two "send to storage" paths so a completed tile never lands in the animal inventory.

**Tech Stack:** Swift 6, SwiftUI, XCTest. No save-format change.

**Spec:** `specs/Spec_GoldenBallTapToCollect.md`

## Global Constraints

- Payout is `item.rarity?.coinValue`, else `SubObjectRarity.speed.coinValue` (15). No new tuning constant: the fallback reuses `speed.coinValue`, so the spec's "constants in `AnimalSpecies.swift`" note is satisfied by there being none to add.
- "Completed sub-object" means `chain.category == .subObject` and `item.tier == chain.maxTier` (the code uses `maxTier`; `subObjectTopTier` is only used by a migration).
- Tiers 0 to 2 of a sub-object chain are untouched: they select, merge and store as today.
- A tile in a locked cell is not collectible (`boardState.isUnlocked(at:)`).
- No schema change, so no `PersistenceTests` case. Keep the game playable at every commit; one task per commit.
- Do not touch: the animal-inventory spill, the Trophy page route, auto-cash, a Sell button, a load-time sweep.
- Run tests with: `xcodebuild test -project PawSanctuary.xcodeproj -scheme PawSanctuary -destination "platform=iOS Simulator,name=iPhone 17" -derivedDataPath /private/tmp/claude-501/pawsanctuary-dd -only-testing:PawSanctuaryTests/PowerUpSinkTests`. The derived-data path must be outside the project folder (a file provider breaks CodeSign inside it).

## Review Focus

- A top-tier **animal** tile (tier 11) must not be collected by this rule. Pinned in Task 1.
- A completed sub-object tile in a **locked** cell must do nothing. Pinned in Task 1.
- A second tap on the now-empty cell must not pay again. Pinned in Task 1.
- Collecting must clear `selectedCell` when it pointed at the collected tile. Pinned in Task 1.
- Dragging a **tier 2** sub-object to storage must still go to the animal inventory. Pinned in Task 2.

---

### Task 1: Collect a completed sub-object by tapping it

**Files:**
- Modify: `PawSanctuary/MergeBoardViewModel.swift` (add the method next to `collectCurrencyItem` near line 3518; add one call in `boardCellTapped` near line 2008)
- Test: `PawSanctuaryTests/PowerUpSinkTests.swift` (reuse its `makeViewModel`, `place`, `dogSubObjectChain`, `a`, `b` helpers)

**Interfaces:**
- Produces: `@discardableResult func collectCompletedSubObject(at pos: GridPosition) -> Bool` on `MergeBoardViewModel`. Returns `true` only when it collected a tile; `false` leaves everything unchanged. Task 2 calls it.

- [ ] **Step 1: Write the failing tests** in `PowerUpSinkTests.swift`, under a new `// MARK: collectCompletedSubObject` heading. Place items with the existing `place` helper; the rarity case needs `vm.board[r][c].item = BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .highTierDrop)`.
  - `testTappingCompletedSubObjectPaysItsRarityValueAndClearsCell`: tile `(dogSubObjectChain, tier 3, rarity .highTierDrop)` at `a`; `vm.boardCellTapped(at: a)`; assert `vm.coins == before + SubObjectRarity.highTierDrop.coinValue` and the cell's item is nil.
  - `testTappingCompletedSubObjectWithoutRarityPaysSpeedValue`: same tile with no rarity; assert payout `SubObjectRarity.speed.coinValue`.
  - `testTappingLowerTierSubObjectDoesNotCollect`: tier 2 tile; after tap, coins unchanged, item still present, `vm.selectedCell == a`.
  - `testTappingTopTierAnimalDoesNotCollect`: `ContentRegistry.animalChainID(.dog)` at tier `animalChainTopTier`; coins unchanged, item still present.
  - `testTappingCompletedSubObjectInLockedCellDoesNothing`: set `vm.board[0][0].isUnlocked = false` with a completed tile in it; tap; coins unchanged, item still present.
  - `testSecondTapOnCollectedCellPaysNothing`: collect once, tap `a` again, assert coins only rose once.
  - `testCollectingClearsSelectionOnThatCell`: set `vm.selectedCell = a`, tap `a` with a completed tile; assert `vm.selectedCell == nil`.

- [ ] **Step 2: Run the new tests; expect failure.** Run the Global Constraints command with `-only-testing:PawSanctuaryTests/PowerUpSinkTests`. Expected: the pay/clear tests FAIL (tile stays, coins unchanged); the "does not collect" tests may already pass.

- [ ] **Step 3: Implement `collectCompletedSubObject(at:)`** in `MergeBoardViewModel.swift` beside `collectCurrencyItem`. Guards: unlocked cell, an item present, its chain's category is `.subObject`, and `item.tier == chain.maxTier`. Then clear the cell, clear `selectedCell` if it was `pos`, `earnCoins` the payout, enqueue `Toast(kind: .info("+\(amount) Coins"))`, play `SoundManager.shared.playButtonTap()`, `recalcBoardIsFull()`, `persist()`, return `true`. Mirror the tail of `collectCurrencyItem` exactly.

- [ ] **Step 4: Wire it into `boardCellTapped`:** add `if collectCompletedSubObject(at: pos) { return }` directly after the `collectCurrencyItem` check.

- [ ] **Step 5: Run the tests; expect all `PowerUpSinkTests` PASS** (the six pre-existing ones included).

- [ ] **Step 6: Commit.**

```bash
git add PawSanctuary/MergeBoardViewModel.swift PawSanctuaryTests/PowerUpSinkTests.swift specs/Spec_GoldenBallTapToCollect.md docs/superpowers/plans/2026-11-23-golden-ball-tap-to-collect.md
git commit -m "Tap a completed sub-object on the board to collect it for coins"
```

---

### Task 2: Collect instead of storing when sent to storage

**Files:**
- Modify: `PawSanctuary/MergeBoardViewModel.swift` (`sendBoardItemToInventory` ~line 2451 and `storeSelectedItemToInventory` ~line 2465)
- Test: `PawSanctuaryTests/PowerUpSinkTests.swift`

**Interfaces:**
- Consumes: `collectCompletedSubObject(at:) -> Bool` from Task 1.

- [ ] **Step 1: Write the failing tests** in `PowerUpSinkTests.swift`:
  - `testSendingCompletedSubObjectToStorageCollectsItInstead`: completed tile (rarity `.mapSupplies`) at `a`; `vm.sendBoardItemToInventory(from: a)`; assert coins rose by `SubObjectRarity.mapSupplies.coinValue`, the cell is empty, `vm.inventoryStore.inventory.compactMap { $0 }` is empty and every `powerUpInventory` slot is nil.
  - `testStoringSelectedCompletedSubObjectCollectsItInstead`: same via `vm.selectedCell = a; vm.storeSelectedItemToInventory()`.
  - `testSendingTierTwoSubObjectToStorageStillGoesToAnimalInventory`: tier 2 tile; after the call the cell is empty, coins unchanged, and `vm.inventoryStore.inventory.compactMap { $0 }.count == 1`.

- [ ] **Step 2: Run them; expect the two "collects instead" tests to FAIL**, the tier-2 test to PASS.

- [ ] **Step 3: Add `if collectCompletedSubObject(at: pos) { return }`** immediately after the existing `collectCurrencyItem(at: pos)` line in both functions (use `from` as the position in `sendBoardItemToInventory`).

- [ ] **Step 4: Run the full suite** (drop `-only-testing`). Expected: all tests PASS, no regressions. Report the count.

- [ ] **Step 5: Commit.**

```bash
git add PawSanctuary/MergeBoardViewModel.swift PawSanctuaryTests/PowerUpSinkTests.swift
git commit -m "Collect a completed sub-object when it is sent to storage"
```

- [ ] **Step 6: Update records.** Tick a line in `TODO.md` under "Completed sub-objects had no sink" noting the stuck-tile fix and that the legacy-tile cause is a hypothesis, unconfirmed against the owner's real save. Commit with `git commit -m "Record the Golden Ball tap-to-collect fix in TODO"`.
