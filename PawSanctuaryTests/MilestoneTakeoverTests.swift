//
//  MilestoneTakeoverTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_MilestoneTakeover.md: crossing an unclaimed Care Points tier raises
//  one takeover (the highest crossed); Claim pays through the normal claim path;
//  Later leaves the tiers claimable.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class MilestoneTakeoverTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    func testStayingUnderTheFirstThresholdRaisesNothing() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsBronze - 1)
        XCTAssertNil(vm.pendingMilestone)
    }

    func testCrossingBronzeRaisesBronze() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsBronze - 1)
        vm.awardCarePoints(1)
        XCTAssertEqual(vm.pendingMilestone, .bronze)
    }

    func testOneBigAwardAcrossTwoTiersShowsTheHighest() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsSilver)
        XCTAssertEqual(vm.pendingMilestone, .silver)
    }

    func testAnAlreadyClaimedTierDoesNotRaiseAgain() {
        let vm = MergeBoardViewModel()
        vm.claimedCarePointTiers = [CarePointTier.bronze.rawValue]
        vm.awardCarePoints(carePointsBronze)
        XCTAssertNil(vm.pendingMilestone)
    }

    func testALaterCrossingRaisesTheTakeoverRatherThanStackingOrLowering() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsBronze)
        XCTAssertEqual(vm.pendingMilestone, .bronze)
        vm.awardCarePoints(carePointsSilver - carePointsBronze)
        XCTAssertEqual(vm.pendingMilestone, .silver, "raised to the higher tier")
        vm.awardCarePoints(1)
        XCTAssertEqual(vm.pendingMilestone, .silver, "no new crossing, unchanged")
    }

    func testLaterClosesItAndLeavesTheTiersClaimable() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsBronze)
        vm.dismissMilestone()
        XCTAssertNil(vm.pendingMilestone)
        XCTAssertEqual(vm.claimableCarePointTiers, [.bronze])
    }

    func testClaimPaysEveryClaimableTierUpToTheOneShownThroughTheNormalPath() {
        let vm = MergeBoardViewModel()
        let tagsBefore = vm.kibbleEngine.dogTags
        vm.awardCarePoints(carePointsSilver)     // Bronze and Silver both crossed
        vm.claimMilestone()

        XCTAssertNil(vm.pendingMilestone)
        XCTAssertTrue(vm.isCarePointTierClaimed(.bronze))
        XCTAssertTrue(vm.isCarePointTierClaimed(.silver))
        XCTAssertFalse(vm.isCarePointTierClaimed(.gold))
        XCTAssertEqual(vm.kibbleEngine.dogTags,
                       tagsBefore + CarePointTier.bronze.dogTagReward + CarePointTier.silver.dogTagReward)
    }

    func testClaimDoesNotTouchATierAboveTheOneShown() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsGold)        // everything crossed
        vm.pendingMilestone = .bronze             // but only Bronze is on screen
        vm.claimMilestone()
        XCTAssertTrue(vm.isCarePointTierClaimed(.bronze))
        XCTAssertFalse(vm.isCarePointTierClaimed(.silver))
        XCTAssertFalse(vm.isCarePointTierClaimed(.gold))
    }

    func testAFreshGameClearsIt() {
        let vm = MergeBoardViewModel()
        vm.awardCarePoints(carePointsBronze)
        vm.resetToFreshGame()
        XCTAssertNil(vm.pendingMilestone)
    }
}
