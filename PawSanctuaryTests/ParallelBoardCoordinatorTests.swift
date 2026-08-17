//
//  ParallelBoardCoordinatorTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Task 3.3 — coverage for the fresh-board setup and generator
//  mechanic, tested with no dependency on MergeBoardViewModel (nothing
//  wires this coordinator in yet).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ParallelBoardCoordinatorTests: XCTestCase {

    private func makeCoordinator() -> ParallelBoardCoordinator {
        ParallelBoardCoordinator(eventID: "e1", chainID: "parallelboard.test")
    }

    func testInitBuildsAFullyUnlockedEmptyGrid() {
        let coordinator = makeCoordinator()
        XCTAssertEqual(coordinator.boardState.board.count, parallelBoardRows)
        for row in coordinator.boardState.board {
            XCTAssertEqual(row.count, parallelBoardCols)
            for cell in row {
                XCTAssertTrue(cell.isUnlocked)
                XCTAssertTrue(cell.isEmpty)
            }
        }
        XCTAssertEqual(coordinator.boardState.emptyUnlockedCells.count, parallelBoardRows * parallelBoardCols)
    }

    func testGeneratorPositionIsFixedAtOrigin() {
        let coordinator = makeCoordinator()
        XCTAssertEqual(coordinator.generatorPosition, GridPosition(row: 0, col: 0))
    }

    func testCollectFromGeneratorSpendsCostAndPlacesABaseTierItem() {
        let coordinator = makeCoordinator()
        let balanceBefore = coordinator.energy.balance
        coordinator.collectFromGenerator()
        XCTAssertEqual(coordinator.energy.balance, balanceBefore - parallelBoardGeneratorCost)

        let placed = coordinator.boardState.board.flatMap { $0 }.filter { $0.item != nil }
        XCTAssertEqual(placed.count, 1)
        XCTAssertEqual(placed.first?.item?.chainID, "parallelboard.test")
        XCTAssertEqual(placed.first?.item?.tier, 0)
    }

    func testCollectFromGeneratorNeverPlacesOnTheGeneratorCellItself() {
        let coordinator = makeCoordinator()
        for _ in 0..<10 {
            coordinator.collectFromGenerator()
        }
        XCTAssertTrue(coordinator.boardState.item(at: coordinator.generatorPosition) == nil,
                       "the generator cell must stay clear for the next generation")
    }

    func testCollectFromGeneratorNoOpsWhenNoEligibleCellIsOpen() {
        let coordinator = makeCoordinator()
        // Fill every cell except the generator position directly.
        for row in 0..<parallelBoardRows {
            for col in 0..<parallelBoardCols {
                let pos = GridPosition(row: row, col: col)
                guard pos != coordinator.generatorPosition else { continue }
                coordinator.boardState.setItem(BoardItem(chainID: "parallelboard.test", tier: 0), at: pos)
            }
        }
        coordinator.boardState.recalc()
        let balanceBefore = coordinator.energy.balance

        coordinator.collectFromGenerator()

        XCTAssertEqual(coordinator.energy.balance, balanceBefore, "a full board must not spend energy")
        XCTAssertTrue(coordinator.boardState.item(at: coordinator.generatorPosition) == nil)
    }

    func testCollectFromGeneratorNoOpsWhenEnergyIsInsufficient() {
        let coordinator = makeCoordinator()
        coordinator.energy.spend(coordinator.energy.balance - 1)   // leave exactly 1, less than the cost
        XCTAssertEqual(coordinator.energy.balance, 1)

        coordinator.collectFromGenerator()

        XCTAssertEqual(coordinator.energy.balance, 1, "an insufficient balance must be left untouched")
        let placed = coordinator.boardState.board.flatMap { $0 }.filter { $0.item != nil }
        XCTAssertTrue(placed.isEmpty)
    }
}
