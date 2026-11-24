//
//  HeldItemOrderUITests.swift
//  PawSanctuaryTests
//
//  Pins the state behind the order card and board UI of D14
//  (Spec_HeldItemOrders.md §4, tasks 1.4 and 1.5):
//
//    - one slot per wanted copy, each missing / held (muted) / ready (vivid) /
//      delivered;
//    - a card is ready, and shows Deliver, only when every copy is held;
//    - the board-tile highlight map: muted where any open card wants the item,
//      vivid where a ready card wants it, vivid winning across orders and daily
//      tasks;
//    - the task 1.3 stopgap is gone: a board change alone delivers nothing;
//    - delivery takes exactly the wanted copies, pays once even if pressed
//      twice, and hands the cleared cells to the departure animation.
//
//  Each negative test keeps a control beside it, as OrderFulfilmentRuleTests does.
//

import XCTest
import SwiftUI
@testable import PawSanctuary

@MainActor
final class HeldItemOrderUITests: XCTestCase {

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

    /// A fully unlocked, empty board; no urgent order, no daily tasks; one open
    /// order wanting a single `dog` at `wantedTier`.
    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1),
        ]
        vm.adoptionBoardCoordinator.urgentOrder = nil
        vm.quests.dailyChallenges = []
        vm.kibbleEngine.dogTags = 100
        return vm
    }

    private func put(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int, row: Int = 0, col: Int) {
        vm.boardState.setItem(BoardItem(chainID: chain, tier: tier), at: GridPosition(row: row, col: col))
    }

    /// The first `count` cells with no item and no producer, in board order.
    /// A plain loop: chained closures here have timed out CI's type checker before.
    private func emptyCells(_ vm: MergeBoardViewModel, _ count: Int) -> [GridPosition] {
        var found: [GridPosition] = []
        for row in vm.board {
            for cell in row where cell.isUnlocked && cell.item == nil && cell.producer == nil {
                if found.count == count { return found }
                found.append(cell.position)
            }
        }
        return found
    }

    private func held(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int) -> Int {
        vm.boardTaskCensus[ChainTierKey(chainID: chain, tier: tier)] ?? 0
    }

    private func order(_ vm: MergeBoardViewModel, _ index: Int = 0) -> AdoptionOrder {
        vm.adoptionBoardCoordinator.adoptionOrders[index]
    }

    private func slotStates(_ vm: MergeBoardViewModel, _ index: Int = 0) -> [OrderSlotState] {
        order(vm, index).slots(census: vm.boardTaskCensus).map(\.state)
    }

    private func key(_ chain: ChainID, _ tier: Int) -> ChainTierKey {
        ChainTierKey(chainID: chain, tier: tier)
    }

    // MARK: Per-copy slots

    func testACountTwoLineWithOneCopyHeldShowsOneHeldSlotAndOneMissing() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 2),
        ]
        XCTAssertEqual(slotStates(vm), [.missing, .missing], "control: two slots, nothing held")

        put(vm, dog, tier: wantedTier, col: 0)

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldCopies, [1], "one of two copies held")
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [false], "the line is not fully held")
        XCTAssertEqual(slotStates(vm), [.held, .missing], "one slot muted, one empty")
        XCTAssertEqual(order(vm).slots(census: vm.boardTaskCensus).map(\.lineIndex), [0, 0])
        XCTAssertEqual(order(vm).slots(census: vm.boardTaskCensus).map(\.copy), [0, 1])
    }

    func testTwoLinesOfOneItemShareTheCensusInOrder() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
        ])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldCopies, [1, 0], "one copy covers the first line only")
        XCTAssertEqual(slotStates(vm), [.held, .missing])
    }

    // MARK: Ready only when every copy is held

    func testTheCardIsReadyOnlyWhenEveryCopyIsHeld() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: cat, tier: 2, count: 1),
        ])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(slotStates(vm), [.held, .missing], "part-held: muted, no vivid slot")
        XCTAssertFalse(vm.orderHeldState(at: 0)?.isReady ?? true)

        put(vm, cat, tier: 2, col: 1)
        XCTAssertEqual(slotStates(vm), [.ready, .ready], "all held: every slot goes vivid")
        XCTAssertTrue(vm.orderHeldState(at: 0)?.isReady ?? false)
    }

    func testAnUrgentOrderOutOfTimeNeverReadsAsReady() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.urgentOrder = AdoptionOrder(
            familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1)
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 0
        put(vm, dog, tier: wantedTier, col: 0)
        let urgent = vm.adoptionBoardCoordinator.urgentOrder

        XCTAssertFalse(vm.isUrgentOrderDeliverable)
        XCTAssertEqual(urgent?.slots(census: vm.boardTaskCensus, canDeliver: false).map(\.state), [.held],
                       "held, but no Deliver once the clock has run out")

        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 60
        XCTAssertTrue(vm.isUrgentOrderDeliverable, "control")
        XCTAssertEqual(urgent?.slots(census: vm.boardTaskCensus, canDeliver: true).map(\.state), [.ready])
    }

    // MARK: Deliver unavailable on a part-filled card

    func testDeliverIsUnavailableOnAPartFilledCardAndChangesNothing() {
        let vm = makeViewModel()
        var basket = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 2)
        basket.rewards = [OrderReward(kind: .dogTags, amount: 7)]
        vm.adoptionBoardCoordinator.adoptionOrders = [basket]
        put(vm, dog, tier: wantedTier, col: 0)
        let tagsBefore = vm.kibbleEngine.dogTags

        XCTAssertFalse(slotStates(vm).contains(.ready), "no vivid slot, so the card shows no button")
        XCTAssertFalse(vm.deliverOrder(id: basket.id), "the view model refuses anyway")
        XCTAssertFalse(vm.deliverOrder(at: 0))
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "nothing left the board")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore, "nothing was paid")
        XCTAssertTrue(vm.departingItems.isEmpty, "nothing animates out")
        XCTAssertTrue(vm.rewardBursts.isEmpty)
        XCTAssertFalse(order(vm).isClaimed)

        put(vm, dog, tier: wantedTier, col: 1)
        XCTAssertTrue(vm.deliverOrder(id: basket.id), "control: the full card delivers")
    }

    func testDeliverByAnUnknownIdDoesNothing() {
        let vm = makeViewModel()
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertFalse(vm.deliverOrder(id: UUID()))
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1)
        XCTAssertTrue(vm.deliverOrder(id: order(vm).id), "control")
    }

    // MARK: Board-tile highlight map

    func testBoardTilesAreMutedForAWantedItemAndVividForAReadyCard() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [
            // Part-held basket: its items are muted.
            AdoptionOrder(familyIndex: 0, lines: [
                OrderLine(chainID: cat, tier: 2, count: 1),
                OrderLine(chainID: cat, tier: 4, count: 1),
            ]),
            // Ready single: its item is vivid.
            AdoptionOrder(familyIndex: 1, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1),
        ]
        put(vm, cat, tier: 2, col: 0)
        put(vm, dog, tier: wantedTier, col: 1)

        let map = vm.heldItemHighlights
        XCTAssertEqual(map[key(cat, 2)]?.level, .wanted, "wanted by a part-held card: muted")
        XCTAssertEqual(map[key(cat, 4)]?.level, .wanted)
        XCTAssertEqual(map[key(dog, wantedTier)]?.level, .stocked, "wanted by a ready card: vivid")
        XCTAssertNil(map[key(dog, 0)], "control: an item no card wants is not tinted")
    }

    func testVividWinsWhenATileServesAReadyOrderAndAnUnstockedDailyTask() {
        let vm = makeViewModel()
        // The daily task wants the dog too, but is short of a cat: not stocked.
        vm.quests.dailyChallenges = [DailyChallenge(lines: [
            DailyTaskLine(chainID: dog, tier: wantedTier, count: 1),
            DailyTaskLine(chainID: cat, tier: 0, count: 1),
        ], difficulty: .easy, coinReward: 50)]
        put(vm, dog, tier: wantedTier, col: 0)

        XCTAssertEqual(vm.dailyTaskHighlights[key(dog, wantedTier)], .wanted,
                       "control: the daily task alone would mute the tile")
        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)]?.level, .stocked,
                       "the ready order makes it vivid; vivid wins")
    }

    func testVividWinsWhenATileServesAStockedDailyTaskAndAPartHeldOrder() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: cat, tier: 2, count: 1),
        ])]
        vm.quests.dailyChallenges = [DailyChallenge(lines: [
            DailyTaskLine(chainID: dog, tier: wantedTier, count: 1),
        ], difficulty: .easy, coinReward: 50)]
        put(vm, dog, tier: wantedTier, col: 0)

        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)]?.level, .stocked)
        XCTAssertEqual(vm.heldItemHighlights[key(cat, 2)]?.level, .wanted, "the order's missing item stays muted")
    }

    // MARK: Whose hue a tile wears (orders: green, daily tasks: blue)

    private func dailyTask(_ lines: [DailyTaskLine]) -> DailyChallenge {
        DailyChallenge(lines: lines, difficulty: .easy, coinReward: 50)
    }

    func testAnOrderTileWearsTheOrderHueAndADailyTaskTileKeepsBlue() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [dailyTask([DailyTaskLine(chainID: cat, tier: 1, count: 1)])]
        put(vm, dog, tier: wantedTier, col: 0)
        put(vm, cat, tier: 1, col: 1)

        let map = vm.heldItemHighlights
        XCTAssertEqual(map[key(dog, wantedTier)], .init(level: .stocked, family: .order))
        XCTAssertEqual(map[key(cat, 1)], .init(level: .stocked, family: .dailyTask),
                       "a daily-task-only tile stays blue")
    }

    func testAVividOrderBeatsAMutedDailyTaskAndShowsTheOrderHue() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [dailyTask([DailyTaskLine(chainID: dog, tier: wantedTier, count: 1),
                                                DailyTaskLine(chainID: cat, tier: 0, count: 1)])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)], .init(level: .stocked, family: .order))
    }

    func testAVividDailyTaskBeatsAMutedOrderAndShowsTheDailyHue() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: cat, tier: 2, count: 1),
        ])]
        vm.quests.dailyChallenges = [dailyTask([DailyTaskLine(chainID: dog, tier: wantedTier, count: 1)])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)], .init(level: .stocked, family: .dailyTask),
                       "vivid wins, and the vivid card's hue shows")
    }

    func testWhenBothAreVividOrBothMutedTheOrderGreenShows() {
        // Both vivid.
        var vm = makeViewModel()
        vm.quests.dailyChallenges = [dailyTask([DailyTaskLine(chainID: dog, tier: wantedTier, count: 1)])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)], .init(level: .stocked, family: .order))

        // Both muted: each card is short of something else.
        vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: wantedTier, count: 1),
            OrderLine(chainID: cat, tier: 2, count: 1),
        ])]
        vm.quests.dailyChallenges = [dailyTask([DailyTaskLine(chainID: dog, tier: wantedTier, count: 1),
                                                DailyTaskLine(chainID: cat, tier: 0, count: 1)])]
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)], .init(level: .wanted, family: .order))
    }

    func testTheOrderHighlightColoursAreTheMeasuredTravelTownGreens() {
        func rgb(_ color: Color) -> [Int] {
            let ui = UIColor(color)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return [r, g, b].map { Int(($0 * 255).rounded()) }
        }
        XCTAssertEqual(rgb(orderHeldMutedGreen), [126, 162, 61], "#7EA23D, Triage §2.10 (d)")
        XCTAssertEqual(rgb(orderReadyLime), [200, 247, 119], "#C8F777, Triage §2.10 (d)")
        XCTAssertTrue(OrderSlotState.held.showsCheck && OrderSlotState.ready.showsCheck,
                      "held slots wear a check mark, so state never rests on colour alone")
        XCTAssertFalse(OrderSlotState.missing.showsCheck || OrderSlotState.delivered.showsCheck)
    }

    func testDeliveredAndOutOfTimeOrdersDoNotLightTheBoard() {
        let vm = makeViewModel()
        put(vm, dog, tier: wantedTier, col: 0)
        put(vm, dog, tier: wantedTier, col: 1)
        vm.adoptionBoardCoordinator.adoptionOrders[0].markDelivered()
        vm.adoptionBoardCoordinator.urgentOrder = AdoptionOrder(
            familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1)
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 0

        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)]?.level, .wanted,
                       "a delivered order adds nothing; an out-of-time urgent order is muted, never vivid")

        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 60
        XCTAssertEqual(vm.heldItemHighlights[key(dog, wantedTier)]?.level, .stocked, "control: on time, vivid")
    }

    // MARK: The stopgap is gone

    func testABoardChangeAloneDoesNotDeliverAReadyCard() async {
        let vm = makeViewModel()
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 10)
        vm.dogTagStore.slots = [slot]

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot), "a board change that readies the card")
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "the bought item is on the board")
        // Another board change: a move between two empty cells. The purchase lands
        // on a random cell, so the cells are looked up after it, never fixed: a fixed
        // one is overwritten by the bought item about one run in fifty.
        let spare = emptyCells(vm, 2)
        XCTAssertEqual(spare.count, 2)
        guard spare.count == 2 else { return }
        put(vm, cat, tier: 0, row: spare[0].row, col: spare[0].col)
        vm.attemptMergeOrMove(from: spare[0], to: spare[1])
        // Give any scheduled main-actor work every chance to run.
        try? await Task.sleep(for: .milliseconds(300))

        XCTAssertTrue(vm.orderHeldState(at: 0)?.isReady ?? false, "the card is ready")
        XCTAssertFalse(order(vm).isClaimed, "but nothing delivers it without the button")
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "the item stays on the board")

        XCTAssertTrue(vm.deliverOrder(id: order(vm).id), "control: the button's call delivers it")
    }

    // MARK: Delivery

    func testDeliveryRemovesExactlyTheWantedCopiesAndPaysOnceEvenIfPressedTwice() {
        let vm = makeViewModel()
        var wanted = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 2)
        wanted.rewards = [OrderReward(kind: .dogTags, amount: 7), OrderReward(kind: .coins, amount: 40)]
        vm.adoptionBoardCoordinator.adoptionOrders = [wanted]
        put(vm, dog, tier: wantedTier, row: 0, col: 2)
        put(vm, dog, tier: wantedTier, row: 1, col: 0)
        put(vm, dog, tier: wantedTier, row: 3, col: 3)
        put(vm, cat, tier: wantedTier, row: 0, col: 0)
        let tagsBefore = vm.kibbleEngine.dogTags
        let coinsBefore = vm.coins

        XCTAssertTrue(vm.deliverOrder(id: wanted.id))
        XCTAssertFalse(vm.deliverOrder(id: wanted.id), "a second press is refused")
        XCTAssertFalse(vm.deliverOrder(at: 0), "by index too")

        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "3 held minus the 2 wanted")
        XCTAssertEqual(held(vm, cat, tier: wantedTier), 1, "same tier, other chain: untouched")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore + 7, "paid exactly once")
        XCTAssertEqual(vm.coins, coinsBefore + 40)
        XCTAssertEqual(vm.rewardBursts.count, 1, "one reward flight")
        XCTAssertEqual(slotStates(vm), [.delivered, .delivered], "the card shows Adopted! during the pause")

        XCTAssertEqual(Set(vm.departingItems.map(\.position)),
                       [GridPosition(row: 0, col: 2), GridPosition(row: 1, col: 0)],
                       "the cleared cells animate out, and only those")
        XCTAssertTrue(vm.departingItems.allSatisfy { $0.item.chainID == dog && $0.item.tier == wantedTier })
    }

    func testTheDepartureAnimationClearsItself() async {
        let vm = makeViewModel()
        put(vm, dog, tier: wantedTier, col: 0)
        XCTAssertTrue(vm.deliverOrder(id: order(vm).id))
        XCTAssertEqual(vm.departingItems.count, 1)

        try? await Task.sleep(for: .seconds(orderDepartureDuration + 0.4))
        XCTAssertTrue(vm.departingItems.isEmpty, "session-only, dropped once it has played")
    }

    func testTheUrgentOrderPaysOnceEvenIfPressedTwice() {
        let vm = makeViewModel()
        var urgent = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1)
        urgent.rewards = [OrderReward(kind: .dogTags, amount: 5)]
        vm.adoptionBoardCoordinator.urgentOrder = urgent
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 600
        put(vm, dog, tier: wantedTier, col: 0)
        put(vm, dog, tier: wantedTier, col: 1)
        let tagsBefore = vm.kibbleEngine.dogTags

        XCTAssertTrue(vm.deliverUrgentOrder())
        XCTAssertFalse(vm.deliverUrgentOrder())

        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore + 5)
        XCTAssertEqual(held(vm, dog, tier: wantedTier), 1, "one copy wanted, one taken")
    }

    // MARK: Accessibility copy

    func testTheDeliverLabelSaysWhatTheOrderPays() {
        var order = AdoptionOrder(familyIndex: 0, wantedChainID: dog, wantedTier: wantedTier, wantedCount: 1)
        order.rewards = [OrderReward(kind: .coins, amount: 40), OrderReward(kind: .dogTags, amount: 2)]
        let summary = order.deliveryRewardSummary
        XCTAssertTrue(summary.contains("40 coins"), summary)
        XCTAssertTrue(summary.contains("2 Dog Tags"), summary)
        XCTAssertTrue(summary.contains("\(xpPerOrderFulfil) XP"), summary)
    }

    func testEachSlotSaysHeldOrMissing() {
        XCTAssertEqual(OrderSlotState.held.accessibilitySuffix, "held")
        XCTAssertEqual(OrderSlotState.missing.accessibilitySuffix, "missing")
        XCTAssertTrue(OrderSlotState.ready.accessibilitySuffix.hasPrefix("held"))
    }
}
