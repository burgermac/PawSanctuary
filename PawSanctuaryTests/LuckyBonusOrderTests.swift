//
//  LuckyBonusOrderTests.swift
//  PawSanctuaryTests
//
//  Pins D14 (Alignment Plan; Spec_HeldItemOrders.md) for BONUS SPAWNS: the
//  "Lucky!" and "Legendary!" extra animals that a boosted spawner tap can drop
//  (`maybeGrantBonusSpawn`). Under D14 a spawn no longer credits an order
//  directly. It only puts an item on the board. If that item is exactly what an
//  order wants, the order's slot becomes HELD because the board now holds it
//  (read live from `boardTaskCensus`), the card becomes ready if it was the last
//  missing item, and the player still has to press Deliver.
//
//  A reference recording showed a spawn producing a wanted item as a bonus. In
//  PawSanctuary that is this path, and these tests show it works through the
//  board rather than around it.
//
//  Forcing the dice: `maybeGrantBonusSpawn` takes `bonusRoll` and `legendaryRoll`
//  (defaults are the production random rolls). A roll of 0 always passes the
//  bonus chance; a roll of 0.99 never passes the 15% Legendary share. The landing
//  cell is still random, so the tests read where the item landed instead of
//  assuming a cell.
//
//  Findings pinned here (see the report on PR #125):
//  - the bonus lands only on an empty UNLOCKED cell, through `finishSpawn`;
//  - when no such cell exists the bonus is silently dropped. It does NOT bank to
//    storage, so there is no "banked bonus item" to count or not count;
//  - it never fires at x1, and it costs no kibble.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class LuckyBonusOrderTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }
    /// The tier a x8 tap spawns at (`spawnTierIndex(forMultiplier: 8)`), so the
    /// Lucky item is the tap's own tier and the Legendary item is one above it.
    private let tapTier = 3

    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    /// Empty, fully unlocked board; boosted to x8 so a bonus can fire; one open
    /// order wanting a single `dog` at `wantedTier`; no urgent order.
    private func makeViewModel(wantedChain: ChainID? = nil, wantedTier: Int? = nil) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.spawnMultiplier = 8
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: wantedChain ?? dog,
                          wantedTier: wantedTier ?? tapTier, wantedCount: 1),
        ]
        vm.adoptionBoardCoordinator.urgentOrder = nil
        vm.kibbleEngine.kibble = 500
        vm.kibbleEngine.dogTags = 100
        return vm
    }

    private func held(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int) -> Int {
        vm.boardTaskCensus[ChainTierKey(chainID: chain, tier: tier)] ?? 0
    }

    private func isReady(_ vm: MergeBoardViewModel) -> Bool {
        vm.orderHeldState(at: 0)?.isReady ?? false
    }

    private func itemCells(_ vm: MergeBoardViewModel) -> [BoardCell] {
        vm.board.flatMap { $0 }.filter { $0.item != nil }
    }

    /// A Lucky roll: the bonus fires, and it is not Legendary.
    private func lucky(_ vm: MergeBoardViewModel) {
        vm.maybeGrantBonusSpawn(species: .dog, chainID: dog, spawnTier: tapTier,
                                bonusRoll: 0, legendaryRoll: 0.99)
    }

    /// A Legendary roll: the bonus fires, one tier richer than the tap.
    private func legendary(_ vm: MergeBoardViewModel) {
        vm.maybeGrantBonusSpawn(species: .dog, chainID: dog, spawnTier: tapTier,
                                bonusRoll: 0, legendaryRoll: 0)
    }

    // MARK: A Lucky bonus lands on the board and fills the slot

    func testALuckyBonusLandsOnTheBoardAndMakesTheWantedSlotHeldAndTheCardReady() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders[0].rewards = [OrderReward(kind: .dogTags, amount: 7)]
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [false], "control: missing before the bonus")
        XCTAssertFalse(isReady(vm))
        let kibbleBefore = vm.kibbleEngine.kibble
        let tagsBefore = vm.kibbleEngine.dogTags

        lucky(vm)

        let landed = itemCells(vm)
        XCTAssertEqual(landed.count, 1, "the bonus put exactly one item on the board")
        XCTAssertEqual(landed.first?.item?.chainID, dog)
        XCTAssertEqual(landed.first?.item?.tier, tapTier, "Lucky is the tap's own tier")
        XCTAssertEqual(landed.first?.isUnlocked, true, "it landed on an unlocked cell")
        XCTAssertEqual(held(vm, dog, tier: tapTier), 1, "and the board census sees it")
        XCTAssertEqual(vm.kibbleEngine.kibble, kibbleBefore, "a bonus is free")

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true], "the slot is held")
        XCTAssertTrue(isReady(vm), "and the card is ready: it was the last missing item")
        XCTAssertEqual(vm.adoptionBoardCoordinator.adoptionOrders[0].lines[0].fulfilled, 0,
                       "D14: the spawn did not credit the order")
        XCTAssertFalse(vm.adoptionBoardCoordinator.adoptionOrders[0].isClaimed, "nothing was auto-delivered")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore, "nothing was paid yet")
    }

    func testTheBonusItemCanThenBeDeliveredFromTheBoard() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders[0].rewards = [OrderReward(kind: .dogTags, amount: 7)]
        lucky(vm)
        XCTAssertTrue(isReady(vm))
        let tagsBefore = vm.kibbleEngine.dogTags

        XCTAssertTrue(vm.deliverOrder(at: 0), "the Deliver button's path works on a bonus item")

        XCTAssertEqual(held(vm, dog, tier: tapTier), 0, "the bonus item left the board")
        XCTAssertEqual(vm.kibbleEngine.dogTags, tagsBefore + 7, "and the order paid")
        XCTAssertTrue(vm.adoptionBoardCoordinator.adoptionOrders[0].isClaimed)
    }

    func testALuckyBonusFillsOneSlotOfATwoLineBasketWithoutReadyingIt() {
        let vm = makeViewModel()
        vm.adoptionBoardCoordinator.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: tapTier, count: 1),
            OrderLine(chainID: cat, tier: 2, count: 1),
        ])]

        lucky(vm)

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true, false])
        XCTAssertFalse(isReady(vm), "one slot of two is not a ready card")
        XCTAssertFalse(vm.deliverOrder(at: 0), "no partial delivery")
        XCTAssertEqual(held(vm, dog, tier: tapTier), 1, "the bonus item stays on the board")

        let free = vm.board.flatMap { $0 }.first { $0.item == nil }
        XCTAssertNotNil(free)
        if let free { vm.boardState.setItem(BoardItem(chainID: cat, tier: 2), at: free.position) }
        XCTAssertTrue(isReady(vm), "control: the second item completes the card")
    }

    // MARK: A Legendary bonus is one tier richer

    func testALegendaryBonusLandsOneTierUpAndFillsASlotWantingThatTier() {
        let vm = makeViewModel(wantedTier: tapTier + 1)

        legendary(vm)

        XCTAssertEqual(itemCells(vm).count, 1)
        XCTAssertEqual(itemCells(vm).first?.item?.tier, tapTier + 1, "Legendary is one tier above the tap")
        XCTAssertEqual(held(vm, dog, tier: tapTier + 1), 1)
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [true])
        XCTAssertTrue(isReady(vm))
        XCTAssertTrue(vm.deliverOrder(at: 0))
        XCTAssertEqual(held(vm, dog, tier: tapTier + 1), 0)
    }

    func testALegendaryBonusDoesNotFillASlotWantingTheTapTier() {
        let vm = makeViewModel()   // wants tier 3

        legendary(vm)              // lands tier 4

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [false],
                       "matching is by exact tier: a richer item does not satisfy the lower slot")
        XCTAssertFalse(isReady(vm))
        XCTAssertFalse(vm.deliverOrder(at: 0))
    }

    func testALuckyBonusDoesNotFillASlotWantingTheLegendaryTier() {
        let vm = makeViewModel(wantedTier: tapTier + 1)

        lucky(vm)

        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [false])
        XCTAssertFalse(isReady(vm))
    }

    // MARK: Controls: a bonus item that does not match leaves the slot missing

    func testABonusOfAnotherChainLeavesTheSlotMissing() {
        let vm = makeViewModel(wantedChain: cat)   // order wants a cat; the bonus is a dog

        lucky(vm)

        XCTAssertEqual(itemCells(vm).count, 1, "the bonus did land, or this test proves nothing")
        XCTAssertEqual(held(vm, dog, tier: tapTier), 1)
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [false])
        XCTAssertFalse(isReady(vm))
        XCTAssertFalse(vm.deliverOrder(at: 0))
    }

    func testNoBonusFiresAtTheBaseMultiplier() {
        let vm = makeViewModel()
        vm.spawnMultiplier = 1

        lucky(vm)   // even a guaranteed roll: the chance at x1 is zero by design

        XCTAssertEqual(itemCells(vm).count, 0)
        XCTAssertFalse(isReady(vm))
    }

    func testAFailedBonusRollPlacesNothing() {
        let vm = makeViewModel()

        vm.maybeGrantBonusSpawn(species: .dog, chainID: dog, spawnTier: tapTier,
                                bonusRoll: 0.99, legendaryRoll: 0)

        XCTAssertEqual(itemCells(vm).count, 0, "0.99 is above the x8 chance of 0.40")
        XCTAssertFalse(isReady(vm))
    }

    // MARK: Where a bonus can and cannot land

    func testTheBonusNeverLandsOnALockedCell() {
        let vm = makeViewModel()
        // Fill every unlocked cell but one with a cat; lock a different, empty cell.
        let lockedPos = GridPosition(row: 0, col: 0)
        let openPos = GridPosition(row: 0, col: 1)
        vm.board[lockedPos.row][lockedPos.col].isUnlocked = false
        for row in 0..<boardRows { for col in 0..<7 {
            let pos = GridPosition(row: row, col: col)
            if pos != lockedPos && pos != openPos {
                vm.boardState.setItem(BoardItem(chainID: cat, tier: 0), at: pos)
            }
        } }
        vm.boardState.recalc()
        XCTAssertEqual(vm.emptyUnlockedCells.map(\.position), [openPos], "setup: one open cell")

        lucky(vm)

        XCTAssertNil(vm.boardState.item(at: lockedPos), "the locked cell stays empty")
        XCTAssertEqual(vm.boardState.item(at: openPos)?.chainID, dog, "the bonus took the one open cell")
        XCTAssertEqual(vm.boardState.item(at: openPos)?.tier, tapTier)
    }

    func testOnAFullBoardTheBonusIsDroppedNotBankedAndNothingCounts() {
        let vm = makeViewModel()
        for row in 0..<boardRows { for col in 0..<7 {
            vm.boardState.setItem(BoardItem(chainID: cat, tier: 0), at: GridPosition(row: row, col: col))
        } }
        vm.boardState.recalc()
        XCTAssertTrue(vm.boardState.boardIsFull)
        let storedBefore = vm.inventoryStore.inventory.compactMap { $0 }.count
        let kibbleBefore = vm.kibbleEngine.kibble

        lucky(vm)

        XCTAssertEqual(vm.inventoryStore.inventory.compactMap { $0 }.count, storedBefore,
                       "the bonus path does not bank to storage; it is silently dropped")
        XCTAssertEqual(held(vm, dog, tier: tapTier), 0)
        XCTAssertEqual(vm.orderHeldState(at: 0)?.heldLines, [false])
        XCTAssertFalse(isReady(vm), "no bonus item exists anywhere, so the slot stays missing")
        XCTAssertEqual(vm.kibbleEngine.kibble, kibbleBefore)
    }

    func testAnItemInStorageDoesNotFillTheSlotEvenIfItIsTheBonusItem() {
        // Spec section 3.1: storage is excluded. Banking is not something the bonus does,
        // so this stands in for it: the same item placed in inventory must not count.
        let vm = makeViewModel()
        XCTAssertTrue(vm.addToInventory(BoardItem(chainID: dog, tier: tapTier)))

        XCTAssertEqual(held(vm, dog, tier: tapTier), 0)
        XCTAssertFalse(isReady(vm), "a stored copy is not held")
    }
}
