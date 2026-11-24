//
//  PowerUpSinkTests.swift
//  PawSanctuaryTests
//
//  Completed sub-objects (e.g. a Canines chain's "Golden Ball") used to have
//  no sink at all: no sell, no discard, no quest/shop/exchange demand. Once
//  the 6-slot Supplies inventory and the animal inventory fallback were both
//  full, `MergeBoardViewModel.applyMergeOutcome` banked the completed item
//  with `inventoryStore.addItem(_:)` and never checked the return value, so
//  the item was silently destroyed while the game still reported success.
//  Covers the "convert to coins" sink added to close that dead end, and the
//  fallback that now fires in place of the silent-destroy bug.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class PowerUpSinkTests: XCTestCase {

    private let dogSubObjectChain = "subobject.dog"   // Canines: passive superpower,
    // so maybeGrantSuperpowerPiece never intercepts its completion — keeps
    // this deterministic instead of depending on the 15% piece-grant roll.

    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)

    private func makeBoard() -> [[BoardCell]] {
        (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
    }

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = makeBoard()
        return vm
    }

    private func place(_ vm: MergeBoardViewModel, chainID: ChainID, tier: Int, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: chainID, tier: tier)
        vm.board = board
    }

    // MARK: coinValue ordering

    func testCoinValueIncreasesWithRarity() {
        XCTAssertLessThan(SubObjectRarity.speed.coinValue, SubObjectRarity.mapSupplies.coinValue)
        XCTAssertLessThan(SubObjectRarity.mapSupplies.coinValue, SubObjectRarity.boardItemGrant.coinValue)
        XCTAssertLessThan(SubObjectRarity.boardItemGrant.coinValue, SubObjectRarity.highTierDrop.coinValue)
    }

    // MARK: convertSelectedPowerUpToCoins — the player-initiated sink

    func testConvertSelectedPowerUpToCoinsAwardsCoinsAndClearsSlot() {
        let vm = makeViewModel()
        vm.inventoryStore.powerUpInventory[2] =
            BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .highTierDrop)
        vm.selectedPowerUpSlot = 2
        let coinsBefore = vm.coins

        vm.convertSelectedPowerUpToCoins()

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.highTierDrop.coinValue)
        XCTAssertNil(vm.inventoryStore.powerUpInventory[2])
        XCTAssertNil(vm.selectedPowerUpSlot)
    }

    func testConvertWithNoSelectionIsANoOp() {
        let vm = makeViewModel()
        let coinsBefore = vm.coins
        vm.convertSelectedPowerUpToCoins()
        XCTAssertEqual(vm.coins, coinsBefore)
    }

    func testSelectedPowerUpCoinValueReflectsTheSelectedSlot() {
        let vm = makeViewModel()
        XCTAssertNil(vm.selectedPowerUpCoinValue, "nothing selected yet")

        vm.inventoryStore.powerUpInventory[0] =
            BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .mapSupplies)
        vm.selectedPowerUpSlot = 0
        XCTAssertEqual(vm.selectedPowerUpCoinValue, SubObjectRarity.mapSupplies.coinValue)
    }

    // MARK: The bug found in review — full storage must never destroy the item

    func testCompletingASubObjectWithFullStorageConvertsToCoinsInsteadOfDestroyingIt() {
        let vm = makeViewModel()
        // Fill every Supplies slot and every base animal-inventory slot so
        // InventoryStore.addItem(_:) has nowhere left to bank a new item —
        // exactly the state that used to silently destroy a completed
        // sub-object while the game still reported success.
        for i in 0..<vm.inventoryStore.powerUpInventory.count {
            vm.inventoryStore.powerUpInventory[i] =
                BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .speed)
        }
        for i in 0..<freeInventorySlots {
            vm.inventoryStore.inventory[i] = BoardItem(chainID: ContentRegistry.animalChainID(.cat), tier: 0)
        }
        vm.inventoryStore.recalcInventoryOccupied()

        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        place(vm, chainID: dogSubObjectChain, tier: 2, at: b)
        let coinsBefore = vm.coins

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertNil(vm.board[b.row][b.col].item, "the board cell is cleared either way")
        XCTAssertGreaterThan(vm.coins, coinsBefore,
                             "with nowhere to store it, the completed item's value must be banked as coins, not lost")
    }

    func testCompletingASubObjectWithRoomBanksItNormallyAndAwardsNoCoins() {
        let vm = makeViewModel()
        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        place(vm, chainID: dogSubObjectChain, tier: 2, at: b)
        let coinsBefore = vm.coins

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertNil(vm.board[b.row][b.col].item)
        XCTAssertEqual(vm.coins, coinsBefore, "storage had room, so the normal bank path pays no coins")
        XCTAssertTrue(vm.inventoryStore.powerUpInventory.contains { $0?.chainID == self.dogSubObjectChain })
    }

    // MARK: collectCompletedSubObject — tapping a finished tile on the board

    private func placeCompleted(_ vm: MergeBoardViewModel, rarity: SubObjectRarity?, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: rarity)
        vm.board = board
    }

    func testTappingCompletedSubObjectPaysItsRarityValueAndClearsCell() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .highTierDrop, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.highTierDrop.coinValue)
        XCTAssertNil(vm.board[a.row][a.col].item)
    }

    func testTappingCompletedSubObjectWithoutRarityPaysSpeedValue() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: nil, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.speed.coinValue)
        XCTAssertNil(vm.board[a.row][a.col].item)
    }

    func testTappingLowerTierSubObjectDoesNotCollect() {
        let vm = makeViewModel()
        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertNotNil(vm.board[a.row][a.col].item)
        XCTAssertEqual(vm.selectedCell, a)
    }

    func testTappingTopTierAnimalDoesNotCollect() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.animalChainID(.dog), tier: animalChainTopTier, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertNotNil(vm.board[a.row][a.col].item)
    }

    func testTappingCompletedSubObjectInLockedCellDoesNothing() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .highTierDrop, at: a)
        vm.board[0][0].isUnlocked = false
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertNotNil(vm.board[a.row][a.col].item)
    }

    func testSecondTapOnCollectedCellPaysNothing() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .mapSupplies, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)
        let coinsAfterFirst = vm.coins
        vm.boardCellTapped(at: a)

        XCTAssertEqual(coinsAfterFirst, coinsBefore + SubObjectRarity.mapSupplies.coinValue)
        XCTAssertEqual(vm.coins, coinsAfterFirst, "the cell is empty now, so a second tap pays nothing")
    }

    func testCollectingClearsSelectionOnThatCell() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .speed, at: a)
        vm.selectedCell = a

        vm.boardCellTapped(at: a)

        XCTAssertNil(vm.selectedCell)
    }
}
