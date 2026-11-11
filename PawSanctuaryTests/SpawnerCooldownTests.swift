//
//  SpawnerCooldownTests.swift
//  PawSanctuaryTests
//
//  specs/Spec_SpawnerCooldown.md: each family spawner counts the kibble it has
//  spent, and every `familySpawnerCooldownKibble` starts a
//  `familySpawnerCooldownSeconds` wait, skippable for Dog Tags. Per spawner.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class SpawnerCooldownTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Tile logic

    func testCrossingTheThresholdStartsACooldownAndCarriesTheRemainder() {
        var tile = ProducerTile(level: .familySpawner, species: .dog)
        XCTAssertFalse(tile.recordKibbleSpent(familySpawnerCooldownKibble - 10))
        XCTAssertTrue(tile.isReady)

        let now = Date()
        XCTAssertTrue(tile.recordKibbleSpent(25, now: now))
        XCTAssertEqual(tile.kibbleSpentSinceCooldown, 15, "the overshoot carries over, not lost")
        XCTAssertEqual(tile.readyAt, now.addingTimeInterval(familySpawnerCooldownSeconds))
        XCTAssertFalse(tile.isReady)
    }

    func testAFreeSpawnAddsNothing() {
        var tile = ProducerTile(level: .familySpawner, species: .dog)
        XCTAssertFalse(tile.recordKibbleSpent(0))
        XCTAssertEqual(tile.kibbleSpentSinceCooldown, 0)
    }

    func testTheCooldownFractionRunsOverTheConfiguredLength() {
        var tile = ProducerTile(level: .familySpawner, species: .dog)
        tile.startCooldown()
        XCTAssertEqual(tile.cooldownFraction, 1, accuracy: 0.05)
        XCTAssertEqual(ProducerLevel.familySpawner.cooldown, familySpawnerCooldownSeconds)
    }

    // MARK: Through the view model

    /// A view model with one fresh family spawner placed on the board and plenty of kibble.
    private func vmWithSpawner() -> (MergeBoardViewModel, GridPosition) {
        let vm = MergeBoardViewModel()
        vm.kibbleEngine.kibble = 100_000
        // A plain, fully unlocked, empty grid — the same fixture the
        // `attemptMergeOrMove` characterization tests use. A bare view model has
        // no board until a game is started or loaded.
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        let pos = GridPosition(row: 0, col: 0)
        vm.boardState.setProducer(ProducerTile(level: .familySpawner, species: .dog), at: pos)
        vm.boardState.recalc()   // `emptyUnlockedCells` is cached, not derived
        return (vm, pos)
    }

    func testTappingUntilTheThresholdCoolsTheSpawnerAndTheNextTapOnlySelects() {
        let (vm, pos) = vmWithSpawner()
        vm.progression.playerLevel = 1   // skip prompt gated off: a tap must not raise it

        var safety = 0
        while vm.boardState.producer(at: pos)?.isReady == true, safety < 400 {
            vm.activateProducer(at: pos)
            safety += 1
            // 150 taps at ×1 would fill the board and stop spending, so clear
            // what each tap spawned (the spawner itself stays).
            var board = vm.board
            for r in board.indices { for c in board[r].indices where board[r][c].producer == nil { board[r][c].item = nil } }
            vm.board = board
            vm.boardState.recalc()
        }
        let tile = try? XCTUnwrap(vm.boardState.producer(at: pos))
        XCTAssertNotNil(tile)
        XCTAssertFalse(tile?.isReady ?? true, "the spawner should have cooled")
        XCTAssertLessThan(tile?.kibbleSpentSinceCooldown ?? .max, familySpawnerCooldownKibble)

        let kibbleBefore = vm.kibbleEngine.kibble
        vm.activateProducer(at: pos)
        XCTAssertEqual(vm.kibbleEngine.kibble, kibbleBefore, "a cooling spawner must not spawn or charge")
        XCTAssertNil(vm.pendingSpawnerSkip, "no skip prompt before monetization unlocks (D7)")
    }

    func testAnotherSpawnerKeepsWorkingWhileOneCools() {
        let (vm, pos) = vmWithSpawner()
        var other = ProducerTile(level: .familySpawner, species: .cat)
        var cooling = vm.boardState.producer(at: pos)!
        cooling.startCooldown()
        vm.boardState.setProducer(cooling, at: pos)
        XCTAssertFalse(vm.boardState.producer(at: pos)!.isReady)
        XCTAssertTrue(other.isReady, "readiness is per tile")
        other.recordKibbleSpent(familySpawnerCooldownKibble - 1)
        XCTAssertTrue(other.isReady)
    }

    // MARK: Skip

    private func coolDown(_ vm: MergeBoardViewModel, at pos: GridPosition) {
        var tile = vm.boardState.producer(at: pos)!
        tile.startCooldown()
        vm.boardState.setProducer(tile, at: pos)
    }

    private func unlockMonetization(_ vm: MergeBoardViewModel) {
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel
    }

    func testSkipChargesDogTagsAndClearsTheWait() {
        let (vm, pos) = vmWithSpawner()
        unlockMonetization(vm)
        vm.kibbleEngine.dogTags = 10
        coolDown(vm, at: pos)

        XCTAssertTrue(vm.skipSpawnerCooldown(at: pos))
        XCTAssertEqual(vm.kibbleEngine.dogTags, 10 - familySpawnerCooldownSkipDogTags)
        XCTAssertTrue(vm.boardState.producer(at: pos)!.isReady)
    }

    func testSkipRefusesWithTooFewDogTagsAndChargesNothing() {
        let (vm, pos) = vmWithSpawner()
        unlockMonetization(vm)
        vm.kibbleEngine.dogTags = familySpawnerCooldownSkipDogTags - 1
        coolDown(vm, at: pos)

        XCTAssertFalse(vm.skipSpawnerCooldown(at: pos))
        XCTAssertEqual(vm.kibbleEngine.dogTags, familySpawnerCooldownSkipDogTags - 1)
        XCTAssertFalse(vm.boardState.producer(at: pos)!.isReady)
    }

    func testSkipIsWithheldBeforeMonetizationUnlocks() {
        let (vm, pos) = vmWithSpawner()
        vm.commerce.hasReachedFirstWall = false
        vm.kibbleEngine.dogTags = 10
        coolDown(vm, at: pos)

        XCTAssertFalse(vm.skipSpawnerCooldown(at: pos))
        vm.requestSpawnerSkip(at: pos)
        XCTAssertNil(vm.pendingSpawnerSkip)
    }

    func testTappingACoolingSpawnerRaisesTheSkipPromptOnceMonetizationIsOpen() {
        let (vm, pos) = vmWithSpawner()
        unlockMonetization(vm)
        coolDown(vm, at: pos)
        vm.activateProducer(at: pos)
        XCTAssertEqual(vm.pendingSpawnerSkip, pos)
    }

    func testSkipIgnoresASpawnerThatIsNotCooling() {
        let (vm, pos) = vmWithSpawner()
        unlockMonetization(vm)
        vm.kibbleEngine.dogTags = 10
        XCTAssertFalse(vm.skipSpawnerCooldown(at: pos))
        XCTAssertEqual(vm.kibbleEngine.dogTags, 10)
    }

    // MARK: Persistence

    func testATileSavedBeforeTheFieldExistedDecodesWithZero() throws {
        let tile = ProducerTile(level: .familySpawner, species: .dog)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(tile)) as? [String: Any])
        json.removeValue(forKey: "kibbleSpentSinceCooldown")
        let old = try JSONSerialization.data(withJSONObject: json)
        let decoded = try JSONDecoder().decode(ProducerTile.self, from: old)
        XCTAssertEqual(decoded.kibbleSpentSinceCooldown, 0)
    }

    func testTheCounterAndTheCooldownSurviveARoundTrip() throws {
        var tile = ProducerTile(level: .familySpawner, species: .dog)
        tile.recordKibbleSpent(40)
        let decoded = try JSONDecoder().decode(ProducerTile.self, from: JSONEncoder().encode(tile))
        XCTAssertEqual(decoded.kibbleSpentSinceCooldown, 40)

        var cooling = ProducerTile(level: .familySpawner, species: .dog)
        cooling.startCooldown()
        let back = try JSONDecoder().decode(ProducerTile.self, from: JSONEncoder().encode(cooling))
        XCTAssertFalse(back.isReady)
    }
}
