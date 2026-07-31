# PawSanctuary — TODO

## Pending

### Xcode capability toggles (Signing & Capabilities — not code changes)
- [ ] Enable **Push Notifications** capability. Required for `UNUserNotificationCenter` permission prompt to work on device — the scheduling logic in `NotificationManager.swift` is already fully implemented and just needs this to actually fire. (Works on a free/Personal Team.)
- [ ] **Re-enable Game Center capability — REGRESSED.** Enabled once in commit `adf1be4`, but `PawSanctuary/PawSanctuary.entitlements` is now an empty `<dict/>` with no `com.apple.developer.game-center` key, and `project.pbxproj` has no Game Center references. `CardTrading.swift` still imports GameKit and `authenticateGameCenter` runs at launch, so the code expects a capability the app no longer declares. Restore via Xcode → Signing & Capabilities → `+ Capability` → Game Center (**not** by hand-editing the plist — that skips App ID registration and causes signing failures). Works on a free/Personal Team. Commit on its own, noting it as a regression. Card trading also needs CloudKit, which remains blocked on paid enrolment.
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
- [ ] **Selling may still read as the default.** Phase 2c §5 asked for a contextual prompt the first time a player holds a mid-tier item with no matching order; the simpler branch was taken (a tutorial hint naming both channels) because the prompt needs new trigger state. Revisit if playtesting shows players sell reflexively rather than weighing the 2.4x premium.
- [x] **RESOLVED.** ~~GDD is now stale in three sections~~ — section 5 (power-up selection, Phase 2), section 4's tier tables (Phase 2b), and section 7 (economy, Phase 2c) have all been rewritten from source and carry dated rewrite notes matching the current code (`PawSanctuary_GDD.md` v4.0).

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
