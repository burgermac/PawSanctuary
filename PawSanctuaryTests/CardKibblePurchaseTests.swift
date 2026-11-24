//
//  CardKibblePurchaseTests.swift
//  PawSanctuaryTests
//
//  Rare cards bought with kibble (specs/Spec_CardsAndChests.md stage 1, §4.1, §5.1,
//  owner Q1-Q3, Q5, Q6, Q13). Dates are injected; nothing reads the wall clock.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class CardKibblePurchaseTests: XCTestCase {

    private let day1 = Date(timeIntervalSince1970: 1_800_000_000)

    private func makeViewModel(unlocked: Bool = true, kibble: Int = 500) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.cardInventory = [:]
        vm.completedAlbumIDs = []
        vm.claimedCollectionPrizeIDs = []
        vm.jokerCards = 0
        vm.rareJokerCards = 0
        vm.isPassActive = false
        vm.coins = 0
        vm.kibbleEngine.kibble = kibble
        vm.kibbleEngine.dogTags = 0
        vm.commerce.hasReachedFirstWall = unlocked
        vm.progression.playerLevel = unlocked ? monetizationUnlockLevel : 1
        return vm
    }

    // MARK: Purchase

    func testBuyingDeductsKibbleAndGrantsTheCard() throws {
        let vm = makeViewModel()
        let id = try XCTUnwrap(vm.offeredRareCardIDs(now: day1).first)
        XCTAssertTrue(vm.purchaseCardWithKibble(id, now: day1))
        XCTAssertEqual(vm.kibbleEngine.kibble, 500 - rareCardKibblePrice)
        XCTAssertEqual(vm.cardInventory[id], 1)
    }

    func testBuyingTheLastCardOfASetCompletesItAndPaysItsRung() throws {
        let vm = makeViewModel()
        let offered = vm.offeredRareCardIDs(now: day1)
        let id = try XCTUnwrap(offered.first)
        let album = try XCTUnwrap(CardRegistry.albums.first { $0.cardIDs.contains(id) })
        for card in album.cardIDs where card != id { vm.cardInventory[card] = 1 }
        let rung = vm.nextAlbumSetReward

        XCTAssertTrue(vm.purchaseCardWithKibble(id, now: day1))
        XCTAssertTrue(vm.completedAlbumIDs.contains(album.id))
        XCTAssertEqual(vm.kibbleEngine.kibble, 500 - rareCardKibblePrice + rung.kibble)
        XCTAssertEqual(vm.kibbleEngine.dogTags, rung.dogTags)
    }

    func testRefusesAnOwnedRare() throws {
        let vm = makeViewModel()
        let id = try XCTUnwrap(vm.offeredRareCardIDs(now: day1).first)
        vm.cardInventory[id] = 1
        XCTAssertFalse(vm.purchaseCardWithKibble(id, now: day1))
        XCTAssertEqual(vm.kibbleEngine.kibble, 500)
        XCTAssertEqual(vm.cardInventory[id], 1)
    }

    func testRefusesACommon() throws {
        let vm = makeViewModel()
        let common = try XCTUnwrap(CardRegistry.commonCards.first)
        XCTAssertFalse(vm.purchaseCardWithKibble(common.id, now: day1))
        XCTAssertEqual(vm.kibbleEngine.kibble, 500)
        XCTAssertNil(vm.cardInventory[common.id])
    }

    func testRefusesWhenUnaffordable() throws {
        let vm = makeViewModel(kibble: rareCardKibblePrice - 1)
        let id = try XCTUnwrap(vm.offeredRareCardIDs(now: day1).first)
        XCTAssertFalse(vm.purchaseCardWithKibble(id, now: day1))
        XCTAssertEqual(vm.kibbleEngine.kibble, rareCardKibblePrice - 1)
        XCTAssertNil(vm.cardInventory[id])
    }

    func testRefusesBeforeTheD7Gate() throws {
        let open = makeViewModel()
        let id = try XCTUnwrap(open.offeredRareCardIDs(now: day1).first)

        let vm = makeViewModel(unlocked: false)
        XCTAssertTrue(vm.offeredRareCardIDs(now: day1).isEmpty)
        XCTAssertFalse(vm.purchaseCardWithKibble(id, now: day1))
        XCTAssertEqual(vm.kibbleEngine.kibble, 500)

        // Level alone is not enough: the first wall must also have been felt.
        vm.progression.playerLevel = monetizationUnlockLevel
        XCTAssertFalse(vm.purchaseCardWithKibble(id, now: day1))
    }

    func testReportsTheSpendToKibbleSpendQuests() throws {
        let vm = makeViewModel()
        vm.quests.activeQuests = [
            Quest(goal: .spendCurrency(.kibble, count: 100), difficulty: .easy, dogTagReward: 1, kibbleReward: 1),
            Quest(goal: .spendCurrency(.dogTags, count: 100), difficulty: .easy, dogTagReward: 1, kibbleReward: 1),
        ]
        let id = try XCTUnwrap(vm.offeredRareCardIDs(now: day1).first)
        XCTAssertTrue(vm.purchaseCardWithKibble(id, now: day1))
        XCTAssertEqual(vm.quests.activeQuests[0].progress, rareCardKibblePrice)
        XCTAssertEqual(vm.quests.activeQuests[1].progress, 0)
    }

    // MARK: The rotating offer (Q3 b, Q13 a)

    func testOffersExactlyThreeMissingRaresAndRefusesTheRest() throws {
        let vm = makeViewModel()
        let offered = vm.offeredRareCardIDs(now: day1)
        XCTAssertEqual(offered.count, rareCardOffersPerDay)
        XCTAssertTrue(offered.allSatisfy { CardRegistry.cardsByID[$0]?.rarity == .rare })
        let notOffered = try XCTUnwrap(CardRegistry.rareCards.map(\.id).first { !offered.contains($0) })
        XCTAssertFalse(vm.purchaseCardWithKibble(notOffered, now: day1))
        XCTAssertEqual(vm.kibbleEngine.kibble, 500)
    }

    func testTheOfferIsStableWithinADayAndRotatesAcrossDays() {
        let vm = makeViewModel()
        XCTAssertEqual(vm.offeredRareCardIDs(now: day1), vm.offeredRareCardIDs(now: day1.addingTimeInterval(60)))
        // Across a month the offer must change at least once.
        let sets = (0..<30).map { n -> [String] in
            let d = Calendar.current.date(byAdding: .day, value: n, to: day1) ?? day1
            return vm.offeredRareCardIDs(now: d)
        }
        XCTAssertGreaterThan(Set(sets.map { $0.joined(separator: ",") }).count, 1)
    }

    func testABoughtCardIsReplacedAtOnceByTheNextUnownedOne() throws {
        let vm = makeViewModel()
        let before = vm.offeredRareCardIDs(now: day1)
        let bought = try XCTUnwrap(before.first)
        XCTAssertTrue(vm.purchaseCardWithKibble(bought, now: day1))
        let after = vm.offeredRareCardIDs(now: day1)
        XCTAssertEqual(after.count, rareCardOffersPerDay)
        XCTAssertFalse(after.contains(bought))
        XCTAssertEqual(Array(after.prefix(2)), Array(before.dropFirst()))
    }

    func testTheOfferShrinksWhenFewerThanThreeRaresRemain() {
        let vm = makeViewModel()
        let all = CardRegistry.rareCards.map(\.id)
        for id in all.dropFirst(2) { vm.cardInventory[id] = 1 }
        XCTAssertEqual(vm.offeredRareCardIDs(now: day1).count, 2)
    }

    // MARK: Economy (Spec §5.1)

    func testTheAlbumStillPaysThePlayer() {
        // The sink is at most the reference's upper estimate, 1,500 of 4,350 (35%).
        XCTAssertLessThanOrEqual(EconomySimulation.albumCardKibbleSinkPerDay,
                                 0.35 * EconomySimulation.albumKibblePerDay)
    }

    func testTheCardSinkIsAMinorDemand() {
        XCTAssertLessThan(EconomySimulation.albumCardKibbleSinkPerDay,
                          0.02 * Double(EconomySimulation.dailySupply(level: 5)))
    }
}
