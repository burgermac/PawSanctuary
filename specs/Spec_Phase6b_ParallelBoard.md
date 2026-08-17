# PawSanctuary — Phase 6b: Parallel Board (third event type)

**Self-contained brief.** Assumes no prior conversation. Follows the Milestone track (`486973c`…`efd5402`, merged `afd2b02`) and the Pass (`92bdfae`…`064cd02`, merged `ef1d080`) — both now design-reviewed and live.

> **Not atomic, and larger than its two predecessors.** Suggested landing order in §3 — land as separate commits, verify each on screen before the next, stop if one resists. Read §0 before starting: this task has five "found while reading the code" items, not the original four (§0.5 added 16 Aug 2026). Two of the five were genuinely open architectural decisions — §0.1/§3.1 (`ParallelBoardHosting`'s fate) and §0.5 (registry placement) — **both decided by the design authority 16 Aug 2026**, retire and separate-registry respectively. §3 is now actually startable.

**DRAFT — written cold by Claude Code at the user's request, not yet reviewed by the design authority.** Per the Alignment Plan's working method (§2), specs are supposed to originate in the design conversation. No such spec existed for this task, matching the precedent set for Pass. **A technical-accuracy pass has now been done** (15 Aug 2026, mirroring Pass's own `b9c8a5b`) — every existing-file citation checked against current source (all accurate as written), and three real internal problems found and fixed: §5's original test-event dates collided with the event they were meant to avoid colliding with (Adoption Drive and Founders' Circle leave no open window between them at all — corrected to after Founders' Circle ends); §3.3's generator mechanic never specified how the generator cell would actually be distinguished from a normal one (fixed with an explicit `generatorPosition`); and §2's target-shape table overstated "Progress / reward" as a full drop-in reuse, contradicting §3.5's own correct finding that only the storage half reuses cleanly (table split accordingly). This pass verifies the plan is internally consistent and its existing-code claims are accurate — it is not the design-authority review the working method calls for, and most of what this doc proposes is still new code with no implementation to check it against yet.

**Re-scoped 16 Aug 2026, after the concurrent-events prerequisite and the real 90-day calendar both shipped and were design-reviewed.** Both were flagged in this very draft (§1) as blocking work due before 6c — they're done now, on `main`. Re-verified every citation in this doc against current source (all still accurate, though several line numbers moved — corrected below) and found one genuinely new problem the 15 Aug pass couldn't have known about, since the code it concerns didn't exist yet: **§0.5**, a real UI collision this event type would hit if built exactly as originally planned. Also updated §1/§5 — the single-active-event constraint that shaped this doc's original scheduling logic no longer exists, which changes what the test event's dates should optimize for. See the annotations inline below (marked "16 Aug update").

**Both open architectural forks decided the same day (design authority):** §0.1/§3.1 — retire `ParallelBoardHosting` rather than expand it. §0.5 — a separate registry for parallel-board events rather than an `EventDefinition` kind discriminator. Both were the option this doc's own analysis leaned toward; neither was decided unilaterally by the doc itself. With both resolved, §3's landing order is unblocked — §3.1 (now a deletion, not a decision) is still the correct first task, since nothing downstream should be written against the protocol it retires.

---

## 0. Why

Per the Alignment Plan §9 (Phase 6b) and the Blueprint (`specs/Merge2_Reference_Blueprint.md:342`): *"parallel board (own board, chains, energy, offers — highest revenue, most expensive)"* — a 3–4 day event type, the third and last of D5's three committed 6b event types alongside Milestone track and Pass. The Feature Parity Audit (`specs/Feature_Parity_Audit.md:60`) describes the observed reference shape more fully: *"a complete second mini-game (e.g. 'Petal Talk') — own board, generators, chain, currency, progress track, 36h duration."*

This is a materially bigger build than its two predecessors. Milestone track and Pass both reused an *existing* board (the player's one board) and an *existing* progress primitive (`ProgressTrack`) — their whole job was wiring a new lane or a new faucet onto machinery that already existed. Parallel Board's defining feature, per its own name, is a **second board** — nothing in the shipped game has ever had two of those, and until this session's Phase D work, the pieces a second board would need weren't clearly separable from the first one at all.

### Five things found while reading the code that change this task's shape, flagged before the plan below (four on 15 Aug, one more on 16 Aug)

#### 1. `ParallelBoardHosting` is a stub protocol, not a real interface

```swift
@MainActor
protocol ParallelBoardHosting {
    func makeBoard(eventID: String) -> UUID
    func teardownBoard(eventID: String)
    func energyBalance(eventID: String) -> Int
}
```

(`LiveOpsPrimitives.swift:80-84` — line shifted by 1 since this was last checked, content unchanged, re-verified 16 Aug 2026.) This is UUID bookkeeping and a read-only energy query — no board-grid ownership, no chain authority, no way to credit/debit energy, no way to place or merge an item. `ParallelBoardStub` (`LiveOpsEngine.swift:759-774` as of 16 Aug 2026 — moved from its 15 Aug citation of `:400-415` by the calendar spec's ~350 lines of new content earlier in the same file; re-verify the line number again before relying on it, the content itself is unchanged) conforms to exactly this and nothing more, and its own doc comment already says so: *"Not the Phase 6b 'Parallel board' event type... The real second board... is its own spec, deferred to 6b."* This task **is** that deferred spec, and it means designing the real interface, not implementing against one that already fits.

#### 2. `BoardStateManager` is cleanly reusable as a second instance — but `MergeBoardViewModel`'s merge resolution is not. This is a real decision, not a detail.

`BoardStateManager` (`BoardStateManager.swift`) is a self-contained `@Observable @MainActor` class: `board: [[BoardCell]]`, `boardIsFull`/`emptyUnlockedCells`, and ten `GridPosition`-keyed read/write primitives — zero references to `MergeBoardViewModel` or any other coordinator. Nothing about it assumes there's only ever one instance. **A second `BoardStateManager()` for the parallel board's own grid is a clean, direct reuse** — a genuine, unplanned payoff of Phase B/C's extraction (`specs/BoardStateManager_Extraction_Plan.md`), which was built for a single-board cleanup and turns out to also be exactly the reusable unit a second board needs.

The merge *resolution* logic is a different story. `attemptMergeOrMove`/`apply(_ result: MergeResult)`/`applyMergeOutcome(_:)` (`MergeBoardViewModel.swift`, Phase D — `specs/BoardStateManager_Phase_D_Plan.md`) are entangled with main-board-only state: `quests`, `cachedActiveBonuses`, `inventoryStore`, `progression`, superpower pieces, sub-object/power-up completion routing, the Nine Lives snapshot. None of that belongs on a 3–4 day side event with its own, much simpler content. **Decision: the parallel board does not reuse `MergeBoardViewModel`'s merge resolution, and does not get a second full `MergeBoardViewModel`-shaped orchestrator.** It gets its own, deliberately smaller resolution path — see §0.3.

#### 3. `computeMergeOutcome` (Phase D) is directly reusable for the parallel board's merge *decision* — this is the finding that makes §0.2's "don't duplicate everything" call affordable

```swift
func computeMergeOutcome(
    from: GridPosition, to: GridPosition,
    srcItem: BoardItem, dstItem: BoardItem,
    spotlightChainID: ChainID, spotlightMultiplierBonus: Int,
    orders: [AdoptionOrder], urgentOrder: AdoptionOrder?, activeQuests: [Quest]
) -> MergeOutcome?
```

(`MergeOutcome.swift`.) This function is already pure and already content-agnostic — it doesn't hardcode anything about the *main* board specifically, only about the general shape of a merge (same-chain-same-tier or wildcard-adopts, is the destination already bubbled, is it already top tier). It takes the main board's spotlight/order/quest state as **explicit parameters**, not by reaching into `self` — which was Phase D §3.6's own resolution, made for testability, and turns out to double as exactly what a second caller needs. The parallel board can call this same function with neutral inputs (`spotlightChainID` set to a value that never matches its own chain IDs, `spotlightMultiplierBonus: 0`, empty `orders`/`urgentOrder`/`activeQuests` so `isBubbleEligible` always reads `false`) and get the identical, already-tested eligibility/tier-advance decision the main board uses. What differs is what happens with the `MergeOutcome` once computed — the parallel board needs its own, much smaller `apply` step (§3.4), not `applyMergeOutcome`'s full cascade.

**Load-bearing precondition this reuse depends on, worth stating explicitly rather than leaving implicit:** `computeMergeOutcome` resolves identity and tier-advancement via `ContentRegistry.shared` (`srcItem.chain`, `ContentRegistry.shared.nextTier(...)`, `ContentRegistry.shared.tier(...)`). If the parallel board's chain (§4) is never actually added to `ContentRegistry.shared.chains`, none of that fails loudly — `chain` resolves to `nil`, `nextTier` returns `nil`, `computeMergeOutcome` returns `nil` for every pair, and `attemptMerge` (§3.4) silently falls to its swap branch forever. A board that never merges, with no error and no obvious reason why. Registering the chain isn't optional groundwork before this reuse works — it's the thing that makes it work at all.

#### 4. `ProducerTile`/`ProducerLevel` are main-board-specific and a poor fit for the parallel board's generator

`ProducerLevel` (`AnimalSpecies.swift:287-416`) is a single global enum carrying `dogTagCost`, `storageUnlockLevel`, per-species `familySpawner` logic, shop-tier gating — all main-economy concerns that don't apply to a 3–4 day side event. Adding parallel-board-specific cases would either pollute that enum with fields that must be neutralized for every existing case, or force the parallel board's generator through a shop/storage/species model it doesn't need. **Decision: the parallel board's generator is not a `ProducerTile` at all** — see §2/§3.3 for what it is instead.

#### 5. New (16 Aug 2026): a real UI collision this event type would hit today, that didn't exist when the rest of this doc was written

Since this doc's last pass, Phase 6c's prerequisite (`Spec_Phase6c_ConcurrentEvents.md`) and the real 90-day calendar (`Spec_Phase6c_Calendar.md`) both shipped. Concretely, `TaskStripView` (`PanelViews.swift:1653`) now renders `ForEach(viewModel.activeEvents)` — **every** `EventDefinition` currently active, unconditionally — as an `EventTaskCard`, and tapping any of them routes through `TaskSheet.event(String)` → `MergeBoardView`'s `routeContent` (`MergeBoardView.swift:571`) → `EventSheetView` (a milestone-lane sheet — rows, progress bars, claim buttons, per §3.6 below).

**If a parallel-board `EventDefinition` is simply added to `EventRegistry.allEvents`, as §5's task literally instructs, two things go wrong simultaneously, both silent:**
1. It gets an *automatic*, unwanted `EventTaskCard` in the strip (small card, milestone-style), duplicating whatever dedicated full-screen entry point §3.6 builds for it.
2. Tapping that automatic card opens `EventSheetView` — which, per §3.6's own finding, **cannot render a board**. Best case it shows an empty/broken milestone list for an event with no `EventMilestone`s (`milestones: []`, the established convention for every Phase 6b+ event); worst case it's just visually confusing — a second, wrong way to "open" an event that's actually a full-screen board.

This isn't a flaw in the concurrent-events work — that work correctly assumed every `EventDefinition` wants the same small-card/milestone-sheet treatment, because until this event type, all of them did. Parallel Board is the first one that doesn't, and the assumption was never tested against a board-shaped event because one didn't exist yet.

**Decided 16 Aug 2026 (design authority): (b), a separate registry.** Keep the parallel-board event entirely out of `EventRegistry.allEvents`. It gets its own small, parallel registry — reusing `EventScheduler`'s already-injectable `events:` parameter, exactly what that parameter is for — and its own `checkEventLifecycle()`-style lifecycle hook, independent of the main one. Zero risk to the now-stable `ForEach`/`TaskSheet.event` pipeline the concurrent-events work just finished stabilizing, at the accepted cost of a second, structurally similar scheduling path to maintain. Confirms what §3.6's original phrasing ("`viewModel.activeParallelBoardEvent` (or equivalent)," singular, separate from the main list) already implied the original draft was leaning toward, even before this collision was identified as the reason to lean that way. The rejected alternative — a `kind` discriminator on `EventDefinition`, filtering the shared `activeEvents`/`ForEach` — would have been cheap in isolation but touched exactly the code this project just finished stabilizing; not worth it once a clean separate-registry option existed.

**This also settles part of §3.7:** the parallel-board lifecycle hook this decision requires is a natural home for whatever `checkEventLifecycle()`-equivalent call `ParallelBoardCoordinator` creation/teardown needs — one new hook, not two.

---

## 1. Decisions this depends on

- **D5 (cadence):** the reference observation is 3–4 days generally, 36h specifically for parallel board (`Feature_Parity_Audit.md:60`). This task's test event (§5) runs 3 days, inside that window.
- **The single-active-event gap this doc flagged a third time (Milestone track §7, Pass §0, here) is now resolved — 16 Aug update.** `EventRegistry.currentEvent` is untouched, but `EventRegistry.activeEvents`/`checkEventLifecycle()`/the UI all now correctly support N genuinely-overlapping events (`Spec_Phase6c_ConcurrentEvents.md`, shipped and design-reviewed 16 Aug 2026), and the real calendar (`Spec_Phase6c_Calendar.md`, same day) now schedules real content through 2026-12-03. This changes what §5's test-event scheduling should optimize for: it no longer needs to dodge into a gap between other events — there is no gap to find, `EventRegistry.allEvents` now has 20 entries spanning nearly continuously through early December. The test event can simply overlap the real calendar, and arguably *should* — deliberately overlapping a real weekly event and a real Season would be a genuine three-way concurrency proof nothing has exercised yet (the calendar's own tests proved at most 2 simultaneously active; a parallel-board event sharing a window with both would be 3). See §5's update below. This doesn't retire §0.5's new UI-collision finding above — that's a separate problem, about *which* events get the small-card treatment, not about *when* they're scheduled.
- **D8 (chain offer):** not load-bearing here — D8's variant builds on the Pass primitive, not this one.

---

## 2. Target shape

| Piece | Source | This task's job |
|---|---|---|
| Second board grid | `BoardStateManager` (existing, reused as-is) | Instantiate a second one, owned by a new coordinator (§2.1) |
| Merge decision | `computeMergeOutcome` (existing, reused as-is) | Call with neutral spotlight/order/quest inputs |
| Merge application | **New** | A small `apply`-equivalent: write the board, advance the event's `ProgressTrack`, no XP/score/quest/superpower cascade |
| Generation mechanic | **New** | Not a `ProducerTile` — see §3.3 |
| Own currency | **New** — `ParallelBoardEnergy` | A lightweight regen pool, deliberately smaller than `KibbleEngine` (§3.2) |
| Progress storage/claim | `ProgressTrack` (existing, reused as-is) | None — genuinely a drop-in reuse |
| Token-earning trigger | **Not** `EventTokenRiderProvider` — see §3.5 | New: merge-completion-triggered, not order-fulfillment-triggered (§3.5 corrects an earlier draft of this table, which listed the rider provider here too) |
| `ParallelBoardHosting` | **Retired** (§3.1) | Delete `ParallelBoardHosting`/`ParallelBoardStub`; `MergeBoardViewModel` holds `ParallelBoardCoordinator` directly |
| Event scheduling | **New, separate from `EventRegistry`** (§0.5) | A small parallel registry + lifecycle hook — not a row in `EventRegistry.allEvents` |
| UI | **New** — a dedicated full-screen board view | Cannot reuse `EventSheetView` (a milestone-lane sheet, not a board renderer) |

### New coordinator: `ParallelBoardCoordinator`

Owns one event's worth of second-board state — mirrors the existing seven-sub-coordinator composition pattern `MergeBoardViewModel` already uses (`kibbleEngine`, `inventoryStore`, `quests`, …), not a new architecture:

```swift
@Observable
@MainActor
final class ParallelBoardCoordinator {
    let eventID: String
    let boardState = BoardStateManager()
    var energy = ParallelBoardEnergy()          // §3.2
    let generatorPosition = GridPosition(row: 0, col: 0)   // §3.3

    init(eventID: String, chainID: ChainID) {
        self.eventID = eventID
        boardState.board = ParallelBoardCoordinator.freshBoard(chainID: chainID)
    }

    func attemptMerge(from: GridPosition, to: GridPosition) { /* §3.4 */ }
    func collectFromGenerator() { /* §3.3 */ }
}
```

One instance per active parallel-board event, created when the event starts and discarded (not persisted past) when it ends — matching `ParallelBoardHosting.teardownBoard(eventID:)`'s existing name and intent, just with a real type behind it now. Whether this needs any persistence at all before teardown is an open question — see §3.7.

---

## 3. Tasks, suggested landing order

### 3.1 — `ParallelBoardHosting`'s fate: retired

**Decided 16 Aug 2026 (design authority): retire the protocol entirely.** `ParallelBoardHosting`/`ParallelBoardStub` (`LiveOpsPrimitives.swift`/`LiveOpsEngine.swift`) are dead code once this lands — delete both, along with any other reference. `ParallelBoardCoordinator` (or, per §0.5's decision, a small registry of them) is held directly by `MergeBoardViewModel`, the same way `kibbleEngine`/`quests`/etc. already are — no protocol indirection.

Reasoning, kept for the record: the protocol was written in Phase 1 (`LiveOpsPrimitives.swift:5-7`, *"protocols and value types only, no implementations... so Phase 6 has a target"*) before any of the other seven primitives' real shapes were known either — and unlike `TokenWalleting`/`ProgressTracking` (both of which turned out to match their real implementations closely), this one didn't survive contact with what a real second board actually needs (UUID bookkeeping and a read-only energy query, versus the credit/debit/board-ownership surface a real coordinator needs). Its only value was "give Phase 6 a target before Phase 6 existed," and Phase 6 is here now with a concrete, better-informed shape available — the rejected alternative (expanding the protocol to match, keeping `ParallelBoardStub`'s conformance) would have kept an abstraction layer with no remaining reason to exist.

**This lands first**, before any other §3 task — nothing downstream should be written against the retired protocol's shape.

### 3.2 — `ParallelBoardEnergy`: a lightweight regen pool

Not a second `KibbleEngine`. `KibbleEngine` (`KibbleEngine.swift`) carries player-level-tied bonus caps (`effectiveRegenCap`), an ad-refill wall, and offline-progress catch-up (`applyOfflineProgress`) — real, tested, but built for a resource that has to last the entire game, not one scoped to a 3-day event. First cut:

```swift
@Observable
@MainActor
final class ParallelBoardEnergy {
    var balance: Int = parallelBoardEnergyCap
    var secondsUntilNext: Int = parallelBoardEnergyRegenSecs

    func tick() {
        guard balance < parallelBoardEnergyCap else { return }
        secondsUntilNext -= 1
        if secondsUntilNext <= 0 {
            balance = min(parallelBoardEnergyCap, balance + 1)
            secondsUntilNext = parallelBoardEnergyRegenSecs
        }
    }

    @discardableResult
    func spend(_ amount: Int) -> Bool {
        guard balance >= amount else { return false }
        balance -= amount
        return true
    }
}
```

Ticked from the same foreground timer loop `MergeBoardViewModel` already runs for `kibbleEngine.tick(...)` — not a new timer. **Deliberately no offline-progress catch-up in this first cut** — energy simply doesn't advance while the app is backgrounded, unlike kibble. Flagged explicitly as a first-cut simplification, not an oversight: `KibbleEngine.applyOfflineProgress` is real, tested logic this doc isn't proposing to duplicate for a resource that only needs to work correctly for one 3-day window before it's discarded. Revisit if playtesting shows players resent losing regen time to backgrounding.

### 3.3 — Generation mechanic (not a `ProducerTile`)

Per §0.4, no new `ProducerLevel` case. Simplest mechanic that still reads as "a generator": the board's own grid only holds `BoardCell`s (there's no other type it could hold), so the generator isn't a distinct cell *type* — it's an **ordinary cell at a fixed, known position**, tracked by the coordinator, not by anything in the cell's own data:

```swift
let generatorPosition = GridPosition(row: 0, col: 0)   // fixed for the event's lifetime
```

The UI queries `coordinator.generatorPosition` to render that one cell with generator chrome (an icon/border, not a normal empty-or-occupied cell) instead of inferring specialness from the cell's own contents. `collectFromGenerator()` always targets this fixed position: spend `parallelBoardGeneratorCost` energy, place a fresh base-tier item of the event's chain on a random *other* empty cell (never onto `generatorPosition` itself, which must stay clear for the next generation) — mirrors `placeFreeTile`'s existing "find an empty cell, place an item" shape (`MergeBoardViewModel.swift`, already `BoardStateManager`-primitive-backed) without needing a producer struct, a cooldown, or a species field none of which apply here.

### 3.4 — Merge resolution: reuse the decision, write a small new application step

`ParallelBoardCoordinator.attemptMerge(from:to:)`:

```swift
func attemptMerge(from: GridPosition, to: GridPosition) {
    guard from != to,
          boardState.isUnlocked(at: from), boardState.isUnlocked(at: to),
          let srcItem = boardState.item(at: from) else { return }
    guard let dstItem = boardState.item(at: to) else {
        boardState.setItem(srcItem, at: to)
        boardState.clearItem(at: from)
        boardState.recalc()
        return
    }
    if let outcome = computeMergeOutcome(
        from: from, to: to, srcItem: srcItem, dstItem: dstItem,
        spotlightChainID: "parallelboard.none", spotlightMultiplierBonus: 0,
        orders: [], urgentOrder: nil, activeQuests: []
    ) {
        boardState.setItem(BoardItem(chainID: outcome.resultChainID, tier: outcome.resultTier), at: to)
        boardState.clearItem(at: from)
        boardState.recalc()
        if outcome.isTopTierCompletion {
            // award the event's ProgressTrack — see §3.5
        }
    } else {
        boardState.setItem(srcItem, at: to)
        boardState.setItem(dstItem, at: from)
    }
}
```

No producer branch (nothing on this board is a producer, per §3.3), no superpower branch (the event's chain has no superpower pieces), no bubbling (`orders`/`activeQuests` passed empty guarantees `isBubbleEligible` is always `false`, so nothing needs to check for it), no Nine Lives snapshot (a 3-day side board doesn't need an undo guard the main board itself only added for its own economy's protection). This is intentionally a fifth of `attemptMergeOrMove`'s size — the whole point of §0.2/§0.3's decision.

### 3.5 — Progress / reward hookup

The *storage* half is a genuine drop-in reuse: a `ProgressTrackRegistry.tracks` entry (§5) is the only new data `ProgressTrack` needs. The *earning* half isn't — `EventTokenRiderProvider` can't be reused a third time here, since its whole mechanism is "attach a bonus to a fraction of newly-generated orders," and the parallel board isn't where orders happen. Simplest first cut: award event tokens directly from `attemptMerge`'s `isTopTierCompletion` branch above (a fixed amount per completed item, no rider/random-chance layer needed since the parallel board's own merges are already the throttle) — a new, small trigger, not a reuse of the order-rider pattern. Reconsider if this reads as too fast/slow in play — same "retune the anchor, not the thresholds" guidance Milestone/Pass's own §4 gave.

### 3.6 — UI: a dedicated full-screen board view

`EventSheetView` (`EventPanelView.swift`) is a milestone-lane sheet — rows, progress bars, claim buttons. It cannot render a board; nothing about it was built to. This needs new SwiftUI, structurally similar to `MergeBoardView`'s own board-rendering code (`CellView.swift` renders one `BoardCell`; worth checking during implementation whether that view is already decoupled enough from `MergeBoardViewModel` specifically to reuse directly against a `ParallelBoardCoordinator`'s `boardState`, or whether it needs a protocol/generic seam first — not resolved here, a real implementation question for whoever picks this task up). Presented full-screen (not a sheet, matching the reference's "complete second mini-game" framing), entered from a new `EventTaskCard`-style entry point (`PanelViews.swift:1327` as of 16 Aug 2026, was `:1309`) added to `TaskStripView` (`PanelViews.swift:1653` as of 16 Aug 2026, was `:1635`) when `viewModel.activeParallelBoardEvent` (or equivalent) is non-nil.

**16 Aug update — confirmed, not just hedged.** §0.5 resolved toward the separate registry: this section's plan (a dedicated entry point, `viewModel.activeParallelBoardEvent` or equivalent, entirely apart from the `ForEach(viewModel.activeEvents)` block) was already correct as originally written. Since it never participates in `EventRegistry.allEvents`, it never reaches `TaskStripView`'s generic `ForEach` or `TaskSheet.event`/`EventSheetView` at all — no filtering-out needed, because it was never in.

### 3.7 — Event lifecycle: creation and teardown

`ParallelBoardCoordinator` is created when the event starts and torn down when it ends — mirrors `checkEventLifecycle()`'s existing rider-registration pattern (`MergeBoardViewModel.swift`). **Open question, not resolved here:** does the board's contents need to survive a force-quit/relaunch mid-event, the way the main board and `ProgressTrack`/`TokenWallet` state already do via `GameState`? If yes, this needs its own `GameState` fields and a schema bump (v31 → v32), following the exact precedent Pass's §3.2 set. If the event is short enough and the board small enough that losing in-progress placement on a rare force-quit is an acceptable first-cut loss (matching how this doc's other simplifications are framed), that's a real, cheaper option — but it should be a stated decision, not a default nobody chose.

---

## 4. First-cut numbers — flag before trusting

Same posture as Milestone track's and Pass's own §4: **no economy model was run for these.** Genuinely more speculative than either predecessor's, since there's no existing mechanic to scale a rider frequency from — this is estimation from the reference's bare description, not derived from anything already tuned in this codebase.

- **Board size:** 5×5 (25 cells), fully unlocked from the start — no row-progression the way the main board has; the event is short enough that gating rows would just be friction, not pacing.
- **Energy:** cap 30, regen 1 per 90s (a full refill in 45 minutes) — a deliberately faster cadence than main-board kibble's, since the whole board resets in 3 days and shouldn't feel gated by a slow-recovering resource for most of that window.
- **Generator cost:** 2 energy per tap (15 generations per full energy bar).
- **Chain:** 5 tiers, single chain, one new `ChainCategory` case or reuse `.animal` with a distinct ID prefix (`parallelboard.<theme>`) — not resolved here, a content-authoring call for whoever picks this up.
- **Progress track:** reuses §4's Founders' Circle shape as a template — free lane only for this first cut (no paid lane; that's the Pass event type's differentiator, not this one's), 8 milestones, linear thresholds.

**This entire section is a placeholder for the design authority to replace, not a designed event.** More provisional than Milestone/Pass's own numbers were, for the reason stated above.

---

## 5. Task — one screen-verifiable test event

**16 Aug update — dates below are stale, kept for the record; see the recommendation that follows.** The original **2026-09-04 to 2026-09-07** proposal was chosen to dodge into the one open gap that existed when this was written. That gap no longer needs dodging (§1) — worse, 2026-09-04 is now the literal start date of two real, named calendar events (`sanctuary_circle_s1_20260904`, `rescue_relay_20260904`), so reusing it verbatim would be needlessly confusing even though it wouldn't be technically wrong.

**Recommended instead (not mandated — a scheduling call the design authority can freely override): 2026-09-11 to 2026-09-14** (3 days, D5-cadence-compliant). This sits inside Sanctuary Circle Season 1 (2026-09-04→10-04) *and* fully overlaps Playtime Rush's second weekly instance (`playtime_rush_20260911`, 2026-09-11→09-15) — a deliberate three-way concurrency case (continuous Pass + weekly event + parallel-board event, all genuinely active at once) that proves something the calendar's own tests didn't need to: that a *third* kind of event layers onto the existing two without incident. Whatever §0.5 decides about registry placement, this is the date window to use once the event is actually schedulable. `ProgressTrackRegistry.tracks[thisEvent.id]` gets the free-lane-only 8-milestone table from §4.

This is test-only content to prove the second-board flow end to end — not 6c's real rolling calendar, matching the identical framing Milestone track's and Pass's own §5 used.

---

## 6. Acceptance

- [x] §3.1 decided (16 Aug 2026, design authority): retire `ParallelBoardHosting`. Remaining acceptance: `ParallelBoardHosting`/`ParallelBoardStub` are deleted, not just unused, and nothing else in the codebase still references either
- [x] §0.5 decided (16 Aug 2026, design authority): separate registry, not a `kind` discriminator. Remaining acceptance: parallel-board events never appear in `EventRegistry.allEvents`/`activeEvents`, never produce an automatic `EventTaskCard`, and tapping the dedicated entry point opens the board directly, never `EventSheetView`
- [ ] `ParallelBoardCoordinator` owns an independent `BoardStateManager` — verify by placing items on both boards simultaneously and confirming neither's state leaks into the other
- [ ] `ParallelBoardEnergy` regenerates on the existing foreground timer tick, caps correctly, and `spend(_:)` correctly rejects an insufficient balance
- [ ] The generator cell places a fresh base-tier item on a random empty cell for `parallelBoardGeneratorCost` energy, and safely no-ops (no energy spent) when the board is full
- [ ] `attemptMerge` reuses `computeMergeOutcome` and produces the same tier-advance decision `AttemptMergeOrMoveCharacterizationTests`/`MergeOutcomeTests` already proved for the main board, on the parallel board's own items
- [ ] A completed top-tier item awards the event's `ProgressTrack`, visible immediately in whatever UI 3.6 builds
- [ ] Teardown (§3.7) doesn't crash or leak state into the next event, whatever persistence answer that task lands on
- [ ] Full test suite green
- [ ] Verified on screen: opening the event, tapping the generator, merging to a completed top-tier item, seeing progress-track credit land

---

## 7. Out of scope

- Offline-progress catch-up for `ParallelBoardEnergy` (§3.2) — explicitly deferred, not fixed here
- A paid lane on the parallel board's progress track — that's Pass's differentiator, not this event type's; if the design authority wants both, that's a deliberate combination decision, not a default
- Fixing the single-active-event model (`EventRegistry.currentEvent`) — **done.** Flagged a third time in §1's original text; fixed by `Spec_Phase6c_ConcurrentEvents.md`, shipped and design-reviewed 16 Aug 2026, before this task ever started. No longer out of scope because there's nothing left to do — §1 above has the updated framing.
- Offers tied to the parallel board (the Blueprint's "own board, chains, energy, **offers**" — the fourth piece this doc doesn't design) — `OfferHooking` already exists (`LiveOpsPrimitives.swift`) and is presumably how this would attach, but wiring a parallel-board-specific offer isn't designed here
- A themed chain's real content/art/copy — §4's chain is a placeholder, same posture as Founders' Circle's and Adoption Drive's own test content
- Re-deriving §4's numbers against a real model
- Whether `CellView.swift` can render a `ParallelBoardCoordinator`'s board directly or needs its own seam first (§3.6) — a real implementation question, not answered here
