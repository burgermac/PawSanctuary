//
//  AlbumCollectionBannerTests.swift
//  PawSanctuaryTests
//
//  Album grand prize, task 3 (specs/Spec_AlbumGrandPrize.md §11): the
//  collection banner's inputs are right in each state. The banner itself is
//  checked on the Simulator.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class AlbumCollectionBannerTests: XCTestCase {

    private var allSetIDs: [String] { CardRegistry.albums.map(\.id) }

    private func makeViewModel(completed: [String], claimed: Bool = false) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.completedAlbumIDs = completed
        vm.claimedCollectionPrizeIDs = claimed ? [CardRegistry.collectionPrizeID] : []
        return vm
    }

    func testANewSaveShowsNoSetsDone() {
        let vm = makeViewModel(completed: [])
        XCTAssertEqual(vm.collectionBannerState, .collecting(done: 0, total: allSetIDs.count))
    }

    func testPartWayShowsTheCount() {
        let vm = makeViewModel(completed: Array(allSetIDs.prefix(3)))
        XCTAssertEqual(vm.collectionBannerState, .collecting(done: 3, total: allSetIDs.count))
    }

    func testEverySetCompleteShowsClaim() {
        let vm = makeViewModel(completed: allSetIDs)
        XCTAssertEqual(vm.collectionBannerState, .claimable)
    }

    func testClaimingTurnsTheBannerToClaimed() {
        let vm = makeViewModel(completed: allSetIDs)
        XCTAssertTrue(vm.claimCollectionPrize())
        XCTAssertEqual(vm.collectionBannerState, .claimed)
    }

    func testASaveThatFinishedEverySetBeforeTheUpdateCanStillClaim() {
        // Owner Q4 a: the v46 migration leaves the prize unclaimed, so a save
        // that was already complete shows Claim, not Claimed.
        let vm = makeViewModel(completed: allSetIDs, claimed: false)
        XCTAssertEqual(vm.collectionBannerState, .claimable)
    }

    func testAClaimedSaveStaysClaimed() {
        let vm = makeViewModel(completed: allSetIDs, claimed: true)
        XCTAssertEqual(vm.collectionBannerState, .claimed)
    }
}
