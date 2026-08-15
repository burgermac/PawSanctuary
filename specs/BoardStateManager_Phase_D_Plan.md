# Phase D — `attemptMergeOrMove` → `MergeResult` Rewrite — Planning Doc

**Status: draft, not started (15 Aug 2026).** This is the planning pass `specs/BoardStateManager_Extraction_Plan.md` §4 says Phase D needs before any code changes — no source files are touched by this doc. Per `CLAUDE.md` rule 5, Phase D itself is a dedicated sprint requiring explicit sign-off; writing this doc is not that sign-off.

**Read `specs/BoardStateManager_Extraction_Plan.md` first.** It covers Phases A–C (state extraction, now fully done) and is the reason Phase D is newly attemptable at all: `BoardStateManager` is dependency-light and unit-testable in a way the rest of `MergeBoardViewModel` isn't.

---

## 1. Current state, measured today

`attemptMergeOrMove(from:to:)` is [MergeBoardViewModel.swift:1762–1905](../PawSanctuary/MergeBoardViewModel.swift#L1762) — **144 lines**, unchanged in size since the Phase A appendix scan (13 Aug), though its absolute line numbers have shifted with later Phase C commits. It is the **only** function in the file that touches all four board-state surfaces (`board[...]`, `boardIsFull`, `emptyUnlockedCells`, `recalcBoardIsFull()`) and it does so through **direct `board[...]` indexing exclusively** — it was explicitly excluded from every Phase C round, so none of the ten `BoardStateManager` primitives are used here yet.

It is not one merge path with options bolted on — it's five structurally distinct outcomes, gated by early returns and nested conditionals, not a shared pipeline:

| Outcome | Lines | What happens |
|---|---|---|
| **Producer merge/swap/move** | 1768–1795 | `srcProducer` present: same-level → upgrade one level (with a 600ms `animatingCell` pulse); different level → swap; empty destination → move. Own `recalcBoardIsFull()`, own early `return`. Explicitly commented as the one exception to the file's "always recalc after an occupancy change" rule (see the comment at 1788–1791) — a real, load-bearing bug-shaped subtlety, not incidental. |
| **Superpower piece spent** | 1801–1812 | `srcItem.chain?.category == .superpower` and a `dstItem` exists → delegates to `applySuperpowerMerge`, which returns a `Bool`. Skips score/XP/bubble/`checkSuperpowerUnlock` entirely — a deliberately separate pipeline from a normal merge. |
| **Wildcard/animal merge** | 1813–1899 | The big one. Eligibility check (wildcard adopts the other item's identity; same-chain-same-tier otherwise) → on success: score (with spotlight multiplier), XP, top-tier celebration *or* bubbling, `mergeCount`/`lastMergeTimestamp`/`lastMergedSpeciesRaw`, `recalcBoardIsFull()`, `updateAllAfterMerge` (→ tier-unlock check, quest/daily-challenge progress ×2 if Hedgehog superpower is active, order progress, spotlight reward payout), `checkSuperpowerUnlock`, `applyPassivePowers`, then **two more branches** for what happens to the merged tile itself: completed sub-object → maybe grants a superpower piece to inventory instead of leaving the tile; power-up-category or completed-sub-object → rolls rarity (if applicable) and moves the tile to power-up inventory. Ends with the 600ms animation pulse and captures `preMoveSnapshot` (Nine Lives undo) — captured **after** all these mutations, deliberately, since assigning it earlier would self-invalidate via `board`'s `didSet` (comment at 1828–1831). |
| **Ineligible pair** | 1896–1899 | Plain item swap, no side effects, no `recalcBoardIsFull()` (occupancy didn't change). |
| **Empty destination** | 1900–1904 | Plain move, `recalcBoardIsFull()`. |

**Side-effect surface reached from the merge branch alone:** `score`, `grantXP`, `mergeCount`, `lastMergeTimestamp`, `lastMergedSpeciesRaw`, `quests` (four distinct call sites across `updateAllAfterMerge`), `adoptionBoardCoordinator` (via `updateOrdersAfterMerge`), `kibbleEngine` (spotlight reward payout), `deepestUnlockedTier`/`checkTierUnlock()`, `unlockedSuperpowerSpecies`/`showSuperpowerUnlockBanner`, `inventoryStore` (power-up/superpower-piece routing), `SoundManager`, `HapticManager`, `enqueueToast`, `animatingCell`, `preMoveSnapshot`. This is not a board-mutation function that happens to also touch a few other things — board mutation is a minority of what it does.

**Zero test coverage.** Confirmed again while writing this doc — `PawSanctuaryTests/` has no `BoardStateManagerTests.swift` (flagged as worth writing in the Phase B entry, never done) and nothing exercises `attemptMergeOrMove` directly. Every verification of merge behavior across Phases B/C was live-simulator testing, never automated.

## 2. Why this needs its own resolution pass, not just "apply the Phase C pattern"

Phase C's primitive-routing pattern (swap `board[pos.row][pos.col].x` for `boardState.x(at: pos)`) doesn't fit here, and applying it directly would be a distraction. The point of `MergeResult` is that this function stops *performing* mutations and side effects inline and instead **computes and returns a description of what should happen**, which something else applies. If that redesign happens, routing the interim direct-`board[...]` reads through primitives first is churn that gets thrown away, not a stepping stone — worth deciding explicitly rather than defaulting into it.

The five-branch shape in §1 also means "rewrite `attemptMergeOrMove`" undersells the task. A `MergeResult` type needs to represent producer upgrades, producer swaps, producer moves, superpower-piece consumption, animal merges (with two further sub-outcomes for where the merged tile ends up), item swaps, and plain moves — seven-ish shapes, not one.

## 3. Open design questions — resolve these before writing code

These are genuine decisions, not implementation details, and this doc isn't the place to unilaterally settle them:

1. **`MergeResult`'s shape.** An `enum` with associated values per outcome (producer branches / superpower-piece / merge / swap / move) reads as the natural fit given §1's table — but the merge outcome alone carries ~15 fields' worth of effects (score, XP, quest updates, tier unlock, superpower unlock, inventory routing, toast, sound/haptic, animation, snapshot). Does that become one large associated-value payload, a nested sub-enum, or does `MergeResult` stay thin and the merge case carries a smaller "what changed" struct that a dispatcher expands? Worth sketching two or three concrete shapes against the table in §1 before picking.
2. **Where dispatch lives.** Presumably a new `apply(_ result: MergeResult)` on `MergeBoardViewModel` that fans effects out to `kibbleEngine`/`quests`/`adoptionBoardCoordinator`/`progression`/`inventoryStore`/etc. — mirroring how `apply(_ s: GameState)` already fans `GameState` out to the seven sub-coordinators. Is that the right model, or does each sub-coordinator get a `handle(_ result: MergeResult)` of its own and `MergeBoardViewModel` just loops over them?
3. **The Nine Lives snapshot's timing.** `preMoveSnapshot` is captured *after* mutation today specifically to dodge `board`'s `didSet` self-invalidating it (§1, merge branch). If merges become "compute a result, then apply it," does the snapshot get taken in the *compute* step (before any real mutation happens, which is more natural but changes the invalidation-guard's semantics) or does `apply` still need the same post-mutation-but-before-didSet-fires care the current code has? Get this wrong and Nine Lives undo silently breaks or silently never invalidates.
4. **Async UI timing isn't result data.** The 600ms `animatingCell` pulse (`Task { try? await Task.sleep(...); self.animatingCell = nil }`) appears twice and is a view-timing concern, not something a `MergeResult` value should carry. Decide up front that `apply(_:)` triggers it as a side effect of certain result cases, rather than trying to model "wait 600ms" as data.
5. **Producer branch's own exception.** §1 flagged that the producer branch's `recalcBoardIsFull()` timing is deliberately *not* "always recalc" — it's there so a later spawn can overwrite a producer the player just placed. Any `MergeResult` design has to preserve this exact ordering guarantee, not just the producer-move outcome in the abstract. This is the kind of subtlety a characterization test (§4, D0) should pin down before the rewrite, precisely because it's easy to lose in a redesign.
6. **Is `computeMergeResult` allowed to read `ContentRegistry`/`cachedActiveBonuses`/quest state, or must it be pure over board state alone?** The merge branch's score multiplier depends on `quests.spotlightChainID` and `cachedActiveBonuses.spotlightMultiplierBonus` — external state, not board state. A "pure function of the board" framing doesn't quite work; decide what inputs the compute step is actually allowed, since that determines how unit-testable it really ends up being.

## 4. Proposed phasing — draft, for discussion

Each phase independently shippable and playable at every commit, per `CLAUDE.md` rule 2 — same discipline B/C already used.

- **D0 — characterization tests for current behavior.** Write tests against *today's* `attemptMergeOrMove`, not the redesigned version, so there's a regression net before anything moves. The live-verified scenarios already catalogued across Phase C rounds (Aquatics Current sliding a sub-object, Splitter's tier-drop-plus-placement, Stampede's cascade, wildcard adoption, bubble-eligible vs. bubble-skip merges, the producer-upgrade/swap/move trio, the sub-object-completion and power-up-completion inventory routing) are a ready-made source of cases — they were exercised by hand once each; turning them into `XCTest` cases is mostly transcription, not new test design. This is the single highest-leverage step and has zero dependency on any design question in §3 being resolved first.
- **D1 — introduce `MergeResult` and a pure `computeMergeResult(from:to:) -> MergeResult` alongside the existing code**, not wired into `attemptMergeOrMove` yet. Unit-testable in isolation once §3.1/§3.6 are settled. The old function keeps running in production during this phase — nothing player-facing changes.
- **D2 — one commit** swapping `attemptMergeOrMove`'s body to call `computeMergeResult` and dispatch through `apply(_:)`. This is the actual cutover and the highest-risk single commit in the whole extraction — D0's characterization tests are what make it safe to take.
- **D3 — cleanup.** Remove the now-dead inline logic left behind by D2, and only *then* consider routing any remaining direct `board[...]` access through `BoardStateManager` primitives, if any survive the rewrite in a form that still needs it.

## 5. Non-goals

This doc does not resolve §3's open questions, does not touch `MergeBoardViewModel.swift` or any other source file, does not change merge rules or economy values, and does not extend to the producer branch's UX. It also doesn't commit to the D0–D3 phasing above as final — that breakdown is a starting proposal for discussion, same as this whole doc.

---

## Appendix — branch inventory (15 August 2026, current line numbers)

Verified by direct reading of `MergeBoardViewModel.swift:1762–1905`, not a scan script (unlike the Phase A appendix, which covered the whole class — this is one function, small enough to read in full and worth re-verifying by eye rather than trusting a regex against its nested-conditional shape).

- **1762–1766:** Guard — `from != to`, destination in bounds, both cells unlocked. Direct `board[...].isUnlocked` reads, ×2.
- **1768–1795:** Producer branch (see §1 table). Direct `board[...].producer` reads/writes throughout. Early `return` at 1794.
- **1797–1798:** Guards — source item exists and isn't bubbled; destination has no producer (producer branch above already returned if it did, but a *different* cell's producer state isn't re-checked without this).
- **1800–1899:** `if let dstItem = board[to.row][to.col].item` — the two occupied-destination outcomes:
  - **1801–1812:** superpower-piece-spent sub-branch, delegates to `applySuperpowerMerge` ([MergeBoardViewModel.swift:2632](../PawSanctuary/MergeBoardViewModel.swift#L2632)).
  - **1813–1895:** eligible-merge sub-branch — the full effect list in §1's table. Calls out to `updateAllAfterMerge` ([:2486](../PawSanctuary/MergeBoardViewModel.swift#L2486)), `checkSuperpowerUnlock` ([:2524](../PawSanctuary/MergeBoardViewModel.swift#L2524)), `applyPassivePowers` ([:2569](../PawSanctuary/MergeBoardViewModel.swift#L2569)), `rollRarityForCompletedSubObject`, `maybeGrantSuperpowerPiece`.
  - **1896–1899:** ineligible-pair else — plain swap.
- **1900–1904:** Empty-destination branch — plain move, `recalcBoardIsFull()`.

**Referenced but out-of-scope for this function's own rewrite** (called into, not migrated as part of Phase D unless a design question in §3 says otherwise): `applySuperpowerMerge`, `updateAllAfterMerge`, `checkSuperpowerUnlock`, `applyPassivePowers`, `updateOrdersAfterMerge`, `maybeBubbleMergedItem`, `triggerTopTierCelebration`, `grantXP`, `checkTierUnlock`.

**`BoardSnapshot`** ([MergeBoardViewModel.swift:99](../PawSanctuary/MergeBoardViewModel.swift#L99)) — `{ board: [[BoardCell]], inventory: [BoardItem?] }`, session-only (not persisted), backs Nine Lives undo. `board`'s computed-property `didSet` ([:143–150](../PawSanctuary/MergeBoardViewModel.swift#L143)) invalidates `preMoveSnapshot` on any board write after it's set — the mechanism §3.3 is about.
