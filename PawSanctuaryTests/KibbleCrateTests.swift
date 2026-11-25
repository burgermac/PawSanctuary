//
//  KibbleCrateTests.swift
//  PawSanctuaryTests
//
//  Cards and chests stage 3 (specs/Spec_CardsAndChests.md §4.2, §8): the Kibble
//  Crate, a producer that puts kibble pieces on the board and vanishes when its
//  eight charges are spent. Nothing sells it yet; only the debug grant places one.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleCrateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Helpers

    /// A game with a fully unlocked empty board (built as `ChainViewerStoreTests` does) and one crate at (0, 0).
    private func makeViewModel(charges: Int? = nil) -> (MergeBoardViewModel, GridPosition) {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        let crateAt = GridPosition(row: 0, col: 0)
        vm.boardState.setProducer(ProducerTile(level: .kibbleCrate, chargesRemaining: charges), at: crateAt)
        vm.boardState.recalc()
        return (vm, crateAt)
    }

    private func allCells(_ vm: MergeBoardViewModel) -> [BoardCell] {
        var cells: [BoardCell] = []
        for row in vm.board { for cell in row { cells.append(cell) } }
        return cells
    }

    private func kibblePieces(_ vm: MergeBoardViewModel) -> [BoardItem] {
        var found: [BoardItem] = []
        for cell in allCells(vm) {
            if let item = cell.item, item.chainID == ContentRegistry.kibbleCurrencyChainID {
                found.append(item)
            }
        }
        return found
    }

    // MARK: What a crate is

    func testACrateHoldsEightChargesOfTierThreeKibble() {
        XCTAssertEqual(ProducerLevel.kibbleCrate.rawValue, 30)
        XCTAssertEqual(ProducerLevel.kibbleCrate.maxCharges, 8)
        XCTAssertEqual(ProducerLevel.kibbleCrate.startTier, 3)
        XCTAssertEqual(ProducerLevel.kibbleCrate.targetChainID, ContentRegistry.kibbleCurrencyChainID)
        XCTAssertEqual(ProducerLevel.kibbleCrate.displayName, "Kibble Crate")
        XCTAssertEqual(ProducerLevel.kibbleCrate.cooldown, 0)
        XCTAssertNil(ProducerLevel.kibbleCrate.next, "crates do not merge with each other")
        XCTAssertEqual(ProducerLevel.kibbleCrate.storageUnlockLevel, 1)
        XCTAssertFalse(ProducerLevel.kibbleCrate.isShopProducer, "nothing sells it in stage 3")
    }

    func testAFullCrateIsWorthItsRawValueInKibble() {
        let perPiece = kibbleCurrencyValue(tier: ProducerLevel.kibbleCrate.startTier)
        XCTAssertEqual(perPiece, 15)
        XCTAssertEqual(perPiece * ProducerLevel.kibbleCrate.maxCharges, 120)
    }

    func testANewCrateStartsFullAndReady() {
        let tile = ProducerTile(level: .kibbleCrate)
        XCTAssertEqual(tile.chargesRemaining, 8)
        XCTAssertTrue(tile.isReady)
    }

    // MARK: Tapping a crate

    func testATapPlacesOneTierThreeKibblePieceAndBurnsACharge() throws {
        let (vm, pos) = makeViewModel()
        vm.activateProducer(at: pos)
        let pieces = kibblePieces(vm)
        XCTAssertEqual(pieces.count, 1)
        XCTAssertEqual(pieces.first?.tier, 3)
        XCTAssertEqual(vm.boardState.producer(at: pos)?.chargesRemaining, 7)
    }

    func testATapCostsNothing() {
        let (vm, pos) = makeViewModel()
        vm.kibbleEngine.kibble = 0
        vm.kibbleEngine.dogTags = 0
        vm.activateProducer(at: pos)
        XCTAssertEqual(kibblePieces(vm).count, 1, "a bought crate never asks for kibble again")
        XCTAssertEqual(vm.kibbleEngine.kibble, 0)
        XCTAssertEqual(vm.kibbleEngine.dogTags, 0)
    }

    func testTheCrateNeverMakesThePlayerWaitBetweenTaps() {
        let (vm, pos) = makeViewModel()
        vm.activateProducer(at: pos)
        vm.activateProducer(at: pos)
        vm.activateProducer(at: pos)
        XCTAssertEqual(kibblePieces(vm).count, 3)
        XCTAssertEqual(vm.boardState.producer(at: pos)?.chargesRemaining, 5)
    }

    func testTheCrateVanishesAfterItsEighthTap() {
        let (vm, pos) = makeViewModel()
        for _ in 0..<8 { vm.activateProducer(at: pos) }
        XCTAssertEqual(kibblePieces(vm).count, 8)
        XCTAssertNil(vm.boardState.producer(at: pos), "the tile is removed at zero charges")
    }

    func testAFullCrateCollectedRawPaysTheWholeHundredAndTwenty() {
        let (vm, pos) = makeViewModel()
        for _ in 0..<8 { vm.activateProducer(at: pos) }
        var total = 0
        for item in kibblePieces(vm) { total += kibbleCurrencyValue(tier: item.tier) }
        XCTAssertEqual(total, 120)
    }

    func testATapOnAFullBoardBurnsNoCharge() {
        let (vm, pos) = makeViewModel()
        for row in vm.board {
            for cell in row where cell.position != pos && cell.isUnlocked {
                vm.boardState.setItem(BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: 0), at: cell.position)
            }
        }
        vm.boardState.recalc()
        vm.activateProducer(at: pos)
        XCTAssertEqual(vm.boardState.producer(at: pos)?.chargesRemaining, 8)
        XCTAssertTrue(kibblePieces(vm).isEmpty)
    }

    // MARK: Selection text

    func testSelectingACrateSaysItIsFreeAndHowManyTapsAreLeft() throws {
        let (vm, pos) = makeViewModel(charges: 6)
        vm.selectedCell = pos
        let text = try XCTUnwrap(vm.selectedItemInfo?.text)
        XCTAssertTrue(text.contains("Kibble Crate"))
        XCTAssertFalse(text.contains("costs"), "a bought crate costs nothing to tap: \(text)")
        XCTAssertTrue(text.contains("6 left"), text)
    }

    // MARK: Storage

    func testACrateCanBeRetiredToItsDesignatedSlotAndBack() {
        let (vm, pos) = makeViewModel(charges: 5)
        vm.retireProducer(at: pos)
        XCTAssertNil(vm.boardState.producer(at: pos))
        let stored = vm.producerStorage[ProducerLevel.kibbleCrate.rawValue]
        XCTAssertEqual(stored?.level, .kibbleCrate)
        XCTAssertEqual(stored?.chargesRemaining, 5, "charges survive storage")

        vm.designatedSlotTapped(level: .kibbleCrate)
        vm.placeDesignatedProducerOnBoard()
        XCTAssertNil(vm.producerStorage[ProducerLevel.kibbleCrate.rawValue])
        var back: ProducerTile?
        for cell in allCells(vm) where cell.producer?.level == .kibbleCrate { back = cell.producer }
        XCTAssertEqual(back?.chargesRemaining, 5)
    }

    // MARK: Debug grant

    #if DEBUG
    func testTheDebugGrantPutsOneFullCrateOnTheBoard() {
        let (vm, pos) = makeViewModel()
        vm.boardState.setProducer(nil, at: pos)
        vm.boardState.recalc()
        vm.debugGrantKibbleCrate()
        var crates: [ProducerTile] = []
        for cell in allCells(vm) {
            if let p = cell.producer, p.level == .kibbleCrate { crates.append(p) }
        }
        XCTAssertEqual(crates.count, 1)
        XCTAssertEqual(crates.first?.chargesRemaining, 8)
    }
    #endif
}
