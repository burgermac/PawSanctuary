//
//  OrderBasketTests.swift
//  PawSanctuaryTests
//
//  Covers `AdoptionOrder`'s basket shape (schema v37) and how a basket is judged
//  against the board under D14 (Spec_HeldItemOrders.md): `heldState(census:)`,
//  `isReady(census:)`, `markDelivered()`.
//
//  These tests originally pinned the D12 credit path
//  (`AdoptionBoard.updateAfterMerge` / `updateUrgentOrderAfterMerge`), which
//  advanced `fulfilled` a line at a time as merges produced items. That path is
//  gone: an order is filled by what the board HOLDS, so the same behaviours are
//  now checked against a census. Delivery itself (items leave the board, rewards
//  paid) is covered by `OrderFulfilmentRuleTests`.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class OrderBasketTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }

    private func census(_ held: [(ChainID, Int, Int)]) -> [ChainTierKey: Int] {
        var result: [ChainTierKey: Int] = [:]
        for (chain, tier, count) in held {
            result[ChainTierKey(chainID: chain, tier: tier), default: 0] += count
        }
        return result
    }

    // MARK: Single-line orders

    func testSingleLineOrderOfTwoIsReadyOnlyWithTwoHeld() {
        let order = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 2)

        XCTAssertFalse(order.isReady(census: census([(dog, 3, 1)])),
                       "one of two held is not ready")
        XCTAssertEqual(order.heldState(census: census([(dog, 3, 1)])).heldLines, [false])
        XCTAssertTrue(order.isReady(census: census([(dog, 3, 2)])),
                      "two held makes it ready")
        XCTAssertTrue(order.isReady(census: census([(dog, 3, 5)])), "spares do no harm")
    }

    func testNonMatchingItemsAreIgnored() {
        let order = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        XCTAssertFalse(order.isReady(census: census([(dog, 4, 1)])), "wrong tier")
        XCTAssertFalse(order.isReady(census: census([(cat, 3, 1)])), "wrong chain")
        XCTAssertEqual(order.fulfilled, 0)
    }

    func testADeliveredOrderIsNeverReadyAgain() {
        var order = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        order.markDelivered()
        XCTAssertTrue(order.isComplete, "complete now means delivered")
        XCTAssertTrue(order.isClaimed)
        XCTAssertEqual(order.fulfilled, 1)
        XCTAssertFalse(order.isReady(census: census([(dog, 3, 1)])),
                       "a delivered order must not report ready twice")
    }

    // MARK: Baskets

    func testBasketNeedsEveryLineHeldBeforeItIsReady() {
        let order = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 2, count: 1),
            OrderLine(chainID: cat, tier: 5, count: 1),
        ])

        let partHeld = order.heldState(census: census([(dog, 2, 1)]))
        XCTAssertEqual(partHeld.heldLines, [true, false])
        XCTAssertFalse(partHeld.isReady, "one line held is not the whole basket")

        let allHeld = order.heldState(census: census([(dog, 2, 1), (cat, 5, 1)]))
        XCTAssertEqual(allHeld.heldLines, [true, true])
        XCTAssertTrue(allHeld.isReady, "holding the last line readies the basket")
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
        XCTAssertEqual(order.wantedCounts[ChainTierKey(chainID: cat, tier: 7)], 2)
    }

    /// A basket listing the same item as two separate lines must still need two
    /// of them held: one copy may only ever cover one line.
    func testTwoLinesOfOneItemNeedTwoCopiesHeld() {
        let order = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 3, count: 1),
            OrderLine(chainID: dog, tier: 3, count: 1),
        ])
        XCTAssertEqual(order.wantedCounts[ChainTierKey(chainID: dog, tier: 3)], 2)

        let one = order.heldState(census: census([(dog, 3, 1)]))
        XCTAssertEqual(one.heldLines, [true, false], "the second identical line is still owed")
        XCTAssertFalse(one.isReady)

        XCTAssertTrue(order.isReady(census: census([(dog, 3, 2)])))
    }

    func testEachLineIsHeldAgainstItsOwnCount() {
        let order = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 2, count: 2),
            OrderLine(chainID: cat, tier: 4, count: 1),
        ])
        let state = order.heldState(census: census([(dog, 2, 2)]))
        XCTAssertEqual(state.heldLines, [true, false], "the dog line is held, the cat line is still owed")
        XCTAssertFalse(state.isReady)
        XCTAssertEqual(order.missingCount(census: census([(dog, 2, 2)])), 1)

        XCTAssertTrue(order.isReady(census: census([(dog, 2, 2), (cat, 4, 1)])))
    }

    func testAClaimedOrderHoldsNothing() {
        var claimed = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        claimed.isClaimed = true
        let state = claimed.heldState(census: census([(dog, 3, 1)]))
        XCTAssertEqual(state.heldLines, [false])
        XCTAssertFalse(state.isReady)
    }

    func testSeveralOrdersWantingTheSameItemAreEachReadyFromOneCopy() {
        // Q18 b: each card checks the board on its own; whichever is delivered
        // first takes the copy (see OrderFulfilmentRuleTests).
        let held = census([(dog, 3, 1)])
        let a = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        let b = AdoptionOrder(familyIndex: 1, wantedChainID: dog, wantedTier: 3, wantedCount: 1)
        XCTAssertTrue(a.isReady(census: held))
        XCTAssertTrue(b.isReady(census: held))
    }

    func testMarkDeliveredFillsEveryLineToItsCount() {
        var order = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 2, count: 2),
            OrderLine(chainID: cat, tier: 4, count: 1),
        ])
        order.markDelivered()
        XCTAssertEqual(order.lines.map(\.fulfilled), [2, 1])
        XCTAssertTrue(order.isComplete)
        XCTAssertTrue(order.isClaimed)
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

    func testUrgentOrderBasketIsReadyOnlyWhenEveryLineIsHeld() {
        let board = AdoptionBoard()
        board.urgentOrder = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 2, count: 1),
            OrderLine(chainID: cat, tier: 3, count: 1),
        ])
        board.urgentOrderTimeRemaining = 600
        let urgent = try? XCTUnwrap(board.urgentOrder)

        XCTAssertEqual(urgent?.isReady(census: census([(dog, 2, 1)])), false)
        XCTAssertEqual(urgent?.isReady(census: census([(dog, 2, 1), (cat, 3, 1)])), true)
    }

    func testTheUrgentTimerKeepsRunningWhileTheOrderIsOnlyHeld() {
        // D14: its timer runs until delivery, not until it is filled. `fulfilled`
        // stays 0, so the order is not complete and `tickUrgentOrder` keeps counting.
        let board = AdoptionBoard()
        board.urgentOrder = AdoptionOrder(familyIndex: 0, wantedChainID: dog,
                                          wantedTier: 2, wantedCount: 1)
        board.urgentOrderTimeRemaining = 600
        XCTAssertTrue(board.urgentOrder?.isReady(census: census([(dog, 2, 1)])) ?? false)

        board.tickUrgentOrder(unlockedChainIDs: [dog], playerLevel: 1)
        XCTAssertEqual(board.urgentOrderTimeRemaining, 599)
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
