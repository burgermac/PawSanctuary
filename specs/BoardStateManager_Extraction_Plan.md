# BoardStateManager Extraction — Design Doc

**Status: planning only. No extraction has started.** This supersedes `docs/CODE_HEALTH.md`'s original scope for this item, which has partly gone stale (see §1). Written 13 August 2026 in response to a direct request to do the extraction; scoped down to a design doc after weighing the risk (see §2) — the phased plan in §4 is what a future session should execute, starting with Phase A.

---

## 1. Current state, measured today

- `MergeBoardViewModel.swift` is **3,609 lines** (`wc -l`) — up from the "2,500+" `docs/CODE_HEALTH.md` cited when it first flagged this extraction. The file has only grown since.
- `board[...]` is indexed directly in roughly **40+ distinct functions** across the file: spawning, producers, merges, currency collection, selling, storage, superpowers, wildcards, tier unlocks, and more. This is not an isolated subsystem with a handful of touchpoints — it's threaded through nearly the whole file.
- `recalcBoardIsFull()` (the board-full/empty-cell cache) is called from **36 sites**.
- `emptyUnlockedCells` is read from **20 sites**.
- `attemptMergeOrMove` has only **one external call site** (`MergeBoardView.swift`'s drag gesture), but internally it's the single most side-effect-laden function in the file: XP, score, quest progress, spotlight multiplier, superpower unlock checks, sub-object/power-up routing, bubbling, tier-unlock checks, and — as of this session — the wildcard merge-identity logic (3.5) all live inside it.
- **`docs/CODE_HEALTH.md`'s original extraction list is partly stale.** It names `func tickProducers(delta:)` as something to move into the new class. That function **no longer exists** — it was already deleted in an earlier PERF-03 fix, replaced by a derived-from-`readyAt` model (see the comment at `MergeBoardViewModel.swift:928`, and `ProducerTile.readyAt`'s own doc comment in `AnimalSpecies.swift`). Any execution of this extraction needs to start from a fresh read of the current file, not from `CODE_HEALTH.md`'s literal list.
- **Zero test coverage on the ViewModel's board-mutation logic.** Confirmed repeatedly this session — no test in `PawSanctuaryTests` instantiates `MergeBoardViewModel`. Every feature built this session (piggy bank, wildcard, free chest, VIP ladder) was verified via unit tests on pure logic plus manual live-simulator testing, never through the ViewModel directly. A rewrite of `attemptMergeOrMove` would have to be verified the same way — no automated regression net exists for it today.

## 2. Why this is a dedicated sprint, not a session task

`docs/CODE_HEALTH.md`'s original vision — `MergeBoardViewModel` becomes a pure coordinator, `attemptMergeOrMove` rewritten to return a `MergeResult` that gets dispatched to `KibbleEngine`/`QuestCoordinator`/`PlayerProgression` — means rewriting the riskiest, most side-effect-dense function in the codebase, with no automated safety net, in a game where a save-breaking or merge-breaking bug is directly player-facing and hard to recover from. `CLAUDE.md`'s own working rules already name this exact refactor as something not to start opportunistically. Both of those still hold, more strongly now than when they were written, given the file has grown and the merge pipeline has picked up more entangled logic (wildcards this session included).

This doc exists so that when the extraction *is* picked up, it starts from an accurate map instead of re-deriving one, and proceeds in independently-shippable phases instead of one large rewrite.

## 3. The pattern to follow — already proven seven times in this file

`MergeBoardViewModel` already composes seven separate `@Observable @MainActor` classes, each owning its own state and exposing `restore(from: GameState)` / `capture(into: inout GameState)`:

```swift
let kibbleEngine  = KibbleEngine()
let inventoryStore = InventoryStore()
let quests        = QuestCoordinator()
let adoptionBoardCoordinator = AdoptionBoard()
let progression   = PlayerProgression()
let dogTagStore   = DogTagStore()
let progressTrack = ProgressTrack()
```

`captureState()` and `apply(_:)` call each one's `capture`/`restore` in turn. External call sites that need e.g. kibble go through a computed passthrough on `MergeBoardViewModel` (`var kibble: Int { get { kibbleEngine.kibble } set { kibbleEngine.kibble = newValue } }`) rather than reaching into `kibbleEngine` directly everywhere.

**`BoardStateManager` should be the eighth instance of this exact pattern, not a new architecture.** That's the strongest reason a *scoped* extraction (state + cache only, §4 Phase B) is low-risk: the composition, restore/capture wiring, and passthrough technique are all already working code elsewhere in this same file, not something to design from scratch.

## 4. Recommended target shape and phased execution

### Target shape (Phase B scope — see below)

```swift
@Observable
@MainActor
final class BoardStateManager {
    private(set) var board: [[BoardCell]]
    private(set) var boardIsFull = false
    private(set) var emptyUnlockedCells: [BoardCell] = []

    func recalc() {
        // moved verbatim from MergeBoardViewModel.recalcBoardIsFull(),
        // minus the recalcExchangeableTrios() call, which stays a
        // MergeBoardViewModel concern (it isn't board state).
    }

    func place(_ item: BoardItem, at pos: GridPosition) { ... }
    func clear(at pos: GridPosition) { ... }
    // additional primitives as Phase A's inventory reveals they're needed —
    // do not guess the full method list before doing that inventory.

    func restore(from s: GameState) { board = s.board }
    func capture(into s: inout GameState) { s.board = board }
}
```

`attemptMergeOrMove` and every merge side-effect **stay in `MergeBoardViewModel`** for this phase. They call into `boardState.place`/`.clear`/etc. instead of indexing `board[...]` directly, but the XP/quest/wildcard/superpower/bubbling logic doesn't move.

### Phases, each independently shippable and live-verified before the next

- **Phase A — exact call-site inventory.** Rerun the grep audit this doc's §1 numbers came from, at execution time, against whatever the file looks like then (it will have changed). Produce the real, current list of every function touching `board[...]`, `boardIsFull`, `emptyUnlockedCells`, and `recalcBoardIsFull()`. Do not reuse this doc's counts as ground truth — they're a snapshot from 13 August 2026.
- **Phase B — extract state + cache only**, per the target shape above. `MergeBoardView.swift`'s ~6 external `viewModel.board` reads (confirmed at `MergeBoardView.swift:651,717,1264,1431-1433`) keep working unchanged via a computed passthrough (`var board: [[BoardCell]] { boardState.board }`) — same technique already used for `kibble`. Verify: game builds, all existing tests pass, and a live simulator pass confirms merging, spawning, selling, and storage still work exactly as before. One commit, playable at the end of it, per `CLAUDE.md`'s "keep the game playable at every commit" rule.
- **Phase C (future, not this pass) — migrate simple board-mutation functions one at a time.** Candidates that look self-contained enough to move without touching `attemptMergeOrMove`: `sendBoardItemToInventory`, `storeSelectedItemToInventory`, `sellSelectedAnimal`. Each gets its own commit, each live-verified before starting the next. Stop and reassess if any candidate turns out to be more entangled than it looks from the outside — that's a signal to leave it and pick a different one, not to push through.
- **Phase D (separate sprint, explicitly deferred) — the `attemptMergeOrMove` → `MergeResult` rewrite.** This is the actual high-risk core of `docs/CODE_HEALTH.md`'s original vision. Needs its own planning pass when picked up — not folded into Phase B or C. Two things should exist before attempting it: confidence built from B/C going cleanly, and *some* way to test board logic in isolation. Phase B's extraction is what makes that newly possible — `BoardStateManager`, being dependency-light (no `KibbleEngine`/`QuestCoordinator`/etc. references), is unit-testable in a way the current monolithic ViewModel isn't. Consider writing `BoardStateManagerTests.swift` as part of Phase B itself, even though nothing forces it — it's the first opportunity this codebase has had to test board logic at all.

## 5. Non-goals for this doc

This is a plan for Phase A/B. It does not attempt Phase C or D, and does not touch `attemptMergeOrMove`, `board[...]` call sites, or any other source file. No code changes accompany this document.

---

*See also `docs/CODE_HEALTH.md` (original recommendation) and `TODO.md`'s "Still open — deliberately not attempted piecemeal" section (status pointer).*
