//
//  AlbumGrandPrizeTests.swift
//  PawSanctuaryTests
//
//  Album grand prize, task 2 (specs/Spec_AlbumGrandPrize.md §4.1, §9, §11):
//  the collection is complete when every registered set is complete; the prize
//  is then claimable once, pays exactly 800 kibble (Pass bonus applies), 100 Dog
//  Tags and 5,000 coins, and can never pay twice. Persistence of the claimed ID
//  itself is covered by the v46 cases in PersistenceTests.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class AlbumGrandPrizeTests: XCTestCase {

    private var allSetIDs: [String] { CardRegistry.albums.map(\.id) }

    private func makeViewModel(completed: [String]) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.completedAlbumIDs = completed
        vm.claimedCollectionPrizeIDs = []
        vm.isPassActive = false
        return vm
    }

    func testTheCollectionHasSixSets() {
        // The banner copy ("N of 6 sets") and the spec assume six; fail loudly if
        // content changes so both are revisited.
        XCTAssertEqual(CardRegistry.albums.count, 6)
    }

    func testNotClaimableWithOneSetMissing() {
        let vm = makeViewModel(completed: Array(allSetIDs.dropLast()))
        XCTAssertEqual(vm.completedSetCount, allSetIDs.count - 1)
        XCTAssertFalse(vm.isCollectionComplete)
        XCTAssertFalse(vm.isCollectionPrizeClaimable)

        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags, coins = vm.coins
        XCTAssertFalse(vm.claimCollectionPrize())
        XCTAssertEqual(vm.kibbleEngine.kibble, kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, tags)
        XCTAssertEqual(vm.coins, coins)
        XCTAssertTrue(vm.claimedCollectionPrizeIDs.isEmpty)
    }

    func testClaimableWhenEverySetIsComplete() {
        let vm = makeViewModel(completed: allSetIDs)
        XCTAssertTrue(vm.isCollectionComplete)
        XCTAssertTrue(vm.isCollectionPrizeClaimable)
        XCTAssertFalse(vm.isCollectionPrizeClaimed)
    }

    func testClaimPaysTheExactPrizeAndRecordsTheID() {
        let vm = makeViewModel(completed: allSetIDs)
        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags, coins = vm.coins

        XCTAssertTrue(vm.claimCollectionPrize())

        XCTAssertEqual(vm.kibbleEngine.kibble, kibble + albumCollectionPrizeKibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, tags + albumCollectionPrizeDogTags)
        XCTAssertEqual(vm.coins, coins + albumCollectionPrizeCoins)
        XCTAssertEqual(vm.claimedCollectionPrizeIDs, [CardRegistry.collectionPrizeID])
        XCTAssertTrue(vm.isCollectionPrizeClaimed)
        XCTAssertFalse(vm.isCollectionPrizeClaimable)
    }

    func testThePrizeAmountsAreTheOwnersChoice() {
        // Owner Q19 / Spec Q2 a.
        XCTAssertEqual(albumCollectionPrizeKibble, 800)
        XCTAssertEqual(albumCollectionPrizeDogTags, 100)
        XCTAssertEqual(albumCollectionPrizeCoins, 5_000)
        XCTAssertEqual(CardRegistry.collectionPrizeID, "collection.1")
    }

    func testThePassBonusAppliesToThePrizeKibbleOnly() {
        let vm = makeViewModel(completed: allSetIDs)
        vm.isPassActive = true
        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags, coins = vm.coins

        XCTAssertTrue(vm.claimCollectionPrize())

        XCTAssertEqual(vm.kibbleEngine.kibble, kibble + vm.withPassBonus(albumCollectionPrizeKibble))
        XCTAssertGreaterThan(vm.withPassBonus(albumCollectionPrizeKibble), albumCollectionPrizeKibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, tags + albumCollectionPrizeDogTags)
        XCTAssertEqual(vm.coins, coins + albumCollectionPrizeCoins)
    }

    func testASecondClaimPaysNothing() {
        let vm = makeViewModel(completed: allSetIDs)
        XCTAssertTrue(vm.claimCollectionPrize())
        let kibble = vm.kibbleEngine.kibble, tags = vm.kibbleEngine.dogTags, coins = vm.coins

        XCTAssertFalse(vm.claimCollectionPrize())

        XCTAssertEqual(vm.kibbleEngine.kibble, kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, tags)
        XCTAssertEqual(vm.coins, coins)
        XCTAssertEqual(vm.claimedCollectionPrizeIDs, [CardRegistry.collectionPrizeID])
    }

    func testAnAlreadyClaimedSaveCannotClaimAgain() {
        // A save loaded with the ID already recorded (the field's round-trip is
        // pinned in PersistenceTests) is complete but not claimable.
        let vm = makeViewModel(completed: allSetIDs)
        vm.claimedCollectionPrizeIDs = [CardRegistry.collectionPrizeID]
        XCTAssertTrue(vm.isCollectionComplete)
        XCTAssertFalse(vm.isCollectionPrizeClaimable)
        XCTAssertFalse(vm.claimCollectionPrize())
    }

    func testAnUnknownSetIDNeitherCountsNorBlocks() {
        let stale = "album.removed-in-a-later-version"
        let short = makeViewModel(completed: Array(allSetIDs.dropLast()) + [stale])
        XCTAssertEqual(short.completedSetCount, allSetIDs.count - 1, "a stale ID must not count")
        XCTAssertFalse(short.isCollectionComplete)

        let full = makeViewModel(completed: allSetIDs + [stale])
        XCTAssertEqual(full.completedSetCount, allSetIDs.count)
        XCTAssertTrue(full.isCollectionComplete, "a stale ID must not block")
    }

    func testDuplicateSetIDsCountOnce() {
        let vm = makeViewModel(completed: [allSetIDs[0], allSetIDs[0]])
        XCTAssertEqual(vm.completedSetCount, 1)
    }

    func testCompletingASetDoesNotPayThePrizeByItself() {
        // The prize is claimed, not paid on completion (owner Q3 a): finishing the
        // last set leaves it claimable and unpaid.
        let vm = makeViewModel(completed: Array(allSetIDs.dropLast()))
        guard let last = CardRegistry.albums.last else { return XCTFail("no albums") }
        guard let missing = last.cardIDs.first else { return XCTFail("empty set") }
        for id in last.cardIDs where id != missing { vm.cardInventory[id] = 1 }
        vm.cardInventory[missing] = 0
        vm.jokerCards = 1
        vm.rareJokerCards = 1
        vm.useJoker(for: missing)   // fills the last card and runs checkAlbumCompletions

        XCTAssertTrue(vm.completedAlbumIDs.contains(last.id), "control: the last set completed")
        XCTAssertTrue(vm.isCollectionPrizeClaimable)
        XCTAssertTrue(vm.claimedCollectionPrizeIDs.isEmpty)
    }

    #if DEBUG
    func testTheDebugResetKeepsTheAlbumAndTheClaim() {
        let vm = makeViewModel(completed: allSetIDs)
        XCTAssertTrue(vm.claimCollectionPrize())

        vm.resetToFreshGame()

        XCTAssertEqual(vm.completedSetCount, allSetIDs.count)
        XCTAssertEqual(vm.claimedCollectionPrizeIDs, [CardRegistry.collectionPrizeID])
        XCTAssertFalse(vm.claimCollectionPrize(), "a debug reset must not let the prize pay twice")
    }
    #endif
}
