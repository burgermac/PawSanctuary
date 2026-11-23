//
//  PaidSpawnerFullBoardTests.swift
//  PawSanctuaryTests
//
//  An energy pack (a paid purchase) grants spawner tiles. On a full board they
//  used to be converted into 10 kibble each, silently. Now they go to producer
//  storage (the Producers tab), the same place a retired producer goes, and
//  the 10-kibble fallback remains only when the board and producer storage
//  are both full.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class PaidSpawnerFullBoardTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// Every cell unlocked; `full` fills them all with a tier-0 animal.
    private func makeViewModel(full: Bool, level: Int = 10) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        let dog = ContentRegistry.animalChainID(.dog)
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col),
                          item: full ? BoardItem(chainID: dog, tier: 0) : nil,
                          isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.progression.playerLevel = level
        vm.inventoryStore.producerStorage = [:]
        vm.inventoryStore.overflowProducerStorage = Array(repeating: nil, count: totalProducerOverflowSlots)
        vm.inventoryStore.recalcProducerStorageOccupied()
        return vm
    }

    private func storedProducers(_ vm: MergeBoardViewModel) -> [ProducerLevel] {
        Array(vm.inventoryStore.producerStorage.values.map(\.level))
            + vm.inventoryStore.overflowProducerStorage.compactMap { $0?.level }
    }

    private func boardProducers(_ vm: MergeBoardViewModel) -> [ProducerLevel] {
        vm.board.flatMap { $0 }.compactMap { $0.producer?.level }
    }

    func testOnAFullBoardThePacksSpawnerGoesToStorageNotKibble() {
        let vm = makeViewModel(full: true)
        let kibble = vm.kibbleEngine.kibble
        guard let pack = IAPProduct.energySmall.energyPackContents else { return XCTFail("no pack") }

        vm.applyPurchase(.energySmall, priceUSD: 0.99)

        XCTAssertEqual(storedProducers(vm), [pack.spawnerLevel], "the paid spawner is kept")
        XCTAssertEqual(vm.kibbleEngine.kibble, kibble + pack.kibble,
                       "only the pack's own kibble, no 10-kibble conversion")
    }

    func testOnAFullBoardBothSpawnersOfTheLargestPackAreKept() {
        let vm = makeViewModel(full: true, level: 10)
        let kibble = vm.kibbleEngine.kibble
        guard let pack = IAPProduct.energyXL.energyPackContents else { return XCTFail("no pack") }

        vm.applyPurchase(.energyXL, priceUSD: 9.99)

        XCTAssertEqual(storedProducers(vm), Array(repeating: pack.spawnerLevel, count: pack.spawnerCount))

        // A $9.99 purchase can also reach a VIP tier that pays kibble, so compare
        // with the same purchase on a board with room: a full board must not add
        // anything (no 10-kibble conversions).
        let control = makeViewModel(full: false, level: 10)
        let controlKibble = control.kibbleEngine.kibble
        control.applyPurchase(.energyXL, priceUSD: 9.99)
        XCTAssertEqual(vm.kibbleEngine.kibble - kibble, control.kibbleEngine.kibble - controlKibble)
    }

    func testControlWithRoomTheSpawnerLandsOnTheBoard() {
        let vm = makeViewModel(full: false)
        guard let pack = IAPProduct.energySmall.energyPackContents else { return XCTFail("no pack") }

        vm.applyPurchase(.energySmall, priceUSD: 0.99)

        XCTAssertEqual(boardProducers(vm), [pack.spawnerLevel])
        XCTAssertTrue(storedProducers(vm).isEmpty)
    }

    func testOnlyWhenBoardAndStorageAreBothFullDoesTheOldFallbackApply() {
        let vm = makeViewModel(full: true, level: 1)
        // Fill every overflow slot and the designated Rescue Crate slot.
        vm.inventoryStore.producerStorage[ProducerLevel.rescueCrate.rawValue] = ProducerTile(level: .rescueCrate)
        vm.inventoryStore.overflowProducerStorage =
            Array(repeating: ProducerTile(level: .shelterPod), count: totalProducerOverflowSlots)
        vm.inventoryStore.recalcProducerStorageOccupied()
        let kibble = vm.kibbleEngine.kibble

        XCTAssertEqual(vm.placeProducerReward(.rescueCrate), .kibbleFallback)
        XCTAssertEqual(vm.kibbleEngine.kibble, kibble + 10)
    }

    func testALevelUpSupplyProducerOnAFullBoardIsKeptToo() {
        let vm = makeViewModel(full: true, level: 25)

        XCTAssertEqual(vm.placeProducerReward(.groomingBox), .storage)
        XCTAssertEqual(storedProducers(vm), [.groomingBox])
    }
}
