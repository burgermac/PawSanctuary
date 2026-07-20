# PawSanctuary — Code Health Report & Improvement Roadmap
**Date:** June 2026

---

## Critical Bugs (Fix Before Next TestFlight)

### BUG-01: Duplicate NotificationManager Delegate Conflict
**File:** MergeBoardView.swift line 34  
**Issue:** `@State private var notifManager = NotificationManager()` creates a second NotificationManager instance that overwrites the singleton's UNUserNotificationCenterDelegate. Whichever instance initializes last wins the delegate slot — the other's foreground presentation handling is dead.  
**Fix:** Remove the local `@State` instance. Replace all 5 uses of `notifManager` in MergeBoardView.swift with `NotificationManager.shared`.

---

### BUG-02: Login Reward & Pass Daily Claim Not Persisted on Crash
**Files:** MergeBoardViewModel.swift lines ~1797, ~1908  
**Issue:** `claimLoginReward()` and `claimPassDaily()` grant kibble/tags but do not call `persist()`. A crash within 5 seconds loses the claim; next launch shows no reward available.  
**Fix:** Add `persist()` call at the end of both methods.

---

### BUG-03: Timer Suppressed During Scroll Gestures
**File:** MergeBoardViewModel.swift — `startTimer()`  
**Issue:** `Timer.scheduledTimer` runs in `.default` RunLoop mode. UIKit/SwiftUI switches to `.tracking` mode during scroll, silently suppressing all ticks — kibble regen, producer cooldowns, adoption countdown, and the 5-second auto-save all pause while the player scrolls.  
**Fix:** Replace `Timer.scheduledTimer(...)` with a timer added to `RunLoop.main` in `.common` mode, or use `DispatchSourceTimer`.

---

## High-Priority Performance Fixes

### PERF-01: Main-Thread JSON Encoding on Every Save
**File:** GameStore.swift lines ~222–233  
**Issue:** `JSONEncoder().encode()` + `data.write(to:, options: .atomic)` run synchronously on @MainActor every 5 seconds and on every user action. On older devices this consumes 5–15 ms of frame budget per save.  
**Fix:** Capture state on main actor, then `Task.detached(priority: .utility)` for encode + write.

---

### PERF-02: `board.flatMap { $0 }` Called 15+ Times Per Interaction
**File:** MergeBoardViewModel.swift — 15 call sites  
**Issue:** Each call allocates a new 63-element array + filter. During a single spawn action, 3–4 of these fire in sequence.  
**Fix:** Add `private var flatBoard: [BoardCell] { board.flatMap { $0 } }` computed property. Cache `emptyUnlockedCells` as a stored property, updated only in `recalcBoardIsFull()`.

---

### PERF-03: `tickProducers()` Unconditional Write-Back Every Second
**File:** MergeBoardViewModel.swift lines ~992–1016  
**Issue:** Every producer cell is written back to `board[row][col].producer` every second, even family spawners that never change cooldown state. Each write triggers @Observable notification to views.  
**Fix:** Make `ProducerTile` Equatable. Only write back when `p != original`. Skip ticking `.familySpawner` producers entirely (they have no cooldown).

---

### PERF-04: `exchangeableTrios` and `retirableProducers` Run Full Board Scan at Render Time
**File:** MergeBoardViewModel.swift lines ~448–478  
**Issue:** Computed properties that scan 63 cells × 15 species on every render pass that touches the quest panel.  
**Fix:** Cache as stored properties; recalculate only after board mutations.

---

## Code Quality Fixes

### QA-01: Memory Leak — `authenticateGameCenter` Strong Capture
**File:** MergeBoardViewModel.swift line ~605  
**Issue:** `{ [self]` captures VM strongly inside GKLocalPlayer's auth handler, which lives for the app lifetime.  
**Fix:** Change to `{ [weak self]`; add `guard let self else { return }`.

---

### QA-02: `SoundManager` Uses Old ObservableObject Pattern
**File:** SoundManager.swift  
**Issue:** The only `ObservableObject`/`@Published` class in the codebase; everything else uses `@Observable`. Causes mismatched diffing and unnecessary `import Combine` in ShopView.swift.  
**Fix:** Migrate to `@Observable`. Remove `import Combine` from ShopView.swift.

---

### QA-03: Force-Unwraps in InventoryStore
**File:** InventoryStore.swift lines ~83, ~91–93, ~193  
**Issue:** `materialCounts[chainID]![tier]` force-unwraps dictionary optionals. Safe in current paths but crash-prone to future refactoring.  
**Fix:** Replace with `subscript(default:)` or explicit optional binding.

---

### QA-04: `activateProducer` 60+ Lines of Duplicated Logic
**File:** MergeBoardViewModel.swift lines ~887–968  
**Issue:** `.familySpawner` and legacy producer branches share identical structure with only chain resolution differing.  
**Fix:** Extract shared logic into `private func spawnItem(chainID: String, tier: Int, at pos: BoardPosition)`.

---

### QA-05: `BoardCell.id` Uses Unstable UUID
**File:** AnimalSpecies.swift line ~479  
**Issue:** `var id = UUID()` regenerates on copy, breaking SwiftUI identity-based animation diffing in the board grid ForEach.  
**Fix:** Use stable `GridPosition` as the id: `var id: GridPosition { position }`.

---

### QA-06: Banner/Overlay Pattern Duplicated 5 Times
**File:** MergeBoardView.swift lines ~112–208  
**Issue:** Unlock, level-up, area-built, ambassador, and milestone banners repeat the same ZStack/spring/auto-dismiss pattern verbatim.  
**Fix:** Extract `BannerView(icon:title:detail:color:)` component. Each banner becomes ~5 lines.

---

### QA-07: Multiple Dismiss Tasks Not Cancelled (Race Condition)
**File:** MergeBoardViewModel.swift — 6 banner dismiss Task sites  
**Issue:** Two rapid events showing the same banner start two Tasks; the first may dismiss the second banner early.  
**Fix:** Store `Task` handles per banner; cancel existing before starting new (same pattern as `Toast` system).

---

### QA-08: Versions 1–7 Saves Silently Wiped
**File:** GameStore.swift line ~315  
**Issue:** Saves from versions 1–7 hit `return nil` without logging or user notification. Early adopters lose all progress silently.  
**Fix:** Add user-facing alert ("Your save is from an older version and could not be restored") and a structured log entry.

---

### QA-09: Dead Code — `totalToolInventorySlots`
**File:** AnimalSpecies.swift line ~873  
**Issue:** Zero references in the codebase.  
**Fix:** Delete the constant.

---

## Structural Recommendation: Extract BoardStateManager

The single most impactful long-term refactor is extracting board manipulation from MergeBoardViewModel into a dedicated `BoardStateManager: @Observable @MainActor class` that owns:

- `var board: [[BoardCell]]`
- `var boardIsFull: Bool` (cached internally)
- `func emptyUnlockedCells() -> [BoardCell]`
- `func placeTile(_ item: BoardItem, preferring: GridPosition?) -> GridPosition?`
- `func attemptMergeOrMove(from: to:) -> MergeResult`
- `func tickProducers(delta: TimeInterval)`

MergeBoardViewModel becomes a true coordinator: it receives `MergeResult` events and dispatches to KibbleEngine, QuestCoordinator, and PlayerProgression. This eliminates all 15 `flatMap` call sites, centralizes `recalcBoardIsFull()`, enables unit testing of board logic in isolation, and makes the PERF-03 fix trivial to implement safely.

**Suggested implementation order:**

1. Fix BUG-01, BUG-02, BUG-03 — critical, before next TestFlight
2. PERF-01, PERF-03 — save encoding + tick optimization, biggest frame-time wins
3. QA-01, QA-02, QA-05 — memory leak, pattern alignment, animation fix
4. BoardStateManager extraction — schedule as a dedicated sprint after Phase 5
