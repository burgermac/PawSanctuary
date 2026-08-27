# PawSanctuary — Project Context

iOS merge-2 puzzle game. SwiftUI, ~16,700 lines across 39 Swift files. Solo-developed.

## Current work: competitive alignment

The game is functionally near-complete but was built ad hoc from informal observation of published merge-2 titles. It is now being aligned against **measured** data from three competitors — Gossip Harbor, Travel Town, Tasty Travels — captured and analysed in July 2026.

**Read `specs/PawSanctuary_Alignment_Plan.md` first.** It is the master backlog: seven phases, the seven design decisions already made, and the working method. Do not propose changes that contradict a recorded decision without flagging it explicitly.

| Document | Purpose |
|---|---|
| `specs/PawSanctuary_Alignment_Plan.md` | Master plan and backlog — **start here** |
| `specs/Spec_Phase1_Foundations.md` | Current phase, task-by-task implementation spec |
| `specs/Merge2_Reference_Blueprint.md` | What good looks like — theme-neutral architecture + the psychology behind it |
| `specs/PawSanctuary_Gap_Analysis.md` | Why each change is being made |
| `specs/Feature_Parity_Audit.md` | Feature-by-feature coverage vs. the three reference titles (complements the psychology-focused Gap Analysis docs) |
| `specs/BoardStateManager_Extraction_Plan.md` | Phased plan for the `BoardStateManager` extraction — Phases A–C done, Phase D deferred. Read before attempting it. |
| `specs/BoardStateManager_Phase_D_Plan.md` | Planning doc for Phase D (`attemptMergeOrMove` → `MergeResult`) — draft, open design questions unresolved, no code written yet. |
| `specs/Spec_Phase6c_ConcurrentEvents.md` | Phase 6c prerequisite — fixes the single-active-event model so a weekly event and the continuous Pass can run genuinely concurrently, per D5. Implemented and design-reviewed 16 Aug 2026. |
| `specs/Spec_Phase6c_Calendar.md` | Phase 6c — the real 90-day rolling `EventDefinition` calendar (13 weekly events + 3 sequential 30-day Passes) that the concurrent-events prerequisite unblocked. Implemented and design-reviewed 16 Aug 2026. |
| `specs/Spec_Phase6b_ParallelBoard.md` | Phase 6b — the third D5 event type, a second full board/chain/energy mini-game. Written cold 15–16 Aug 2026, implemented across §3.1–§3.7 + §5 content (`595d7b0`…`736e869`, `205da50`), 366/366 tests green at the time. **Design-authority code review complete 18 Aug 2026** — core mechanics (coordinator, energy, generator, merge resolution, registry, chain/progress-track content) all matched the spec exactly; found and fixed two real gaps: `resetToFreshGame()` (debug-only) didn't reset `activeParallelBoardEvent`, so a debug reset while an event was active would persist stale board state into the fresh save; and tapping the generator while another cell was selected left that selection visually active, so the next tap could silently attempt an unintended merge. Also closed a real test-coverage gap — `checkEventLifecycle()`'s actual coordinator creation/sharing/idempotence/teardown/relaunch-restore wiring had zero integration coverage (only the coordinator's own methods were unit-tested in isolation) — added `ParallelBoardLifecycleTests.swift` (7 tests) and a small injectable-date seam on `loadGame(at:)` to make the relaunch-restore path provable without waiting for the real calendar date. 441/441 green. **Still genuinely open, unrelated to this review:** the spec's own §6 on-screen acceptance item (tap-generator-merge-watch-progress-advance, live) — blocked until `second_chances_20260911`'s real window (2026-09-11→09-14) arrives, or a Simulator clock workaround is found; see `TODO.md`. |
| `specs/Spec_Phase6b_RewardLadder.md` | Phase 6b — D8 ("chain offer," renamed to avoid colliding with this codebase's own merge-chain vocabulary). Written cold and design-reviewed 18 Aug 2026. Tasks 3.1–3.5 all implemented and tested (424/424) — IAP + purchase logic, persistence, trigger gate, Shop + task-strip UI, real 6-rung registry content, plus a debug unlock toggle (§5). Both UI surfaces (`RewardLadderSection`, `RewardLadderTaskCard`) confirmed rendering correctly on screen 18 Aug 2026, matching design exactly. Only the real StoreKit purchase flow needs a proper Xcode Run to verify (not `simctl launch`) — see `TODO.md`. |
| `specs/Spec_SpendQuotaDailies.md` | D6 — a "Spend N currency" daily-challenge task type, overriding the Alignment Plan's own Warmth-pillar "out" recommendation (decided 18 Aug 2026, adopt anyway). Written cold, fully design-reviewed, and fully implemented 18 Aug 2026 — `QuestGoal.spendCurrency` case, progress pathway, all nine real spend sites wired, both currencies live in the daily-challenge anchor pool. Done. |
| `specs/Spec_StandingQuestSpendGoals.md` | D6 follow-up — extends `QuestGoal.spendCurrency` to standing quests (the `Quest` struct), confirmed out of scope for D6 itself once `generateQuest` turned out not to share the daily-challenge generator's formula. Written cold and fully design-reviewed 18 Aug 2026 — reward-rebate (no special case) and currency symmetry (both at all four difficulties) resolved; §4's numbers deliberately deferred to playtesting, not blocking. Tasks 3.1 (spend goals added to all four `generateQuest` difficulty pools) and 3.2 (`updateQuestsAfterSpend` + chokepoint) implemented and tested 18 Aug 2026 — 3.3/3.4 confirmed to need no new code (spec's own finding). Spec fully implemented; §5's on-screen check accepted as covered by the 6 new unit tests targeting this exact logic (no new UI surface — only an existing, already-verified Quest card occasionally showing an already-tested string) rather than a live Simulator confirmation, since forcing the RNG-gated roll proved impractical to automate reliably. Done. |
| `specs/Spec_PartyBoard_Draft.md` | Draft, open design questions unresolved, no code written yet, not yet entered into the Alignment Plan's D1–D8 log. A gacha-style prize-grid offer (12 tiles, one guaranteed free pull, real-money IAP for repeats) found via reference-video review 26 Aug 2026, reskinned toward PawSanctuary's own currencies/characters. Presentation surface and cadence deliberately deferred pending review of more reference material. |
| `specs/Spec_BoardAnimation_Draft.md` | Draft, no code written yet, same status as the Party Board draft. Merge-animation choreography (5 phases, ~1.0s) and a producer "affordance shimmer" gated on whether the player can afford the spawn, both measured from reference video 26 Aug 2026. Proposes a pet-themed tinted-fur particle for the shimmer, and flags that a `TimelineView`-based implementation would reverse the deliberate no-per-second-timer decision recorded at `CellView.swift:273-283`. |
| `PawSanctuary_GDD.md` | Game design doc v3.0. Section 5 (Sub-Object Spawning & Power-Ups) was rewritten from source on 27 July 2026 — it had described a rarity-weighted power-up table the code never implemented. That section is now accurate; the rest of the document was written from source but has drifted before, so verify before relying on any specific claim. |
| `scripts/README.md` | How to run `scripts/refvideo.swift` — the reference-video analysis tool (frame extraction, zoom crops, contact sheets) used to produce the animation/feature draft specs from competitor screen recordings. Covers both the cheap triage pass and the deep frame-by-frame dive. |
| `TODO.md` | Launch blockers and code-health debt |
| `docs/CODE_HEALTH.md` | Known structural debt |
| `docs/PawSanctuary_Graphical_Element_Inventory.xlsx` | Every merge-chain visual element (species x tier, plus every other `ChainCategory`), transcribed from `ItemChain.swift`/`AnimalSpecies.swift`/`SuperpowerSystem.swift` 19 Aug 2026 — the UI/art-style planning reference. All current icons are SF Symbol placeholders (no illustrated art yet); regenerate from source rather than hand-editing if chain content changes. Supersedes the root-level `Animal Species and Stages.xlsx`, which predates the Phase 2b 12-tier reduction and is now stale. |

Specs are written to be self-contained. If a spec seems to conflict with the code, **check the code and say so** — the spec was written from a read of the codebase and may have missed something.

## Working rules for this project

1. **One task per session.** The specs are broken into numbered tasks. Do one, verify it, commit it, stop. Do not batch.
2. **Keep the game playable at every commit.** No commit should leave a build that won't run.
3. **Respect the out-of-scope list.** Each spec has one. Later-phase plumbing lands early by design; using it early is how phases bleed into each other.
4. **Never break the migration chain.** `GameStore` is at schema v24 with an unbroken migration path back to v8. Any change to a persisted shape needs a version bump, a migration, and a test in `PersistenceTests.swift`.
5. **Ask before large refactors.** The `BoardStateManager` extraction (see `TODO.md`) is deliberately deferred as a dedicated sprint — don't start it opportunistically.

## Architecture

**Pattern:** MVVM. SwiftUI views over `@Observable @MainActor` domain coordinators, orchestrated by `MergeBoardViewModel`.

**Generalized chain model:** every mergeable item is `BoardItem(chainID: String, tier: Int)`. All display data resolves from `ContentRegistry` at runtime. Saves persist only chain ID and tier — never display data — so content can be added without a save migration.

**Key files**

| File | Role |
|---|---|
| `MergeBoardViewModel.swift` (~2,600 lines) | Core gameplay orchestrator. Large; extraction deferred. |
| `ItemChain.swift` | `ChainCategory`, `MergeChain`, `ContentRegistry` |
| `AnimalSpecies.swift` | Families, tiers, board constants, `AdoptionOrder`, IAP enum, tuning constants |
| `GameStore.swift` | `GameState` + save/load/migration chain |
| `KibbleEngine.swift` | Energy state, regen, ad bookkeeping |
| `AdoptionBoard.swift` | Order generation and countdown |
| `PlayerProgression.swift` | Level, XP, unlocks |
| `QuestCoordinator.swift` | Quests, daily challenges, spotlight |
| `SanctuaryMap.swift` | Meta progression — 15 areas × 4 upgrade tiers |
| `SubObjectSystem.swift` | Sub-object drops, pity timers, power-ups |
| `EventSystem.swift` | Live-ops infrastructure — currently one expired event |
| `CardSystem.swift` / `CardTrading.swift` | Albums, packs, Star Shop, CloudKit trading |

**Tuning constants** live at the bottom of `AnimalSpecies.swift` (~line 870+): `kibbleRegenCap`, `kibbleRegenSecs`, `startingKibble`, `maxDailyAdWatches`, `adKibbleReward`, `adoptionOrderDuration`, `DogTagKibbleExchange`.

## Conventions

- Swift 6 concurrency: domain coordinators are `@MainActor`, persistence encoding runs off-main via `Task.detached`
- No force-unwraps in new code
- Persisted enums use `String` raw values
- New tuning numbers go in `AnimalSpecies.swift` with the other constants, not inline at the call site
- Migration helpers follow the existing naming: `migrateVNtoVN+1(_ data: Data) -> GameState?`

## Testing

`PawSanctuaryTests/PersistenceTests.swift` (~1,100 lines) covers save/load/migration. Every schema change needs a case here. Run before every commit that touches `GameState`.

> **History worth knowing (found 26 July 2026):** this suite had **never successfully compiled** before that date. The scheme's `TestAction` had no `<Testables>` entry, so `xcodebuild test` failed outright rather than running; once fixed, the test target's deployment target (17.0 vs the app's 17.6) blocked `@testable import`; once that was fixed, 9 accumulated compile errors surfaced referencing fields deleted long ago (`GameState.supplyCount`, `AdoptionOrder.rewardKibble`, `AreaReward.newSpecies`).
>
> **Implication:** every schema migration from v8 through v24 shipped without test verification. Treat the older migrations as unproven rather than trusted. If a save-corruption bug surfaces, that chain is the first place to look.
>
> **Current state:** 70 passing, 7 pre-existing failures (see `TODO.md`). Do not fold fixes for those into unrelated feature work.
