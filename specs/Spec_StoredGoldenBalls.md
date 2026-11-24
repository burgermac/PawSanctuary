# Spec — Stop completed Golden Balls filling animal storage, and clear the ones already there

**Status: approved by the owner 24 Nov 2026 with Trophy-slots-first; implemented on fix/stored-golden-balls.** Small change, no save-format change. Follow-up to `specs/Spec_GoldenBallTapToCollect.md` (merged as PR 158) and `specs/Spec_GoldenBallTrophyPage.md`.

## 1. The problem

Owner report: completed Golden Balls are clogging **animal storage only** (not the grid, not Supplies). Cause in code: `InventoryStore.addItem` sends a completed sub-object (one with a rolled `rarity`) to the 6 Supplies slots and, when those are full, falls back to the animal inventory (`addToPowerUpInventory(item) || addToAnimalInventory(item)`). Animal storage is shared with animals, wildcards and rare superpower pieces (the `.superpower` category falls to `default: addToAnimalInventory`), so a pile of balls there crowds out things the player wants. A ball in animal storage has only one exit today: Place on Board, then tap it.

## 2. Rules

1. **No more spill.** A completed sub-object may only be banked in Supplies. When Supplies is full, `addItem` returns false and the caller's existing fallback cashes it for coins (`applyMergeOutcome`, `case (false, let rolled?)`). Tiers 0 to 2 (no rarity) still go to animal storage as before.
2. **Sweep the existing ones.** When a save is loaded, every completed sub-object in animal storage is removed and paid out, in inventory slot order: it fills its family's next free Trophy slot (100 coins each, plus 500 on the fifth slot, exactly as `addSelectedPowerUpToTrophy` pays); a ball whose family page is already full is cashed at `(rarity ?? .speed).coinValue`. Trophy slots first, since it pays best and gives the pages a purpose.
3. One toast summarises the sweep, e.g. "Cashed 3 stored Golden Balls: +350 coins". Nothing is shown when there are none.
4. Supplies, the grid, and every non-completed item are untouched. Board tiles stay tap-to-collect (owner's earlier choice).

## 3. Goals, non-goals

- **Goal:** animal storage never holds a completed ball, now or after the sweep.
- **Non-goals:** auto-cashing once a Trophy page is full (mostly moot after rule 1; revisit only if Supplies fills in play); a Sell button; moving balls into Supplies; changing payouts.
- **Anti-goal:** losing a ball without paying for it. Every removed ball must produce coins in the same step.

## 4. Approaches considered

- **A. Trophy slots first, cash the remainder (proposed).**
- **B. Cash every stored ball at its own value.** Simpler, pays less.
- **C. Move them into free Supplies slots, cash the overflow.** Keeps power-ups but refills Supplies with old balls.

## 5. Build notes

- Rule 1: change the `.subObject` case in `InventoryStore.addItem` (`PawSanctuary/InventoryStore.swift`) so a rarity-bearing item tries only `addToPowerUpInventory`. Audit every `addItem` caller for one that assumed the fallback (`placeOrBankItem`, `addToInventory`, `applyPouchPiece`, the two storage-send paths); none is expected to hold a completed ball.
- Rule 2: a `MergeBoardViewModel` method run from `loadGame` after `apply(saved)` and after the weekly, monthly and event checks (so its coins count toward the current week rather than being zeroed by the weekly reset), before the board sample and before any player input; it reuses the Trophy payout and `earnCoins` rather than re-implementing them. Idempotent: it finds nothing once animal storage is clean, so no schema change or migration. The code can be deleted once old saves are clean.
- It must run after `apply`, because `trophyCounts` and the inventory come from the save. It must not run on a fresh start.
- Payout arithmetic is shared with the existing Trophy add so the two cannot drift.

## 6. Tests

Extend `PowerUpSinkTests` or add a sibling: a completed ball with Supplies full is refused by `addItem` and nothing lands in animal inventory; a tier 0 to 2 sub-object still goes to animal inventory; the sweep with stored balls of one family fills slots in order and pays 100 each and +500 on the fifth; a sixth ball of that family pays its rarity value; balls of two families fill separate pages; running the sweep twice pays nothing the second time; an empty animal inventory shows no toast; non-ball items (animals, superpower pieces, tier 0 to 2 sub-objects) are untouched. Total coins paid equals the sum of the individual payouts.

## 7. Decided

Trophy-first was chosen over cash-everything. The sweep runs on every load with no persisted flag: it is idempotent (it finds nothing once animal storage is clean), so there is no schema bump or migration, and it can be deleted once old saves are clean.
