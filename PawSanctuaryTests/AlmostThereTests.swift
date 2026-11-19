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

    // MARK: Judged against the board (D14)
    //
    // `fulfilled` no longer advances as items are produced, so the stored
    // `isAlmostThere` cannot fire in play; the nudge is judged against what the
    // board holds. The order card still reads the stored property until task 1.4
    // (card UI) switches it over.

    private func census(_ held: [(ChainID, Int, Int)]) -> [ChainTierKey: Int] {
        Dictionary(uniqueKeysWithValues: held.map { (ChainTierKey(chainID: $0.0, tier: $0.1), $0.2) })
    }

    func testHoldingAllButOneItemTurnsTheNudgeOn() {
        let order = basket([(dog, 3, 1, 0), (cat, 2, 1, 0)])
        XCTAssertFalse(order.isAlmostThere(census: [:]), "two short")
        XCTAssertTrue(order.isAlmostThere(census: census([(dog, 3, 1)])), "one short")
        XCTAssertFalse(order.isAlmostThere(census: census([(dog, 3, 1), (cat, 2, 1)])),
                       "everything held is ready, not almost there")
    }

    func testASingleItemOrderNeverNudgesFromTheBoard() {
        XCTAssertFalse(basket([(dog, 3, 1, 0)]).isAlmostThere(census: [:]))
    }

    func testAClaimedOrderNeverNudgesFromTheBoard() {
        var order = basket([(dog, 3, 1, 0), (cat, 2, 1, 0)])
        order.isClaimed = true
        XCTAssertFalse(order.isAlmostThere(census: census([(dog, 3, 1)])))
    }
}
