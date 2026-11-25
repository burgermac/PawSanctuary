//
//  EnergyPackCrateTests.swift
//  PawSanctuaryTests
//
//  Cards and chests stage 5 (specs/Spec_CardsAndChests.md §4.2, §8, owner Q7, Q9, Q14):
//  the kibble in each IAP energy pack is delivered as a Kibble Crate instead of being
//  credited. Owner, 25 Nov 2026: Small 100, Medium 300, Large 480, XL 1000 kibble.
//  A crate carries its own piece tier and charge count (schema v49).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EnergyPackCrateTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Helpers

    private let ownerAmounts: [(IAPProduct, Int)] = [
        (.energySmall, 100), (.energyMedium, 300), (.energyLarge, 480), (.energyXL, 1_000),
    ]

    private func makeViewModel(full: Bool = false, level: Int = 10,
                               freeOverflow: Int = totalProducerOverflowSlots) -> MergeBoardViewModel {
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
        vm.inventoryStore.overflowProducerStorage = (0..<totalProducerOverflowSlots).map {
            $0 < freeOverflow ? nil : ProducerTile(level: .shelterPod)
        }
        vm.inventoryStore.recalcProducerStorageOccupied()
        vm.kibbleEngine.kibble = 0
        return vm
    }

    private func tiles(_ vm: MergeBoardViewModel, level: ProducerLevel, onBoard: Bool) -> [ProducerTile] {
        var found: [ProducerTile] = []
        if onBoard {
            for row in vm.board { for cell in row { if let p = cell.producer, p.level == level { found.append(p) } } }
        } else {
            for (_, p) in vm.inventoryStore.producerStorage where p.level == level { found.append(p) }
            for slot in vm.inventoryStore.overflowProducerStorage {
                if let p = slot, p.level == level { found.append(p) }
            }
        }
        return found
    }

    /// Crates on the board plus crates in storage.
    private func allCrates(_ vm: MergeBoardViewModel) -> [ProducerTile] {
        tiles(vm, level: .kibbleCrate, onBoard: true) + tiles(vm, level: .kibbleCrate, onBoard: false)
    }

    private func boardCrates(_ vm: MergeBoardViewModel) -> [ProducerTile] {
        tiles(vm, level: .kibbleCrate, onBoard: true)
    }

    // MARK: The sizing table

    func testEveryPackIsWorthAtLeastTheOwnersAmountAndWithinFivePercent() {
        for (product, amount) in ownerAmounts {
            guard let pack = product.energyPackContents else { return XCTFail("no pack for \(product)") }
            XCTAssertGreaterThanOrEqual(pack.kibble, amount, "\(product) must not pay less than \(amount)")
            XCTAssertLessThanOrEqual(pack.kibble * 100, amount * 105, "\(product) must not overshoot by more than 5%")
        }
    }

    func testTheCrateShapesPerPack() {
        func shape(_ p: IAPProduct) -> [[Int]] {
            (p.energyPackContents?.crates ?? []).map { [$0.charges, $0.tier] }
        }
        XCTAssertEqual(shape(.energySmall),  [[7, 3]])
        XCTAssertEqual(shape(.energyMedium), [[5, 5]])
        XCTAssertEqual(shape(.energyLarge),  [[8, 5]])
        XCTAssertEqual(shape(.energyXL),     [[8, 5], [8, 5]])
    }

    func testNoCrateHoldsMoreChargesThanTheCellsCanShowAsPips() {
        for (product, _) in ownerAmounts {
            for size in product.energyPackContents?.crates ?? [] {
                XCTAssertLessThanOrEqual(size.charges, ProducerLevel.kibbleCrate.maxCharges)
            }
        }
    }

    func testThePacksOtherContentsAreUnchanged() {
        XCTAssertEqual(IAPProduct.energySmall.energyPackContents?.dogTags, 8)
        XCTAssertEqual(IAPProduct.energyXL.energyPackContents?.dogTags, 80)
        XCTAssertEqual(IAPProduct.energyXL.energyPackContents?.spawnerCount, 2)
        XCTAssertEqual(IAPProduct.energyLarge.energyPackContents?.spawnerLevel, .fosterHome)
    }

    // MARK: A sized crate on the board

    func testASizedCrateEmitsItsOwnTierAndHoldsItsOwnCharges() {
        let tile = ProducerTile.kibbleCrate(KibbleCrateSize(charges: 5, tier: 5))
        XCTAssertEqual(tile.chargesRemaining, 5)
        XCTAssertEqual(tile.totalCharges, 5)
        XCTAssertEqual(tile.emitTier, 5)
        // An unsized crate (stage 3's debug grant) keeps the level's own defaults.
        let plain = ProducerTile(level: .kibbleCrate)
        XCTAssertEqual(plain.totalCharges, 8)
        XCTAssertEqual(plain.emitTier, 3)
    }

    func testTappingASizedCrateEmitsItsTierAndVanishesAfterItsLastCharge() {
        let vm = makeViewModel()
        let pos = GridPosition(row: 0, col: 0)
        vm.boardState.setProducer(ProducerTile.kibbleCrate(KibbleCrateSize(charges: 5, tier: 5)), at: pos)
        vm.boardState.recalc()
        for _ in 0..<5 { vm.activateProducer(at: pos) }

        var pieces: [BoardItem] = []
        for row in vm.board { for cell in row {
            if let item = cell.item, item.chainID == ContentRegistry.kibbleCurrencyChainID { pieces.append(item) }
        } }
        XCTAssertEqual(pieces.count, 5)
        for piece in pieces { XCTAssertEqual(piece.tier, 5) }
        XCTAssertNil(vm.boardState.producer(at: pos), "gone after the fifth tap")
    }

    // MARK: Buying a pack

    func testBuyingEachPackOnARoomyBoardPlacesItsCratesAndCreditsNoKibble() {
        // The Medium and Large packs are under the $5 VIP threshold, so nothing else pays kibble.
        for (product, _) in [(IAPProduct.energySmall, 0), (.energyMedium, 0), (.energyLarge, 0)] {
            let vm = makeViewModel()
            guard let pack = product.energyPackContents else { return XCTFail("no pack") }
            let tagsBefore = vm.kibbleEngine.dogTags
            vm.applyPurchase(product, priceUSD: 0.99)
            XCTAssertEqual(vm.kibbleEngine.kibble, 0, "\(product): the kibble arrives as a crate, not a credit")
            XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore + pack.dogTags, "\(product): tags still credited")
            let placed = allCrates(vm)
            XCTAssertEqual(placed.count, pack.crates.count, "\(product)")
            var total = 0
            for tile in placed { total += tile.chargesRemaining * kibbleCurrencyValue(tier: tile.emitTier) }
            XCTAssertEqual(total, pack.kibble, "\(product): the crates hold the pack's kibble")
            XCTAssertEqual(tiles(vm, level: pack.spawnerLevel, onBoard: true).count, pack.spawnerCount,
                           "\(product): the spawner is still delivered")
        }
    }

    func testTheXLPackPlacesTwoCratesAndTwoSpawners() {
        let vm = makeViewModel()
        vm.applyPurchase(.energyXL, priceUSD: 9.99)
        XCTAssertEqual(boardCrates(vm).count, 2)
        XCTAssertEqual(tiles(vm, level: .fosterHome, onBoard: true).count, 2)
    }

    func testOnAFullBoardTheCrateGoesToStorageWithItsSize() {
        let vm = makeViewModel(full: true, level: 10)
        vm.applyPurchase(.energyMedium, priceUSD: 2.99)
        XCTAssertTrue(boardCrates(vm).isEmpty, "nothing fits on the board")
        let stored = tiles(vm, level: .kibbleCrate, onBoard: false)
        XCTAssertEqual(stored.count, 1)
        XCTAssertEqual(stored.first?.chargesRemaining, 5)
        XCTAssertEqual(stored.first?.emitTier, 5)
        XCTAssertEqual(vm.kibbleEngine.kibble, 0)
    }

    func testOnAFullBoardBothXLCratesAreKept() {
        let vm = makeViewModel(full: true, level: 10)
        vm.applyPurchase(.energyXL, priceUSD: 9.99)
        XCTAssertEqual(tiles(vm, level: .kibbleCrate, onBoard: false).count, 2)
        XCTAssertEqual(tiles(vm, level: .fosterHome, onBoard: false).count, 2)
    }

    func testWithNowhereToPutACrateTheStatedKibbleIsCreditedNeverLess() {
        // Board full and every storage slot taken: only the purchase paths that bypass the
        // pre-purchase room check (a late "Ask to Buy" approval) can get here.
        let vm = makeViewModel(full: true, level: 10, freeOverflow: 0)
        vm.inventoryStore.producerStorage[ProducerLevel.kibbleCrate.rawValue] = ProducerTile(level: .kibbleCrate)
        vm.inventoryStore.producerStorage[ProducerLevel.rescueCrate.rawValue] = ProducerTile(level: .rescueCrate)
        vm.inventoryStore.recalcProducerStorageOccupied()
        vm.applyPurchase(.energySmall, priceUSD: 0.99)
        XCTAssertEqual(vm.kibbleEngine.kibble, 10 + IAPProduct.energySmall.energyPackContents!.kibble,
                       "10 for the Rescue Crate spawner as before, and the crate's whole raw value")
    }

    // MARK: The room check counts the crate

    func testAPackNeedsRoomForItsSpawnersAndItsCrates() {
        // Level 1: the Foster Home's own slot is locked, the crate's own slot is open.
        let none = makeViewModel(full: true, level: 1, freeOverflow: 0)
        none.inventoryStore.producerStorage[ProducerLevel.rescueCrate.rawValue] = ProducerTile(level: .rescueCrate)
        none.inventoryStore.producerStorage[ProducerLevel.kibbleCrate.rawValue] = ProducerTile(level: .kibbleCrate)
        none.inventoryStore.recalcProducerStorageOccupied()
        XCTAssertFalse(none.hasRoomForSpawners(of: .energySmall), "both own slots and all overflow slots are taken")

        // Small needs 2 (spawner + crate). With both own slots free that is already 2.
        let own = makeViewModel(full: true, level: 1, freeOverflow: 0)
        XCTAssertTrue(own.hasRoomForSpawners(of: .energySmall))
        // With the Rescue Crate's own slot taken, one overflow slot is the second place.
        let one = makeViewModel(full: true, level: 1, freeOverflow: 1)
        one.inventoryStore.producerStorage[ProducerLevel.rescueCrate.rawValue] = ProducerTile(level: .rescueCrate)
        one.inventoryStore.recalcProducerStorageOccupied()
        XCTAssertTrue(one.hasRoomForSpawners(of: .energySmall))
        let zero = makeViewModel(full: true, level: 1, freeOverflow: 0)
        zero.inventoryStore.producerStorage[ProducerLevel.rescueCrate.rawValue] = ProducerTile(level: .rescueCrate)
        zero.inventoryStore.recalcProducerStorageOccupied()
        XCTAssertFalse(zero.hasRoomForSpawners(of: .energySmall), "only the crate's own slot is left: 1 of 2")

        // XL needs 4 (2 Foster Homes + 2 crates): crate slot + 3 overflow.
        let two = makeViewModel(full: true, level: 1, freeOverflow: 2)
        XCTAssertFalse(two.hasRoomForSpawners(of: .energyXL))
        let three = makeViewModel(full: true, level: 1, freeOverflow: 3)
        XCTAssertTrue(three.hasRoomForSpawners(of: .energyXL))
    }

    func testTheRoomCountMatchesWhereAPacksProducersReallyGo() {
        let vm = makeViewModel(full: true, level: 1, freeOverflow: 3)
        XCTAssertTrue(vm.hasRoomForSpawners(of: .energyXL))
        vm.applyPurchase(.energyXL, priceUSD: 9.99)
        XCTAssertEqual(allCrates(vm).count, 2)
        XCTAssertEqual(tiles(vm, level: .fosterHome, onBoard: false).count, 2)
        // A $9.99 purchase also earns a VIP kibble perk, so compare with the same purchase on a
        // roomy board: a full board must add nothing (no kibble fallback).
        let control = makeViewModel(full: false, level: 1)
        control.applyPurchase(.energyXL, priceUSD: 9.99)
        XCTAssertEqual(vm.kibbleEngine.kibble, control.kibbleEngine.kibble, "nothing fell back to a kibble credit")
        XCTAssertFalse(vm.hasRoomForSpawners(of: .energySmall), "and now there is no room left")
    }
}
