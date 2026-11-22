//
//  ParallelOrderEnergyTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_ParallelOrderEnergy.md: a claimed main-board order adds +1 energy
//  to a live Parallel Board event, banked above the regen cap up to 60. Regen
//  stays; with no event live, orders add nothing.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ParallelOrderEnergyTests: XCTestCase {

    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    /// Inside second_chances_20260911 (09-11...09-14), a fixed date.
    private let insideWindow = "2026-09-12"

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func completeOrder() -> AdoptionOrder {
        AdoptionOrder(familyIndex: 0,
                      wantedChainID: ContentRegistry.animalChainID(.dog),
                      wantedTier: 1, wantedCount: 1)
    }

    /// D14: an order pays only when it is delivered, and delivery needs every
    /// wanted item held on the board. (These tests used to hand in an order
    /// already marked complete, which only the removed merge-credit path made.)
    private func holdWantedItem(_ vm: MergeBoardViewModel) {
        // `MergeBoardViewModel()` has no board until `loadGame()`; give it a bare unlocked one.
        if vm.board.isEmpty {
            vm.board = (0..<boardRows).map { row in
                (0..<7).map { col in
                    BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
                }
            }
        }
        vm.boardState.recalc()
        guard let cell = vm.boardState.emptyUnlockedCells.first else {
            return XCTFail("no free cell to hold the wanted item")
        }
        vm.boardState.setItem(BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: 1),
                              at: cell.position)
    }

    private func deliver(_ vm: MergeBoardViewModel, file: StaticString = #filePath, line: UInt = #line) {
        vm.adoptionBoardCoordinator.urgentOrder = nil
        holdWantedItem(vm)
        XCTAssertTrue(vm.deliverOrder(at: 0), file: file, line: line)
    }

    // MARK: The pool

    func testBonusFillsTheBarThenBanksAboveTheCap() {
        let energy = ParallelBoardEnergy()
        energy.balance = parallelBoardEnergyCap - 1
        XCTAssertEqual(energy.addBonus(1), 1)
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap)
        XCTAssertFalse(energy.isBanked, "exactly at the cap is full, not banked")
        XCTAssertEqual(energy.addBonus(1), 1)
        XCTAssertTrue(energy.isBanked)
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap + 1)
    }

    func testTheBankStopsAtTheBankCap() {
        let energy = ParallelBoardEnergy()
        energy.balance = parallelBoardEnergyBankCap - 1
        XCTAssertEqual(energy.addBonus(5), 1, "only the room left is added")
        XCTAssertEqual(energy.balance, parallelBoardEnergyBankCap)
        XCTAssertEqual(energy.addBonus(1), 0)
        XCTAssertEqual(energy.balance, parallelBoardEnergyBankCap)
    }

    func testABalanceAlreadyOverTheBankCapIsNeverLowered() {
        let energy = ParallelBoardEnergy()
        energy.balance = parallelBoardEnergyBankCap + 10      // e.g. a future cap change
        XCTAssertEqual(energy.addBonus(1), 0)
        XCTAssertEqual(energy.balance, parallelBoardEnergyBankCap + 10)
    }

    func testRegenDoesNothingOnceBankedAndSpendingStillWorks() {
        let energy = ParallelBoardEnergy()
        energy.balance = parallelBoardEnergyCap + 5
        for _ in 0..<(parallelBoardEnergyRegenSecs * 3) { energy.tick() }
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap + 5, "regen must not add to a banked pool")
        XCTAssertTrue(energy.spend(parallelBoardGeneratorCost))
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap + 5 - parallelBoardGeneratorCost)
    }

    func testRegenStillRefillsABelowCapPool() {
        let energy = ParallelBoardEnergy()
        energy.balance = 0
        for _ in 0..<parallelBoardEnergyRegenSecs { energy.tick() }
        XCTAssertEqual(energy.balance, 1, "the passive regen is kept, not replaced")
    }

    // MARK: Through the order claim

    func testClaimingAnOrderDuringAnEventAddsEnergy() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try! XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.energy.balance = 10

        vm.adoptionBoardCoordinator.adoptionOrders = [completeOrder()]
        deliver(vm)
        XCTAssertEqual(coordinator.energy.balance, 10 + parallelBoardEnergyPerOrder)
    }

    func testClaimingTheUrgentOrderAlsoAddsEnergy() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try! XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.energy.balance = 10

        vm.adoptionBoardCoordinator.urgentOrder = completeOrder()
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 600
        holdWantedItem(vm)
        XCTAssertTrue(vm.deliverUrgentOrder())
        XCTAssertEqual(coordinator.energy.balance, 10 + parallelBoardEnergyPerOrder)
    }

    func testClaimingAnOrderWithNoEventLiveChangesNothingAndDoesNotCrash() {
        let vm = MergeBoardViewModel()
        XCTAssertNil(vm.activeParallelBoardEvent)
        vm.adoptionBoardCoordinator.adoptionOrders = [completeOrder()]
        deliver(vm)
        XCTAssertNil(vm.activeParallelBoardEvent)
    }

    func testManyOrdersStopAtTheBankCap() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try! XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.energy.balance = parallelBoardEnergyBankCap - 1
        for _ in 0..<5 {
            vm.adoptionBoardCoordinator.adoptionOrders = [completeOrder()]
            deliver(vm)
        }
        XCTAssertEqual(coordinator.energy.balance, parallelBoardEnergyBankCap)
    }

    // MARK: Persistence

    func testABankedBalanceSurvivesASaveAndRestore() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try! XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.energy.balance = parallelBoardEnergyCap + 12

        let saved = coordinator.makeSaveState()
        let other = MergeBoardViewModel()
        other.checkEventLifecycle(at: date(insideWindow))
        let restored = try! XCTUnwrap(other.activeParallelBoardEvent)
        restored.restore(from: saved)
        XCTAssertEqual(restored.energy.balance, parallelBoardEnergyCap + 12,
                       "restore must not clamp banked energy back to the regen cap")
    }

    func testTheBankCapIsTwiceTheRegenCap() {
        XCTAssertEqual(parallelBoardEnergyBankCap, parallelBoardEnergyCap * 2)
        XCTAssertEqual(parallelBoardEnergyPerOrder, 1)
    }
}
