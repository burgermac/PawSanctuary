//
//  FrictionCoachMarkTests.swift
//  PawSanctuaryTests
//
//  Context tutorial, task 4.3 stage 4 (specs/Spec_ContextTutorial.md §4.2 M8 to
//  M12, §5): the first friction moments as the view model drives them. The
//  bubbles and the in-sheet line are checked on the Simulator.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class FrictionCoachMarkTests: XCTestCase {

    private let completedKey = "tutorialCompleted"
    private let nudgeKey = "hasShownSellVsOrderNudge"
    private let dog = ContentRegistry.animalChainID(.dog)

    override func setUp() {
        super.setUp()
        GameStore.clear()
        let completedKey = self.completedKey, nudgeKey = self.nudgeKey
        let d = UserDefaults.standard
        let savedCompleted = d.object(forKey: completedKey) as? Bool
        let savedNudge = d.object(forKey: nudgeKey) as? Bool
        addTeardownBlock {
            let d = UserDefaults.standard
            if let v = savedCompleted { d.set(v, forKey: completedKey) } else { d.removeObject(forKey: completedKey) }
            if let v = savedNudge { d.set(v, forKey: nudgeKey) } else { d.removeObject(forKey: nudgeKey) }
        }
        d.removeObject(forKey: completedKey)
        d.removeObject(forKey: nudgeKey)
    }

    override func tearDown() {
        GameStore.clear()
        super.tearDown()
    }

    // MARK: Helpers

    /// A game past the opening tips with an empty board and no orders. M12 is
    /// marked seen so an empty board does not bring it (each test that is about
    /// M12 clears that mark itself).
    private func game() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.skipTutorialTips()
        vm.markTutorialMomentSeen(.noMergesLeft)
        vm.adoptionOrders = []
        vm.adoptionBoardCoordinator.urgentOrder = nil
        clearItems(vm)
        return vm
    }

    private func clearItems(_ vm: MergeBoardViewModel) {
        var board = vm.board
        for r in board.indices { for c in board[r].indices { board[r][c].item = nil } }
        vm.board = board
        vm.boardState.recalc()
    }

    private func place(_ vm: MergeBoardViewModel, _ item: BoardItem, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = item
        vm.board = board
        vm.boardState.recalc()
    }

    private func emptyCells(_ vm: MergeBoardViewModel, _ n: Int) -> [GridPosition] {
        var found: [GridPosition] = []
        for row in vm.board {
            for cell in row where cell.isUnlocked && cell.item == nil && cell.producer == nil {
                if found.count == n { return found }
                found.append(cell.position)
            }
        }
        return found
    }

    private func spawnerPosition(_ vm: MergeBoardViewModel) -> GridPosition? {
        for row in vm.board { for cell in row where cell.producer?.level == .familySpawner { return cell.position } }
        return nil
    }

    /// Fills every empty cell with a different low-tier animal so no pair exists.
    private func fillTheBoard(_ vm: MergeBoardViewModel) {
        // Every cell gets its own species and tier, so no two animals match.
        var combos: [(AnimalSpecies, Int)] = []
        for tier in 0..<12 { for species in AnimalSpecies.allCases { combos.append((species, tier)) } }
        for (pos, combo) in zip(emptyCells(vm, 500), combos) {
            place(vm, BoardItem(chainID: ContentRegistry.animalChainID(combo.0), tier: combo.1), at: pos)
        }
    }

    private func next(_ vm: MergeBoardViewModel, covered: Bool = false, now: Date = Date()) -> TutorialMoment? {
        vm.nextCoachMark(isCoveredByOtherUI: covered, now: now)
    }

    private func restSpawner(_ vm: MergeBoardViewModel, at pos: GridPosition) throws {
        var tile = try XCTUnwrap(vm.boardState.producer(at: pos))
        tile.readyAt = Date().addingTimeInterval(30)
        vm.boardState.setProducer(tile, at: pos)
    }

    // MARK: M8, board full

    func testTheBoardFullToastBringsTheBoardFullTip() {
        let vm = game()
        XCTAssertNil(next(vm))
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
    }

    func testNoBoardFullTipWithoutTheToast() {
        let vm = game()
        fillTheBoard(vm)
        XCTAssertNil(next(vm), "a full board alone is not the moment; the failed spawn is")
    }

    func testTappingTheSpawnerOnAFullBoardBringsTheBoardFullTip() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.kibble = 500
        fillTheBoard(vm)
        vm.activateProducer(at: spawner)
        XCTAssertEqual(next(vm), .boardFull)
    }

    func testTheBoardFullTipPointsAtTheBasketNotACell() {
        XCTAssertEqual(TutorialMoment.boardFull.target, .basketButton)
        let vm = game()
        vm.triggerToast(.boardFull)
        XCTAssertTrue(vm.coachMarkCells(for: .boardFull).isEmpty)
    }

    func testAMergeClosesTheBoardFullTipAndMarksItSeen() {
        let vm = game()
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
        let cells = emptyCells(vm, 2)
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[1])
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertTrue(vm.hasSeenTutorialMoment(.boardFull))
        XCTAssertNotEqual(next(vm), .boardFull)
    }

    func testSellingClosesTheBoardFullTip() {
        let vm = game()
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.selectedCell = cell
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
        vm.selectedCell = cell
        vm.sellSelectedAnimal()
        XCTAssertTrue(vm.hasSeenTutorialMoment(.boardFull))
    }

    func testTheCrossClosesTheBoardFullTipForGood() {
        let vm = game()
        vm.triggerToast(.boardFull)
        vm.closeCoachMark(.boardFull)
        XCTAssertNil(next(vm))
        vm.triggerToast(.boardFull)
        XCTAssertNil(next(vm), "seen once, never again")
    }

    func testAMergeBeforeTheBoardEverFillsDoesNotUseUpTheBoardFullTip() {
        let vm = game()
        let cells = emptyCells(vm, 2)
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[1])
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertFalse(vm.hasSeenTutorialMoment(.boardFull))
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
    }

    func testTheBoardFullTipWaitsOutTheGapAfterAnotherTip() {
        let vm = game()
        let now = Date()
        vm.closeCoachMark(.toolbox, now: now)   // some other tip just closed
        vm.triggerToast(.boardFull)
        XCTAssertNil(next(vm, now: now.addingTimeInterval(1)), "inside the 20 s gap")
    }

    // MARK: M9, first item stored

    func testStoringAnAnimalBringsTheStoredTip() {
        let vm = game()
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.sendBoardItemToInventory(from: cell)
        XCTAssertEqual(next(vm), .firstItemStored)
        XCTAssertEqual(TutorialMoment.firstItemStored.target, .basketButton)
    }

    func testStoringFromTheInfoBarBringsTheStoredTipToo() {
        let vm = game()
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.selectedCell = cell
        vm.storeSelectedItemToInventory()
        XCTAssertEqual(next(vm), .firstItemStored)
    }

    func testTheStoredTipClosesItselfAfterFiveSecondsAndShowsOnce() {
        XCTAssertEqual(TutorialMoment.firstItemStored.autoCloseSeconds, 5)
        let vm = game()
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.sendBoardItemToInventory(from: cell)
        vm.closeCoachMark(.firstItemStored)
        XCTAssertNil(next(vm))
        let again = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 2), at: again)
        vm.sendBoardItemToInventory(from: again)
        XCTAssertNil(next(vm), "seen once, never again")
    }

    func testStoringWhileTheBoardFullTipIsUpFinishesItAndHandsOverToTheStoredTip() {
        let vm = game()
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
        vm.sendBoardItemToInventory(from: cell)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.boardFull))
        XCTAssertEqual(next(vm), .firstItemStored, "the stored tip follows at once, without the gap")
    }

    func testAFailedStoreShowsNoStoredTip() {
        let vm = game()
        let cell = emptyCells(vm, 1)[0]
        // Fill the storage so the store is refused.
        while vm.inventoryStore.addItem(BoardItem(chainID: dog, tier: 0)) {}
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.sendBoardItemToInventory(from: cell)
        XCTAssertNotEqual(next(vm), .firstItemStored)
    }

    // MARK: M10, a resting spawner

    func testTappingARestingSpawnerBeforeTheGateBringsTheRestingTipAtThatSpawner() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        try restSpawner(vm, at: spawner)
        XCTAssertFalse(vm.isMonetizationUnlocked)
        vm.activateProducer(at: spawner)
        XCTAssertEqual(next(vm), .spawnerResting)
        XCTAssertEqual(vm.coachMarkCells(for: .spawnerResting), [spawner])
    }

    func testTappingAReadySpawnerBringsNoRestingTip() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.kibble = 500
        vm.activateProducer(at: spawner)
        XCTAssertNotEqual(next(vm), .spawnerResting)
    }

    func testTheRestingTipNeverFiresOnceTheGateIsOpen() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel
        XCTAssertTrue(vm.isMonetizationUnlocked, "test setup: the gate is open")
        try restSpawner(vm, at: spawner)
        vm.activateProducer(at: spawner)
        XCTAssertNotEqual(next(vm), .spawnerResting)
        XCTAssertFalse(vm.hasSeenTutorialMoment(.spawnerResting))
    }

    func testTheRestingTipVanishesIfTheGateOpensWhileItIsUp() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        try restSpawner(vm, at: spawner)
        vm.activateProducer(at: spawner)
        XCTAssertEqual(next(vm), .spawnerResting)
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel
        XCTAssertNotEqual(next(vm), .spawnerResting)
    }

    func testTheRestingTipIsShownOnceAndClosesItself() throws {
        XCTAssertEqual(TutorialMoment.spawnerResting.autoCloseSeconds, 5)
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        try restSpawner(vm, at: spawner)
        vm.activateProducer(at: spawner)
        vm.closeCoachMark(.spawnerResting)
        vm.activateProducer(at: spawner)
        XCTAssertNil(next(vm))
    }

    func testTheRestingTipTextNeverSaysSkipOrSpend() throws {
        let text = try XCTUnwrap(TutorialMoment.spawnerResting.coachMarkText).lowercased()
        XCTAssertTrue(text.contains("resting"))
        for word in ["skip", "dog tag", "spend", "pay"] { XCTAssertFalse(text.contains(word), word) }
    }

    // MARK: M11, out of kibble

    func testRunningOutOfKibbleOpensTheSheetAndOffersTheLineOnce() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.kibble = 0
        XCTAssertTrue(vm.showsOutOfKibbleTip)
        vm.activateProducer(at: spawner)
        XCTAssertTrue(vm.showKibbleSheet)
        XCTAssertTrue(vm.showsOutOfKibbleTip)
        vm.closeCoachMark(.outOfKibble)          // the sheet closing
        XCTAssertFalse(vm.showsOutOfKibbleTip)
    }

    func testTheOutOfKibbleTipIsNeverAnOverlayBubble() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.kibble = 0
        vm.activateProducer(at: spawner)
        XCTAssertNotEqual(next(vm), .outOfKibble, "it lives inside the sheet")
        XCTAssertNotEqual(next(vm, covered: true), .outOfKibble)
    }

    func testTheOutOfKibbleTipPointsOnlyAtTheOrderFooterEvenWhenTheSameTapOpensTheGate() throws {
        let vm = game()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.progression.playerLevel = monetizationUnlockLevel
        vm.kibble = 0
        XCTAssertFalse(vm.isMonetizationUnlocked, "the wall has not been hit yet")
        vm.activateProducer(at: spawner)
        XCTAssertTrue(vm.isMonetizationUnlocked, "this tap opened the gate")
        XCTAssertTrue(vm.showsOutOfKibbleTip)
        XCTAssertEqual(TutorialMoment.outOfKibble.target, .refillOrderFooter)
        XCTAssertFalse(TutorialMoment.outOfKibble.target.isPaidSurface)
    }

    func testTheOutOfKibbleLineUsesTheSpecsWordsAndNamesNoPurchase() throws {
        let text = try XCTUnwrap(TutorialMoment.outOfKibble.coachMarkText)
        XCTAssertEqual(text, "Kibble refills on its own. Meanwhile, merge what you have or deliver an order.")
    }

    func testAnOldSaveThatAlreadyHitTheWallSeesNoOutOfKibbleLine() {
        let vm = game()
        vm.markTutorialMomentSeen(.outOfKibble)
        XCTAssertFalse(vm.showsOutOfKibbleTip)
    }

    // MARK: M12, no merges left

    private func gameWithMergesLeftUnseen() -> MergeBoardViewModel {
        let vm = game()
        vm.seenTutorialMoments.removeAll { $0 == TutorialMoment.noMergesLeft.rawValue }
        vm.kibble = 500
        return vm
    }

    func testABoardWithNoPairAndAReadySpawnerBringsTheNoMergesTipAtTheSpawner() throws {
        let vm = gameWithMergesLeftUnseen()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 0), at: cell)
        XCTAssertNil(vm.findMergeableHintPair())
        XCTAssertEqual(next(vm), .noMergesLeft)
        XCTAssertEqual(vm.coachMarkCells(for: .noMergesLeft), [spawner])
    }

    func testAPairOnTheBoardMeansNoNoMergesTip() {
        let vm = gameWithMergesLeftUnseen()
        let cells = emptyCells(vm, 2)
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[1])
        XCTAssertNotNil(vm.findMergeableHintPair())
        XCTAssertNotEqual(next(vm), .noMergesLeft)
    }

    func testNoNoMergesTipWithoutKibbleToSpawn() {
        let vm = gameWithMergesLeftUnseen()
        vm.kibble = 0
        XCTAssertNotEqual(next(vm), .noMergesLeft)
    }

    func testNoNoMergesTipWhileTheSpawnerIsResting() throws {
        let vm = gameWithMergesLeftUnseen()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        try restSpawner(vm, at: spawner)
        XCTAssertNotEqual(next(vm), .noMergesLeft)
    }

    func testNoNoMergesTipOnAFullBoardWhereASpawnCannotLand() {
        let vm = gameWithMergesLeftUnseen()
        fillTheBoard(vm)
        XCTAssertNil(vm.findMergeableHintPair())
        XCTAssertNotEqual(next(vm), .noMergesLeft)
    }

    func testASpawnWhileTheNoMergesTipIsUpClosesItForGood() throws {
        let vm = gameWithMergesLeftUnseen()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        place(vm, BoardItem(chainID: dog, tier: 0), at: emptyCells(vm, 1)[0])
        XCTAssertEqual(next(vm), .noMergesLeft)
        vm.activateProducer(at: spawner)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.noMergesLeft))
    }

    func testASpawnThatHappensInsideTheGapDoesNotUseUpTheNoMergesTip() throws {
        let vm = gameWithMergesLeftUnseen()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        place(vm, BoardItem(chainID: dog, tier: 0), at: emptyCells(vm, 1)[0])
        vm.closeCoachMark(.toolbox)             // a tip just closed: the gap is running
        XCTAssertNil(next(vm))
        vm.activateProducer(at: spawner)
        XCTAssertFalse(vm.hasSeenTutorialMoment(.noMergesLeft), "it was never shown")
    }

    // MARK: Order, gap and wording

    func testOnlyOneFrictionTipShowsAtATimeAndABusyCoreTipWins() {
        let vm = game()
        vm.seenTutorialMoments.removeAll { $0 == TutorialMoment.firstQuestClaim.rawValue }
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
    }

    func testAnotherTipClosingDropsAQueuedFrictionTip() {
        let vm = game()
        vm.triggerToast(.boardFull)
        vm.closeCoachMark(.toolbox)             // some other tip closes first
        XCTAssertNotEqual(next(vm, now: Date().addingTimeInterval(60)), .boardFull,
                          "the moment passed: it is dropped, not shown 20 s late")
        XCTAssertFalse(vm.hasSeenTutorialMoment(.boardFull), "and not used up either")
    }

    func testADroppedFrictionTipFiresOnTheNextEventOnceTheGapHasRunOut() {
        let vm = game()
        let long = Date().addingTimeInterval(-3600)
        vm.closeCoachMark(.toolbox, now: long)   // closed an hour ago
        vm.triggerToast(.boardFull)
        XCTAssertEqual(next(vm), .boardFull)
    }

    func testNothingShowsWhileAnotherScreenCoversTheBoard() {
        let vm = game()
        vm.triggerToast(.boardFull)
        XCTAssertNil(next(vm, covered: true))
        XCTAssertEqual(next(vm, covered: false), .boardFull)
    }

    func testTheFrictionTipsUseTheSpecsWording() {
        XCTAssertEqual(TutorialMoment.boardFull.coachMarkText,
                       "No room left. Merge a pair, drag an animal to the basket to store it, or sell one from the info bar.")
        XCTAssertEqual(TutorialMoment.firstItemStored.coachMarkText,
                       "Stored animals are safe in the basket, but orders and daily tasks only count animals on the board.")
        XCTAssertEqual(TutorialMoment.noMergesLeft.coachMarkText,
                       "No matching pairs right now. Tap the spawner for more animals.")
    }

    func testNoFrictionTipTextMentionsAPaidThing() {
        let paid = ["shop", "buy", "dog tag", "skip", "watch", "offer", "pass", "$", "kibble drive"]
        for m in [TutorialMoment.boardFull, .firstItemStored, .spawnerResting, .outOfKibble, .noMergesLeft] {
            let text = (m.coachMarkText ?? "").lowercased()
            XCTAssertFalse(text.isEmpty, "\(m) has text")
            for word in paid { XCTAssertFalse(text.contains(word), "\(m) mentions \(word)") }
        }
    }
}
