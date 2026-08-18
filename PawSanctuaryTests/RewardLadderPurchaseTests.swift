//
//  RewardLadderPurchaseTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Reward Ladder (D8) Task 3.1 — applyPurchase(.rewardLadderRung:)
//  and pendingRewardLadderRung's capture/clear/fallback bookkeeping. Mirrors
//  EventPassPurchaseTests' shape for the identical time-of-check/time-of-use
//  reason (see pendingRewardLadderRung's doc comment).
//
//  Unlike eventPass, `rewardLadderTrackID` ("reward_ladder") has no
//  ProgressTrackRegistry content yet — that lands in Task 3.5. So these tests
//  cover only what's observable without it: progress bookkeeping and pending-
//  state hygiene. Which paid/free rewards a given rung actually grants isn't
//  testable until 3.5's registry entry exists. ProgressTrack.claim's
//  below-threshold-returns-nothing guard (the safety net a stale/out-of-range
//  pendingRewardLadderRung would hit) is already covered generically by
//  LiveOpsEngineTests.testClaimBelowThresholdReturnsNothing — not re-tested here.
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

    func testPurchaseWithNoRegistryContentYetGrantsNoRewardsWithoutCrashing() {
        let vm = makeViewModel()
        let kibbleBefore = vm.kibble
        let dogTagsBefore = vm.dogTags

        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)

        XCTAssertEqual(vm.kibble, kibbleBefore,
                       "reward_ladder has no ProgressTrackRegistry entry until Task 3.5 — claim() must return "
                       + "[] safely rather than crash, so no kibble should be granted yet")
        XCTAssertEqual(vm.dogTags, dogTagsBefore)
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
    /// instant `applyPurchase` returns. Real force-quits have the same gap
    /// (shared by every IAP's persist() call, not specific to Reward Ladder;
    /// out of scope for this task to fix), so a genuine relaunch simulation
    /// has to give the detached task a moment to actually finish rather than
    /// racing it.
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

    func testMultipleRungsAllSurviveForceQuitAndRelaunch() {
        let vm = MergeBoardViewModel()
        vm.loadGame()

        // One persist() per purchase, letting each disk write land before the
        // next fires — not three instant taps. Real purchases each round-trip
        // through a StoreKit confirmation sheet, so they're never actually
        // this close together; back-to-back applyPurchase() calls with no gap
        // between them would race persist()'s fire-and-forget Task.detached
        // writes against each other (last-write-wins, out of call order) —
        // a pre-existing characteristic of every IAP's persist() call, not
        // something specific to the Reward Ladder and not this task's to fix.
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        waitForPersistToLandOnDisk()
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        waitForPersistToLandOnDisk()
        vm.applyPurchase(.rewardLadderRung, priceUSD: 2.99)
        waitForPersistToLandOnDisk()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertEqual(relaunched.progressTrack.progress(trackID: rewardLadderTrackID), 3)
    }
}
