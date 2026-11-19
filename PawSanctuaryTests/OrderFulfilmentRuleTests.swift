//
//  OrderFulfilmentRuleTests.swift
//  PawSanctuaryTests
//
//  Pins D14 (Alignment Plan; Spec_HeldItemOrders.md): an adoption order is
//  filled by items HELD on the board, read live from `boardTaskCensus`. A part-
//  filled card delivers nothing. Delivery takes exactly the wanted items off the
//  board and pays the order. A merge or a spawn no longer credits an order by
//  itself.
//
//  This file replaces the four D12 tests that pinned the opposite rule (an order
//  was credited only as a side effect of a merge or spawn producing the item).
//  If you mean to change the rule again, change D14 first.
//
//  Each negative test keeps a control beside it that proves the same order *is*
//  ready or deliverable once the thing that should satisfy it is present, so a
//  negative result cannot come from a mis-built order.
//
//  Task 1.3 has no Deliver button yet: a TEMPORARY stopgap auto-delivers every
//  ready card on the next main-actor turn after a board change. The tests that
//  look at held or ready state call the engine directly and read it before that
//  turn, and one test (`testTheInterimTriggerDeliversAReadyCard...`) pins the
//  stopgap itself so it is removed deliberately in tasks 1.4/1.5.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class OrderFulfilmentRuleTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }
    private let wantedTier = 3

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// A view model with a fully unlocked, empty board, no urgent order, and one
    /// open order wanting a single `dog` at `wantedTier`. Dog Tags are plentiful
    /// so a purchase is never refused for cost.
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
        vm.adoptionBoardCoordinator.urgentOrder = nil
        vm.kibbleEngine.dogTags = 100
        return vm
    }

    private func order(_ vm: MergeBoardViewModel, _ index: Int = 0) -> AdoptionOrder {
        vm.adoptionBoardCoordinator.adoptionOrders[index]
    }

    private func put(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int,
                     row: Int = 0, col: Int, bubbled: Bool = false) {
        vm.boardState.setItem(
            BoardItem(chainID: chain, tier: tier,
                      bubbledAt: bubbled ? Date().timeIntervalSince1970 : nil),
            at: GridPosition(row: row, col: col))
    }

    private func held(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int) -> Int {
        vm.boardTaskCensus[ChainTierKey(chainID: chain, tier: tier)] ?? 0
    }

    private func isReady(_ vm: MergeBoardViewModel, _ index: Int = 0) -> Bool {
        vm.orderHeldState(at: index)?.isReady ?? false
    }

    private func twoLineBasket() -> AdoptionOrder {
        AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: cat, tier: 2, count: 1),
        ])
    }

    // MARK: A part card is not ready and delivers nothing

    func testAPartHeldCardIsNotReadyAndDeliversNothing() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [twoLineBasket()]
        vm.adoptionBoardCoordinator.adoptionOrders[0].rewards = [OrderReward(kind: .dogTags, amount: 7)]
        put(vm, dog, tier: wantedTier, col: 0)
        let tagsBefore = vm.kibbleEngine.dogTags

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true, false],
                       "the dog line is held, the cat line is missing")
        XCTAssertFalse(isReady(vm), "one line of two held is not a ready card")

        XCTAssertFalse(vm.deliverOrder(at: 0), "no partial delivery")
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "nothing may leave the board")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore, "nothing may be paid")
        XCTAssertFalse(order(vm).isClaimed)
        XCTAssertFalse(order(vm).isComplete)
    }

    func testControlEveryItemHeldMakesTheCardReadyAndDeliverable() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [twoLineBasket()]
        put(vm, dog, tier: wantedTier, col: 0)
        put(vm, cat, tier: 2, col: 1)

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true, true])
        XCTAssertTrue(isReady(vm), "every wanted item is on the board")
        XCTAssertTrue(vm.deliverOrder(at: 0))
    }

    func testTwoLinesOfOneItemNeedTwoCopiesHeld() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
        ])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true, false],
                       "one copy covers one line, not both")
        XCTAssertFalse(isReady(vm))

        put(vm, dog, tier: wantedTier, col: 1)
        XCTAssertTrue(isReady(vm))
    }

    // MARK: Delivery

    func testDeliveringRemovesExactlyTheWantedItemsAndPaysAndMarksClaimed() {
        let vm = makeViewModel()
        var wanted = AdoptionOrder(familyIndex: 0, wantedChainID: dog,
                                   wantedTier: wantedTier, wantedCount: 2)
        wanted.rewards = [OrderReward(kind: .dogTags, amount: 7),
                          OrderReward(kind: .coins, amount: 40)]
        vm.adoptionBoardCoordinator.adoptionOrders = [wanted]
        for col in 0..<3 { put(vm, dog, tier: wantedTier, col: col) }
        put(vm, cat, tier: 1, col: 5)
        let tagsBefore = vm.kibbleEngine.dogTags
        let coinsBefore = vm.coins
        let xpBefore = vm.playerXP + vm.playerLevel * 1_000_000
        let carePointsBefore = vm.carePointsThisWeek
        let smileBefore = vm.smilePointsBanked

        XCTAssertTrue(vm.deliverOrder(at: 0))

        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "3 held minus the 2 wanted; the spare survives")
        XCTAssertEqual(held(vm, cat, tier: 1), 1, "unrelated items are untouched")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore + 7)
        XCTAssertEqual(vm.coins, coinsBefore + 40)
        XCTAssertNotEqual(vm.playerXP + vm.playerLevel * 1_000_000, xpBefore, "XP is granted")
        XCTAssertEqual(vm.carePointsThisWeek, carePointsBefore + carePointsPerOrder)
        XCTAssertEqual(vm.smilePointsBanked, smileBefore + wanted.smileValue)
        XCTAssertTrue(order(vm).isClaimed)
        XCTAssertTrue(order(vm).isComplete, "complete now means delivered")
        XCTAssertEqual(order(vm).lines.map(\.fulfilled), order(vm).lines.map(\.count))
        XCTAssertEqual(vm.rewardBursts.count, 1, "the payout flies out as before")
        XCTAssertFalse(vm.deliverOrder(at: 0), "a delivered order cannot be delivered twice")
    }

    func testADeliveredOrderIsReplacedAfterThePause() async {
        let vm = makeViewModel()
        let original = order(vm)
        put(vm, dog, tier: wantedTier, col: 0)

        XCTAssertTrue(vm.deliverOrder(at: 0))
        XCTAssertEqual(order(vm).id, original.id, "still the delivered card during the pause")

        try? await Task.sleep(for: .seconds(2.6))
        XCTAssertNotEqual(order(vm).id, original.id, "replaced after the existing 2 s pause")
        XCTAssertFalse(order(vm).isClaimed)
    }

    // MARK: A store purchase counts once it is on the board

    func testAStorePurchaseOfTheWantedItemMakesTheSlotHeld() {
        let vm = makeViewModel()
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 10)
        vm.dogTagStore.slots = [slot]
        XCTAssertFalse(isReady(vm), "control: nothing held before the purchase")

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot), "the purchase itself must succeed")

        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1)
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true])
        XCTAssertTrue(isReady(vm), "a bought item on the board satisfies the slot")
        XCTAssertEqual(order(vm).lines[0].fulfilled, 0, "held is derived, not credited")
    }

    func testAPurchaseBankedToStorageBecauseTheBoardIsFullDoesNotCount() {
        let vm = makeViewModel()
        // Fill every cell with something that is not the wanted item.
        for row in 0..<boardRows { for col in 0..<7 { put(vm, cat, tier: 0, row: row, col: col) } }
        vm.boardState.recalc()
        XCTAssertTrue(vm.boardState.boardIsFull)
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 10)
        vm.dogTagStore.slots = [slot]

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))

        XCTAssertEqual(vm.inventoryStore.inventory.compactMap { $0 }.filter {
            $0.chainID == dog && $0.tier == wantedTier
        }.count, 1, "the bought item went to storage, or this test proves nothing")
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 0)
        XCTAssertFalse(isReady(vm), "storage does not count; the player takes it out first")
    }

    // MARK: A merge no longer credits an order on its own

    func testAMergeNoLongerCreditsAnOrderOnItsOwn() {
        let vm = makeViewModel()

        // The bookkeeping a merge runs, naming exactly the item the order wants.
        vm.updateAllAfterMerge(chainID: dog, tier: wantedTier)
        vm.autoDeliverReadyOrders()

        XCTAssertEqual(order(vm).lines[0].fulfilled, 0,
                       "producing the item is not holding it; nothing may credit the order")
        XCTAssertFalse(order(vm).isClaimed)
        XCTAssertFalse(order(vm).isComplete)
    }

    func testControlARealMergeLeavesTheItemHeldAndTheCardReadyButUnpaid() {
        let vm = makeViewModel()
        put(vm, dog, tier: wantedTier - 1, col: 0)
        put(vm, dog, tier: wantedTier - 1, col: 1)
        let tagsBefore = vm.kibbleEngine.dogTags

        vm.attemptMergeOrMove(from: GridPosition(row: 0, col: 0), to: GridPosition(row: 0, col: 1))

        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "the merge made the item and it is held")
        XCTAssertTrue(isReady(vm), "the held result readies the card")
        XCTAssertFalse(order(vm).isClaimed, "but the merge itself paid nothing")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore)
    }

    // MARK: What counts as held

    func testInventoryAndBubbledItemsDoNotCount() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.addToInventory(BoardItem(chainID: dog, tier: wantedTier)))
        put(vm, dog, tier: wantedTier, col: 0, bubbled: true)

        XCTAssertEqual(held(vm, dog, tier: wantedTier), 0)
        XCTAssertFalse(isReady(vm), "stored and still-bubbled items are not held")
        XCTAssertFalse(vm.deliverOrder(at: 0))

        // Control: a plain copy on an unlocked cell does count.
        put(vm, dog, tier: wantedTier, col: 1)
        XCTAssertTrue(isReady(vm))
    }

    func testAnItemOnALockedCellDoesNotCount() {
        let vm = makeViewModel()
        put(vm, dog, tier: wantedTier, col: 0)
        vm.board[0][0].isUnlocked = false
        XCTAssertFalse(isReady(vm))
        vm.board[0][0].isUnlocked = true
        XCTAssertTrue(isReady(vm), "control")
    }

    func testOnlyTheExactChainAndTierCounts() {
        let vm = makeViewModel()
        put(vm, dog, tier: wantedTier + 1, col: 0)
        put(vm, dog, tier: wantedTier - 1, col: 1)
        put(vm, cat, tier: wantedTier, col: 2)
        XCTAssertFalse(isReady(vm), "neighbouring tiers and other chains must not satisfy the slot")

        put(vm, dog, tier: wantedTier, col: 3)
        XCTAssertTrue(isReady(vm), "control: the exact chain and tier does")
    }

    func testAWildcardDoesNotFillASlot() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.purchaseWildcard(), "the wildcard purchase succeeds")
        XCTAssertEqual(held(vm, ContentRegistry.wildcardChainID, tier: 0), 1,
                       "the wildcard is on the board, or this test proves nothing")

        XCTAssertFalse(isReady(vm), "a wildcard never fills a slot (Q18 a)")
        XCTAssertFalse(vm.deliverOrder(at: 0))

        put(vm, dog, tier: wantedTier, col: 6)
        XCTAssertTrue(isReady(vm), "control: the real item still does")
    }

    // MARK: Which copy leaves the board

    func testTheRowMajorCopyIsTakenWhenSpareCopiesAreHeld() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 2),
        ]
        // Placed out of order on purpose; the (0,0) copy is bubbled, so it is skipped.
        put(vm, dog, tier: wantedTier, row: 4, col: 0)
        put(vm, dog, tier: wantedTier, row: 2, col: 1)
        put(vm, dog, tier: wantedTier, row: 0, col: 5)
        put(vm, dog, tier: wantedTier, row: 0, col: 0, bubbled: true)

        XCTAssertTrue(vm.deliverOrder(at: 0))

        XCTAssertNil(vm.boardState.item(at: GridPosition(row: 0, col: 5)), "first copy in scan order is taken")
        XCTAssertNil(vm.boardState.item(at: GridPosition(row: 2, col: 1)), "second copy in scan order is taken")
        XCTAssertNotNil(vm.boardState.item(at: GridPosition(row: 4, col: 0)), "the later spare survives")
        XCTAssertNotNil(vm.boardState.item(at: GridPosition(row: 0, col: 0)), "a bubbled copy is never taken")
    }

    // MARK: Two cards, one held item

    func testTwoCardsSharingOneHeldItemFirstDeliveryWins() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1),
            AdoptionOrder(familyIndex: 1, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1),
        ]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertTrue(isReady(vm, 0))
        XCTAssertTrue(isReady(vm, 1), "each card checks the board on its own (Q18 b)")

        XCTAssertTrue(vm.deliverOrder(at: 1), "whichever is delivered first takes the copy")

        XCTAssertFalse(isReady(vm, 0), "the other card drops back to not ready at once")
        XCTAssertFalse(vm.deliverOrder(at: 0), "and cannot be delivered on stale state")
        XCTAssertFalse(order(vm, 0).isClaimed)
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 0)
    }

    func testADailyTaskAndAnOrderCompeteForTheSameCopy() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: wantedTier, count: 1)],
                                  difficulty: .easy, coinReward: 50)
        vm.quests.dailyChallenges = [task]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertTrue(isReady(vm))
        XCTAssertTrue(vm.isDailyTaskStocked(task))

        vm.claimDailyTask(id: task.id)

        XCTAssertFalse(isReady(vm), "the task took the only copy; the order is no longer ready")
        XCTAssertFalse(vm.deliverOrder(at: 0))
    }

    func testAnOrderDeliveryLeavesADailyTaskUnstocked() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: wantedTier, count: 1)],
                                  difficulty: .easy, coinReward: 50)
        vm.quests.dailyChallenges = [task]
        put(vm, dog, tier: wantedTier, col: 0)

        XCTAssertTrue(vm.deliverOrder(at: 0))

        XCTAssertFalse(vm.isDailyTaskStocked(task), "the order took the only copy")
    }

    // MARK: The urgent order

    private func urgent(_ vm: MergeBoardViewModel, time: Double = 600) {
        vm.adoptionBoardCoordinator.urgentOrder = AdoptionOrder(
            familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1)
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = time
    }

    func testUrgentOrderTimerRunsUntilDelivery() {
        let vm = makeViewModel()
        urgent(vm)
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.urgentOrderHeldState?.isReady, true)

        let chains = [dog]
        vm.adoptionBoardCoordinator.tickUrgentOrder(unlockedChainIDs: chains, playerLevel: 1)
        XCTAssertEqual(vm.adoptionBoardCoordinator.urgentOrderTimeRemaining, 599,
                       "holding the item does not stop the clock")

        XCTAssertTrue(vm.deliverUrgentOrder())
        XCTAssertTrue(vm.adoptionBoardCoordinator.urgentOrder?.isClaimed ?? false)
        vm.adoptionBoardCoordinator.tickUrgentOrder(unlockedChainIDs: chains, playerLevel: 1)
        XCTAssertEqual(vm.adoptionBoardCoordinator.urgentOrderTimeRemaining, 599,
                       "delivery stops the clock")
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 0)
    }

    func testUrgentOrderExpiresWhileHeldButUndelivered() {
        let vm = makeViewModel()
        urgent(vm, time: 0)
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.urgentOrderHeldState?.isReady, true, "held, but the clock has run out")
        XCTAssertFalse(vm.deliverUrgentOrder(), "an out-of-time order cannot be delivered")

        vm.adoptionBoardCoordinator.tickUrgentOrder(unlockedChainIDs: [dog], playerLevel: 1)

        XCTAssertNil(vm.adoptionBoardCoordinator.urgentOrder, "it expires, items held or not")
        XCTAssertGreaterThan(vm.adoptionBoardCoordinator.urgentOrderCooldownRemaining, 0)
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "the player keeps the item")
    }

    func testAPartHeldUrgentOrderDeliversNothing() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.urgentOrder = twoLineBasket()
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 600
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertFalse(vm.deliverUrgentOrder())
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1)

        put(vm, cat, tier: 2, col: 1)
        XCTAssertTrue(vm.deliverUrgentOrder(), "control")
    }

    // MARK: The temporary interim trigger (task 1.3; remove in 1.4/1.5)

    func testTheInterimTriggerDeliversAReadyCardAfterABoardChange() async {
        let vm = makeViewModel()
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 10)
        vm.dogTagStore.slots = [slot]
        // Let the fresh game's own scheduled check run first, so what follows
        // is caused by the purchase and nothing else.
        try? await Task.sleep(for: .milliseconds(100))

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))
        XCTAssertFalse(order(vm).isClaimed, "not inside the purchase call itself")

        for _ in 0..<50 where !order(vm).isClaimed {
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTAssertTrue(order(vm).isClaimed,
                      "TEMPORARY: a ready card is delivered through deliverOrder after the change")
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 0, "the delivery took the item off the board")
    }

    func testTheInterimTriggerLeavesAPartHeldCardAlone() async {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [twoLineBasket()]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertTrue(vm.placeOrBankItem(BoardItem(chainID: cat, tier: 0)))   // a board change

        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertFalse(order(vm).isClaimed)
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1)
    }
}
