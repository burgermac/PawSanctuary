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
        var order = AdoptionOrder(familyIndex: 0,
                                  wantedChainID: ContentRegistry.animalChainID(.dog),
                                  wantedTier: 1, wantedCount: 1)
        order.lines[0].fulfilled = 1
        return order
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
        vm.autoClaimOrder(at: 0)
        XCTAssertEqual(coordinator.energy.balance, 10 + parallelBoardEnergyPerOrder)
    }

    func testClaimingTheUrgentOrderAlsoAddsEnergy() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try! XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.energy.balance = 10

        vm.adoptionBoardCoordinator.urgentOrder = completeOrder()
        vm.autoClaimUrgentOrder()
        XCTAssertEqual(coordinator.energy.balance, 10 + parallelBoardEnergyPerOrder)
    }

    func testClaimingAnOrderWithNoEventLiveChangesNothingAndDoesNotCrash() {
        let vm = MergeBoardViewModel()
        XCTAssertNil(vm.activeParallelBoardEvent)
        vm.adoptionBoardCoordinator.adoptionOrders = [completeOrder()]
        vm.autoClaimOrder(at: 0)
        XCTAssertNil(vm.activeParallelBoardEvent)
    }

    func testManyOrdersStopAtTheBankCap() {
        let vm = MergeBoardViewModel()
        vm.checkEventLifecycle(at: date(insideWindow))
        let coordinator = try! XCTUnwrap(vm.activeParallelBoardEvent)
        coordinator.energy.balance = parallelBoardEnergyBankCap - 1
        for _ in 0..<5 {
            vm.adoptionBoardCoordinator.adoptionOrders = [completeOrder()]
            vm.autoClaimOrder(at: 0)
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
