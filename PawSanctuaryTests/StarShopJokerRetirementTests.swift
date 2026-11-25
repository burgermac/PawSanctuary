//
//  StarShopJokerRetirementTests.swift
//  PawSanctuaryTests
//
//  Cards and chests stage 2 (specs/Spec_CardsAndChests.md §4.1 item 6, §8, owner Q4 (c)):
//  the Star Shop stops selling the common Joker and keeps the Rare Joker. Balances
//  already held stay usable through `useJoker`. No save change.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class StarShopJokerRetirementTests: XCTestCase {

    private func makeViewModel(stars: Int = 1_000) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.cardInventory = [:]
        vm.completedAlbumIDs = []
        vm.claimedCollectionPrizeIDs = []
        vm.jokerCards = 0
        vm.rareJokerCards = 0
        vm.pendingCardPacks = []
        vm.starCount = stars
        return vm
    }

    private func firstCardID(_ rarity: CardRarity) throws -> String {
        try XCTUnwrap(CardRegistry.allCards.first { $0.rarity == rarity }?.id)
    }

    // MARK: What the shop sells

    func testTheShopSellsThePacksAndTheRareJokerOnly() {
        XCTAssertEqual(Set(StarShopItem.allCases.map(\.rawValue)),
                       ["pack1Star", "pack2Star", "pack3Star", "rareJokerCard"])
    }

    func testNoShopItemDescribesAFillForCommons() {
        for item in StarShopItem.allCases {
            XCTAssertFalse(item.description.contains("common"),
                           "\(item.displayName) still talks about commons")
        }
    }

    func testTheRareJokerStillCostsStarsAndGrantsARareJoker() {
        let vm = makeViewModel(stars: 500)
        vm.buyFromStarShop(.rareJokerCard)
        XCTAssertEqual(vm.starCount, 500 - StarShopItem.rareJokerCard.starCost)
        XCTAssertEqual(vm.rareJokerCards, 1)
        XCTAssertEqual(vm.jokerCards, 0)
    }

    func testBuyingAnythingInTheShopNeverGrantsACommonJoker() {
        let vm = makeViewModel()
        for item in StarShopItem.allCases { vm.buyFromStarShop(item) }
        XCTAssertEqual(vm.jokerCards, 0)
    }

    // MARK: Held balances keep working

    func testAHeldCommonJokerStillFillsAMissingCommon() throws {
        let vm = makeViewModel()
        let id = try firstCardID(.common)
        vm.jokerCards = 2
        vm.useJoker(for: id)
        XCTAssertEqual(vm.cardInventory[id], 1)
        XCTAssertEqual(vm.jokerCards, 1)
    }

    func testAHeldRareJokerStillFillsAMissingRare() throws {
        let vm = makeViewModel()
        let id = try firstCardID(.rare)
        vm.rareJokerCards = 1
        vm.useJoker(for: id)
        XCTAssertEqual(vm.cardInventory[id], 1)
        XCTAssertEqual(vm.rareJokerCards, 0)
    }

    func testAJokerIsNotSpentOnACardAlreadyOwned() throws {
        let vm = makeViewModel()
        let id = try firstCardID(.common)
        vm.cardInventory[id] = 1
        vm.jokerCards = 1
        vm.useJoker(for: id)
        XCTAssertEqual(vm.jokerCards, 1)
    }

    func testACommonJokerCannotFillARare() throws {
        let vm = makeViewModel()
        let id = try firstCardID(.rare)
        vm.jokerCards = 3
        vm.useJoker(for: id)
        XCTAssertNil(vm.cardInventory[id])
        XCTAssertEqual(vm.jokerCards, 3)
    }
}
