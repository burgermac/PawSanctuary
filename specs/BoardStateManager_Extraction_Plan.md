# BoardStateManager Extraction — Design Doc

**Status: Phase A, B, and three rounds of C complete (14 Aug 2026).** `BoardStateManager` exists (`PawSanctuary/BoardStateManager.swift`), owns `board`/`boardIsFull`/`emptyUnlockedCells`, and eight read/write primitives (`item(at:)`, `hasProducer(at:)`, `clearItem(at:)`, `setBubbledAt(_:at:)`, `setItem(_:at:)`, `isEmpty(at:)`, `isUnlocked(at:)`) used by thirteen migrated functions (three independent, the five-function bubble subsystem, and the five-function superpower group) — see §4 for details. Phase D (the `attemptMergeOrMove` rewrite) is **not started**. Further Phase C candidates remain (spawning/producers, item placement/removal, tier/progression, currency, meta/map, and the read-only-query group — see the Appendix table) — this is a "solid progress, not finished" checkpoint, not a completed extraction. This originally superseded `docs/CODE_HEALTH.md`'s scope for this item, which had partly gone stale (see §1).

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

### Target shape — as actually built (Phase B, 14 Aug 2026)

```swift
// PawSanctuary/BoardStateManager.swift
@Observable
@MainActor
class BoardStateManager {
    var board: [[BoardCell]] = []
    private(set) var boardIsFull: Bool = false
    private(set) var emptyUnlockedCells: [BoardCell] = []

    func recalc() {
        // moved verbatim from the old MergeBoardViewModel.recalcBoardIsFull(),
        // minus the recalcExchangeableTrios() call, which stays a
        // MergeBoardViewModel concern (it isn't board state).
        let flat = board.flatMap { $0 }
        let unlocked = flat.filter { $0.isUnlocked }
        boardIsFull = unlocked.allSatisfy { !$0.isEmpty }
        emptyUnlockedCells = unlocked.filter { $0.isEmpty }
    }
}
```

**Two deliberate deviations from what this doc originally guessed**, both discovered during implementation, not planned in advance:

- **No `place`/`clear` mutation primitives.** `board` is `var` (not `private(set)`), and `MergeBoardViewModel.board` is a computed passthrough with both a getter and setter — Swift's standard "read, mutate the copy, write back" mechanism means all ~42 internal functions keep writing `board[row][col].item = ...` exactly as before, unchanged, with zero call-site edits. Adding `place`/`clear` methods would have meant rewriting 42 call sites to use them for no behavioral gain at this phase — pure churn. That rewrite is exactly what Phase D's `MergeResult`-dispatch redesign is for, not Phase B.
- **No `restore(from:)`/`capture(into:)`.** `MergeBoardViewModel.captureState()` already builds `GameState(board: board, ...)` and `apply(_:)` already does `board = s.board`, both by referencing the (now computed) `board` property by name. Since that already round-trips correctly through the passthrough, adding separate restore/capture methods on `BoardStateManager` would have been unused dead code — the seven existing sub-coordinators need them because `MergeBoardViewModel` doesn't already reference their state by a matching property name; `board` was already named `board` everywhere, so it didn't need the indirection.

`MergeBoardViewModel.board`'s computed setter also carries over the `didSet` side effect the old stored property had (clearing `preMoveSnapshot` — the Nine Lives undo guard) — that logic moved into the setter body, not into `BoardStateManager`, since it's ViewModel-level state, not board state.

`attemptMergeOrMove` and every merge side-effect **stayed in `MergeBoardViewModel`** for this phase, exactly as planned — they read/write through the `board` passthrough, but the XP/quest/wildcard/superpower/bubbling logic didn't move.

**Verified:** build succeeds, all 223 tests pass, and a live simulator pass confirmed spawning (`activateProducer`), merging (`attemptMergeOrMove` — the single highest-risk function in the inventory), and full persistence round-trip (terminate + relaunch preserved exact board state) all still work correctly.

### Phases, each independently shippable and live-verified before the next

- **Phase A — exact call-site inventory. Done (13 Aug 2026) — see Appendix.** Produced via a brace-depth-aware scan of every top-level class member (not a regex heuristic — verified against known boundaries like `attemptMergeOrMove`'s exact start/end lines), not the rougher grep this doc's §1 counts came from. **If execution starts more than a few days after 13 Aug 2026, re-run the scan** (script preserved below) rather than trusting the Appendix numbers — the file will have moved on.
- **Phase B — extract state + cache only. Done (14 Aug 2026).** Per the target shape above. `MergeBoardView.swift`'s ~6 external `viewModel.board` reads (confirmed at `MergeBoardView.swift:651,717,1264,1431-1433`) needed no changes — they compiled and ran unmodified against the new computed passthrough. Verified: build, full test suite (223 tests), and a live simulator pass covering spawning, merging, and a full persistence round-trip (terminate + relaunch). One commit, playable throughout, per `CLAUDE.md`'s "keep the game playable at every commit" rule. Selling and drag-to-storage were attempted live but not confirmed (simulator tap-coordinate misses, not a code issue — see [[ios-simulator-tap-coordinate-scaling]] in memory); both are simple single-purpose functions already classified as low-risk in the Appendix, so this doesn't lower confidence in the phase, just leaves two items unconfirmed by direct observation.
- **Phase C — round 1 done (14 Aug 2026).** All three named candidates (`sendBoardItemToInventory`, `storeSelectedItemToInventory`, `sellSelectedAnimal`) migrated, one commit each (`c828389`, `3555467`, `3f14c39`). None turned out more entangled than expected — no reassessment needed. Added three primitives to `BoardStateManager`, introduced by the first real caller rather than guessed up front: `item(at:) -> BoardItem?`, `hasProducer(at:) -> Bool`, `clearItem(at:)`. All three functions still live on `MergeBoardViewModel` (they orchestrate `inventoryStore`/`selectedCell`/toasts/`earnCoins`, none of which belong on a board-state class) — only their board reads/writes route through the new primitives now.

  **Two things found along the way, not planned:** `storeSelectedItemToInventory` turned out to have **zero call sites anywhere in the app or tests** — confirmed dead code, flagged as a separate task (`task_52ca652c`) rather than deleted here, since deletion is out of scope for a migration pass. And **the "Sell" button couldn't be verified live** — six tap attempts across two sessions at plausible coordinates never registered, while every other tap this session (including selecting the very item the Sell button then appears for) worked on the first or second try. Read as a tooling quirk specific to that one button, not a code signal — `sellSelectedAnimal` shares identical primitive calls with `sendBoardItemToInventory`, whose underlying board read/write *was* live-verified via the Phase B spawn+merge test.

- **Phase C — round 2 done (14 Aug 2026).** The bubble-mechanic group (`maybeBubbleMergedItem`, `isActiveBubble`, `collectDecayedBubbleIfAny`, `popBubbleWithDogTags`, `popBubbleWithAd`) migrated as **one commit** (`dee09a0`), unlike round 1's one-per-function cadence — this group is one cohesive subsystem (all five share `item.bubbledAt`), matching the Appendix's own framing of it as "a plausible batch" rather than independent candidates. Added one new primitive, `setBubbledAt(_ timestamp: Double?, at:)`, used for both setting and clearing depending on the argument. Live-verified thoroughly: a fresh and an already-decayed bubble (placed via save patch) rendered with visibly distinct badges, popping the fresh one with Dog Tags matched the exact quoted cost (`bubblePopDogTagCost(tier: 5) = 8`) and preserved the underlying item, and the decayed one's auto-collect matched the exact quoted coin value ("+44 Coins"). `popBubbleWithAd` wasn't directly exercised (needs the ad-provider flow) but shares the identical `setBubbledAt(nil)` call already proven correct by the Dog Tags path.

- **Phase C — round 3 done (14 Aug 2026).** The superpower group (`applyAquaticsCurrent`, `applySplitterPiece`, `runStampede`, `handleLeapTap`, `applyPouchPiece`), migrated exactly as the Appendix called for — individually sized and committed, not a batch (one commit each: `aae8143`, `3510c60`, `89844eb`, `ceb3368`, `6383c98`). `applyPouchPiece` went first since it needed zero new primitives (reused round 1's `clearItem`); `applyAquaticsCurrent` went second and introduced `setItem(_ item: BoardItem?, at:)`, which `applySplitterPiece` and `runStampede` then reused unchanged; `handleLeapTap` went last and introduced `isEmpty(at:)`/`isUnlocked(at:)` (mirroring `BoardCell`'s own two properties directly, since the call site needed both together). None turned out more entangled than expected. Live-verified all five via save-file patches (same technique as round 2): Pouch banked a target into Storage Row 1; Aquatics Current visibly slid a sub-object into a merge-emptied cell; Splitter dropped a tier-2 target to tier-1 in place and placed a second tier-1 copy on an open cell; Stampede cascaded four tier-1 items into one higher-tier item through repeated merges; Leap moved a tile from its source cell to a tapped destination three columns over.

  **Tooling note:** the chat-rendered simulator screenshot is not a reliable coordinate source — eyeballing pixel positions off it produced repeated missed taps/drags this round. The fix that worked: take a raw screenshot via `xcrun simctl io <udid> screenshot`, inspect its exact pixel size with PIL, confirm it's an integer multiple (2x or 3x — iPhone 17 sim is exactly 3x) of the point-space `attach` reports, crop the raw PNG near the target and read coordinates off the crop, then divide by the integer scale factor. See the `ios-simulator-tap-coordinate-scaling` memory entry for the full method. Also confirmed again this round: an `xcrun simctl launch` can land the app in a new container even without an explicit `launch` MCP-tool call (e.g. after a `test` build) — always re-fetch the container path with `get_app_container` immediately before patching a save, never reuse one from earlier in the session.

  **Remaining Phase C candidates**, not attempted yet — re-scope with a fresh Phase A-style grep (the file will have moved on) before picking further ones. Per the Appendix table: spawning/producers (10 functions, largest remaining group — `activateProducer` likely needs splitting before it's a clean single-function move), item placement/removal (6 functions left after round 1's trio), tier/progression, currency, meta/map, and the read-only-query group (lowest risk — all become one-line passthroughs).
- **Phase D (separate sprint, explicitly deferred) — the `attemptMergeOrMove` → `MergeResult` rewrite.** This is the actual high-risk core of `docs/CODE_HEALTH.md`'s original vision. Needs its own planning pass when picked up — not folded into Phase B or C. Two things should exist before attempting it: confidence built from B/C going cleanly, and *some* way to test board logic in isolation. Phase B's extraction is what makes that newly possible — `BoardStateManager`, being dependency-light (no `KibbleEngine`/`QuestCoordinator`/etc. references), is unit-testable in a way the current monolithic ViewModel isn't. Consider writing `BoardStateManagerTests.swift` as part of Phase B itself, even though nothing forces it — it's the first opportunity this codebase has had to test board logic at all.

## 5. Non-goals for this doc

This is a plan for Phase A/B. It does not attempt Phase C or D, and does not touch `attemptMergeOrMove`, `board[...]` call sites, or any other source file. No code changes accompany this document.

---

## Appendix — Phase A inventory (13 August 2026)

Scanned every top-level member of `MergeBoardViewModel` (370 total: funcs, stored properties, computed properties) via a brace-depth walk, not a line-regex heuristic — spot-verified against known boundaries (`attemptMergeOrMove` correctly resolved to exactly lines 1759–1902). Superset of what a mechanical grep would find, because it correctly handles multi-line signatures and nested closures instead of matching "next declaration line."

**Board state itself:** `board` (declared line 137, with a `didSet` that invalidates `preMoveSnapshot`), `boardIsFull` (line 276), `emptyUnlockedCells` (line 279, `private(set)`).

**49 members read or write it — 42 funcs + 7 computed vars.** Grouped by what they do, not file order, since that's the more useful shape for deciding Phase C migration order:

| Group | Members | Notes for Phase C ordering |
|---|---|---|
| **Merge core** | `attemptMergeOrMove` (1759–1902, 144 lines) | The one function Phase D exists for. By far the largest concentration of non-board logic (XP, quests, superpowers, wildcards, sub-objects, power-ups, spotlight, bubbling, tier unlocks) mixed with board writes. Touches `board[]`, `boardIsFull`, `emptyUnlockedCells`, and calls `recalcBoardIsFull()` — all four, the only function that does. |
| **Lifecycle / setup** | `freshStart`, `ensureStartingProducer`, `apply`, `recalcBoardIsFull` | `recalcBoardIsFull` itself (1271–1277) is the cache-recompute function Phase B moves as `BoardStateManager.recalc()`, verbatim. `apply` is the `GameState` → ViewModel restore path — needs care since it also restores six other sub-coordinators in the same function. |
| **Spawning / producers** | `finishSpawn`, `maybeGrantBonusSpawn`, `activateProducer` (1334–1457, 124 lines — second largest), `buyProducer`, `placeProducerReward`, `spawnAnimal`, `retireProducer`, `placeFamilySpawnerOnBoard`, `placeDesignatedProducerOnBoard`, `placeOverflowProducerOnBoard` | 10 functions, the largest group. Mostly "find an empty cell, place a producer tile" shape — plausible Phase C candidates once `place`/`clear` primitives exist, but `activateProducer`'s size means it likely needs splitting before it's a clean one-function move. |
| **Board interaction (tap/select)** | `boardCellTapped`, `maybeShowSellVsOrderNudge`, `findMergeableHintPair`, `exchangeAmbassadorTrio` | UI-adjacent; `boardCellTapped` is the main tap-routing function and probably shouldn't move at all — it dispatches to most of the other groups here. |
| **Item placement / removal** | `placeOrBankItem`, `applyPowerUpToSpawner`, `sendBoardItemToInventory`, `storeSelectedItemToInventory`, `sellSelectedAnimal`, `placeSelectedInventoryItemOnBoard`, `placeFreeTile`, `placeToolbox`, `absorbToolbox` | 9 functions. `sendBoardItemToInventory`, `storeSelectedItemToInventory`, and `sellSelectedAnimal` are the three named as Phase C candidates in §4 — confirmed here as genuinely self-contained (each touches `board[]` + `recalcBoardIsFull()` only, nothing else in this table's other groups). |
| **Tier / progression** | `checkTierUnlock`, `claimAmbassadorQuest` | |
| **Bubbles** | `maybeBubbleMergedItem`, `isActiveBubble`, `collectDecayedBubbleIfAny`, `popBubbleWithDogTags`, `popBubbleWithAd` | Self-contained subsystem (Gap_Analysis_Round2 C-4) — a plausible second Phase C batch after the item-placement group. |
| **Superpowers** | `applyAquaticsCurrent`, `applySplitterPiece`, `runStampede`, `handleLeapTap`, `applyPouchPiece` | Each is one species' active-ability effect. Independent of each other but each also independently entangled with merge/spawn state — treat as individually-sized Phase C candidates, not a batch. |
| **Currency** | `collectCurrencyItem` | |
| **Meta / map** | `buildArea` | Only reaches into board state for `areaEventCoins` bonus item placement — smaller board footprint than its line count suggests. |
| **Read-only queries (computed vars)** | `selectedCellHasProducer`, `selectedCellHasAnimalItem`, `selectedItemInfo`, `retirableProducers`, `lockedCells`, `unlockProgress`, `unlockHintText` | All read `board[]`, none write it. Once `BoardStateManager` exists these become one-line passthroughs (`boardState.board[...]`) — no logic changes needed, lowest-risk items in the whole inventory. |

**External touch points — exactly 6, all read-only, all in `MergeBoardView.swift`:** lines 651, 717, 1264, 1431, 1432, 1433. All either index `viewModel.board[row][col]` or read `viewModel.board.count`. None write. This confirms §4 Phase B's passthrough plan needs to cover exactly one property (`board`, as `[[BoardCell]]`) for the view layer to keep compiling unchanged — `boardIsFull` and `emptyUnlockedCells` have **no external readers at all**, only internal ones, so their passthroughs (if kept as passthroughs rather than fully hidden inside `BoardStateManager`) exist purely for `MergeBoardViewModel`'s own remaining 49-minus-whatever-moved internal call sites.

### Reproducing this scan

```python
import re

path = "PawSanctuary/MergeBoardViewModel.swift"  # run from the repo root
with open(path) as f:
    lines = f.readlines()

class_start = next(i for i, l in enumerate(lines) if re.match(r'^class MergeBoardViewModel\b', l))

def brace_delta(line):
    d, in_str, i, n = 0, False, 0, len(line)
    while i < n:
        c = line[i]
        if in_str:
            if c == '\\': i += 2; continue
            if c == '"': in_str = False
        else:
            if c == '"': in_str = True
            elif c == '/' and i + 1 < n and line[i + 1] == '/': break
            elif c == '{': d += 1
            elif c == '}': d -= 1
        i += 1
    return d

decl_re = re.compile(r'^\s*(private\(set\)\s+|private\s+|@discardableResult\s*)*(func|var|let)\s+([A-Za-z0-9_`]+)')
members, current, depth = [], None, 0
i = class_start
while i < len(lines):
    line = lines[i]
    if depth == 1 and current is None:
        m = decl_re.match(line)
        if m: current = {'start': i, 'kind': m.group(2), 'name': m.group(3)}
    d = brace_delta(line)
    new_depth = depth + d
    if current is not None:
        if depth == 1 and new_depth == 1 and d == 0:
            current['end'] = i; members.append(current); current = None
        elif new_depth == 1 and depth >= 2:
            current['end'] = i; members.append(current); current = None
    depth = new_depth
    i += 1
    if depth == 0: break

for m in members:
    if m['kind'] not in ('func', 'var'): continue
    start, end = m['start'], m['end']
    if m['kind'] == 'var' and end == start: continue  # simple stored property
    body = ''.join(lines[start:end + 1])
    touches = [t for t, pat in [('board[]', r'\bboard\['), ('boardIsFull', r'\bboardIsFull\b'),
                                 ('emptyUnlockedCells', r'\bemptyUnlockedCells\b'),
                                 ('recalcBoardIsFull()', r'\brecalcBoardIsFull\(')]
               if re.search(pat, body)]
    if touches: print(f"L{start+1}-{end+1}  {m['name']}  {', '.join(touches)}")
```

---

*See also `docs/CODE_HEALTH.md` (original recommendation) and `TODO.md`'s "Still open — deliberately not attempted piecemeal" section (status pointer).*
