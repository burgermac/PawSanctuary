//
//  AlmostThereTests.swift
//  PawSanctuaryTests
//
//  The "Almost there!" nudge (Spec_TravelTownReview_Draft.md §5): a basket with
//  exactly one item still owed. Single-item, finished and claimed orders never
//  nudge.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class AlmostThereTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }

    private func basket(_ lines: [(ChainID, Int, Int, Int)]) -> AdoptionOrder {
        var order = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        order.lines = lines.map { OrderLine(chainID: $0.0, tier: $0.1, count: $0.2, fulfilled: $0.3) }
        return order
    }

    func testOneItemShortOfATwoItemBasketNudges() {
        XCTAssertTrue(basket([(dog, 3, 1, 1), (cat, 2, 1, 0)]).isAlmostThere)
    }

    func testOneItemShortOfARepeatedLineNudges() {
        XCTAssertTrue(basket([(dog, 3, 3, 2)]).isAlmostThere)
    }

    func testTwoItemsShortDoesNot() {
        XCTAssertFalse(basket([(dog, 3, 3, 1)]).isAlmostThere)
        XCTAssertFalse(basket([(dog, 3, 1, 0), (cat, 2, 1, 0)]).isAlmostThere)
    }

    func testASingleItemOrderNeverNudges() {
        XCTAssertFalse(basket([(dog, 3, 1, 0)]).isAlmostThere)
    }

    func testACompleteOrderDoesNot() {
        XCTAssertFalse(basket([(dog, 3, 1, 1), (cat, 2, 1, 1)]).isAlmostThere)
    }

    func testAClaimedOrderDoesNot() {
        var order = basket([(dog, 3, 1, 1), (cat, 2, 1, 0)])
        order.isClaimed = true
        XCTAssertFalse(order.isAlmostThere)
    }

    func testDeliveringTheLastButOneItemTurnsTheNudgeOn() {
        let board = AdoptionBoard()
        board.adoptionOrders = [basket([(dog, 3, 1, 0), (cat, 2, 1, 0)])]
        XCTAssertFalse(board.adoptionOrders[0].isAlmostThere)
        _ = board.updateAfterMerge(chainID: dog, tier: 3)
        XCTAssertTrue(board.adoptionOrders[0].isAlmostThere)
        _ = board.updateAfterMerge(chainID: cat, tier: 2)
        XCTAssertFalse(board.adoptionOrders[0].isAlmostThere, "complete now")
    }
}
