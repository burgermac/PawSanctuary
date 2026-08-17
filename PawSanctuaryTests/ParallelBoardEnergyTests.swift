//
//  ParallelBoardEnergyTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Task 3.2 — coverage for the Parallel Board's standalone energy
//  pool, tested with no dependency on MergeBoardViewModel or
//  ParallelBoardCoordinator (neither wires this in yet).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ParallelBoardEnergyTests: XCTestCase {

    func testStartsFullAtCapWithFreshRegenTimer() {
        let energy = ParallelBoardEnergy()
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap)
        XCTAssertEqual(energy.secondsUntilNext, parallelBoardEnergyRegenSecs)
    }

    func testTickAtCapDoesNothing() {
        let energy = ParallelBoardEnergy()
        let secondsBefore = energy.secondsUntilNext
        energy.tick()
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap)
        XCTAssertEqual(energy.secondsUntilNext, secondsBefore, "the countdown shouldn't move while already full")
    }

    func testTickDecrementsCountdownWithoutRegeneratingEarly() {
        let energy = ParallelBoardEnergy()
        energy.spend(1)
        energy.tick()
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap - 1)
        XCTAssertEqual(energy.secondsUntilNext, parallelBoardEnergyRegenSecs - 1)
    }

    func testRegeneratesOnePointAfterRegenSecsTicksAndResetsCountdown() {
        let energy = ParallelBoardEnergy()
        energy.spend(1)
        for _ in 0..<parallelBoardEnergyRegenSecs {
            energy.tick()
        }
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap)
        XCTAssertEqual(energy.secondsUntilNext, parallelBoardEnergyRegenSecs)
    }

    func testRegenerationStopsExactlyAtCapEvenWithExcessTicks() {
        let energy = ParallelBoardEnergy()
        energy.spend(1)
        for _ in 0..<(parallelBoardEnergyRegenSecs * 3) {
            energy.tick()
        }
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap, "balance must never exceed the cap")
    }

    func testSpendSucceedsAndDecrementsBalance() {
        let energy = ParallelBoardEnergy()
        let succeeded = energy.spend(5)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap - 5)
    }

    func testSpendRejectsInsufficientBalanceAndLeavesBalanceUnchanged() {
        let energy = ParallelBoardEnergy()
        let succeeded = energy.spend(parallelBoardEnergyCap + 1)
        XCTAssertFalse(succeeded)
        XCTAssertEqual(energy.balance, parallelBoardEnergyCap, "a rejected spend must not touch the balance")
    }

    func testSpendExactBalanceSucceedsAndZeroesIt() {
        let energy = ParallelBoardEnergy()
        let succeeded = energy.spend(parallelBoardEnergyCap)
        XCTAssertTrue(succeeded)
        XCTAssertEqual(energy.balance, 0)
    }
}
