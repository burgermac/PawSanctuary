# Spec — Tap a stuck Golden Ball to collect it

**Status: draft, awaiting owner approval, 23 Nov 2026.** Small change, no save-format change.

## 1. The problem

A completed top-tier sub-object (Canines' "Golden Ball", shown as Level 4) left on the board grid has no way off it. Items merged today leave the grid at once, so these are older tiles from before that routing existed (the owner confirmed they are "old ones"). They cannot merge (top tier), cannot be sold (`sellSelectedAnimal` is animal-only), and tapping only selects them. Dragging one to storage may land it in the animal inventory, where Convert to Coins and Trophy pages do not reach it.

I could not reproduce a freshly merged ball staying on the grid: every merge goes through `applyMergeOutcome`, which clears it. No simulator save here holds one. The legacy-tile cause is the best fit, not a measured fact.

## 2. Reference model

Travel Town and Tasty Travels treat a finished piece as a collectable: the hint bar reads "Tap to collect N" and at max level the tap pays out with a fly-to-HUD callout. PawSanctuary already does this for the Kibble and Coin currency chains (`collectCurrencyItem`). No reference game combines maxed items; merging happens before the top level.

## 3. Rule

- Tapping a completed sub-object tile (a `.subObject` chain item at `maxTier`) on an unlocked board cell collects it: the tile is removed and coins are paid.
- Payout is the item's own `rarity?.coinValue` (15 / 30 / 75 / 200). A tile with no rolled effect pays the `.speed` value (15). **My call, flag for tuning.**
- A toast reads "+N Coins", as the currency collect does, with the same sound and haptic.
- Dragging such a tile to storage, or using the Store button, collects it too instead of sending it to the animal inventory. Same interception `collectCurrencyItem` already gets.
- Lower tiers (0 to 2) are untouched: they still select, merge and store as today.
- Tiles inside a locked cell are not collectible, matching the currency rule.

## 4. Goals, non-goals

- **Goal:** no Golden Ball can sit on the grid with no exit.
- **Non-goals:** a one-time sweep of old tiles on load; stopping completed balls spilling into the animal inventory; auto-cashing once a Trophy page is full; a Sell button for sub-objects; routing the tap payout into Trophy pages. All separate follow-ups, deliberately not here.
- **Anti-goal:** removing the power-up. Balls that reach Supplies keep working as they do now.

## 5. Approaches considered

- **A. Tap to collect (chosen by owner).** Matches the references, reuses an existing pattern, player-paced.
- **B. One-time sweep on load.** Clears tiles without a tap, but removes the player's choice for those balls.
- **C. Both.** Owner chose A only.

## 6. Build notes

- New `collectCompletedSubObject(at:)` beside `collectCurrencyItem` in `MergeBoardViewModel.swift`; called from `boardCellTapped`, `sendBoardItemToInventory` and `storeSelectedItemToInventory`.
- The coin fallback value goes with the other tuning constants in `AnimalSpecies.swift`.
- No schema change, so no `PersistenceTests` case.

## 7. Tests

Extend `PowerUpSinkTests.swift` or add a sibling file: a tier-3 sub-object tile with a rolled rarity pays that rarity's value and clears the cell; one with no rarity pays 15; a tier-0 to 2 sub-object is not collected and stays selectable; a tile in a locked cell is refused; dragging a completed tile to storage collects it and leaves the animal inventory unchanged.

## 8. Open (owner)

Whether 15 to 200 coins feels right for a ball that took 4 merges' worth of effort; the Trophy-page route is not offered on this tap.
