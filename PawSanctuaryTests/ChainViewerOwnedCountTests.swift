//
//  ChainViewerOwnedCountTests.swift
//  PawSanctuaryTests
//
//  Task 1 of `specs/Spec_ChainViewerUpgrades_Draft.md` (D13): the chain viewer
//  shows how many of each tier the player holds. `ownedItemCounts` is the
//  fourth "what does the player have" definition in the view model, so these
//  tests pin exactly what it includes and excludes:
//
//    counts   items on unlocked board cells, and items in the animal inventory
//    excludes bubbled items (not yet the player's), other chains, other tiers
//
//  It is deliberately not `boardTaskCensus` (board only); a change that
//  collapses it into that should fail here.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ChainViewerOwnedCountTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }

    /// A fully unlocked, empty board. `loadGame()` is never called, so nothing
    /// touches disk or timers. The board setter does not recompute
    /// BoardStateManager's cached empty cells, hence the explicit `recalc()`.
    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        return vm
    }

    private func key(_ chain: ChainID, _ tier: Int) -> ChainTierKey {
        ChainTierKey(chainID: chain, tier: tier)
    }

    func testAnEmptyBoardAndInventoryOwnsNothing() {
        let vm = makeViewModel()

        XCTAssertTrue(vm.ownedItemCounts.isEmpty)
    }

    func testItemsOnTheBoardAreCountedPerChainAndTier() {
        let vm = makeViewModel()
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 2), at: GridPosition(row: 0, col: 0))
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 2), at: GridPosition(row: 0, col: 1))
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 3), at: GridPosition(row: 0, col: 2))

        let counts = vm.ownedItemCounts

        XCTAssertEqual(counts[key(dog, 2)], 2)
        XCTAssertEqual(counts[key(dog, 3)], 1)
        XCTAssertNil(counts[key(dog, 1)], "a tier the player does not hold has no entry, so no badge")
    }

    func testAnItemInTheInventoryIsCounted() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.inventoryStore.addItem(BoardItem(chainID: dog, tier: 4)),
                      "the item must actually land in inventory, or this test proves nothing")

        XCTAssertEqual(vm.ownedItemCounts[key(dog, 4)], 1)
    }

    func testBoardAndInventoryCountsAddUp() {
        let vm = makeViewModel()
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 1), at: GridPosition(row: 0, col: 0))
        XCTAssertTrue(vm.inventoryStore.addItem(BoardItem(chainID: dog, tier: 1)))

        XCTAssertEqual(vm.ownedItemCounts[key(dog, 1)], 2)
    }

    func testABubbledItemIsNotCounted() {
        let vm = makeViewModel()
        var encased = BoardItem(chainID: dog, tier: 2)
        encased.bubbledAt = Date().timeIntervalSince1970
        vm.boardState.setItem(encased, at: GridPosition(row: 0, col: 0))
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 2), at: GridPosition(row: 0, col: 1))

        XCTAssertEqual(vm.ownedItemCounts[key(dog, 2)], 1,
                       "a creature still in a bubble is not yet the player's to count")
    }

    func testOtherChainsAreKeptApart() {
        let vm = makeViewModel()
        vm.boardState.setItem(BoardItem(chainID: cat, tier: 2), at: GridPosition(row: 0, col: 0))

        let counts = vm.ownedItemCounts

        XCTAssertEqual(counts[key(cat, 2)], 1)
        XCTAssertNil(counts[key(dog, 2)], "the same tier of a different chain must not share a count")
    }
}
