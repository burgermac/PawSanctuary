# PawSanctuary — Project Context

iOS merge-2 puzzle game. SwiftUI, solo-developed.

## Current work: competitive alignment

The game is being aligned against **measured** data from three competitors — Gossip Harbor, Travel Town, Tasty Travels — captured and analysed in July 2026.

**Read `specs/PawSanctuary_Alignment_Plan.md` first.** It is the master backlog: phases, the design decisions already made (D1–D11), and the working method. Do not propose changes that contradict a recorded decision without flagging it explicitly.

Each spec carries its own status (done / draft / parked) at the top — read the spec, not this file, for where it stands.

| Document | Purpose |
|---|---|
| `specs/PawSanctuary_Alignment_Plan.md` | Master plan and backlog — **start here** |
| `specs/Spec_Phase1_Foundations.md` | Phase 1 task-by-task implementation spec |
| `specs/Merge2_Reference_Blueprint.md` | What good looks like — architecture + psychology |
| `specs/PawSanctuary_Gap_Analysis.md` | Why each change is being made |
| `specs/Feature_Parity_Audit.md` | Feature coverage vs. the three reference titles |
| `specs/BoardStateManager_Extraction_Plan.md` | Phased `BoardStateManager` extraction — Phases A–D complete (15 Aug 2026) |
| `specs/BoardStateManager_Phase_D_Plan.md` | Phase D (`attemptMergeOrMove` → `MergeResult`) — complete (15 Aug 2026); §3.4 cosmetic quirk documented, not fixed |
| `specs/Spec_Phase6c_ConcurrentEvents.md` | Concurrent weekly event + Pass (D5) |
| `specs/Spec_Phase6c_Calendar.md` | 90-day rolling `EventDefinition` calendar |
| `specs/Spec_Phase6b_ParallelBoard.md` | Parallel Board event (D5); older "ParallelBoardTaskCard" references are stale — it is now a `TaskTrayView` tile |
| `specs/Spec_Phase6b_RewardLadder.md` | D8 "chain offer" reward ladder (renamed to avoid clashing with merge-chain vocabulary); real StoreKit flow still needs an Xcode Run, see `TODO.md` |
| `specs/Spec_SpendQuotaDailies.md` | D6 spend-currency tasks; daily-challenge half superseded by `Spec_DailyHandInTasks.md` |
| `specs/Spec_StandingQuestSpendGoals.md` | D6 follow-up: spend goals on standing quests |
| `specs/Spec_PartyBoard_Draft.md` | Gacha prize-grid offer — draft, parked pending more reference footage |
| `specs/Spec_BoardAnimation_Draft.md` | Merge burst / producer shimmer animations (mostly implemented); suspected real-device OOM from shimmer blur/shadow still untested |
| `specs/Spec_OrdersAndTasks_Draft.md` | Order baskets, Smile Points, Care Points — implemented |
| `specs/Spec_TravelTownReview_Draft.md` | Travel Town review — draft |
| `specs/Spec_ParallelBoardReview_Draft.md` | Travel Town Greek Fest capture — draft, no decisions |
| `specs/Spec_TaskTrayRedesign_Draft.md` | Task tray + HUD flattening — implemented; Loyalty and ambassador-trio tiles verified on screen 11 Nov 2026, Pass-daily tile still unverified (needs the StoreKit run) |
| `specs/Spec_QuestLaneCards_Draft.md` | Quest cards in the order lane (a design decision, not a reference reading); amends TaskTrayRedesign §3.4–3.6 |
| `specs/Spec_KibbleDrive_Draft.md` | $4.99 activity-fed "Kibble Drive" ladder — steps 1–3 done, steps 4–7 not started; StoreKit unverified |
| `specs/Spec_DailyHandInTasks.md` | Daily hand-in baskets — implemented (schema v40); overrides Gap Analysis Round 2 §3.1 near-miss stagger |
| `PawSanctuary_GDD.md` | Game design doc v3.0 — has drifted before, verify claims against code |
| `scripts/README.md` | `scripts/refvideo.swift` reference-video analysis tool |
| `TODO.md` | Launch blockers and code-health debt |
| `docs/CODE_HEALTH.md` | Known structural debt |
| `docs/PawSanctuary_Graphical_Element_Inventory.xlsx` | Every merge-chain visual element; regenerate from source rather than hand-editing |

Specs are written to be self-contained. If a spec seems to conflict with the code, **check the code and say so** — the spec was written from a read of the codebase and may have missed something.

## Working rules for this project

1. **One task per session.** The specs are broken into numbered tasks. Do one, verify it, commit it, stop. Do not batch.
2. **Keep the game playable at every commit.** No commit should leave a build that won't run.
3. **Respect the out-of-scope list.** Each spec has one. Later-phase plumbing lands early by design; using it early is how phases bleed into each other.
4. **Never break the migration chain.** `GameStore` has an unbroken migration path back to v8 (check the current schema version in code). Any change to a persisted shape needs a version bump, a migration, and a test in `PersistenceTests.swift`.
5. **Ask before large refactors.** Any structural refactor is its own dedicated sprint — don't start one opportunistically. (The `BoardStateManager` extraction, Phases A–D, is complete.)

## Architecture

**Pattern:** MVVM. SwiftUI views over `@Observable @MainActor` domain coordinators, orchestrated by `MergeBoardViewModel`.

**Generalized chain model:** every mergeable item is `BoardItem(chainID: String, tier: Int)`. All display data resolves from `ContentRegistry` at runtime. Saves persist only chain ID and tier — never display data — so content can be added without a save migration.

**Tuning constants** live at the bottom of `AnimalSpecies.swift`; new tuning numbers go there, not inline.

## Conventions

- Swift 6 concurrency: domain coordinators are `@MainActor`, persistence encoding runs off-main via `Task.detached`
- No force-unwraps in new code
- Persisted enums use `String` raw values
- Migration helpers follow the existing naming: `migrateVNtoVN+1(_ data: Data) -> GameState?`

## Testing

`PawSanctuaryTests/PersistenceTests.swift` covers save/load/migration. Every schema change needs a case here. Run before every commit that touches `GameState`.

Older migrations (v8–v24) shipped before the suite first compiled (26 July 2026) — treat them as less proven than newer ones. If a save-corruption bug surfaces, look there first.
