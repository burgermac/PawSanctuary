# Spec — Merging frees a bubbled animal

**Status: building, 17 Nov 2026.** Adds a third way to free a bubbled animal, beside spending Dog Tags and watching an ad. No saved-data change.

## 0. What the game does today (read from the code, 17 Nov 2026)

- A below-top-tier animal merge, at tier 5 or higher, that an open order or quest wants, has a 15% chance (`bubbleChance`) of landing **bubbled**: `BoardItem.bubbledAt` holds the time it was bubbled (`maybeBubbleMergedItem`).
- Tapping an active bubble opens `BubblePopSheet`: **Watch Ad** (shares the daily ad cap) or **Pop with Dog Tags** (`3 + tier`). Either clears `bubbledAt`; the animal stays the same tier.
- After 10 minutes (`bubbleDecaySeconds`) it counts as decayed. The next tap auto-sells it for 50% of its coin value (`bubbleDecayFloor`), never zero.
- A bubbled animal **cannot be dragged**: `attemptMergeOrMove` returns early when the source is bubbled.
- Dragging another item **onto** a bubbled animal never merged. `computeMergeOutcome` returned nil for a bubbled destination, so the two just **swapped places**. This is pinned by two existing tests.
- Bubbled animals are skipped by the merge-hint finder, the order/quest board census, and superpower pieces (which fizzle on them).
- Bubbles never appear on the Parallel Board: it calls the same `computeMergeOutcome` but passes no orders or quests, so nothing there can bubble.
- Bubbles are in the reference plan (`Merge2_Reference_Blueprint.md`, `Alignment_Plan` 4.4: "opened by ad (capped) / gems / waiting"). **No recorded decision D1 to D11 covers or forbids bubbles**, so this does not contradict any of them.

## 1. Rule

Drag a **normal** animal onto a **bubbled** animal of the **same species and the same level**. It is a **normal merge**: both pieces are used up and the next level appears where the bubbled one sat. That is a bigger reward than popping, because popping keeps the animal at the same level.

"Same species, same level" means exactly the existing merge rule: same `chainID`, same `tier`, and below the top tier. The only changes are that the destination may be bubbled, and that the bubbled piece must still be **active** (not decayed).

| Case | Result |
|---|---|
| Normal onto active bubble, same species and level | Normal merge (score, XP, quests, passive powers, merge count, undo snapshot as any merge) |
| Normal onto active bubble, different level or species | Swap places, as today |
| Normal onto **decayed** bubble | Swap places, as today. A decayed bubble is waiting to be collected for coins by a tap, so it is not a merge partner. |
| Wildcard onto a bubble, or bubble that is a wildcard | Swap places, as today. Wildcards are not "same species". |
| Bubbled piece dragged anywhere | Cannot move, as today. So **two bubbled pieces never merge**: you must free one first. |
| Bubble at top tier | Not applicable: top-tier pieces are not bubbled, and top tier cannot merge. |

## 2. What the result is

- The result is a **fresh item** at the bubbled piece's cell, so its bubble and its decay timer simply disappear with it. Nothing is paid, nothing is refunded, no ad is used, and no Dog Tags are spent.
- The new item goes through the normal bubble roll like any merge result (15% if an order or quest wants it). This is intentional: it is a normal merge.
- The "Bubble popped!" toast is not shown: this is a merge, with the merge sound and animation.

## 3. Undo and the Parallel Board

- **Undo (Nine Lives, `preMoveSnapshot`):** a free-by-merge is a normal merge, so it takes the same snapshot. The snapshot holds the whole board including `bubbledAt`, so undoing it brings back **both pieces, the bubble, and its original timer**.
- **Parallel Board:** no change and no bubbles, as in section 0. The shared function change is safe there because those items never carry `bubbledAt`.

## 4. Player-facing text

The bubble sheet gains one line: "Or drag another [name] of the same level onto it to merge them."

## 4b. Hints

The idle hint (`findMergeableHintPair`) now suggests bubble merges: a normal animal and an active bubbled one of the same species and level form a pair, ordered normal first (the hint nudges the first toward the second). Two bubbles never pair, and a decayed bubble is skipped. The "board full / can merge" toast uses the same search, so it also counts these. Tests: `MergeHintTests`.

## 5. Out of scope

Dragging a bubbled piece; wildcards freeing bubbles; changing the bubble chance, cost or decay.

## 6. Code

`computeMergeOutcome` (`MergeOutcome.swift`): the bubbled-destination guard becomes "bubbled is allowed only if active, non-wildcard on both sides, and exact same chain and tier". It gains a `now:` parameter for testing. `attemptMergeOrMove` needs no change. `BubblePopSheet` gets the one hint line.

## 7. Tests

`MergeOutcomeTests`: active same-level bubble merges; decayed, different level, different species, and wildcard cases return nil. `AttemptMergeOrMoveCharacterizationTests`: the old "bubbled destination swaps" test is updated to a different-level case, and new tests cover a real merge (result unbubbled, source cell empty, score up), a decayed bubble swapping, a bubbled source not moving, and undo restoring the bubble.
