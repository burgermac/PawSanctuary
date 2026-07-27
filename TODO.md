# PawSanctuary — TODO

## Pending

### Xcode capability toggles (Signing & Capabilities — not code changes)
- [ ] Enable **Push Notifications** capability. Required for `UNUserNotificationCenter` permission prompt to work on device — the scheduling logic in `NotificationManager.swift` is already fully implemented and just needs this to actually fire. (Works on a free/Personal Team.)
- [x] Enable **Game Center** capability — done (commit `adf1be4`). (Works on a free/Personal Team.)
- [ ] **BLOCKED on paid Apple Developer Program enrollment ($99/yr):** the Xcode account for this project (team `H2QZGDY8UN`) is currently a free/Personal Team, and Apple does not expose the **iCloud** capability at all for Personal Teams — it's missing from the `+ Capability` list, not just greyed out. Confirmed 2026-07-23. Both of the following are blocked on enrolling first:
  - [ ] Enable **iCloud** capability → check **Key-Value Storage**. The sync code in `GameStore.swift` is wired and degrades gracefully without it, but cross-device save sync won't actually happen until this is provisioned.
  - [ ] Enable **iCloud** capability → check **CloudKit** → create/select a container (separate from the Key-Value Storage service above). Required for card trading.
- [ ] In the CloudKit Dashboard, confirm the `CardTrade` record type has fields `cardID`, `fromPlayerID`, `fromDisplayName`, `toPlayerID`, `toDisplayName`, `sentAt`, `status` — mark `toPlayerID`, `fromPlayerID`, and `status` **Queryable** (the trading queries in `CardTradeBackend` filter on these and CloudKit rejects predicates on non-queryable fields). Deploy the schema from Development to Production before release. Depends on iCloud/CloudKit above.

### Real integrations still stubbed
- [ ] **Rewarded ads:** `AdProvider.swift`'s `StubAdProvider` just waits 1.5s and always succeeds. Swap in a real SDK (AdMob, AppLovin, etc.) before launch — the reward logic and daily-cap bookkeeping around it are already correct.
- [ ] When ready for final audio assets, replace `AudioServicesPlaySystemSound(XXXX)` calls in `SoundManager.swift` with `AVAudioPlayer` instances pointed at the real asset files.

### App Store submission blockers (not code)
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] AI-generated content disclosure (Guideline 2.1)
- [ ] Age rating declaration
- [ ] Replace the placeholder App Store URL in `InviteSystem.swift` (`pawSanctuaryAppStoreURL`, currently `id0000000000`) once the app has a real listing.

### Content gaps
- [ ] **Seasonal Events — add future events to registry:** the infrastructure in `EventSystem.swift` is complete, but the only event ever defined (`rescue_rush_jun2026`, June 1–15 2026) has expired. Add new `EventDefinition` entries to `EventRegistry.allEvents` — nothing seasonal is currently active.
- [ ] **Card artwork:** all 54 cards in `CardSystem.swift` use SF Symbols as stand-ins. Illustrated art is a content/asset-production task, not a code change.

### Test suite health (discovered 26 July 2026, fixed same day)

`PersistenceTests.swift` (~1,100 lines) had never successfully compiled. The scheme's `TestAction` had no `<Testables>` entry, so `xcodebuild test` failed outright rather than running; once fixed, the test target's deployment target (17.0 vs the app's 17.6) blocked `@testable import`; once that was fixed, 9 accumulated compile errors surfaced referencing fields deleted long ago (`GameState.supplyCount`, `AdoptionOrder.rewardKibble`, `AreaReward.newSpecies`).

**Implication:** every schema migration from v8 through v24 shipped without test verification. Treat the older migrations as unproven rather than trusted. If a save-corruption bug surfaces, that chain is the first place to look.

All fixed: scheme wiring, deployment target, the 9 compile errors, and 7 further behavioural failures the suite surfaced once it could actually run (stale expected values for tier-clamping/level-band logic and Sanctuary Map upgrade-tier count, one `isTopTier` assertion against test data that assumed a 9-tier chain instead of the real 15-tier one, and a `GameStore.save()`/`load()` race in 3 tests — see below). 70 passing, then 78 with these fixes.

- [ ] **`RescueStage` is vestigial but still drives live quest generation.** `RescueStage` is a legacy 9-stage enum (its own doc comment says so) from before the game moved to 15-tier-per-family chains. It survives in `AnimalSpecies.swift` (5 references) — but also in **`QuestCoordinator.swift`, at 17 sites**, where `RescueStage.X.tierIndex` (range 0–8) is used to build `reachTier` goals against chains whose real range is 0–14.
  **Consequence:** quests can only ever target the bottom 9 tiers of a 15-tier chain. **Tiers 9–14 — a third of the authored content, including every top-tier Ambassador stage — are unreachable as quest objectives.** This is the same apples-to-oranges confusion found in the tests, except it is in shipping code.
  Fix alongside Phase 5 (order/quest restructuring), or sooner if quest variety matters before then.

### Background save was fire-and-forget at suspension time — FIXED 26 July 2026

The `GameStore.save()`/`load()` race hit by 3 tests above wasn't only a test-timing artefact. `MergeBoardView.swift` handled `.background`/`.inactive` by calling `viewModel.persist()` under a "Flush save" comment, but `GameStore.save()`/`saveAndSync()` are `Task.detached(priority: .utility)` — a low-QoS task started as iOS suspends the process, with no background-task assertion protecting it. Not a flush; a request that might never be scheduled. Saves made in the final moments of a session could be silently lost.

**Resolution:** added `GameStore.saveNow(_:)` (synchronous, reusing the existing private helpers) and `MergeBoardViewModel.persistNow()`. `.background` now saves synchronously; `.inactive` keeps the async path, since it fires on transient events (Control Centre, notification banners) and on the way back to `.active`. `save()`/`saveAndSync()` unchanged — the PERF-01 detachment remains correct for periodic saves.

**Measured:** encode + two atomic writes + cloud check averages **1.2 ms** (max 2.1 ms) on a realistic ~9.6 KB `GameState`. Safe on the main thread at a one-time transition.

The three previously-failing persistence tests now call `saveNow()` directly, so they exercise the real production path instead of a hand-rolled substitute.

### Competitive analysis
- [ ] **Feature-parity audit vs. Gossip Harbor / Travel Town / Tasty Travels.** `PawSanctuary_Gap_Analysis.md` (in the parent Claude Code folder) deliberately scoped itself to *gameplay psychology* — the mechanisms driving return visits and spend — and explicitly did **not** enumerate feature-by-feature coverage. A straight parity audit is still outstanding: catalogue every discrete feature in the three reference titles, mark present / partial / absent in PawSanctuary, and flag which absences are deliberate differentiation versus unexamined gaps. Reference material: `Merge2_Reference_Blueprint.md`, `Findings_26July.md`, `Reference_Data_Extract.md`, `Phase2_Economy_Model.xlsx`.

## Code Health (from June 2026 audit, cross-checked against `docs/CODE_HEALTH.md` — fixed in the July 2026 pass unless noted)

- [x] **BUG-01:** Duplicate NotificationManager in MergeBoardView.swift — fixed, all call sites use `NotificationManager.shared`
- [x] **BUG-02:** Missing `persist()` after `claimLoginReward()`/`claimPassDaily()` — fixed
- [x] **BUG-03:** Timer RunLoop mode (`.default` → `.common`) — fixed
- [x] **PERF-01:** Main-thread JSON encoding on every save — fixed (`Task.detached` off the main actor)
- [x] **PERF-02:** `board.flatMap { $0 }` re-scanned 63 cells 17× per interaction — fixed via a cached `emptyUnlockedCells` property, recomputed once per board mutation
- [x] **PERF-03:** `tickProducers()` unconditional write-back every second — fixed (Equatable guard)
- [x] **PERF-04:** `exchangeableTrios` full-board scan at render time — cached (depends only on board state). `retirableProducers` deliberately left uncached — it also depends on quest/challenge completion state that doesn't always coincide with a board mutation, and a 63-cell scan is cheap enough that a stale-cache bug wasn't worth risking.
- [x] **QA-01:** Strong capture in `authenticateGameCenter` — fixed (`[weak self]`)
- [x] **QA-02:** SoundManager migrated to `@Observable`; `import Combine` removed from ShopView.swift
- [x] **QA-03:** Force-unwraps in InventoryStore's material-count subscripts — replaced with safe optional-chaining mutation
- [x] **QA-04:** `activateProducer`'s duplicated ~30-line spawn bookkeeping (family spawner vs. legacy producer) — extracted into `finishSpawn(item:at:cost:)`
- [x] **QA-05:** `BoardCell.id` was a regenerating UUID, breaking merge/unlock animation diffing — now a stable `GridPosition`-derived id
- [x] **QA-06:** Banner/overlay ZStack pattern duplicated across 4 inline banners in MergeBoardView.swift — extracted a shared `BannerView` component in PanelViews.swift
- [x] **QA-07:** Banner dismiss Tasks had no protection against a second trigger cutting off the first's still-showing banner — added generation-counter guards (6 sites) plus a shared `presentAreaBuiltBanner` helper for the two duplicated area-banner call sites
- [x] **QA-08:** Saves from schema v1–v7 were silently discarded with total progress loss — added `GameStore.discardedIncompatibleVersion` tracking, a log line, and a user-facing alert
- [x] **QA-09:** Dead `totalToolInventorySlots` constant — deleted

### Still open — deliberately not attempted piecemeal
- [ ] **Extract `BoardStateManager`:** the single largest remaining structural item from `docs/CODE_HEALTH.md`. Move board manipulation (`board`, `boardIsFull`, `emptyUnlockedCells`, `attemptMergeOrMove`, `tickProducers`) out of the 2,500+-line `MergeBoardViewModel` into a dedicated `@Observable @MainActor` class, with `MergeBoardViewModel` becoming a coordinator that dispatches `MergeResult` events to `KibbleEngine`/`QuestCoordinator`/`PlayerProgression`. Flagged in `CODE_HEALTH.md` as a dedicated-sprint-sized refactor — high value, but risky enough to warrant its own focused pass rather than bundling into a mixed edit session.
