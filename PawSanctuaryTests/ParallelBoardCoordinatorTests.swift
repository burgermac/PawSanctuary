//
//  ParallelBoardCoordinatorTests.swift
//  PawSanctuaryTests
//
//  Phase 6b, Tasks 3.3–3.4 — coverage for the fresh-board setup, generator
//  mechanic, and merge resolution, tested with no dependency on
//  MergeBoardViewModel (nothing wires this coordinator in yet).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ParallelBoardCoordinatorTests: XCTestCase {

    private func makeCoordinator(chainID: ChainID = "parallelboard.test") -> ParallelBoardCoordinator {
        ParallelBoardCoordinator(eventID: "e1", chainID: chainID)
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

    // MARK: - §3.4 attemptMerge

    private let catChain = ContentRegistry.animalChainID(.cat)
    private let hamsterChain = ContentRegistry.animalChainID(.hamster)

    func testAttemptMergeIntoAnEmptyCellMovesTheItem() {
        let coordinator = makeCoordinator(chainID: catChain)
        let from = GridPosition(row: 1, col: 1)
        let to = GridPosition(row: 1, col: 2)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 2), at: from)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: from, to: to)

        XCTAssertNil(coordinator.boardState.item(at: from))
        XCTAssertEqual(coordinator.boardState.item(at: to)?.chainID, catChain)
        XCTAssertEqual(coordinator.boardState.item(at: to)?.tier, 2)
    }

    func testAttemptMergeOfMatchingPairAdvancesTierAndClearsSource() {
        let coordinator = makeCoordinator(chainID: catChain)
        let from = GridPosition(row: 1, col: 1)
        let to = GridPosition(row: 1, col: 2)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 3), at: from)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 3), at: to)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: from, to: to)

        XCTAssertNil(coordinator.boardState.item(at: from))
        XCTAssertEqual(coordinator.boardState.item(at: to)?.chainID, catChain)
        XCTAssertEqual(coordinator.boardState.item(at: to)?.tier, 4)
    }

    func testAttemptMergeOfIneligiblePairSwapsInPlace() {
        let coordinator = makeCoordinator(chainID: catChain)
        let from = GridPosition(row: 1, col: 1)
        let to = GridPosition(row: 1, col: 2)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 0), at: from)
        coordinator.boardState.setItem(BoardItem(chainID: hamsterChain, tier: 3), at: to)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: from, to: to)

        XCTAssertEqual(coordinator.boardState.item(at: from)?.chainID, hamsterChain)
        XCTAssertEqual(coordinator.boardState.item(at: from)?.tier, 3)
        XCTAssertEqual(coordinator.boardState.item(at: to)?.chainID, catChain)
        XCTAssertEqual(coordinator.boardState.item(at: to)?.tier, 0)
    }

    func testAttemptMergeToCompletionReachesTopTier() {
        let coordinator = makeCoordinator(chainID: catChain)
        let from = GridPosition(row: 1, col: 1)
        let to = GridPosition(row: 1, col: 2)
        let top = animalChainTopTier
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: top - 1), at: from)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: top - 1), at: to)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: from, to: to)

        XCTAssertEqual(coordinator.boardState.item(at: to)?.tier, top)
    }

    func testAttemptMergeFromAnEmptySourceIsANoOp() {
        let coordinator = makeCoordinator(chainID: catChain)
        let from = GridPosition(row: 1, col: 1)
        let to = GridPosition(row: 1, col: 2)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 0), at: to)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: from, to: to)

        XCTAssertNil(coordinator.boardState.item(at: from))
        XCTAssertEqual(coordinator.boardState.item(at: to)?.tier, 0, "an empty source must leave the destination untouched")
    }

    func testAttemptMergeWithSameFromAndToIsANoOp() {
        let coordinator = makeCoordinator(chainID: catChain)
        let pos = GridPosition(row: 1, col: 1)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 2), at: pos)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: pos, to: pos)

        XCTAssertEqual(coordinator.boardState.item(at: pos)?.tier, 2)
    }

    func testAttemptMergeOntoALockedDestinationIsANoOp() {
        let coordinator = makeCoordinator(chainID: catChain)
        let from = GridPosition(row: 1, col: 1)
        let to = GridPosition(row: 1, col: 2)
        coordinator.boardState.setItem(BoardItem(chainID: catChain, tier: 2), at: from)
        coordinator.boardState.setUnlocked(false, at: to)
        coordinator.boardState.recalc()

        coordinator.attemptMerge(from: from, to: to)

        XCTAssertEqual(coordinator.boardState.item(at: from)?.tier, 2, "a locked destination must reject the attempt entirely")
        XCTAssertNil(coordinator.boardState.item(at: to))
    }
}
