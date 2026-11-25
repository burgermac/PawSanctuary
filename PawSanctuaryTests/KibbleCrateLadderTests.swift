//
//  KibbleCrateLadderTests.swift
//  PawSanctuaryTests
//
//  Cards and chests stage 4 (specs/Spec_CardsAndChests.md §4.2, §8, owner Q7, Q10, Q12):
//  the Dog Tag kibble ladder gains Kibble Crate rungs. The 3rd purchase of the day and
//  every second one after the 4th put a crate on the board (else producer storage, else
//  nothing is charged); every other rung credits kibble as before. No schema change.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleCrateLadderTests: XCTestCase {

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Helpers

    private func makeViewModel(tags: Int = 1_000) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.kibbleEngine.dogTags = tags
        vm.kibbleEngine.kibble = 0
        vm.kibbleEngine.dogTagExchangesToday = 0
        vm.kibbleEngine.lastExchangeResetDate = Date()
        vm.progression.playerLevel = 1
        vm.inventoryStore.producerStorage = [:]
        vm.inventoryStore.overflowProducerStorage = Array(repeating: nil, count: totalProducerOverflowSlots)
        return vm
    }

    private func crates(_ vm: MergeBoardViewModel) -> [ProducerTile] {
        var found: [ProducerTile] = []
        for row in vm.board {
            for cell in row {
                if let p = cell.producer, p.level == .kibbleCrate { found.append(p) }
            }
        }
        return found
    }

    private func fillBoard(_ vm: MergeBoardViewModel) {
        let dog = ContentRegistry.animalChainID(.dog)
        for row in vm.board {
            for cell in row {
                vm.boardState.setItem(BoardItem(chainID: dog, tier: 0), at: cell.position)
            }
        }
        vm.boardState.recalc()
    }

    // MARK: The ladder's shape

    func testTheLadderReadsCreditCreditCrateThenAlternates() {
        let kinds = (0..<9).map { DogTagKibbleExchange.offer(purchasesToday: $0).isCrate }
        XCTAssertEqual(kinds, [false, false, true, false, true, false, true, false, true])
    }

    func testTheRungPrices() {
        let costs = (0..<8).map { DogTagKibbleExchange.offer(purchasesToday: $0).dogTagCost }
        XCTAssertEqual(costs, [15, 30, 36, 60, 72, 60, 72, 60])
    }

    func testACrateRungAdvertisesTheCratesRawKibble() {
        let crate = DogTagKibbleExchange.offer(purchasesToday: 2)
        XCTAssertEqual(crate.kibbleGain, 120)
        XCTAssertEqual(crate.rewardLabel, "Kibble Crate ×8")
        XCTAssertEqual(DogTagKibbleExchange.offer(purchasesToday: 0).rewardLabel, "+100 Kibble")
    }

    // MARK: Buying a crate rung

    func testTheFirstTwoRungsStillCreditKibbleAndPlaceNoCrate() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.kibble, 200)
        XCTAssertEqual(vm.kibbleEngine.dogTags, 1_000 - 15 - 30)
        XCTAssertTrue(crates(vm).isEmpty)
    }

    func testTheThirdRungPlacesAFullCrateAndCreditsNoKibble() {
        let vm = makeViewModel()
        _ = vm.exchangeTagsForKibble()
        _ = vm.exchangeTagsForKibble()
        let tagsBefore = vm.kibbleEngine.dogTags
        let kibbleBefore = vm.kibbleEngine.kibble
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore - 36)
        XCTAssertEqual(vm.kibbleEngine.kibble, kibbleBefore, "the kibble arrives as pieces, not as a credit")
        XCTAssertEqual(crates(vm).count, 1)
        XCTAssertEqual(crates(vm).first?.chargesRemaining, 8)
        XCTAssertEqual(vm.kibbleEngine.dogTagExchangesToday, 3, "the counter advances once per purchase")
    }

    func testTheFourthRungCreditsAgainAndTheFifthIsACrate() {
        let vm = makeViewModel()
        for _ in 0..<3 { _ = vm.exchangeTagsForKibble() }
        let kibbleBefore = vm.kibbleEngine.kibble
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.kibble, kibbleBefore + 100)
        XCTAssertEqual(crates(vm).count, 1)
        let tagsBefore = vm.kibbleEngine.dogTags
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore - 72)
        XCTAssertEqual(crates(vm).count, 2)
    }

    func testACrateRungRefusesWhenTagsAreShort() {
        let vm = makeViewModel(tags: 35)
        vm.kibbleEngine.dogTagExchangesToday = 2
        XCTAssertFalse(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.dogTags, 35)
        XCTAssertEqual(vm.kibbleEngine.dogTagExchangesToday, 2)
        XCTAssertTrue(crates(vm).isEmpty)
    }

    // MARK: Where a bought crate lands (Q10 a)

    func testAFullBoardStoresTheCrateInItsDesignatedSlot() {
        let vm = makeViewModel()
        vm.kibbleEngine.dogTagExchangesToday = 2
        fillBoard(vm)
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertTrue(crates(vm).isEmpty)
        XCTAssertEqual(vm.producerStorage[ProducerLevel.kibbleCrate.rawValue]?.level, .kibbleCrate)
        XCTAssertEqual(vm.kibbleEngine.dogTags, 1_000 - 36)
        XCTAssertEqual(vm.kibbleEngine.dogTagExchangesToday, 3)
    }

    func testAFullBoardAndOccupiedDesignatedSlotUseAnOverflowSlot() {
        let vm = makeViewModel()
        vm.kibbleEngine.dogTagExchangesToday = 2
        fillBoard(vm)
        vm.inventoryStore.producerStorage[ProducerLevel.kibbleCrate.rawValue] = ProducerTile(level: .kibbleCrate)
        XCTAssertTrue(vm.exchangeTagsForKibble())
        var overflowCrates = 0
        for slot in vm.inventoryStore.overflowProducerStorage where slot?.level == .kibbleCrate { overflowCrates += 1 }
        XCTAssertEqual(overflowCrates, 1)
    }

    func testAFullBoardAndFullStorageChargeNothing() {
        let vm = makeViewModel()
        vm.kibbleEngine.dogTagExchangesToday = 2
        fillBoard(vm)
        vm.inventoryStore.producerStorage[ProducerLevel.kibbleCrate.rawValue] = ProducerTile(level: .kibbleCrate)
        for i in vm.inventoryStore.overflowProducerStorage.indices {
            vm.inventoryStore.overflowProducerStorage[i] = ProducerTile(level: .kibbleCrate)
        }
        XCTAssertFalse(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.dogTags, 1_000, "no tags are taken")
        XCTAssertEqual(vm.kibbleEngine.dogTagExchangesToday, 2, "the ladder does not advance")
    }

    func testACreditRungStillWorksOnAFullBoard() {
        let vm = makeViewModel()
        fillBoard(vm)
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.kibble, 100)
    }

    // MARK: Daily reset

    func testTheLadderStartsAgainTomorrow() {
        let vm = makeViewModel()
        vm.kibbleEngine.dogTagExchangesToday = 5
        vm.kibbleEngine.lastExchangeResetDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        XCTAssertEqual(vm.currentTagExchange.dogTagCost, 15, "yesterday's counter reads as 0")
        XCTAssertTrue(vm.exchangeTagsForKibble())
        XCTAssertEqual(vm.kibbleEngine.dogTagExchangesToday, 1)
        XCTAssertEqual(vm.kibbleEngine.kibble, 100)
    }

    // MARK: Quests (owner Q12)

    func testTheLadderReportsItsTagSpendToQuests() {
        let vm = makeViewModel()
        vm.quests.activeQuests = [
            Quest(goal: .spendCurrency(.dogTags, count: 100), difficulty: .easy, dogTagReward: 1, kibbleReward: 1)
        ]
        _ = vm.exchangeTagsForKibble()
        XCTAssertEqual(vm.quests.activeQuests.first?.progress, 15)
        vm.kibbleEngine.dogTagExchangesToday = 2
        _ = vm.exchangeTagsForKibble()
        XCTAssertEqual(vm.quests.activeQuests.first?.progress, 15 + 36, "a crate rung reports too")
    }

    func testAFailedCrateRungReportsNoSpend() {
        let vm = makeViewModel()
        vm.kibbleEngine.dogTagExchangesToday = 2
        fillBoard(vm)
        vm.inventoryStore.producerStorage[ProducerLevel.kibbleCrate.rawValue] = ProducerTile(level: .kibbleCrate)
        for i in vm.inventoryStore.overflowProducerStorage.indices {
            vm.inventoryStore.overflowProducerStorage[i] = ProducerTile(level: .kibbleCrate)
        }
        vm.quests.activeQuests = [
            Quest(goal: .spendCurrency(.dogTags, count: 100), difficulty: .easy, dogTagReward: 1, kibbleReward: 1)
        ]
        _ = vm.exchangeTagsForKibble()
        XCTAssertEqual(vm.quests.activeQuests.first?.progress, 0)
    }
}
