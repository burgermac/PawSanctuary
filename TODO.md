# PawSanctuary — TODO

## Pending

- [ ] Drag `SoundManager.swift` from Finder into the Xcode project navigator and add it to the PawSanctuary target. Xcode won't pick it up automatically since it was created outside the IDE.
- [ ] Drag `HapticManager.swift` from Finder into the Xcode project navigator and add it to the PawSanctuary target.
- [ ] Enable **Push Notifications** capability in Xcode: target → Signing & Capabilities → + Push Notifications. Required for `UNUserNotificationCenter` permission prompt to work on device.
- [ ] When ready for final audio assets, replace `AudioServicesPlaySystemSound(XXXX)` calls in `SoundManager.swift` with `AVAudioPlayer` instances pointed at the real asset files.
- [ ] **Phase 6 — Superpower System:** Implement per-family superpowers that unlock when a family first reaches Era 3 (Stage 7). Deferred from the 15-tier expansion. See GDD v2.1 and FEATURE_EXPANSION_PLAN.md for context.
- [ ] Update PawSanctuary_GDD.md to reflect correct board size: 9×7 = 63 cells (GDD currently states 6×5 = 30 cells).
- [ ] **Seasonal Events — add future events to registry:** The event infrastructure in `EventSystem.swift` is complete, but the only event defined (`rescue_rush_jun2026`, June 1–15 2026) has expired. Add new `EventDefinition` entries to `EventRegistry.allEvents` before the next event window.

## Code Health (from June 2026 audit — fix in priority order)

- [x] **BUG-01:** Fix duplicate NotificationManager in MergeBoardView.swift — remove `@State private var notifManager`, replace all 5 uses with `NotificationManager.shared`
- [x] **BUG-02:** Add `persist()` call at end of `claimLoginReward()` and `claimPassDaily()` in MergeBoardViewModel.swift (~lines 1797, 1908)
- [x] **BUG-03:** Fix timer RunLoop mode in `startTimer()` — change `.default` to `.common` (or switch to DispatchSourceTimer) so ticks don't pause during scroll gestures
- [x] **PERF-01:** Move JSON encoding off main thread — capture state on @MainActor, then `Task.detached(priority: .utility)` for encode + write in GameStore.swift (~lines 222–233)
- [x] **PERF-03:** Guard `tickProducers()` write-back with Equatable check on ProducerTile — only write back when value changed; skip `.familySpawner` ticking entirely
- [x] **QA-01:** Fix strong capture in `authenticateGameCenter` — change `{ [self]` to `{ [weak self]` in MergeBoardViewModel.swift (~line 605)
- [x] **QA-02:** Migrate SoundManager to `@Observable`; remove `import Combine` from ShopView.swift
