//
//  FreeChestSkipGateTests.swift
//  PawSanctuaryTests
//
//  D7 (no monetization in session one) and an accidental-spend guard for the
//  free-chest tray tile. Opening the chest early costs Dog Tags, so, like the
//  spawner-cooldown skip, it stays unavailable until `isMonetizationUnlocked`,
//  and after that a tap asks first instead of charging. A ready chest is free
//  and opens on a tap whatever the gate says.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class FreeChestSkipGateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func makeViewModel(wall: Bool, level: Int, ready: Bool) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.kibbleEngine.dogTags = 100
        vm.freeChestReadyAt = ready ? .distantPast : Date().addingTimeInterval(3600)
        vm.commerce.hasReachedFirstWall = wall
        vm.progression.playerLevel = level
        return vm
    }

    private func toolboxCount(_ vm: MergeBoardViewModel) -> Int {
        vm.board.flatMap { $0 }.filter { $0.item?.chainID == ContentRegistry.toolboxChainID }.count
    }

    // MARK: Session one (gate closed)

    func testTappingAWaitingChestInSessionOneSpendsNothing() {
        let vm = makeViewModel(wall: false, level: 1, ready: false)
        let readyAt = vm.freeChestReadyAt

        vm.tapFreeChest()

        XCTAssertEqual(vm.kibbleEngine.dogTags, 100)
        XCTAssertFalse(vm.pendingFreeChestSkip, "no paid offer before the gate")
        XCTAssertEqual(toolboxCount(vm), 0)
        XCTAssertEqual(vm.freeChestReadyAt, readyAt, "the cooldown is untouched")
    }

    func testTheEarlyOpenItselfRefusesInSessionOne() {
        let vm = makeViewModel(wall: false, level: 1, ready: false)

        XCTAssertFalse(vm.claimOrSkipFreeChest())

        XCTAssertEqual(vm.kibbleEngine.dogTags, 100)
        XCTAssertEqual(toolboxCount(vm), 0)
    }

    func testBelowTheUnlockLevelIsStillSessionOne() {
        let vm = makeViewModel(wall: true, level: monetizationUnlockLevel - 1, ready: false)

        vm.tapFreeChest()

        XCTAssertEqual(vm.kibbleEngine.dogTags, 100)
        XCTAssertFalse(vm.pendingFreeChestSkip)
    }

    func testAReadyChestOpensFreeInSessionOne() {
        let vm = makeViewModel(wall: false, level: 1, ready: true)

        vm.tapFreeChest()

        XCTAssertEqual(vm.kibbleEngine.dogTags, 100, "a ready chest is free")
        XCTAssertEqual(toolboxCount(vm), 1)
        XCTAssertFalse(vm.isFreeChestReady, "the cooldown restarts")
    }

    // MARK: After the gate

    func testTappingAWaitingChestAsksFirstAndSpendsNothing() {
        let vm = makeViewModel(wall: true, level: monetizationUnlockLevel, ready: false)

        vm.tapFreeChest()

        XCTAssertTrue(vm.pendingFreeChestSkip, "the confirmation shows")
        XCTAssertEqual(vm.kibbleEngine.dogTags, 100, "a tap alone never charges")
        XCTAssertEqual(toolboxCount(vm), 0)
    }

    func testControlConfirmingOpensEarlyForTheSkipCost() {
        let vm = makeViewModel(wall: true, level: monetizationUnlockLevel, ready: false)
        vm.tapFreeChest()

        XCTAssertTrue(vm.claimOrSkipFreeChest())   // the alert's "Open for N Dog Tags"

        XCTAssertEqual(vm.kibbleEngine.dogTags, 100 - freeChestSkipCostDogTags)
        XCTAssertEqual(toolboxCount(vm), 1)
    }

    func testAReadyChestOpensFreeWithoutAskingAfterTheGate() {
        let vm = makeViewModel(wall: true, level: monetizationUnlockLevel, ready: true)

        vm.tapFreeChest()

        XCTAssertFalse(vm.pendingFreeChestSkip)
        XCTAssertEqual(vm.kibbleEngine.dogTags, 100)
        XCTAssertEqual(toolboxCount(vm), 1)
    }
}
