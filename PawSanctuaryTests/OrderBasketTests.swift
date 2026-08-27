//
//  OrderBasketTests.swift
//  PawSanctuaryTests
//
//  Covers `AdoptionOrder`'s basket shape (schema v37) and the fulfilment path
//  that credits it — `AdoptionBoard.updateAfterMerge` /
//  `updateUrgentOrderAfterMerge`.
//
//  That fulfilment path had no unit coverage before this file: it was only
//  exercised indirectly through view-model tests, which is why the basket
//  reshape needed tests written alongside it rather than after.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class OrderBasketTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }

    private func makeBoard(orders: [AdoptionOrder]) -> AdoptionBoard {
        let board = AdoptionBoard()
        board.adoptionOrders = orders
        return board
    }

    // MARK: Single-line orders behave exactly as they did pre-v37

    func testSingleLineOrderCompletesOnTheExpectedDelivery() {
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 2),
        ])

        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [],
                       "one of two delivered is not yet complete")
        XCTAssertEqual(board.adoptionOrders[0].fulfilled, 1)
        XCTAssertFalse(board.adoptionOrders[0].isComplete)

        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [0],
                       "the second delivery completes it")
        XCTAssertTrue(board.adoptionOrders[0].isComplete)
    }

    func testNonMatchingDeliveryIsIgnored() {
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1),
        ])
        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 4), [], "wrong tier")
        XCTAssertEqual(board.updateAfterMerge(chainID: cat, tier: 3), [], "wrong chain")
        XCTAssertEqual(board.adoptionOrders[0].fulfilled, 0)
    }

    func testAnOrderNeverOverfills() {
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1),
        ])
        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [0])
        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [],
                       "a complete order must not report completion twice")
        XCTAssertEqual(board.adoptionOrders[0].fulfilled, 1)
    }

    // MARK: Baskets

    func testBasketNeedsEveryLineBeforeItCompletes() {
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, lines: [
                OrderLine(chainID: dog, tier: 2, count: 1),
                OrderLine(chainID: cat, tier: 5, count: 1),
            ]),
        ])

        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 2), [],
                       "one line filled is not the whole basket")
        XCTAssertFalse(board.adoptionOrders[0].isComplete)
        XCTAssertEqual(board.adoptionOrders[0].progressFraction, 0.5, accuracy: 0.001)

        XCTAssertEqual(board.updateAfterMerge(chainID: cat, tier: 5), [0],
                       "filling the last line completes the basket")
        XCTAssertTrue(board.adoptionOrders[0].isComplete)
    }

    func testBasketLinesMaySpanChainsAndTiersIndependently() {
        let order = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 1, count: 1),
            OrderLine(chainID: cat, tier: 7, count: 2),
        ])
        XCTAssertTrue(order.wants(chainID: dog, tier: 1))
        XCTAssertTrue(order.wants(chainID: cat, tier: 7))
        XCTAssertFalse(order.wants(chainID: dog, tier: 7), "chain and tier must match together")
        XCTAssertFalse(order.wants(chainID: cat, tier: 1))
        XCTAssertEqual(order.wantedCount, 3, "demand sums across lines")
    }

    /// A basket listing the same item as two separate lines must still consume
    /// two of them — one delivery may only ever credit one line.
    func testOneDeliveryCreditsOnlyOneLineEvenWhenTwoLinesMatch() {
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, lines: [
                OrderLine(chainID: dog, tier: 3, count: 1),
                OrderLine(chainID: dog, tier: 3, count: 1),
            ]),
        ])

        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [])
        XCTAssertEqual(board.adoptionOrders[0].lines[0].fulfilled, 1)
        XCTAssertEqual(board.adoptionOrders[0].lines[1].fulfilled, 0,
                       "the second identical line must still be owed")

        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [0])
        XCTAssertEqual(board.adoptionOrders[0].lines[1].fulfilled, 1)
    }

    func testDeliveriesFillEachLineToItsOwnCount() {
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, lines: [
                OrderLine(chainID: dog, tier: 2, count: 2),
                OrderLine(chainID: cat, tier: 4, count: 1),
            ]),
        ])
        for _ in 0..<2 { _ = board.updateAfterMerge(chainID: dog, tier: 2) }
        XCTAssertEqual(board.adoptionOrders[0].lines[0].fulfilled, 2)
        XCTAssertFalse(board.adoptionOrders[0].isComplete, "the cat line is still owed")

        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 2), [],
                       "a filled line must not absorb further deliveries")
        XCTAssertEqual(board.adoptionOrders[0].lines[0].fulfilled, 2)

        XCTAssertEqual(board.updateAfterMerge(chainID: cat, tier: 4), [0])
    }

    func testClaimedOrdersAreSkipped() {
        var claimed = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        claimed.isClaimed = true
        let board = makeBoard(orders: [claimed])
        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [])
        XCTAssertEqual(board.adoptionOrders[0].fulfilled, 0)
    }

    func testSeveralOrdersWantingTheSameItemAllAdvanceOnOneDelivery() {
        // Matches the pre-v37 behaviour: `updateAfterMerge` credits every
        // matching order, not just the first. One merged animal satisfying two
        // separate customers is deliberate.
        let board = makeBoard(orders: [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1),
            AdoptionOrder(familyIndex: 1, wantedChainID: dog, wantedTier: 3, wantedCount: 1),
        ])
        XCTAssertEqual(board.updateAfterMerge(chainID: dog, tier: 3), [0, 1])
    }

    // MARK: Empty basket

    func testAnEmptyBasketIsNeverComplete() {
        let order = AdoptionOrder(familyIndex: 0, lines: [])
        XCTAssertFalse(order.isComplete,
                       "an empty basket must not read as claimable — it would pay out for free")
        XCTAssertEqual(order.progressFraction, 0)
        XCTAssertEqual(order.wantedCount, 0)
    }

    // MARK: Urgent order

    func testUrgentOrderBasketCompletesOnlyWhenEveryLineIsFilled() {
        let board = AdoptionBoard()
        board.urgentOrder = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 2, count: 1),
            OrderLine(chainID: cat, tier: 3, count: 1),
        ])
        board.urgentOrderTimeRemaining = 600

        XCTAssertFalse(board.updateUrgentOrderAfterMerge(chainID: dog, tier: 2))
        XCTAssertTrue(board.updateUrgentOrderAfterMerge(chainID: cat, tier: 3))
        XCTAssertTrue(try XCTUnwrap(board.urgentOrder).isComplete)
    }

    func testUrgentOrderIgnoresDeliveriesOnceItsTimerHasExpired() {
        let board = AdoptionBoard()
        board.urgentOrder = AdoptionOrder(familyIndex: 0, wantedChainID: dog,
                                          wantedTier: 2, wantedCount: 1)
        board.urgentOrderTimeRemaining = 0

        XCTAssertFalse(board.updateUrgentOrderAfterMerge(chainID: dog, tier: 2))
        XCTAssertEqual(board.urgentOrder?.fulfilled, 0)
    }

    // MARK: Description

    func testOrderDescriptionListsEveryLine() {
        let single = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 0, wantedCount: 1)
        XCTAssertFalse(single.orderDescription.contains("+"),
                       "a one-line order reads as a plain phrase, as it did pre-v37")

        let basket = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 0, count: 1),
            OrderLine(chainID: cat, tier: 0, count: 2),
        ])
        XCTAssertTrue(basket.orderDescription.contains("+"),
                      "a basket joins its lines: \(basket.orderDescription)")
    }
}
