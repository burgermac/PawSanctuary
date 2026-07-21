# PawSanctuary — TODO

## Pending

### Xcode capability toggles (Signing & Capabilities — not code changes)
- [ ] Enable **Push Notifications** capability. Required for `UNUserNotificationCenter` permission prompt to work on device — the scheduling logic in `NotificationManager.swift` is already fully implemented and just needs this to actually fire.
- [ ] Enable **iCloud** capability → check **Key-Value Storage**. The sync code in `GameStore.swift` is wired and degrades gracefully without it, but cross-device save sync won't actually happen until this is provisioned.
- [ ] Enable **iCloud** capability → check **CloudKit** → create/select a container (separate from the Key-Value Storage service above). Required for card trading.
- [ ] Enable **Game Center** capability. Also required for card trading (Game Center auth gates the whole feature) and for friend discovery in the invite system.
- [ ] In the CloudKit Dashboard, confirm the `CardTrade` record type has fields `cardID`, `fromPlayerID`, `fromDisplayName`, `toPlayerID`, `toDisplayName`, `sentAt`, `status` — mark `toPlayerID`, `fromPlayerID`, and `status` **Queryable** (the trading queries in `CardTradeBackend` filter on these and CloudKit rejects predicates on non-queryable fields). Deploy the schema from Development to Production before release.

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
