# PawSanctuary — TODO

## Pending

### Test rot — `testCheckEventLifecycleRegistersAnIndependentRiderForEachRealActiveEvent` — RESOLVED 18 Aug 2026

~~`ConcurrentEventRiderRegistrationTests` (`EventSystemTests.swift:196`) reads real wall-clock time against `EventRegistry.activeEvents`... its own author already anticipated: "Foster Weekend's window (2026-08-14...18) may have closed -- add a fresh overlapping EventDefinition to re-enable this test." That's now exactly what's happening~~ — **fixed at the root, not patched.** `checkEventLifecycle()` (`MergeBoardViewModel.swift`) and `ParallelBoardEventRegistry.activeEvent` (`ParallelBoardEvents.swift`, `static var` → `static func activeEvent(at date: Date = Date())`) both gained an injectable `at date:` parameter, defaulting to `Date()` so the one production call site (`loadGame()`) is unchanged. The two rotted tests now check against a fixed, permanent synthetic date (2026-09-12) deep inside the real, already-shipped 90-day calendar instead of today's real wall clock — they'll never rot again, since those calendar dates don't change. A third test was added that this fix directly unlocked (`testCheckEventLifecycleUnregistersOnlyTheEndedEventsRiderWhenOneOfTwoOverlappingEventsEnds`), closing a gap `LiveOpsEngineTests.swift` had explicitly flagged as untestable before this. 373/373 tests pass; smoke-tested on the iOS Simulator to confirm the production call site's behavior is unchanged.

Deliberately did *not* take the cheaper "add another Foster-Weekend-style event" option the original entry also offered — that would have rotted again the next time its own window closed, same failure mode, just delayed.

### Back-to-back `persist()` calls can race each other's disk write — RESOLVED 18 Aug 2026

~~Writing `RewardLadderPersistenceTests`... surfaced a genuine race... three `applyPurchase` calls fired with no gap between them landed only 2 rungs on disk after relaunch, not 3~~ — **fixed at the root.** Every write now carries the real `Date()` it was captured at (`GameStore.save`/`saveAndSync`/`saveNow` all gained a `capturedAt: Date` parameter), and a new `OSAllocatedUnfairLock`-guarded high-water mark (`GameStore.shouldWrite(capturedAt:)`) rejects any write older than the most recent one already accepted — so "most recent capture wins" holds regardless of which fire-and-forget `Task.detached` happens to finish first. A per-instance incrementing counter was considered and rejected: it would need state that doesn't survive across the many short-lived `MergeBoardViewModel` instances a single test process creates, silently rejecting a later instance's legitimate first write as "stale." `saveNow()` stayed fully synchronous (no actor hop) and shares the same guard via the lock, so it still can't be deferred at app-suspension the way `Task.detached` can.

**Test coverage, as the original entry asked for — its own, not bundled into feature work:** three new `PersistenceTests.swift` tests invert call order directly (call the newer-timestamped write first, the older-timestamped one second) rather than trying to race real concurrency, deterministically proving the guarantee for `save()`, `saveAndSync()`, and `saveNow()` each. `RewardLadderPersistenceTests`' regression test no longer needs the artificial spacing between purchases it used to require — three back-to-back `applyPurchase` calls with zero gap now correctly persist all three rungs, a real end-to-end confirmation the fix works, not just a unit-level one.

424/424 tests passing (4 new). Confirmed via Simulator: fresh install still launches and saves/loads cleanly.

### Xcode capability toggles (Signing & Capabilities — not code changes)
- [ ] **Phase 3, Task 3.5.** Enable **Push Notifications** capability. Required for `UNUserNotificationCenter` permission prompt to work on device — the scheduling logic in `NotificationManager.swift` is already fully implemented and just needs this to actually fire. (Works on a free/Personal Team.) Blocks nothing else in Phase 3 — 3.1–3.4 are done and don't depend on it.
- [ ] **Re-enable Game Center capability — REGRESSED.** Enabled once in commit `adf1be4`, but `PawSanctuary/PawSanctuary.entitlements` is now an empty `<dict/>` with no `com.apple.developer.game-center` key, and `project.pbxproj` has no Game Center references. `CardTrading.swift` still imports GameKit and `authenticateGameCenter` runs at launch, so the code expects a capability the app no longer declares. Restore via Xcode → Signing & Capabilities → `+ Capability` → Game Center (**not** by hand-editing the plist — that skips App ID registration and causes signing failures). Works on a free/Personal Team. Commit on its own, noting it as a regression. Card trading also needs CloudKit, which remains blocked on paid enrolment.
- [ ] **BLOCKED on paid Apple Developer Program enrollment ($99/yr):** the Xcode account for this project (team `H2QZGDY8UN`) is currently a free/Personal Team, and Apple does not expose the **iCloud** capability at all for Personal Teams — it's missing from the `+ Capability` list, not just greyed out. Confirmed 2026-07-23. Both of the following are blocked on enrolling first:
  - [ ] Enable **iCloud** capability → check **Key-Value Storage**. The sync code in `GameStore.swift` is wired and degrades gracefully without it, but cross-device save sync won't actually happen until this is provisioned.
  - [ ] Enable **iCloud** capability → check **CloudKit** → create/select a container (separate from the Key-Value Storage service above). Required for card trading.
- [ ] In the CloudKit Dashboard, confirm the `CardTrade` record type has fields `cardID`, `fromPlayerID`, `fromDisplayName`, `toPlayerID`, `toDisplayName`, `sentAt`, `status` — mark `toPlayerID`, `fromPlayerID`, and `status` **Queryable** (the trading queries in `CardTradeBackend` filter on these and CloudKit rejects predicates on non-queryable fields). Deploy the schema from Development to Production before release. Depends on iCloud/CloudKit above.

### Real integrations still stubbed
- [ ] **Phase 3, Task 3.6 — now load-bearing, not just pre-launch polish.** `AdProvider.swift`'s `StubAdProvider` just waits 1.5s and always succeeds. Swap in a real SDK (AdMob, AppLovin, etc.) — the reward logic and daily-cap bookkeeping around it are already correct. The rebuilt `KibbleRefillSheet` (3.1) is built around a real ad actually being available as the first rung of the ladder, so this blocks Phase 3 from being fully closed even though 3.1–3.4 are done. Needs an SDK/account decision before work can start.
- [ ] When ready for final audio assets, replace `AudioServicesPlaySystemSound(XXXX)` calls in `SoundManager.swift` with `AVAudioPlayer` instances pointed at the real asset files.

### App Store submission blockers (not code)
- [ ] Privacy policy URL
- [ ] Terms of service URL
- [ ] AI-generated content disclosure (Guideline 2.1)
- [ ] Age rating declaration
- [ ] Replace the placeholder App Store URL in `InviteSystem.swift` (`pawSanctuaryAppStoreURL`, currently `id0000000000`) once the app has a real listing.

### Stale documentation — Alignment Plan Phase 1 checklist — RESOLVED 18 Aug 2026

~~`specs/PawSanctuary_Alignment_Plan.md` §4 (Phase 1 — Foundations) shows all six items (1.1–1.6) unchecked, but the underlying work is very likely already shipped~~ — **verified against actual source, file/line, and checked off in the Alignment Plan itself** (§4), same rigor as the Phase 2 correction this entry asked for, not just assumed from context:

- **1.1** (`[OrderReward]` list + `RewardKind`) — confirmed: `AnimalSpecies.swift:768-808`, `AdoptionBoard.swift:66-135`, `MergeBoardViewModel.swift:3109`.
- **1.2** (rider-injection hook) — confirmed: `OrderRewardRegistry.swift:14-31`, called at generation time in `AdoptionBoard.swift:128`.
- **1.3** (`ChainCategory.currency`) — confirmed: `ItemChain.swift:30`, real chains using it at `:417`/`:435`.
- **1.4** (player purchase-state tracking) — confirmed: `PlayerCommerceState` (`AnimalSpecies.swift:953-977`), `firstLaunchDate` set exactly once at `MergeBoardViewModel.swift:888`.
- **1.5** (live-ops primitive interfaces) — confirmed: `LiveOpsPrimitives.swift`, 6 of the original 8 still present with real Phase 6a implementations, rider injection folded directly into 1.2, and the 8th (`ParallelBoardHosting`) legitimately retired 16 Aug 2026 once Parallel Board's real shape was known — not a gap.
- **1.6** (schema migration) — confirmed: unbroken chain, now at v36; the primitives' own fields got their migration at v29, tested.

See the Alignment Plan's §4 for the full per-item citations.

### Content gaps
- [ ] **Seasonal Events — add future events to registry:** the infrastructure in `EventSystem.swift` is complete, but the only event ever defined (`rescue_rush_jun2026`, June 1–15 2026) has expired. Add new `EventDefinition` entries to `EventRegistry.allEvents` — nothing seasonal is currently active.
- [ ] **Card artwork:** all 54 cards in `CardSystem.swift` use SF Symbols as stand-ins. Illustrated art is a content/asset-production task, not a code change.

### Parallel Board — "Second Chances" on-screen verification still open (added 16 Aug 2026)

`specs/Spec_Phase6b_ParallelBoard.md` §3.1–§3.7 and §5 are fully implemented, tested (366/366), and merged — but the spec's own "Verified on screen: opening the event, tapping the generator, merging to a completed top-tier item, seeing progress-track credit land" acceptance item is still unchecked. The real test event (`second_chances_20260911`, `ParallelBoardEventRegistry`) doesn't start until **2026-09-11** (ends 2026-09-14), so it can't be opened in a running instance of the app until that window arrives — every fact a live screen would demonstrate is covered by unit tests instead (dates, overlap with Sanctuary Circle S1 and Playtime Rush, chain/tier count, milestone-table shape), but the actual tap-generator → merge → progress-advance flow has never been watched happen.

An attempt was made the same day to shortcut this by moving the iOS Simulator's guest clock forward via Settings → General → Date & Time, using blind coordinate taps (no accessibility-tree reader available for that control surface). It didn't reliably reach the right screen after a reasonable number of tries and was abandoned rather than continued indefinitely — see the spec's own §5 status note for the full account.

- [ ] **When 2026-09-11 arrives (or the Simulator's clock can otherwise be moved into 2026-09-11→09-14):** launch the app, confirm the "Second Chances" `ParallelBoardTaskCard` appears in `TaskStripView`, tap it to open `ParallelBoardView` full-screen, tap the generator cell to place an item, merge two matching items to confirm tier-advance, merge to a completed top-tier item and confirm the progress bar/`ProgressTrack` advances by `parallelBoardTokensPerCompletion` (10), and confirm a force-quit/relaunch mid-event restores the board via `GameState.parallelBoardState` (v36) rather than resetting it. Check off the acceptance item in the spec once done.
- A scheduled reminder has been set (see reference below) to surface this automatically once the window opens — this TODO entry is the fallback if that doesn't fire or gets missed.

### `SWIFT_ACTIVE_COMPILATION_CONDITIONS` was never set — every `#if DEBUG` block has been dead in every command-line build (found + fixed 18 Aug 2026)

Found while adding a `#if DEBUG` debug toggle for the Reward Ladder (below): the new method compiled fine into a standalone `xcodebuild build`, but a test referencing it directly by name failed with "no member" — proof the symbol didn't actually exist in that build, not just a visibility quirk. Checked `xcodebuild -showBuildSettings`: `SWIFT_ACTIVE_COMPILATION_CONDITIONS` was empty for both the `PawSanctuary` and `PawSanctuaryTests` targets under the Debug configuration, and grepping `project.pbxproj` confirmed it was never set anywhere in the project — not at project level, not per-target. Probed with a throwaway test calling the *existing* `resetToFreshGame()` (unrelated to this session's work, added long before) and got the identical failure, confirming this wasn't new: `#if DEBUG` has evaluated false in every `xcodebuild`-driven build this project has ever produced, silently dropping `resetToFreshGame()`, `ProgressTrack.reset()`, and the "Reset Save (Debug)" button itself from every such binary. Builds/runs driven from Xcode.app's own UI may have masked this (its default build settings can differ from bare `xcodebuild`), which is likely why it went unnoticed.

**Fixed:** added `SWIFT_ACTIVE_COMPILATION_CONDITIONS = "DEBUG $(inherited)";` to the project's Debug configuration (`project.pbxproj`, project-level `XCBuildConfiguration`, applies to both targets). Verified via `-showBuildSettings` (now resolves to `DEBUG`) and confirmed visually on the Simulator — a new `#if DEBUG`-gated button (see below) now actually renders on screen, which it would not have before this fix regardless of any code correctness.

### Reward Ladder — debug unlock toggle added, full interactive verification still open (18 Aug 2026)

`specs/Spec_Phase6b_RewardLadder.md` Tasks 3.1–3.5 are fully implemented and tested (396/396). Per §5's flagged open question, added `MergeBoardViewModel.unlockMonetizationForTesting()` (`#if DEBUG`, sets `hasReachedFirstWall = true` and bumps `playerLevel` to at least `monetizationUnlockLevel`) plus a HUD button in `MergeBoardView.swift` — placed in the **same slot the Shop button occupies once unlocked**, not inside `ShopView` itself, since `ShopView` is only reachable once `isMonetizationUnlocked` is already true (a toggle placed there could only ever fire as a no-op). Confirmed via Simulator screenshot: the "Unlock" button correctly renders on a fresh, level-1 account, right where the fix above made it possible to see for the first time.

- [ ] **Full interactive click-through still not completed this session.** Tapping through the Simulator hit a wall unrelated to any of the above: the daily-login "Good Morning!" modal's `Claim!` button never registered a synthetic tap across many calibrated attempts, and (newly noticed comparing screenshots) the top HUD row renders visibly dimmed while the modal is up — Storage/Map at the bottom don't dim and did register taps, suggesting the top HUD sits under some part of the modal's presentation that the bottom bar doesn't. Once past that (or once verified from a build not hitting this specific tap issue): tap the new "Unlock" button, confirm `RewardLadderSection` (Shop) and `RewardLadderTaskCard` (task strip) both appear, confirm the purchased/next/locked rung states render as designed, and complete one real purchase to watch `applyPurchase` grant the correct rewards — already unit-tested (`RewardLadderPurchaseTests`/`RewardLadderContentTests`), never watched happen.

### Test suite health (discovered 26 July 2026, fixed same day)

`PersistenceTests.swift` (~1,100 lines) had never successfully compiled. The scheme's `TestAction` had no `<Testables>` entry, so `xcodebuild test` failed outright rather than running; once fixed, the test target's deployment target (17.0 vs the app's 17.6) blocked `@testable import`; once that was fixed, 9 accumulated compile errors surfaced referencing fields deleted long ago (`GameState.supplyCount`, `AdoptionOrder.rewardKibble`, `AreaReward.newSpecies`).

**Implication:** every schema migration from v8 through v24 shipped without test verification. Treat the older migrations as unproven rather than trusted. If a save-corruption bug surfaces, that chain is the first place to look.

All fixed: scheme wiring, deployment target, the 9 compile errors, and 7 further behavioural failures the suite surfaced once it could actually run (stale expected values for tier-clamping/level-band logic and Sanctuary Map upgrade-tier count, one `isTopTier` assertion against test data that assumed a 9-tier chain instead of the real 15-tier one, and a `GameStore.save()`/`load()` race in 3 tests — see below). 70 passing, then 78 with these fixes.

- [x] **RESOLVED (commit `fdf02df`, 4 Aug 2026) — stale entry, already fixed before this line was next reviewed.** ~~`RescueStage` is vestigial but still drives live quest generation... quests can only ever target the bottom 9 tiers... Tiers 9–14 unreachable~~. Two things had changed since this was written that this entry never caught up to: the animal chains themselves were cut from 15 tiers to 12 (`animalChainTopTier = 11`) in an earlier pass, and separately, `fdf02df` ("Extend quest pools to reach tiers 9-11, closing the endgame quest gap") added direct `reachTier` goals for tiers 9/10/11 ("Mythic"/"Ancient"/"Primordial") to both the legendary quest pool and the hard/legendary daily-challenge pool in `QuestCoordinator.swift`, alongside the pre-existing `RescueStage`-derived entries for tiers 0–8. `PawSanctuaryTests/QuestCoordinatorTests.swift` covers it, including a 2000-iteration statistical reachability check at max player level confirming all three top tiers actually get generated, not just theoretically present in the pool. `RescueStage` itself is still vestigial/legacy — it just isn't blocking anything anymore. Verified current on 13 Aug 2026 (also independently confirmed in `specs/Gap_Analysis_Round2.md` as closed item C-10).

### Background save was fire-and-forget at suspension time — FIXED 26 July 2026

The `GameStore.save()`/`load()` race hit by 3 tests above wasn't only a test-timing artefact. `MergeBoardView.swift` handled `.background`/`.inactive` by calling `viewModel.persist()` under a "Flush save" comment, but `GameStore.save()`/`saveAndSync()` are `Task.detached(priority: .utility)` — a low-QoS task started as iOS suspends the process, with no background-task assertion protecting it. Not a flush; a request that might never be scheduled. Saves made in the final moments of a session could be silently lost.

**Resolution:** added `GameStore.saveNow(_:)` (synchronous, reusing the existing private helpers) and `MergeBoardViewModel.persistNow()`. `.background` now saves synchronously; `.inactive` keeps the async path, since it fires on transient events (Control Centre, notification banners) and on the way back to `.active`. `save()`/`saveAndSync()` unchanged — the PERF-01 detachment remains correct for periodic saves.

**Measured:** encode + two atomic writes + cloud check averages **1.2 ms** (max 2.1 ms) on a realistic ~9.6 KB `GameState`. Safe on the main thread at a one-time transition.

The three previously-failing persistence tests now call `saveNow()` directly, so they exercise the real production path instead of a hand-rolled substitute.

### Sub-object system defects (traced 27 July 2026)

Investigation of `SubObjectSystem` for the Phase 2 economy work found three distinct problems.

- [x] **RESOLVED (Phase 2, commit `a36faed`).** ~~Spawner Refill is an unbounded kibble faucet under neutral pricing.~~ Replaced by a Board Item Grant at the same 10% weight, now rarity-rolled rather than tier-targetable. Note: the grant's `deepestUnlockedTier - 2` rule proved exponential in tenure and required an absolute ceiling (`recirculationMaxItemTier = 7`). `SubObjectSystem.swift:149` grants a flat `+20` kibble through a forwarding setter that **bypasses `kibbleRegenCap`** (quest and level rewards clamp; this path does not). Effect is keyed on merged tier, so 4 tier-0 sub-objects become one tier-2 Spawner Refill.
  Expected return per spawner activation = `p(drop) x 20 / 4`:

  | Condition | Drop rate | Kibble per activation |
  |---|---|---|
  | Base | 0.20 | **1.00** — exactly break-even at x1 |
  | Full area upgrades (+45pp) | 0.65 | **3.25** |
  | Base + Hoard (Rodents) | 0.20 | **2.00** |
  | Full upgrades + Hoard | 0.65 | **6.50** |

  Invisible under current pricing (an x8 tap costs 8 kibble, so ~12% rebate). Under Phase 2's neutral `cost = 2^tierIndex`, x1 tapping becomes self-funding and then outright profitable. Family spawners have no cooldown, there is no daily cap, and the 6 power-up slots spill into animal inventory rather than capping.
  **Decision (27 July):** remove kibble from the sub-object reward table entirely; replace the tier-2 effect with a **board-item grant**. Reducing the amount does not fix the shape — the rebate and the cost are denominated in the same per-tap unit. The effect is also vestigial: it exists to refill spawner charges, and family spawners have unlimited charges. Converting it to an item grant turns the exploit into the recirculation channel Phase 2 needs.

- [x] **RESOLVED (Phase 2, commit `a36faed`).** ~~8 Sanctuary Map upgrades sell a bonus that does nothing.~~ Rarity selection was wired through to effect resolution, so `pityTimerReduction` now affects real pity thresholds. `pityTimerReduction` (7x5 + 1x10 = -45) feeds pity thresholds that gate `SubObjectRarity` — but rarity is destructured away with `_` at both call sites (`MergeBoardViewModel.swift:1121`, `:1138`), and `SubObjectRarity` has zero references outside `SubObjectSystem.swift`. The rarity/pity subsystem is a closed loop with no output.
  **This is a defect, not debt** — players spend coins and materials on these upgrades. Either wire rarity through to effect selection, or repurpose those 8 upgrade slots. Resolve before launch.

- [x] **RESOLVED twice, drifted twice.** ~~GDD section 5 does not match the implementation.~~ Rewritten from source 27 July (tier-keyed), invalidated the same day by Phase 2 (rarity-keyed), rewritten again. **Fourth drift on this section** — treat any future claim in GDD section 5 as suspect until checked against source. It documents a 60/25/10/5 rarity table selecting the power-up effect. The code selects on merged tier and discards rarity. Third instance of that section being wrong about this system — treat it as unreliable until rewritten from source.

### The coin economy — RESOLVED (Phase 2c, commit `ff20b88`)

Phases 2 and 2b modelled kibble supply against kibble demand and hit the target ratio curve. **Coins were never modelled** — yet they gate the Sanctuary Map (15 areas x 4 upgrade tiers), which is the game's forever goal.

Two faucets exist and were never derived against each other:

| Channel | Tier-11 item | Approx. coins/day at ~745 kibble/day |
|---|---|---|
| Fulfil an adoption order — `(tier+1)*2 + rand(0...2)` | ~25 coins | ~110 |
| **Sell the item** — `animalSellValues[11]` | **18,000 coins** | **~6,500** |

Selling is ~720x better per item and ~60x better as a daily channel, so it bypasses the intended merge → order → coin → map loop entirely. For scale, early map upgrades cost 80–1,600 coins: one tier-11 sale funds several complete early areas.

- [x] **Model coin supply against Sanctuary Map demand** the way Phase 2 modelled kibble. What should a full map build-out cost in player-days?
- [x] **Decide what selling is for.** Resolved: both channels pay coins, orders pay ~2.4x more. Selling is instant liquidity for items no order wants. ~~ Recommended: a lossy pressure valve for unwanted items, priced *below* what fulfilling an order for the same item pays — not a progress-monetization channel.
- [x] **Re-derive both tables together.** Orders now ~6.5 coins/kibble of build cost, selling `round(2.75 * 2^tier)`. Also rescaled: weekly goals 50/120/250 -> 2,500/6,000/12,000, quest claims -> 50/150/400/1,000, dailies -> 400, ambassador merge -> 500, albums -> 6,250. ~~ Order coin payouts look too low relative to map costs; sell values look far too high relative to everything.

Note the sell table currently satisfies a defensible internal property (coins-per-kibble-of-build-cost rising monotonically, 1.0 at tier 0 to 8.8 at tier 11). The problem is not its shape but its scale relative to the order channel.

### Open items from the economy trilogy (Phases 2 / 2b / 2c)

- [x] **RESOLVED.** ~~Ambassador trio exchange was a trap — verify the fix in play.~~ Verified on screen 31 July 2026: with 3 matching Canines Ambassador tiles on the board, the Trio Exchange task card correctly reads "+21,120 coins" (3 × 5,632 sell value × 1.25 premium) with a single obvious Claim affordance — reads clearly as the best option for three matching Ambassadors.
- [x] **RESOLVED.** ~~Selling may still read as the default.~~ Added the contextual prompt Phase 2c §5 asked for: the first time a player selects a mid-tier (tier 3–8) item with no matching order, a one-time toast surfaces both numbers (`MergeBoardViewModel.maybeShowSellVsOrderNudge`, gated by the `hasShownSellVsOrderNudge` UserDefaults flag, same pattern as `tutorialCompleted`). Verified on screen 31 July 2026. Revisit only if playtesting shows players still sell reflexively despite the nudge.
- [x] **RESOLVED.** ~~GDD is now stale in three sections~~ — section 5 (power-up selection, Phase 2), section 4's tier tables (Phase 2b), and section 7 (economy, Phase 2c) have all been rewritten from source and carry dated rewrite notes matching the current code (`PawSanctuary_GDD.md` v4.0).

### Card trading — `claimedTradeIDs` grows without bound (found 8 Aug 2026, cold-start performance review)

`MergeBoardViewModel.claimIncomingTrade(_:)` ([MergeBoardViewModel.swift:2252](PawSanctuary/MergeBoardViewModel.swift:2252)) inserts into `claimedTradeIDs: Set<UUID>` (persisted, `GameState.claimedTradeIDs`, added v33) on every single accepted trade and never removes anything — grepped the codebase for any `.remove`/`.subtract`/reassignment of the set; there isn't one. It's insert-only for the life of the save.

The set exists for a real reason (its doc comment explains it): if `CardTradeBackend.markClaimed` never confirms on CloudKit, a still-`pending` trade record can get re-fetched and would otherwise be granted twice. But it only needs to remember a trade *until that confirmation lands* — not forever. For an active trader this will quietly grow into the hundreds or thousands of UUIDs over months of play, all serialized on every `save()`/`persist()` and deserialized on every `GameStore.load()` — a slow-burn regression against the cold-start load time fixed elsewhere in that same review (see the four commits from `9b96126` through `4d795f5`), and one that specifically punishes the game's most socially-engaged players.

**Why not fixed on the spot:** the correct fix needs `CardTradeBackend.markClaimed` (currently `Void`-returning and not even awaited by its caller — see [CardTrading.swift:251](PawSanctuary/PawSanctuary/CardTrading.swift:251)) to report success back so the caller can prune the ID once confirmed. That touches the trade-confirmation flow in a system this file already documents as having shipped real correctness bugs before (dropped sign-in controller, unmanaged `GKAccessPoint` overlay, and the double-grant bug this very set was added to prevent). Getting the timing wrong risks reintroducing that double-grant. Deliberately deferred rather than bundled into a performance-focused session — this is a correctness-adjacent change, not a mechanical one.

- [x] **RESOLVED (Option A, chosen deliberately over Option B — see below).** ~~cap `claimedTradeIDs` at the most recent N entries~~ `claimedTradeIDs` changed from `Set<UUID>` to `[UUID]` (same JSON array shape, no migration needed) and capped at `maxClaimedTradeIDs = 200` via a new `appendCapped(_:to:cap:)` helper — evicts oldest-first once over the cap, generous relative to the 5/day send throttle. Leaves `markClaimed`/confirmation semantics untouched, so no risk to the double-grant guard this set exists to enforce.
- [ ] **Option B (exact, higher risk, not attempted) — remains open if the cap ever proves insufficient:** make `markClaimed` return success/failure and only remove the ID from `claimedTradeIDs` once CloudKit actually confirms the status write. Requires care not to reintroduce the double-grant `claimedTradeIDs` exists to prevent — recommend a dedicated pass with trading-specific test coverage, not a bundled edit.

### Competitive analysis
- [x] **DONE (13 Aug 2026) — see `specs/Feature_Parity_Audit.md`.** ~~Feature-parity audit vs. Gossip Harbor / Travel Town / Tasty Travels~~. Catalogued ~50 discrete features across 9 categories, cross-checked against source. Most gaps found were already known and already decided (3.8/3.9, the conservative monetization posture from 3.7). Two genuinely new, undecided findings surfaced: no tier number shown on board tiles (cheap, directly recommended by the reference research), and generator cooldowns cluster at 25–60s with no long-cooldown "return visit" class like the reference's 30-min generators — unless the Free Chest (3.6) is judged to already cover that role.

## Code Health (from June 2026 audit, cross-checked against `docs/CODE_HEALTH.md` — fixed in the July 2026 pass unless noted)

- [x] **BUG-01:** Duplicate NotificationManager in MergeBoardView.swift — fixed, all call sites use `NotificationManager.shared`
- [x] **BUG-02:** Missing `persist()` after `claimLoginReward()`/`claimPassDaily()` — fixed
- [x] **BUG-03:** Timer RunLoop mode (`.default` → `.common`) — fixed
- [x] **PERF-01:** Main-thread JSON encoding on every save — fixed (`Task.detached` off the main actor)
- [x] **PERF-02:** `board.flatMap { $0 }` re-scanned 63 cells 17× per interaction — fixed via a cached `emptyUnlockedCells` property, recomputed once per board mutation
- [x] **PERF-03:** `tickProducers()` unconditional write-back every second — fixed (Equatable guard)
- [x] **PERF-04:** `exchangeableTrios` full-board scan at render time — cached (depends only on board state). `retirableProducers` deliberately left uncached — it also depends on quest/challenge completion state that doesn't always coincide with a board mutation, and a 63-cell scan is cheap enough that a stale-cache bug wasn't worth risking.
- [x] **PERF-05:** ~~`claimedTradeIDs` grows without bound, serialized/deserialized on every save/load~~ — capped at 200 entries, oldest-first eviction. See "Card trading — `claimedTradeIDs` grows without bound" above.
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
- [x] **RESOLVED (15 Aug 2026) — Extract `BoardStateManager`:** the single largest structural item from `docs/CODE_HEALTH.md`. **Phases A–D all complete — see `specs/BoardStateManager_Extraction_Plan.md` and `specs/BoardStateManager_Phase_D_Plan.md`.** `BoardStateManager` (`PawSanctuary/BoardStateManager.swift`) owns `board`/`boardIsFull`/`emptyUnlockedCells` plus ten read/write primitives (`item(at:)`, `hasProducer(at:)`, `producer(at:)`, `clearItem(at:)`, `setItem(_:at:)`, `setProducer(_:at:)`, `setUnlocked(_:at:)`, `isEmpty(at:)`, `isUnlocked(at:)`, `setBubbledAt(_:at:)`); forty-two functions route through them instead of indexing `board[...]` directly — every single-cell dereference in the file, including the last Phase C gap (`freshStart`) and everything Phase D's `attemptMergeOrMove` rewrite introduced. `apply` (`MergeBoardViewModel`'s `GameState`-restore function) remains deliberately on bulk `board` access — its touches are whole-array assignment and row padding, not single-cell. `attemptMergeOrMove` itself is now 43 lines of pure dispatch (was 144) — every branch (producer merge/swap/move, the eligible-merge pipeline, superpower-piece-spent, item swap, item move) routes through a `MergeResult` case and `apply(_:)`, with `computeMergeOutcome`/`computeProducerOutcome` as the pure, independently-tested decision steps for the two branches that had real decisions to make. One small open item remains, tracked in the Phase D doc (§3.4): a cosmetic `animatingCell`-clobbering quirk, assessed and deliberately left documented rather than fixed. Two two-session collisions happened along the way (round 7's `activateProducer`/`fce3325`, and D3's `freshStart` gap/`b909155`) — both confirmed correct via full test passes, neither rewritten, per this codebase's git safety rules. Also flagged along the way: a dead unreachable branch in `selectedItemInfo` (`task_385bed05`, already picked up by the user).
