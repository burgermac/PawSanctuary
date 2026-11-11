//
//  SpawnFlightTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_SpawnFlight.md: a spawned item is placed in board state at once,
//  an arc from its producer is recorded for the view, and the landing pop waits
//  for the arc to finish.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class SpawnFlightTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// An empty unlocked grid with one family spawner at (0,0) and kibble to spend.
    private func vmWithSpawner() -> (MergeBoardViewModel, GridPosition) {
        let vm = MergeBoardViewModel()
        vm.kibbleEngine.kibble = 100_000
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        let pos = GridPosition(row: 0, col: 0)
        vm.boardState.setProducer(ProducerTile(level: .familySpawner, species: .dog), at: pos)
        vm.boardState.recalc()
        return (vm, pos)
    }

    private func settle(_ seconds: Double) async {
        try? await Task.sleep(for: .seconds(seconds))
    }

    func testATapRecordsAFlightFromTheSpawnerToTheCellTheItemLandedIn() {
        let (vm, pos) = vmWithSpawner()
        vm.activateProducer(at: pos)

        let first = vm.spawnFlights.first
        XCTAssertNotNil(first, "a spawn from a producer should record a flight")
        XCTAssertEqual(first?.from, pos)
        if let to = first?.to {
            XCTAssertNotEqual(to, pos)
            XCTAssertEqual(vm.boardState.item(at: to)?.chainID, first?.item.chainID,
                           "the item is already in board state while it flies")
        }
    }

    func testTheLandingPopWaitsForTheArcAndTheFlightClears() async {
        let (vm, pos) = vmWithSpawner()
        vm.activateProducer(at: pos)
        let landing = vm.spawnFlights.first?.to

        XCTAssertNil(vm.animatingCell, "no pop while the item is still in the air")

        await settle(spawnFlightDuration + 0.25)
        XCTAssertTrue(vm.spawnFlights.isEmpty, "the flight is removed once it lands")
        XCTAssertEqual(vm.animatingCell, landing, "the pop starts on arrival")
    }

    func testAPlacementWithNoProducerRecordsNoFlight() {
        let (vm, _) = vmWithSpawner()
        // A toolbox claim places an item with no producer involved.
        _ = vm.placeOrBankItem(BoardItem(chainID: ContentRegistry.toolboxChainID, tier: 0))
        XCTAssertTrue(vm.spawnFlights.isEmpty)
    }

    func testTheFlightDurationMatchesTheMeasuredReferenceRange() {
        XCTAssertGreaterThanOrEqual(spawnFlightDuration, 0.08)
        XCTAssertLessThanOrEqual(spawnFlightDuration, 0.12)
    }
}
