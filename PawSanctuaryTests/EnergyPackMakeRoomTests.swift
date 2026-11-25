//
//  EnergyPackMakeRoomTests.swift
//  PawSanctuaryTests
//
//  Owner, 22 Nov 2026: a paid energy pack is never bought when its spawner(s)
//  would have nowhere to go. `hasRoomForSpawners(of:)` counts free board cells
//  plus free producer storage (that level's own slot once unlocked, and the
//  overflow slots) against the number of spawners the pack grants (an XL pack
//  grants 2). `StoreManager.blockReason` turns a "no" into the message that
//  stops the purchase before StoreKit is asked to charge.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EnergyPackMakeRoomTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func makeViewModel(full: Bool, level: Int, freeOverflow: Int = totalProducerOverflowSlots,
                               designatedTaken: [ProducerLevel] = []) -> MergeBoardViewModel {
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
        for l in designatedTaken { vm.inventoryStore.producerStorage[l.rawValue] = ProducerTile(level: l) }
        vm.inventoryStore.overflowProducerStorage = (0..<totalProducerOverflowSlots).map {
            $0 < freeOverflow ? nil : ProducerTile(level: .shelterPod)
        }
        vm.inventoryStore.recalcProducerStorageOccupied()
        return vm
    }

    func testWithRoomOnTheBoardEveryPackCanBeBought() {
        let vm = makeViewModel(full: false, level: 10)
        for iap in [IAPProduct.energySmall, .energyMedium, .energyLarge, .energyXL] {
            XCTAssertTrue(vm.hasRoomForSpawners(of: iap), "\(iap)")
        }
    }

    func testOnAFullBoardStorageRoomStillAllowsThePack() {
        let vm = makeViewModel(full: true, level: 10)
        XCTAssertTrue(vm.hasRoomForSpawners(of: .energyXL))
    }

    func testOnAFullBoardWithStorageFullThePackIsStopped() {
        let vm = makeViewModel(full: true, level: 1, freeOverflow: 0, designatedTaken: [.rescueCrate])
        XCTAssertFalse(vm.hasRoomForSpawners(of: .energySmall))
    }

    func testTheXLPackNeedsRoomForAllFourProducers() {
        // Level 1: the Foster Home's own storage slot is still locked (level 7), so only
        // the overflow slots count for the spawners; the Kibble Crate's own slot is open.
        // The XL pack grants 2 spawners and 2 crates, so it needs 4 places.
        let two = makeViewModel(full: true, level: 1, freeOverflow: 2)
        XCTAssertFalse(two.hasRoomForSpawners(of: .energyXL))
        XCTAssertTrue(two.hasRoomForSpawners(of: .energyLarge), "the Large pack grants a spawner and a crate: 2")

        let three = makeViewModel(full: true, level: 1, freeOverflow: 3)
        XCTAssertTrue(three.hasRoomForSpawners(of: .energyXL))
    }

    func testTheRoomCountMatchesWhereSpawnersReallyGo() {
        // Exactly as much room as the XL pack needs: buying it must keep everything,
        // with no kibble fallback.
        let vm = makeViewModel(full: true, level: 1, freeOverflow: 3)
        XCTAssertTrue(vm.hasRoomForSpawners(of: .energyXL))
        XCTAssertEqual(vm.placeProducerReward(.fosterHome), .storage)
        XCTAssertEqual(vm.placeProducerReward(.fosterHome), .storage)
        XCTAssertEqual(vm.placeProducerReward(ProducerTile(level: .kibbleCrate), fallbackKibble: 0), .storage)
        XCTAssertEqual(vm.placeProducerReward(ProducerTile(level: .kibbleCrate), fallbackKibble: 0), .storage)
        XCTAssertFalse(vm.hasRoomForSpawners(of: .energyLarge), "and now there is none left")
    }

    func testProductsWithoutASpawnerAreNeverStopped() {
        let vm = makeViewModel(full: true, level: 1, freeOverflow: 0, designatedTaken: [.rescueCrate])
        for iap in [IAPProduct.kibbleSmall, .dogTagsSmall, .starterBundle, .eventPass, .sanctuaryPass] {
            XCTAssertTrue(vm.hasRoomForSpawners(of: iap), "\(iap)")
        }
    }

    func testTheStoreRefusesBeforeChargingWhenThereIsNoRoom() {
        let vm = makeViewModel(full: true, level: 1, freeOverflow: 0, designatedTaken: [.rescueCrate])
        let store = StoreManager()
        store.purchaseBlockReason = { vm.hasRoomForSpawners(of: $0) ? nil : energyPackMakeRoomMessage }

        XCTAssertEqual(store.blockReason(forProductID: IAPProduct.energySmall.rawValue), energyPackMakeRoomMessage)
        XCTAssertNil(store.blockReason(forProductID: IAPProduct.kibbleSmall.rawValue))
    }

    func testAFreeLevelUpProducerIsNeverBlockedItKeepsTheFallback() {
        // Level-up supply producers are free: they keep the storage, then
        // 10-kibble, fallback rather than stopping the level-up.
        let vm = makeViewModel(full: true, level: 25, freeOverflow: 0, designatedTaken: [.groomingBox])
        let kibble = vm.kibbleEngine.kibble
        XCTAssertEqual(vm.placeProducerReward(.groomingBox), .kibbleFallback)
        XCTAssertEqual(vm.kibbleEngine.kibble, kibble + 10)
    }
}
