//
//  OrderFulfilmentRuleTests.swift
//  PawSanctuaryTests
//
//  Pins D12 (Alignment Plan): an adoption order is fulfilled only as a side
//  effect of a producer spawn or a merge producing the wanted item. An item
//  that merely sits on the board, or that arrives some other way (a Dog Tag
//  store purchase, a chest, a reward), does nothing for an order asking for
//  that same chain and tier.
//
//  The rule was originally recorded only in a doc comment in
//  `MergeBoardViewModel.swift` (the one beginning "Chain/tier pairs the player
//  could produce with one merge", now sitting above `boardTaskCensus`).
//  Nothing exercised it, and the only
//  test that calls `purchaseDogTagStoreSlot` (`SpendQuotaDailiesTests`) checks
//  the spend counter, not orders. These tests fail if a later change makes a
//  purchase (or a held item) credit an order, so the rule cannot flip by
//  accident. If you mean to change it, change D12 first.
//
//  Each "does not credit" test has a control that proves the same order *is*
//  creditable by the event that is supposed to credit it, so the negative
//  result cannot be a mis-built order.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class OrderFulfilmentRuleTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }
    private let wantedTier = 3

    /// A view model with a fully unlocked, empty board and one open order
    /// wanting a single `dog` at `wantedTier`. Dog Tags are plentiful so a
    /// purchase is never refused for cost.
    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        // The board setter does not recompute BoardStateManager's cached empty
        // cells (see SpendQuotaDailiesWiringTests); without this, placing an
        // item silently no-ops and the purchase guard returns false.
        vm.boardState.recalc()
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1),
        ]
        vm.kibbleEngine.dogTags = 100
        return vm
    }

    private func order(_ vm: MergeBoardViewModel) -> AdoptionOrder {
        vm.adoptionBoardCoordinator.adoptionOrders[0]
    }

    private func boardHolds(_ vm: MergeBoardViewModel, chain: ChainID, tier: Int) -> Bool {
        vm.board.flatMap { $0 }.contains { $0.item?.chainID == chain && $0.item?.tier == tier }
    }

    // MARK: A Dog Tag store purchase never credits an order

    func testBuyingTheExactWantedItemFromTheStoreDoesNotCreditTheOrder() {
        let vm = makeViewModel()
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 10)
        vm.dogTagStore.slots = [slot]

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot), "the purchase itself must succeed")

        XCTAssertTrue(boardHolds(vm, chain: dog, tier: wantedTier),
                      "the bought item must actually be on the board, or this test proves nothing")
        XCTAssertEqual(order(vm).lines[0].fulfilled, 0,
                       "a store purchase must not credit an order, even for the exact chain and tier it wants")
        XCTAssertFalse(order(vm).isComplete)
        XCTAssertFalse(order(vm).isClaimed)
    }

    func testControlAMergeProducingTheSameItemDoesCreditTheOrder() {
        let vm = makeViewModel()

        vm.updateOrdersAfterMerge(chainID: dog, tier: wantedTier)

        XCTAssertTrue(order(vm).isComplete,
                      "the same order must be completed by the event that is meant to credit it")
        XCTAssertTrue(order(vm).isClaimed, "completion auto-claims")
    }

    // MARK: A held item never fills an order

    func testAnItemAlreadyOnTheBoardDoesNotFillAnOrderOnItsOwn() {
        let vm = makeViewModel()
        vm.boardState.setItem(BoardItem(chainID: dog, tier: wantedTier),
                              at: GridPosition(row: 0, col: 0))

        // An unrelated production event must not sweep the board for matches.
        vm.updateOrdersAfterMerge(chainID: cat, tier: 0)

        XCTAssertTrue(boardHolds(vm, chain: dog, tier: wantedTier))
        XCTAssertEqual(order(vm).lines[0].fulfilled, 0,
                       "credit is driven by the produced item, not by what the board happens to hold")
        XCTAssertFalse(order(vm).isComplete)
    }

    func testOnlyTheProducedChainAndTierCreditsTheOrder() {
        let vm = makeViewModel()

        vm.updateOrdersAfterMerge(chainID: dog, tier: wantedTier + 1)
        vm.updateOrdersAfterMerge(chainID: cat, tier: wantedTier)

        XCTAssertEqual(order(vm).lines[0].fulfilled, 0,
                       "neighbouring tiers and other chains must not credit the order")
    }
}
