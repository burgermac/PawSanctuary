//
//  PowerUpSinkTests.swift
//  PawSanctuaryTests
//
//  Completed sub-objects (e.g. a Canines chain's "Golden Ball") used to have
//  no sink at all: no sell, no discard, no quest/shop/exchange demand. Once
//  the 6-slot Supplies inventory and the animal inventory fallback were both
//  full, `MergeBoardViewModel.applyMergeOutcome` banked the completed item
//  with `inventoryStore.addItem(_:)` and never checked the return value, so
//  the item was silently destroyed while the game still reported success.
//  Covers the "convert to coins" sink added to close that dead end, and the
//  fallback that now fires in place of the silent-destroy bug.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class PowerUpSinkTests: XCTestCase {

    private let dogSubObjectChain = "subobject.dog"   // Canines: passive superpower,
    // so maybeGrantSuperpowerPiece never intercepts its completion — keeps
    // this deterministic instead of depending on the 15% piece-grant roll.

    private let a = GridPosition(row: 0, col: 0)
    private let b = GridPosition(row: 0, col: 1)

    // The load-wiring tests below go through `GameStore`, which is shared
    // on-disk state; every test in this class starts and ends with it empty.
    override func setUp() {
        super.setUp()
        GameStore.clear()
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    private func makeBoard() -> [[BoardCell]] {
        (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
    }

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = makeBoard()
        return vm
    }

    private func place(_ vm: MergeBoardViewModel, chainID: ChainID, tier: Int, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: chainID, tier: tier)
        vm.board = board
    }

    // MARK: coinValue ordering

    func testCoinValueIncreasesWithRarity() {
        XCTAssertLessThan(SubObjectRarity.speed.coinValue, SubObjectRarity.mapSupplies.coinValue)
        XCTAssertLessThan(SubObjectRarity.mapSupplies.coinValue, SubObjectRarity.boardItemGrant.coinValue)
        XCTAssertLessThan(SubObjectRarity.boardItemGrant.coinValue, SubObjectRarity.highTierDrop.coinValue)
    }

    // MARK: convertSelectedPowerUpToCoins — the player-initiated sink

    func testConvertSelectedPowerUpToCoinsAwardsCoinsAndClearsSlot() {
        let vm = makeViewModel()
        vm.inventoryStore.powerUpInventory[2] =
            BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .highTierDrop)
        vm.selectedPowerUpSlot = 2
        let coinsBefore = vm.coins

        vm.convertSelectedPowerUpToCoins()

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.highTierDrop.coinValue)
        XCTAssertNil(vm.inventoryStore.powerUpInventory[2])
        XCTAssertNil(vm.selectedPowerUpSlot)
    }

    func testConvertWithNoSelectionIsANoOp() {
        let vm = makeViewModel()
        let coinsBefore = vm.coins
        vm.convertSelectedPowerUpToCoins()
        XCTAssertEqual(vm.coins, coinsBefore)
    }

    func testSelectedPowerUpCoinValueReflectsTheSelectedSlot() {
        let vm = makeViewModel()
        XCTAssertNil(vm.selectedPowerUpCoinValue, "nothing selected yet")

        vm.inventoryStore.powerUpInventory[0] =
            BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .mapSupplies)
        vm.selectedPowerUpSlot = 0
        XCTAssertEqual(vm.selectedPowerUpCoinValue, SubObjectRarity.mapSupplies.coinValue)
    }

    // MARK: The bug found in review — full storage must never destroy the item

    func testCompletingASubObjectWithFullStorageConvertsToCoinsInsteadOfDestroyingIt() {
        let vm = makeViewModel()
        // Fill every Supplies slot and every base animal-inventory slot so
        // InventoryStore.addItem(_:) has nowhere left to bank a new item —
        // exactly the state that used to silently destroy a completed
        // sub-object while the game still reported success.
        for i in 0..<vm.inventoryStore.powerUpInventory.count {
            vm.inventoryStore.powerUpInventory[i] =
                BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .speed)
        }
        for i in 0..<freeInventorySlots {
            vm.inventoryStore.inventory[i] = BoardItem(chainID: ContentRegistry.animalChainID(.cat), tier: 0)
        }
        vm.inventoryStore.recalcInventoryOccupied()

        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        place(vm, chainID: dogSubObjectChain, tier: 2, at: b)
        let coinsBefore = vm.coins

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertNil(vm.board[b.row][b.col].item, "the board cell is cleared either way")
        XCTAssertGreaterThan(vm.coins, coinsBefore,
                             "with nowhere to store it, the completed item's value must be banked as coins, not lost")
    }

    func testCompletingASubObjectWithRoomBanksItNormallyAndAwardsNoCoins() {
        let vm = makeViewModel()
        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        place(vm, chainID: dogSubObjectChain, tier: 2, at: b)
        let coinsBefore = vm.coins

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertNil(vm.board[b.row][b.col].item)
        XCTAssertEqual(vm.coins, coinsBefore, "storage had room, so the normal bank path pays no coins")
        XCTAssertTrue(vm.inventoryStore.powerUpInventory.contains { $0?.chainID == self.dogSubObjectChain })
    }

    // MARK: stored balls — a completed ball may only be banked in Supplies

    private func fillSupplies(_ vm: MergeBoardViewModel) {
        for i in 0..<vm.inventoryStore.powerUpInventory.count {
            vm.inventoryStore.powerUpInventory[i] =
                BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .speed)
        }
    }

    func testCompletedSubObjectIsRefusedWhenSuppliesFullAndNeverEntersAnimalStorage() {
        let vm = makeViewModel()
        fillSupplies(vm)

        let banked = vm.inventoryStore.addItem(
            BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .speed))

        XCTAssertFalse(banked, "Supplies is full, so the ball is refused for the caller to cash")
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty,
                      "a completed ball must never spill into animal storage")
    }

    func testCompletedSubObjectGoesToASuppliesSlotWhenOneIsFree() {
        let vm = makeViewModel()
        fillSupplies(vm)
        vm.inventoryStore.powerUpInventory[4] = nil

        let banked = vm.inventoryStore.addItem(
            BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: .mapSupplies))

        XCTAssertTrue(banked)
        XCTAssertEqual(vm.inventoryStore.powerUpInventory[4]?.rarity, .mapSupplies)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty)
    }

    func testTierTwoSubObjectStillGoesToAnimalStorageWhenSuppliesFull() {
        let vm = makeViewModel()
        fillSupplies(vm)

        let banked = vm.inventoryStore.addItem(BoardItem(chainID: dogSubObjectChain, tier: 2))

        XCTAssertTrue(banked)
        XCTAssertEqual(vm.inventoryStore.inventory.compactMap { $0 }.count, 1,
                       "an inert tier 0-2 intermediate keeps its animal-storage home")
    }

    func testCompletingASubObjectWithSuppliesFullPaysCoinsAndLeavesAnimalStorageEmpty() {
        let vm = makeViewModel()
        fillSupplies(vm)
        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        place(vm, chainID: dogSubObjectChain, tier: 2, at: b)
        let coinsBefore = vm.coins

        vm.attemptMergeOrMove(from: a, to: b)

        XCTAssertNil(vm.board[b.row][b.col].item)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty,
                      "animal storage must stay empty")
        let paid = vm.coins - coinsBefore
        XCTAssertTrue(SubObjectRarity.allCases.map(\.coinValue).contains(paid),
                      "the rolled rarity's coin value was banked, got \(paid)")
    }

    // MARK: collectCompletedSubObject — tapping a finished tile on the board

    private func placeCompleted(_ vm: MergeBoardViewModel, rarity: SubObjectRarity?, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = BoardItem(chainID: dogSubObjectChain, tier: 3, rarity: rarity)
        vm.board = board
    }

    func testTappingCompletedSubObjectPaysItsRarityValueAndClearsCell() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .highTierDrop, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.highTierDrop.coinValue)
        XCTAssertNil(vm.board[a.row][a.col].item)
    }

    func testTappingCompletedSubObjectWithoutRarityPaysSpeedValue() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: nil, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.speed.coinValue)
        XCTAssertNil(vm.board[a.row][a.col].item)
    }

    func testTappingLowerTierSubObjectDoesNotCollect() {
        // Tiers 0 through 2 of the dog sub-object chain are all below the completed tier.
        for tier in 0...2 {
            let vm = makeViewModel()
            place(vm, chainID: dogSubObjectChain, tier: tier, at: a)
            let coinsBefore = vm.coins

            vm.boardCellTapped(at: a)

            XCTAssertEqual(vm.coins, coinsBefore, "tier \(tier) must not pay coins")
            XCTAssertNotNil(vm.board[a.row][a.col].item, "tier \(tier) must stay on the board")
            XCTAssertEqual(vm.selectedCell, a, "tier \(tier) tap selects the cell as usual")
        }
    }

    func testTappingTopTierAnimalDoesNotCollect() {
        let vm = makeViewModel()
        place(vm, chainID: ContentRegistry.animalChainID(.dog), tier: animalChainTopTier, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertNotNil(vm.board[a.row][a.col].item)
    }

    func testTappingCompletedSubObjectInLockedCellDoesNothing() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .highTierDrop, at: a)
        vm.board[0][0].isUnlocked = false
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)

        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertNotNil(vm.board[a.row][a.col].item)
    }

    func testSecondTapOnCollectedCellPaysNothing() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .mapSupplies, at: a)
        let coinsBefore = vm.coins

        vm.boardCellTapped(at: a)
        let coinsAfterFirst = vm.coins
        vm.boardCellTapped(at: a)

        XCTAssertEqual(coinsAfterFirst, coinsBefore + SubObjectRarity.mapSupplies.coinValue)
        XCTAssertEqual(vm.coins, coinsAfterFirst, "the cell is empty now, so a second tap pays nothing")
    }

    func testCollectingClearsSelectionOnThatCell() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .speed, at: a)
        vm.selectedCell = a

        XCTAssertTrue(vm.collectCompletedSubObject(at: a))

        XCTAssertNil(vm.selectedCell)
    }

    func testCollectingLeavesSelectionOnAnotherCellAlone() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .speed, at: a)
        vm.selectedCell = b

        XCTAssertTrue(vm.collectCompletedSubObject(at: a))

        XCTAssertEqual(vm.selectedCell, b)
    }

    // MARK: drag hint — dropping a completed tile off-board collects it

    func testDragHintForCompletedSubObjectSaysDropCollectsCoins() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .highTierDrop, at: a)
        vm.draggingFrom = a

        let text = vm.selectedItemInfo?.text ?? ""

        XCTAssertTrue(text.contains("\(SubObjectRarity.highTierDrop.coinValue)"),
                      "hint must show the payout, got: \(text)")
        XCTAssertTrue(text.lowercased().contains("collect"), "got: \(text)")
        XCTAssertFalse(text.contains("storage"), "got: \(text)")
    }

    func testDragHintForCompletedSubObjectWithoutRarityShowsSpeedValue() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: nil, at: a)
        vm.draggingFrom = a

        let text = vm.selectedItemInfo?.text ?? ""

        XCTAssertTrue(text.contains("\(SubObjectRarity.speed.coinValue)"), "got: \(text)")
    }

    func testDragHintForNonCompletedItemStillSaysMoveToStorage() {
        let vm = makeViewModel()
        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        vm.draggingFrom = a

        XCTAssertEqual(vm.selectedItemInfo?.text, "Drag off-board to move to storage")
    }

    // MARK: send-to-storage — a completed tile is collected, not stored

    func testSendingCompletedSubObjectToStorageCollectsItInstead() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .mapSupplies, at: a)
        let coinsBefore = vm.coins

        vm.sendBoardItemToInventory(from: a)

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.mapSupplies.coinValue)
        XCTAssertNil(vm.board[a.row][a.col].item)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty,
                      "a completed sub-object is cashed in, never filed as an animal")
        XCTAssertTrue(vm.inventoryStore.powerUpInventory.allSatisfy { $0 == nil })
    }

    func testStoringSelectedCompletedSubObjectCollectsItInstead() {
        let vm = makeViewModel()
        placeCompleted(vm, rarity: .mapSupplies, at: a)
        let coinsBefore = vm.coins
        vm.selectedCell = a

        vm.storeSelectedItemToInventory()

        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.mapSupplies.coinValue)
        XCTAssertNil(vm.board[a.row][a.col].item)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty)
        XCTAssertTrue(vm.inventoryStore.powerUpInventory.allSatisfy { $0 == nil })
    }

    func testSendingTierTwoSubObjectToStorageStillGoesToAnimalInventory() {
        let vm = makeViewModel()
        place(vm, chainID: dogSubObjectChain, tier: 2, at: a)
        let coinsBefore = vm.coins

        vm.sendBoardItemToInventory(from: a)

        XCTAssertNil(vm.board[a.row][a.col].item)
        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertEqual(vm.inventoryStore.inventory.compactMap { $0 }.count, 1)
    }

    // MARK: sweepStoredGoldenBalls — cashing balls an old save left in animal storage

    private func storeBall(_ vm: MergeBoardViewModel, chainID: ChainID? = nil, count: Int = 1,
                           rarity: SubObjectRarity? = .speed, tier: Int = 3, from start: Int = 0) {
        for i in 0..<count {
            vm.inventoryStore.inventory[start + i] =
                BoardItem(chainID: chainID ?? dogSubObjectChain, tier: tier, rarity: rarity)
        }
    }

    private var fiveSlotTotal: Int { 5 * trophySlotCoins + trophyPageBonusCoins }

    func testSweepPaysTrophySlotsInOrderAndClearsStorage() {
        let vm = makeViewModel()
        storeBall(vm, count: 3)
        let coinsBefore = vm.coins

        let paid = vm.sweepStoredGoldenBalls()

        XCTAssertEqual(paid, 3 * trophySlotCoins)
        XCTAssertEqual(vm.trophyCounts["dog"], 3)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty)
        XCTAssertEqual(vm.coins, coinsBefore + paid)
    }

    func testSweepFifthSlotPaysThePageBonus() {
        let vm = makeViewModel()
        storeBall(vm, count: 5)

        XCTAssertEqual(vm.sweepStoredGoldenBalls(), fiveSlotTotal)
        XCTAssertEqual(vm.trophyCounts["dog"], trophySlotsPerFamily)
    }

    func testSweepSixthBallPaysItsRarityValue() {
        let vm = makeViewModel()
        storeBall(vm, count: 6)

        XCTAssertEqual(vm.sweepStoredGoldenBalls(), fiveSlotTotal + SubObjectRarity.speed.coinValue)
        XCTAssertEqual(vm.trophyCounts["dog"], 5)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty)
    }

    func testSweepBallWithNoRarityIsLeftAlone() {
        let vm = makeViewModel()
        storeBall(vm, rarity: nil)

        XCTAssertEqual(vm.sweepStoredGoldenBalls(), 0)
        XCTAssertEqual(vm.inventoryStore.inventory.compactMap { $0 }.count, 1)
    }

    func testSweepKeepsFamiliesOnSeparatePages() {
        let vm = makeViewModel()
        storeBall(vm, count: 2)
        storeBall(vm, chainID: "subobject.cat", from: 2)

        vm.sweepStoredGoldenBalls()

        XCTAssertEqual(vm.trophyCounts[AnimalSpecies.dog.rawValue], 2)
        XCTAssertEqual(vm.trophyCounts[AnimalSpecies.cat.rawValue], 1)
    }

    func testSweepLeavesAnimalsSuperpowerPiecesAndLowerTiersAlone() {
        let vm = makeViewModel()
        guard let active = AnimalSpecies.allCases.first(where: { $0.superpower.isActive }) else {
            return XCTFail("no species has an active superpower")
        }
        vm.inventoryStore.inventory[0] = BoardItem(chainID: "dog", tier: 2)
        vm.inventoryStore.inventory[1] = BoardItem(chainID: dogSubObjectChain, tier: 2)
        vm.inventoryStore.inventory[2] = BoardItem(chainID: ContentRegistry.superpowerChainID(active), tier: 0)
        let coinsBefore = vm.coins

        XCTAssertEqual(vm.sweepStoredGoldenBalls(), 0)
        XCTAssertEqual(vm.inventoryStore.inventory.compactMap { $0 }.count, 3)
        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertTrue(vm.trophyCounts.isEmpty)
    }

    func testSweepTwiceDoesNotPayTwice() {
        let vm = makeViewModel()
        storeBall(vm, count: 3)
        vm.sweepStoredGoldenBalls()
        let coinsAfterFirst = vm.coins

        XCTAssertEqual(vm.sweepStoredGoldenBalls(), 0)
        XCTAssertEqual(vm.coins, coinsAfterFirst)
        XCTAssertEqual(vm.trophyCounts["dog"], 3)
    }

    func testSweepWithEmptyStorageShowsNoToastAndPaysNothing() {
        let vm = makeViewModel()
        let toastsBefore = vm.toastQueue.count
        let coinsBefore = vm.coins

        XCTAssertEqual(vm.sweepStoredGoldenBalls(), 0)
        XCTAssertEqual(vm.toastQueue.count, toastsBefore)
        XCTAssertEqual(vm.coins, coinsBefore)
    }

    func testSweepToastNamesCountAndCoins() {
        let vm = makeViewModel()
        storeBall(vm, count: 3)

        let paid = vm.sweepStoredGoldenBalls()

        guard let toast = vm.toastQueue.last, case .info(let text) = toast.kind else {
            return XCTFail("expected an info toast")
        }
        XCTAssertTrue(text.contains("3 stored Golden Balls"), text)
        XCTAssertTrue(text.contains("+\(paid) coins"), text)
    }

    func testSweepToastIsSingularForOneBall() {
        let vm = makeViewModel()
        storeBall(vm, count: 1)

        vm.sweepStoredGoldenBalls()

        guard let toast = vm.toastQueue.last, case .info(let text) = toast.kind else {
            return XCTFail("expected an info toast")
        }
        XCTAssertTrue(text.contains("1 stored Golden Ball:"), text)
    }

    func testSweepBallOfAnUnresolvableFamilyIsCashedAtItsRarityValue() {
        // "subobject.unknownspecies" still has the subobject. prefix and a rarity,
        // so the sweep treats it as a completed ball; no AnimalSpecies matches,
        // so it skips the Trophy page and pays the rarity value.
        let vm = makeViewModel()
        storeBall(vm, chainID: "subobject.unknownspecies", rarity: .speed)
        let coinsBefore = vm.coins

        let paid = vm.sweepStoredGoldenBalls()

        XCTAssertEqual(paid, SubObjectRarity.speed.coinValue)
        XCTAssertEqual(vm.coins, coinsBefore + SubObjectRarity.speed.coinValue)
        XCTAssertTrue(vm.inventoryStore.inventory.compactMap { $0 }.isEmpty)
        XCTAssertTrue(vm.trophyCounts.isEmpty)
    }

    // MARK: loadGame runs the sweep (the production path)

    /// A save written by an older build: one completed dog ball in animal storage.
    private func saveWithStoredBall(lastWeeklyReset: Date? = nil) -> Int {
        let vm = makeViewModel()
        storeBall(vm, count: 1)
        if let lastWeeklyReset { vm.lastWeeklyGoalReset = lastWeeklyReset }
        vm.persistNow()
        return vm.coins
    }

    func testLoadGameCashesABallAnOldSaveLeftInAnimalStorage() {
        let savedCoins = saveWithStoredBall()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertTrue(relaunched.inventoryStore.inventory.compactMap { $0 }.isEmpty)
        XCTAssertEqual(relaunched.coins, savedCoins + trophySlotCoins)
        XCTAssertEqual(relaunched.trophyCounts["dog"], 1)
        XCTAssertTrue(relaunched.toastQueue.contains { toast in
            if case .info(let text) = toast.kind { return text.contains("1 stored Golden Ball") }
            return false
        })
    }

    func testLoadGameSweepPayoutCountsTowardTheCurrentWeekNotTheOneJustEnded() {
        // The save's last weekly reset was two weeks ago, so loadGame zeroes
        // coinsEarnedThisWeek. The sweep must pay after that, or its coins land
        // in last week's total and are wiped.
        let twoWeeksAgo = Date().addingTimeInterval(-14 * 24 * 3600)
        _ = saveWithStoredBall(lastWeeklyReset: twoWeeksAgo)

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()

        XCTAssertEqual(relaunched.coinsEarnedThisWeek, trophySlotCoins)
    }

    func testFreshStartPaysNothingAndShowsNoSweepToast() {
        let vm = MergeBoardViewModel()
        vm.loadGame()

        XCTAssertTrue(vm.trophyCounts.isEmpty)
        XCTAssertFalse(vm.toastQueue.contains { toast in
            if case .info(let text) = toast.kind { return text.contains("Golden Ball") }
            return false
        })
    }
}
