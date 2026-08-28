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

    // MARK: Generation (schema v37)

    private func generate(slot: Int, level: Int = 45, samples: Int = 300) -> [AdoptionOrder] {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        return (0..<samples).map { _ in
            board.generateOrder(unlockedChainIDs: chains, playerLevel: level, forSlot: slot)
        }
    }

    func testBasketSizeFollowsTheSlotDifficulty() {
        // Slot pattern is easy / medium / medium / hard.
        let easy = generate(slot: 0).map(\.lines.count)
        XCTAssertTrue(easy.allSatisfy { $0 == 1 }, "the easy slot stays a single ask")

        let medium = Set(generate(slot: 1).map(\.lines.count))
        XCTAssertTrue(medium.isSubset(of: [1, 2]), "medium rolls 1-2 lines, saw \(medium)")
        XCTAssertEqual(medium, [1, 2], "over 300 samples medium should show both sizes")

        let hard = Set(generate(slot: 3).map(\.lines.count))
        XCTAssertTrue(hard.isSubset(of: [2, 3]), "hard rolls 2-3 lines, saw \(hard)")
        XCTAssertEqual(hard, [2, 3], "over 300 samples hard should show both sizes")
    }

    func testOnlySingleLineOrdersEverAskForTwoOfTheSameItem() {
        for order in generate(slot: 3) + generate(slot: 1) where order.lines.count > 1 {
            XCTAssertTrue(order.lines.allSatisfy { $0.count == 1 },
                          "a basket asks for one of each; stacking would compound two multipliers")
        }
    }

    func testFillerLinesDrawFromAnEasierBandThanTheHeadline() {
        // Hard's own band starts at tier 4; its filler band (medium) is tiers 2-3.
        for order in generate(slot: 3) where order.lines.count > 1 {
            for line in order.lines.dropFirst() {
                XCTAssertLessThanOrEqual(line.tier, 3,
                                         "filler lines draw the medium band, saw tier \(line.tier)")
            }
        }
    }

    func testEveryGeneratedOrderHasAtLeastOneLine() {
        for slot in 0..<4 {
            for order in generate(slot: slot, samples: 100) {
                XCTAssertFalse(order.lines.isEmpty)
                XCTAssertFalse(order.isComplete, "a freshly generated order is never already complete")
            }
        }
    }

    func testGeneratedTiersRespectTheLevelCap() {
        let cap = maxAchievableOrderTier(forPlayerLevel: 12)
        for slot in 0..<4 {
            for order in generate(slot: slot, level: 12, samples: 100) {
                for line in order.lines {
                    XCTAssertLessThanOrEqual(line.tier, cap,
                                             "every line is capped, not just the headline")
                }
            }
        }
    }

    func testBasketsDoSpanChains() {
        // Not guaranteed per-order (each line picks independently, so a basket may
        // land on one chain by chance), but across 300 hard orders it must happen.
        let sawMixedChains = generate(slot: 3).contains { order in
            Set(order.lines.map(\.chainID)).count > 1
        }
        XCTAssertTrue(sawMixedChains, "basket lines pick chains independently — a mix must occur")
    }

    func testBoardItemRewardKeysOffTheDeepestLine() {
        for order in generate(slot: 3) {
            guard let reward = order.rewards.first(where: { $0.kind == .boardItem }),
                  let tier = reward.payloadTier else { continue }
            let deepest = order.lines.map(\.tier).max() ?? 0
            XCTAssertLessThanOrEqual(tier, max(0, deepest - orderRewardTierOffset),
                                     "the recirculated item stays well below the order's headline ask")
        }
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
