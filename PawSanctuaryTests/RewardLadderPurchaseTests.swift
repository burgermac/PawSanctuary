//
//  RewardLadderPurchaseTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Reward Ladder (D8) Task 3.1 — applyPurchase(.rewardLadderRung:)
//  and pendingRewardLadderRung's capture/clear/fallback bookkeeping. Mirrors
//  EventPassPurchaseTests' shape for the identical time-of-check/time-of-use
//  reason (see pendingRewardLadderRung's doc comment).
//
//  RewardLadderPurchaseTests covered only progress bookkeeping and
//  pending-state hygiene until Task 3.5 added rewardLadderTrackID's real
//  ProgressTrackRegistry content (LiveOpsEngine.swift) — which paid/free
//  rewards a given rung actually grants is now covered too. ProgressTrack.
//  claim's below-threshold-returns-nothing guard (the safety net a stale/
//  out-of-range pendingRewardLadderRung would hit) is already covered
//  generically by LiveOpsEngineTests.testClaimBelowThresholdReturnsNothing —
//  not re-tested here. RewardLadderContentTests below covers the registry
//  entry's own shape (Task 3.5).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class RewardLadderPurchaseTests: XCTestCase {

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    func testPurchaseAdvancesLadderProgressByExactlyOne() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.progressTrack.progress(trackID: rewardLadderTrackID), 0)

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)

        XCTAssertEqual(vm.progressTrack.progress(trackID: rewardLadderTrackID), 1)
    }

    func testSuccessivePurchasesEachAdvanceProgressByOne() {
        let vm = makeViewModel()

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)

        XCTAssertEqual(vm.progressTrack.progress(trackID: rewardLadderTrackID), 3,
                       "three separate purchases must land three separate rungs, not double- or under-advance")
    }

    func testPendingRungIsClearedAfterBeingConsumed() {
        let vm = makeViewModel()
        vm.pendingRewardLadderRung = 1

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)

        XCTAssertNil(vm.pendingRewardLadderRung,
                     "must not leak into a later, unrelated purchase")
    }

    func testNonRewardLadderPurchaseDoesNotTouchThePendingRung() {
        let vm = makeViewModel()
        vm.pendingRewardLadderRung = 2

        vm.applyPurchase(.kibbleSmall, priceUSD: 0.99)

        XCTAssertEqual(vm.pendingRewardLadderRung, 2,
                       "an unrelated purchase completing mid-flight must not clear or consume it")
    }

    func testPurchaseWithNoPendingRungStillAdvancesUsingTheLiveFallback() {
        let vm = makeViewModel()
        XCTAssertNil(vm.pendingRewardLadderRung)

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)

        XCTAssertEqual(vm.progressTrack.progress(trackID: rewardLadderTrackID), 1,
                       "a grant with no matching button tap this session (e.g. a StoreKit-redelivered "
                       + "transaction after relaunch) must still advance via progress(trackID:) + 1, not no-op")
    }

    /// Task 3.5 gave `rewardLadderTrackID` real registry content — this closes
    /// the exact gap this file's header comment flagged as untestable before
    /// that landed: rung 1's paid dog tags (36) plus both free rewards (35
    /// kibble, 4 dog tags) must land together in one purchase, per §4's table.
    func testFirstPurchaseGrantsExactlyRungOnesPaidAndFreeRewards() {
        let vm = makeViewModel()
        let kibbleBefore = vm.kibble
        let dogTagsBefore = vm.dogTags

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)

        XCTAssertEqual(vm.kibble, kibbleBefore + 35, "rung 1's free-lane kibble must be granted")
        XCTAssertEqual(vm.dogTags, dogTagsBefore + 36 + 4,
                       "rung 1's paid (36) and free (4) dog tags must both land in one purchase")
    }

    func testSecondPurchaseGrantsRungTwosOwnRewardsNotRungOnesAgain() {
        let vm = makeViewModel()
        // Past every VIP tier's spend threshold (AnimalSpecies.swift's
        // vipTiers tops out at $2,000) so neither purchase below newly
        // crosses one and adds its own kibble/dog-tag bonus on top of the
        // ladder's — this test is isolated to the ladder's own reward
        // granting, not VIP interaction (a real, separate mechanic).
        vm.commerce.totalSpendMicros = 3_000_000_000
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)   // rung 1
        let kibbleAfterRungOne = vm.kibble
        let dogTagsAfterRungOne = vm.dogTags

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)   // rung 2

        XCTAssertEqual(vm.kibble, kibbleAfterRungOne + 35, "rung 2's free-lane kibble")
        XCTAssertEqual(vm.dogTags, dogTagsAfterRungOne + 40 + 4, "rung 2's paid (40) and free (4) dog tags")
    }
}

/// Task 3.5 — the real ProgressTrackRegistry[rewardLadderTrackID] entry
/// (specs/Spec_Phase6b_RewardLadder.md §4/§5). Guards the one invariant the
/// implementation's own comment (LiveOpsEngine.swift) flags as silently
/// dangerous if wrong: threshold must equal index + 1 exactly, or
/// applyPurchase's `claim(milestone: nextRung - 1, ...)` call stops matching
/// a purchased rung to its reward.
final class RewardLadderContentTests: XCTestCase {

    private var milestones: [TrackMilestone] {
        ProgressTrackRegistry.tracks[rewardLadderTrackID] ?? []
    }

    func testHasExactlySixRungsPerSpecSection4() {
        XCTAssertEqual(milestones.count, 6)
    }

    func testEveryThresholdEqualsItsIndexPlusOne() {
        for milestone in milestones {
            XCTAssertEqual(milestone.threshold, milestone.index + 1,
                           "rung \(milestone.index) has threshold \(milestone.threshold) — applyPurchase's "
                           + "claim(milestone: nextRung - 1) silently stops matching if this ever drifts")
        }
    }

    func testPaidLaneIsDogTagsOnlyAndStrictlyIncreasing() {
        var previousAmount = 0
        for milestone in milestones {
            XCTAssertEqual(milestone.paidRewards.count, 1)
            let reward = milestone.paidRewards[0]
            XCTAssertEqual(reward.kind, .dogTags, "paid lane must be dog tags only per §4 — no cardPack hero reward")
            XCTAssertGreaterThan(reward.amount, previousAmount, "paid-lane amount must strictly increase rung to rung")
            previousAmount = reward.amount
        }
    }

    func testPaidLaneNeverReachesDogTagsMediumsShelfRate() {
        // dogTagsMedium: 60 dog tags for $2.99 — the real "shelf" comparison
        // §4's recalibration is anchored against. The paid lane alone must
        // always read as a worse deal than just buying dog tags directly.
        for milestone in milestones {
            let paidAmount = milestone.paidRewards.first?.amount ?? 0
            XCTAssertLessThan(paidAmount, 60, "rung \(milestone.index)'s paid-alone dog tags must stay below shelf")
        }
    }

    func testCombinedValueAlwaysExceedsShelf() {
        // 1 kibble ≈ 0.6 dog-tag-equivalent at DogTagKibbleExchange's flat
        // rate (§4's own conversion) — combined (paid + free, kibble
        // converted) must always beat the 60-dog-tag shelf comparison.
        for milestone in milestones {
            let paidTags = milestone.paidRewards.first { $0.kind == .dogTags }?.amount ?? 0
            let freeTags = milestone.freeRewards.first { $0.kind == .dogTags }?.amount ?? 0
            let freeKibble = milestone.freeRewards.first { $0.kind == .kibble }?.amount ?? 0
            let combinedTagEquivalent = Double(paidTags + freeTags) + Double(freeKibble) * 0.6
            XCTAssertGreaterThan(combinedTagEquivalent, 60,
                                 "rung \(milestone.index)'s combined value must exceed dogTagsMedium's shelf rate")
        }
    }

    func testExactTableMatchesSpecSection4() {
        let expected: [(index: Int, paidTags: Int, freeKibble: Int, freeTags: Int)] = [
            (0, 36, 35, 4),
            (1, 40, 35, 4),
            (2, 43, 40, 5),
            (3, 47, 40, 6),
            (4, 50, 45, 7),
            (5, 54, 50, 8),
        ]
        XCTAssertEqual(milestones.count, expected.count)
        for row in expected {
            guard let milestone = milestones.first(where: { $0.index == row.index }) else {
                XCTFail("missing rung \(row.index)")
                continue
            }
            XCTAssertEqual(milestone.paidRewards, [OrderReward(kind: .dogTags, amount: row.paidTags)])
            XCTAssertEqual(milestone.freeRewards, [OrderReward(kind: .kibble, amount: row.freeKibble),
                                                    OrderReward(kind: .dogTags, amount: row.freeTags)])
        }
    }
}

/// Task 3.3 — isRewardLadderAvailable is a thin wrapper reusing D7's
/// isMonetizationUnlocked gate exactly (spec §0/§3.3), not a new condition.
/// These tests exercise both halves of that gate directly rather than
/// asserting equality with isMonetizationUnlocked itself, so a future
/// divergence between the two properties would actually be caught here.
@MainActor
final class RewardLadderAvailabilityTests: XCTestCase {

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    func testUnavailableBeforeEitherHalfOfTheGateIsMet() {
        let vm = makeViewModel()
        vm.commerce.hasReachedFirstWall = false
        vm.progression.playerLevel = 1

        XCTAssertFalse(vm.isRewardLadderAvailable)
    }

    func testUnavailableWhenOnlyTheLevelHalfIsMet() {
        let vm = makeViewModel()
        vm.commerce.hasReachedFirstWall = false
        vm.progression.playerLevel = monetizationUnlockLevel

        XCTAssertFalse(vm.isRewardLadderAvailable)
    }

    func testUnavailableWhenOnlyTheWallHalfIsMet() {
        let vm = makeViewModel()
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel - 1

        XCTAssertFalse(vm.isRewardLadderAvailable)
    }

    func testAvailableOnceBothHalvesOfTheGateAreMet() {
        let vm = makeViewModel()
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel

        XCTAssertTrue(vm.isRewardLadderAvailable)
    }

    func testTracksIsMonetizationUnlockedExactly() {
        let vm = makeViewModel()
        for wall in [false, true] {
            for level in [1, monetizationUnlockLevel - 1, monetizationUnlockLevel, monetizationUnlockLevel + 1] {
                vm.commerce.hasReachedFirstWall = wall
                vm.progression.playerLevel = level
                XCTAssertEqual(vm.isRewardLadderAvailable, vm.isMonetizationUnlocked,
                               "must never diverge from the gate it wraps (wall=\(wall), level=\(level))")
            }
        }
    }
}

/// Debug-only helper added to unblock Reward Ladder on-screen verification
/// (spec §5 found resetToFreshGame() resets *away* from isMonetizationUnlocked,
/// not toward it). #if DEBUG only — these tests run in the Debug test
/// configuration, same as the rest of this target.
@MainActor
final class UnlockMonetizationForTestingTests: XCTestCase {

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    func testFlipsIsRewardLadderAvailableTrueFromFreshState() {
        let vm = makeViewModel()
        XCTAssertFalse(vm.isRewardLadderAvailable)

        vm.unlockMonetizationForTesting()

        XCTAssertTrue(vm.isRewardLadderAvailable)
    }

    func testBumpsLevelToTheUnlockThresholdWhenBelowIt() {
        let vm = makeViewModel()
        vm.progression.playerLevel = 1

        vm.unlockMonetizationForTesting()

        XCTAssertEqual(vm.progression.playerLevel, monetizationUnlockLevel)
    }

    func testNeverLowersAnAlreadyHigherLevel() {
        let vm = makeViewModel()
        vm.progression.playerLevel = monetizationUnlockLevel + 10

        vm.unlockMonetizationForTesting()

        XCTAssertEqual(vm.progression.playerLevel, monetizationUnlockLevel + 10,
                       "must bump toward the threshold, never lower real progress")
    }
}

/// Task 3.2 — confirms, rather than assumes, that the Reward Ladder needs no
/// new GameState field: its entire state is progressTrack's existing
/// states[trackID] entry, already persisted via ProgressTrack.capture(into:)/
/// restore(from:) (GameState.progressTracks, v29). Unlike
/// EventTokenWalletsAndProgressTracksRoundTripOnAFreshSave (PersistenceTests.swift),
/// which round-trips a GameState value directly through Codable, this drives
/// the real public API two separate MergeBoardViewModel instances would use
/// across an actual app relaunch — applyPurchase (which calls persist()
/// internally) on one, loadGame() on a fresh other — through the real
/// disk-backed GameStore, not an in-memory encode/decode.
@MainActor
final class RewardLadderPersistenceTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()   // isolate from any prior save state
    }

    override func tearDown() {
        GameStore.clear()   // never leave test data behind in the shared store
        super.tearDown()
    }

    /// `persist()` writes via `GameStore.saveAndSync`, which is fire-and-forget
    /// (`Task.detached`) — the write hasn't necessarily landed on disk the
    /// instant `applyPurchase` returns. Real force-quits have the same gap,
    /// so a genuine relaunch simulation has to give the detached task a
    /// moment to actually finish before reading it back.
    private func waitForPersistToLandOnDisk() {
        let exp = expectation(description: "async save completes")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { exp.fulfill() }
        wait(for: [exp], timeout: 2.0)
    }

    func testRewardLadderProgressSurvivesForceQuitAndRelaunchWithNoSchemaChange() {
        let vm = MergeBoardViewModel()
        vm.loadGame()

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        XCTAssertEqual(vm.progressTrack.progress(trackID: rewardLadderTrackID), 1)
        waitForPersistToLandOnDisk()

        // A fresh instance standing in for the process relaunch — nothing
        // carries over except what loadGame() reads back off disk.
        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertEqual(relaunched.progressTrack.progress(trackID: rewardLadderTrackID), 1,
                       "a purchased rung must survive force-quit/relaunch with zero additional "
                       + "persistence code — the ladder's state is just another progressTracks entry")
    }

    /// Three instant taps, no gap at all — this used to require artificial
    /// spacing between purchases to pass (see git history), because
    /// persist()'s fire-and-forget writes could land out of order and lose
    /// progress. Fixed at the root in GameStore (TODO.md, "Back-to-back
    /// persist() calls can race each other's disk write" — every write is
    /// now timestamped at capture and a stale one can never clobber a
    /// fresher one, regardless of which detached task finishes first), so
    /// this is now a real regression test for that fix, not a workaround.
    func testMultipleRungsAllSurviveForceQuitAndRelaunchEvenFiredBackToBack() {
        let vm = MergeBoardViewModel()
        vm.loadGame()

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        waitForPersistToLandOnDisk()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertEqual(relaunched.progressTrack.progress(trackID: rewardLadderTrackID), 3,
                       "all three purchases must survive even fired back-to-back with no gap — "
                       + "see GameStore's write-ordering guarantee")
    }
}
