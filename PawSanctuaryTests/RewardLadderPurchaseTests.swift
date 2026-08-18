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
