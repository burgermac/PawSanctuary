//
//  ChainViewerStoreTests.swift
//  PawSanctuaryTests
//
//  Pins revision task 2.2, the chain viewer's "See in store" shortcut
//  (Spec_ChainViewerUpgrades_Draft.md §3.3, §3.8; CV-1 answered B: the button
//  opens the shop scrolled to the slot, it never buys).
//
//  - `chainViewerStoreSlot(chainID:tier:)` is nil before the D7 gate, and after
//    it the first unsold slot matching chain and tier.
//  - `liveDogTagStoreSlot(id:)` resolves an id only while that slot is in stock
//    and unsold; every rebuild makes new ids, so an old id goes stale.
//  - D14 guard: buying the slot the shortcut points at (what the shop row does)
//    makes an order slot held when the item lands on the board, delivers
//    nothing, and counts nothing when the item is banked to storage.
//
//  The sheet swap, the scroll and the highlight are view code and are checked
//  on the Simulator only (spec §6).
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ChainViewerStoreTests: XCTestCase {

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

    /// Built as `OrderFulfilmentRuleTests.makeViewModel()` does: a fully
    /// unlocked, empty board, one open order wanting a single `dog` at
    /// `wantedTier`, plenty of Dog Tags. The D7 gate is left closed; tests open
    /// it with `unlockMonetizationForTesting()`.
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
        vm.kibbleEngine.dogTags = 100
        vm.commerce.hasReachedFirstWall = false
        vm.progression.playerLevel = 1
        return vm
    }

    private func put(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int, row: Int, col: Int) {
        vm.boardState.setItem(BoardItem(chainID: chain, tier: tier),
                              at: GridPosition(row: row, col: col))
    }

    private func order(_ vm: MergeBoardViewModel) -> AdoptionOrder {
        vm.adoptionBoardCoordinator.adoptionOrders[0]
    }

    // MARK: D7 gate

    func testNoSlotBeforeTheGateAndTheSlotAfterIt() {
        let vm = makeViewModel()
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)
        vm.dogTagStore.slots = [slot]
        XCTAssertFalse(vm.isMonetizationUnlocked, "control: the gate starts closed")

        XCTAssertNil(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier),
                     "D7: the viewer shows no price or button before the gate")

        vm.unlockMonetizationForTesting()

        XCTAssertEqual(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier), slot)
    }

    func testEachHalfOfTheGateAloneIsNotEnough() {
        let vm = makeViewModel()
        vm.dogTagStore.slots = [DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)]

        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel - 1
        XCTAssertNil(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier), "wall only")

        vm.commerce.hasReachedFirstWall = false
        vm.progression.playerLevel = monetizationUnlockLevel
        XCTAssertNil(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier), "level only")
    }

    // MARK: Matching

    func testNilForAChainOrTierTheStoreDoesNotStock() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        vm.dogTagStore.slots = [DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)]

        XCTAssertNil(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier + 1), "other tier")
        XCTAssertNil(vm.chainViewerStoreSlot(chainID: cat, tier: wantedTier), "other chain")
        XCTAssertNil(vm.chainViewerStoreSlot(chainID: "supply.food", tier: 0), "a chain never stocked")
        XCTAssertNotNil(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier), "control")
    }

    func testNilOnceTheOnlyMatchingSlotIsBought() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        vm.dogTagStore.slots = [DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)]
        guard let slot = vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier) else {
            return XCTFail("control: the slot is offered before it is bought")
        }

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))

        XCTAssertNil(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier),
                     "a sold slot shows nothing in the viewer, not a dead \"Sold\"")
    }

    func testWithTwoMatchingSlotsOneSoldTheUnsoldOneIsReturned() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        let first = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)
        let second = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)
        vm.dogTagStore.slots = [first, second]
        XCTAssertEqual(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier)?.id, first.id,
                       "control: the first unsold match while both are unsold")

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(first))

        XCTAssertEqual(vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier)?.id, second.id)
    }

    // MARK: liveDogTagStoreSlot(id:)

    func testLiveSlotResolvesALiveIdAndNotABoughtOne() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        let slot = DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)
        vm.dogTagStore.slots = [slot]

        XCTAssertEqual(vm.liveDogTagStoreSlot(id: slot.id), slot)
        XCTAssertNil(vm.liveDogTagStoreSlot(id: UUID()), "an unknown id")

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))

        XCTAssertNil(vm.liveDogTagStoreSlot(id: slot.id), "sold: the shop opens unscrolled")
    }

    func testAnIdTakenBeforeAPaidRefreshIsStaleAfterIt() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        vm.deepestUnlockedTier = 6
        vm.dogTagStore.forceRefresh(deepestUnlockedTier: vm.deepestUnlockedTier,
                                    unlockedChainIDs: vm.progression.unlockedChainIDs)
        guard let old = vm.dogTagStore.slots.first else {
            return XCTFail("control: the store must have stock, or this test proves nothing")
        }
        XCTAssertNotNil(vm.liveDogTagStoreSlot(id: old.id), "control: live before the reroll")

        XCTAssertTrue(vm.paidRefreshDogTagStore())

        XCTAssertFalse(vm.dogTagStore.slots.isEmpty, "the reroll built new stock")
        XCTAssertNil(vm.liveDogTagStoreSlot(id: old.id), "new stock, new ids")
    }

    func testAnIdTakenBeforeADayRolloverIsStaleAfterIt() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        vm.deepestUnlockedTier = 6
        vm.dogTagStore.forceRefresh(deepestUnlockedTier: vm.deepestUnlockedTier,
                                    unlockedChainIDs: vm.progression.unlockedChainIDs)
        guard let old = vm.dogTagStore.slots.first else {
            return XCTFail("control: the store must have stock, or this test proves nothing")
        }
        XCTAssertNotNil(vm.liveDogTagStoreSlot(id: old.id), "control")

        // Stands in for the rebuild a day rollover triggers.
        vm.dogTagStore.forceRefresh(deepestUnlockedTier: vm.deepestUnlockedTier,
                                    unlockedChainIDs: vm.progression.unlockedChainIDs)

        XCTAssertNil(vm.liveDogTagStoreSlot(id: old.id))
    }

    // MARK: D14 guard

    func testBuyingTheShortcutsSlotOntoTheBoardMakesTheOrderHeldButDeliversNothing() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        vm.dogTagStore.slots = [DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)]
        let tagsBefore = vm.kibbleEngine.dogTags
        XCTAssertEqual(vm.orderHeldState(at: 0)?.isReady, false, "control: not held before")
        guard let slot = vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier) else {
            return XCTFail("the shortcut must find the slot")
        }

        // What the shop row does once the shortcut has brought the player there.
        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))

        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore - 33, "debited once, at the store price")
        XCTAssertEqual(vm.orderHeldState(at: 0)?.isReady, true, "the bought item on the board is held")
        XCTAssertEqual(order(vm).lines[0].fulfilled, 0, "held is derived; nothing is credited")
        XCTAssertFalse(order(vm).isClaimed, "the purchase delivers nothing; Deliver is still pressed")
    }

    func testBuyingTheShortcutsSlotIntoStorageDoesNotMakeTheOrderHeld() {
        let vm = makeViewModel()
        vm.unlockMonetizationForTesting()
        for row in 0..<boardRows { for col in 0..<7 { put(vm, cat, tier: 0, row: row, col: col) } }
        vm.boardState.recalc()
        XCTAssertTrue(vm.boardState.boardIsFull)
        vm.dogTagStore.slots = [DogTagStoreSlot(chainID: dog, tier: wantedTier, priceDogTags: 33)]
        let key = ChainTierKey(chainID: dog, tier: wantedTier)
        let ownedBefore = vm.ownedItemCounts[key] ?? 0
        guard let slot = vm.chainViewerStoreSlot(chainID: dog, tier: wantedTier) else {
            return XCTFail("the shortcut must find the slot")
        }

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))

        XCTAssertEqual(vm.ownedItemCounts[key] ?? 0, ownedBefore + 1,
                       "the item went to storage, which the viewer's badge counts")
        XCTAssertEqual(vm.orderHeldState(at: 0)?.isReady, false,
                       "storage does not count for an order (D14)")
        XCTAssertFalse(order(vm).isClaimed)
    }
}
