//
//  BubblePopGateTests.swift
//  PawSanctuaryTests
//
//  D7 (no monetization in session one): the bubble sheet's paid pops, a
//  rewarded ad and a Dog Tag spend, stay unavailable until
//  `isMonetizationUnlocked`, the same rule the spawner-cooldown skip follows.
//  Before then a bubble can still be merged or left to decay into coins.
//

import XCTest
@testable import PawSanctuary

/// Records whether an ad was asked for, and never grants one.
private final class RecordingAdProvider: RewardedAdProvider, @unchecked Sendable {
    private(set) var wasShown = false
    func showRewardedAd(completion: @escaping @Sendable (AdResult) -> Void) {
        wasShown = true
    }
}

@MainActor
final class BubblePopGateTests: XCTestCase {

    private let pos = GridPosition(row: 0, col: 0)

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func makeViewModel(wall: Bool, level: Int) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.boardState.setItem(BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: bubbleMinTier,
                                        bubbledAt: Date().timeIntervalSince1970),
                              at: pos)
        vm.kibbleEngine.dogTags = 500
        vm.commerce.hasReachedFirstWall = wall
        vm.progression.playerLevel = level
        return vm
    }

    private func isBubbled(_ vm: MergeBoardViewModel) -> Bool {
        vm.boardState.item(at: pos)?.bubbledAt != nil
    }

    // MARK: The gate itself

    func testNoPaidPopBeforeTheFirstWall() {
        XCTAssertFalse(makeViewModel(wall: false, level: monetizationUnlockLevel).isBubblePopOfferAvailable)
    }

    func testNoPaidPopBelowTheUnlockLevel() {
        XCTAssertFalse(makeViewModel(wall: true, level: monetizationUnlockLevel - 1).isBubblePopOfferAvailable)
    }

    func testPaidPopOnceMonetizationUnlocks() {
        XCTAssertTrue(makeViewModel(wall: true, level: monetizationUnlockLevel).isBubblePopOfferAvailable)
    }

    // MARK: Dog Tag pop

    func testDogTagPopSpendsNothingInSessionOne() {
        let vm = makeViewModel(wall: false, level: 1)
        let tags = vm.kibbleEngine.dogTags

        vm.popBubbleWithDogTags(at: pos)

        XCTAssertEqual(vm.kibbleEngine.dogTags, tags)
        XCTAssertTrue(isBubbled(vm), "the bubble must stay until it is merged or decays")
    }

    func testControlDogTagPopWorksOnceMonetizationUnlocks() {
        let vm = makeViewModel(wall: true, level: monetizationUnlockLevel)
        let tags = vm.kibbleEngine.dogTags

        vm.popBubbleWithDogTags(at: pos)

        XCTAssertEqual(vm.kibbleEngine.dogTags, tags - bubblePopDogTagCost(tier: bubbleMinTier))
        XCTAssertFalse(isBubbled(vm))
    }

    // MARK: Ad pop

    func testAdPopShowsNoAdInSessionOne() {
        let vm = makeViewModel(wall: false, level: 1)
        let provider = RecordingAdProvider()

        vm.popBubbleWithAd(at: pos, provider: provider)

        XCTAssertFalse(provider.wasShown)
        XCTAssertTrue(isBubbled(vm))
    }

    func testControlAdPopAsksForAnAdOnceMonetizationUnlocks() {
        let vm = makeViewModel(wall: true, level: monetizationUnlockLevel)
        let provider = RecordingAdProvider()

        vm.popBubbleWithAd(at: pos, provider: provider)

        XCTAssertTrue(provider.wasShown)
    }
}
