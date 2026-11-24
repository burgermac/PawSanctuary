//
//  FeatureCoachMarkTests.swift
//  PawSanctuaryTests
//
//  Context tutorial, task 4.3 stage 5 (specs/Spec_ContextTutorial.md §4.2 M13 to
//  M20, §5, §7): the feature-discovery tips as the view model drives them. The
//  bubbles themselves are checked on the Simulator.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class FeatureCoachMarkTests: XCTestCase {

    private let completedKey = "tutorialCompleted"
    private let nudgeKey = "hasShownSellVsOrderNudge"
    private let dog = ContentRegistry.animalChainID(.dog)
    private let cat = ContentRegistry.animalChainID(.cat)

    /// Every stage-5 moment that can show as a bubble. A test about one of them
    /// leaves that one unseen and marks the rest, so a fresh game's ready chest
    /// or starting toolbox does not get in the way.
    private let bubbleFeatures: [TutorialMoment] = [
        .chainViewer, .firstDailyHandIn, .toolbox, .mapAreaAffordable,
        .firstCardPack, .freeChest, .firstBubble,
    ]

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

    /// A game past the opening tips with an empty board, no orders, and every
    /// stage-5 bubble moment seen except `testing`.
    private func game(testing moment: TutorialMoment? = nil) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.skipTutorialTips()
        vm.markTutorialMomentSeen(.noMergesLeft)
        for m in bubbleFeatures where m != moment { vm.markTutorialMomentSeen(m) }
        vm.adoptionOrders = []
        vm.adoptionBoardCoordinator.urgentOrder = nil
        clearItems(vm)
        // The fresh game's chest is ready from the start; tests that are not about it rest it.
        vm.freeChestReadyAt = Date().addingTimeInterval(3_600)
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
        // A plain loop: chained closures time out the type checker on CI's Xcode.
        var found: [GridPosition] = []
        for row in vm.board {
            for cell in row where cell.isUnlocked && cell.item == nil && cell.producer == nil {
                if found.count == n { return found }
                found.append(cell.position)
            }
        }
        return found
    }

    /// D7's gate: a felt wall and the unlock level.
    private func openTheGate(_ vm: MergeBoardViewModel) {
        vm.commerce.hasReachedFirstWall = true
        vm.progression.playerLevel = monetizationUnlockLevel
        XCTAssertTrue(vm.isMonetizationUnlocked)
    }

    private func next(_ vm: MergeBoardViewModel, covered: Bool = false, now: Date = Date()) -> TutorialMoment? {
        vm.nextCoachMark(isCoveredByOtherUI: covered, now: now)
    }

    // MARK: M13, the chain viewer

    func testSelectingAnAnimalAfterTheFirstMergeBringsTheChainViewerTip() {
        let vm = game(testing: .chainViewer)
        vm.mergeCount = 1
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        XCTAssertNil(next(vm), "nothing is selected yet")
        vm.selectedCell = cell
        XCTAssertEqual(next(vm), .chainViewer)
        XCTAssertEqual(TutorialMoment.chainViewer.target, .chainInfoButton)
    }

    func testTheChainViewerTipWaitsForTheFirstMerge() {
        let vm = game(testing: .chainViewer)
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.selectedCell = cell
        XCTAssertNil(next(vm), "M13 comes after M2")
        vm.mergeCount = 1
        XCTAssertEqual(next(vm), .chainViewer)
    }

    func testASpawnerSelectionHasNoChainViewerTip() throws {
        let vm = game(testing: .chainViewer)
        vm.mergeCount = 1
        var spawner: GridPosition?
        for row in vm.board { for cell in row where cell.producer?.level == .familySpawner { spawner = cell.position } }
        vm.selectedCell = try XCTUnwrap(spawner)
        XCTAssertNil(next(vm), "a spawner has no chain to view")
    }

    func testOpeningTheChainViewerClosesTheTipForGood() {
        let vm = game(testing: .chainViewer)
        vm.mergeCount = 1
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.selectedCell = cell
        vm.noteChainViewerOpened()
        XCTAssertTrue(vm.hasSeenTutorialMoment(.chainViewer))
        XCTAssertNil(next(vm))
    }

    func testTheChainViewerTipIsDroppedNotMarkedWhenTheSelectionGoes() {
        let vm = game(testing: .chainViewer)
        vm.mergeCount = 1
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 1), at: cell)
        vm.selectedCell = cell
        XCTAssertEqual(next(vm), .chainViewer)
        vm.selectedCell = nil
        XCTAssertNil(next(vm))
        XCTAssertFalse(vm.hasSeenTutorialMoment(.chainViewer))
    }

    // MARK: M14, the first daily hand-in

    private func stockedDailyTask(_ vm: MergeBoardViewModel, onBoard: Bool) -> DailyChallenge {
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                                  difficulty: .easy, coinReward: 10)
        vm.quests.dailyChallenges = [task]
        if onBoard { place(vm, BoardItem(chainID: dog, tier: 0), at: emptyCells(vm, 1)[0]) }
        return task
    }

    func testAStockedDailyTaskBringsTheHandInTip() {
        let vm = game(testing: .firstDailyHandIn)
        let task = stockedDailyTask(vm, onBoard: true)
        XCTAssertEqual(next(vm), .firstDailyHandIn)
        XCTAssertEqual(vm.coachMarkOrderID(for: .firstDailyHandIn), task.id,
                       "the lane scrolls to this card")
        XCTAssertEqual(TutorialMoment.firstDailyHandIn.target, .dailyTaskClaim)
    }

    func testAShortDailyTaskBringsNoHandInTip() {
        let vm = game(testing: .firstDailyHandIn)
        _ = stockedDailyTask(vm, onBoard: false)
        XCTAssertNil(next(vm), "the animals are not all on the board")
    }

    func testAStoredAnimalDoesNotStockADailyTask() {
        let vm = game(testing: .firstDailyHandIn)
        _ = stockedDailyTask(vm, onBoard: true)
        clearItems(vm)
        XCTAssertNil(next(vm))
    }

    func testClaimingADailyTaskClosesTheHandInTip() {
        let vm = game(testing: .firstDailyHandIn)
        let task = stockedDailyTask(vm, onBoard: true)
        XCTAssertEqual(next(vm), .firstDailyHandIn)
        vm.claimDailyTask(id: task.id)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstDailyHandIn))
    }

    func testARefusedDailyClaimDoesNotUseUpTheTip() {
        let vm = game(testing: .firstDailyHandIn)
        let task = stockedDailyTask(vm, onBoard: false)
        vm.claimDailyTask(id: task.id)
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstDailyHandIn))
    }

    // MARK: M15, the toolbox

    func testAToolboxOnTheBoardBringsTheToolboxTip() {
        let vm = game(testing: .toolbox)
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: ContentRegistry.toolboxChainID, tier: 0), at: cell)
        XCTAssertEqual(next(vm), .toolbox)
        XCTAssertEqual(vm.coachMarkCells(for: .toolbox), [cell])
        XCTAssertEqual(TutorialMoment.toolbox.target, .toolboxCell)
    }

    func testNoToolboxTipWithoutAToolbox() {
        let vm = game(testing: .toolbox)
        XCTAssertNil(next(vm))
        XCTAssertTrue(vm.coachMarkCells(for: .toolbox).isEmpty)
    }

    func testAbsorbingAToolboxClosesTheToolboxTip() {
        let vm = game(testing: .toolbox)
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: ContentRegistry.toolboxChainID, tier: 0), at: cell)
        vm.absorbToolbox(at: cell)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.toolbox))
    }

    func testTheFreshGamesOwnToolboxBringsTheTipAfterTheOpeningTips() {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.skipTutorialTips()
        vm.markTutorialMomentSeen(.noMergesLeft)
        vm.markTutorialMomentSeen(.freeChest)
        // The day's tasks are random: one may already be stocked by the first animals.
        vm.markTutorialMomentSeen(.firstDailyHandIn)
        XCTAssertEqual(next(vm), .toolbox, "a new game places a toolbox on the board")
    }

    // MARK: M16, a Sanctuary area becomes affordable

    private func makeFirstAreaAffordable(_ vm: MergeBoardViewModel) {
        vm.inventoryStore.materialCounts[ContentRegistry.woodChainID] = [0, 0, 0, 0, 0, 2]
    }

    func testAffordingTheNextAreaBringsTheMapTip() {
        let vm = game(testing: .mapAreaAffordable)
        XCTAssertNil(next(vm))
        makeFirstAreaAffordable(vm)
        XCTAssertEqual(next(vm), .mapAreaAffordable)
        XCTAssertEqual(TutorialMoment.mapAreaAffordable.target, .mapButton)
    }

    func testOpeningTheMapWhileAffordableClosesTheMapTip() {
        let vm = game(testing: .mapAreaAffordable)
        makeFirstAreaAffordable(vm)
        vm.noteMapOpened()
        XCTAssertTrue(vm.hasSeenTutorialMoment(.mapAreaAffordable))
    }

    func testOpeningTheMapBeforeAnythingIsAffordableKeepsTheTip() {
        let vm = game(testing: .mapAreaAffordable)
        vm.noteMapOpened()
        XCTAssertFalse(vm.hasSeenTutorialMoment(.mapAreaAffordable),
                       "looking at the map early must not use up 'you can build now'")
        makeFirstAreaAffordable(vm)
        XCTAssertEqual(next(vm), .mapAreaAffordable)
    }

    func testABuiltAreaIsNotAffordableAgain() {
        let vm = game(testing: .mapAreaAffordable)
        makeFirstAreaAffordable(vm)
        vm.completedAreaIDs.append("area.welcome")
        XCTAssertNotEqual(next(vm), .mapAreaAffordable,
                          "the first area is built; the next one needs its own materials")
    }

    // MARK: M17, the first card pack

    func testEarningACardPackBringsTheCardPackTip() {
        let vm = game(testing: .firstCardPack)
        XCTAssertNil(next(vm))
        vm.earnCardPack(.star1)
        XCTAssertEqual(next(vm), .firstCardPack)
        XCTAssertEqual(TutorialMoment.firstCardPack.target, .mapButton)
    }

    func testOpeningAPackClosesTheCardPackTip() {
        let vm = game(testing: .firstCardPack)
        vm.earnCardPack(.star1)
        vm.openNextCardPack()
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstCardPack))
    }

    func testOpeningThePackQueueWhenItIsEmptyUsesNothingUp() {
        let vm = game(testing: .firstCardPack)
        vm.openNextCardPack()
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstCardPack))
    }

    // MARK: M18, the free chest

    func testAReadyChestBringsTheChestTip() {
        let vm = game(testing: .freeChest)
        vm.freeChestReadyAt = Date().addingTimeInterval(-1)
        XCTAssertEqual(next(vm), .freeChest)
        XCTAssertEqual(TutorialMoment.freeChest.target, .freeChestTile)
    }

    func testARestingChestNeverBringsTheChestTip() {
        let vm = game(testing: .freeChest)
        vm.freeChestReadyAt = Date().addingTimeInterval(600)
        XCTAssertNil(next(vm), "M18 never points at a resting chest")
        openTheGate(vm)
        XCTAssertNil(next(vm), "not even once the skip is for sale")
    }

    func testAFreshGameStartsWithAReadyChest() {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        XCTAssertTrue(vm.isFreeChestReady)
    }

    func testClaimingTheChestClosesTheChestTip() {
        let vm = game(testing: .freeChest)
        vm.freeChestReadyAt = Date().addingTimeInterval(-1)
        XCTAssertTrue(vm.claimOrSkipFreeChest())
        XCTAssertTrue(vm.hasSeenTutorialMoment(.freeChest))
    }

    func testARefusedEarlyOpenDoesNotUseUpTheChestTip() {
        let vm = game(testing: .freeChest)
        vm.freeChestReadyAt = Date().addingTimeInterval(600)
        XCTAssertFalse(vm.claimOrSkipFreeChest())
        XCTAssertFalse(vm.hasSeenTutorialMoment(.freeChest))
    }

    // MARK: M19, the first bubble

    private func placeBubble(_ vm: MergeBoardViewModel, age: Double = 5) -> GridPosition {
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 5), at: cell)
        vm.boardState.setBubbledAt(Date().timeIntervalSince1970 - age, at: cell)
        return cell
    }

    func testABubbledAnimalBringsTheBubbleTipOnItsCell() {
        let vm = game(testing: .firstBubble)
        XCTAssertNil(next(vm))
        let cell = placeBubble(vm)
        XCTAssertEqual(next(vm), .firstBubble)
        XCTAssertEqual(vm.coachMarkCells(for: .firstBubble), [cell])
        XCTAssertEqual(TutorialMoment.firstBubble.target, .bubbledCell,
                       "the cell, never the pop sheet")
    }

    func testADecayedBubbleBringsNoBubbleTip() {
        let vm = game(testing: .firstBubble)
        _ = placeBubble(vm, age: bubbleDecaySeconds + 5)
        XCTAssertNil(next(vm), "a decayed bubble is only waiting to be collected for coins")
    }

    func testMergingOntoTheBubbleClosesTheBubbleTip() {
        let vm = game(testing: .firstBubble)
        let bubble = placeBubble(vm)
        let partner = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 5), at: partner)
        XCTAssertEqual(next(vm), .firstBubble)
        vm.attemptMergeOrMove(from: partner, to: bubble)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstBubble))
    }

    func testCollectingADecayedBubbleClosesTheBubbleTip() {
        let vm = game(testing: .firstBubble)
        let cell = placeBubble(vm, age: bubbleDecaySeconds + 5)
        vm.boardCellTapped(at: cell)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstBubble))
    }

    func testAnOrdinaryMergeDoesNotUseUpTheBubbleTip() {
        let vm = game(testing: .firstBubble)
        let cells = emptyCells(vm, 2)
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[1])
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstBubble))
    }

    func testTheBubbleTipNeverLeadsToThePaidPops() {
        // D7 (spec §5): the tip teaches the free route and aims at the cell.
        let text = (TutorialMoment.firstBubble.coachMarkText ?? "").lowercased()
        var words: [String] = []
        for part in text.split(whereSeparator: { !$0.isLetter }) { words.append(String(part)) }
        for word in ["ad", "ads", "tag", "tags", "pop", "popped", "watch", "buy", "shop"] {
            XCTAssertFalse(words.contains(word), "the bubble tip must not mention \(word)")
        }
        XCTAssertFalse(TutorialMoment.firstBubble.target.isPaidSurface)
        XCTAssertNotEqual(TutorialMoment.firstBubble.target, .bubblePopSheetButtons)
    }

    func testTheBubbleTipIsTheSameWithTheGateOpenOrShut() {
        let vm = game(testing: .firstBubble)
        _ = placeBubble(vm)
        XCTAssertEqual(next(vm), .firstBubble)
        openTheGate(vm)
        XCTAssertEqual(next(vm), .firstBubble)
        XCTAssertEqual(TutorialMoment.firstBubble.target, .bubbledCell)
    }

    // MARK: M20, sell versus order

    private func selectSellableAnimal(_ vm: MergeBoardViewModel) -> GridPosition {
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: sellVsOrderNudgeTierRange.lowerBound), at: cell)
        return cell
    }

    private func infoToasts(_ vm: MergeBoardViewModel) -> [String] {
        var found: [String] = []
        for toast in vm.toastQueue {
            if case .info(let text) = toast.kind, text.hasPrefix("No order wants this yet") { found.append(text) }
        }
        return found
    }

    func testTheSellNudgeShowsOnceAndIsRememberedInTheSharedStore() {
        let vm = game()
        let cell = selectSellableAnimal(vm)
        vm.boardCellTapped(at: cell)
        XCTAssertEqual(infoToasts(vm).count, 1, "old behaviour: a toast with both numbers")
        XCTAssertTrue(vm.hasSeenTutorialMoment(.sellVsOrder))
        XCTAssertTrue(vm.seenTutorialMoments.contains("m20_sell_vs_order"))
        vm.boardCellTapped(at: cell)   // deselect
        vm.boardCellTapped(at: cell)   // select again
        XCTAssertEqual(infoToasts(vm).count, 1, "once only")
    }

    func testTheSellNudgeNoLongerWritesItsOwnUserDefaultsFlag() {
        let vm = game()
        vm.boardCellTapped(at: selectSellableAnimal(vm))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: nudgeKey),
                       "the seen flag lives in seenTutorialMoments now")
    }

    func testASeenSellNudgeInTheStoreSuppressesTheToast() {
        let vm = game()
        vm.markTutorialMomentSeen(.sellVsOrder)
        vm.boardCellTapped(at: selectSellableAnimal(vm))
        XCTAssertTrue(infoToasts(vm).isEmpty)
    }

    func testTheSellNudgeSurvivesASaveAndReload() {
        let vm = game()
        vm.boardCellTapped(at: selectSellableAnimal(vm))
        vm.persistNow()
        let again = MergeBoardViewModel()
        again.loadGame()
        XCTAssertTrue(again.hasSeenTutorialMoment(.sellVsOrder))
    }

    func testTheSellNudgeIsNotABubbleAndNeverQueuesOne() {
        XCTAssertNil(TutorialMoment.sellVsOrder.coachMarkText)
        XCTAssertEqual(TutorialMoment.sellVsOrder.target, .none)
        let vm = game()
        _ = selectSellableAnimal(vm)
        XCTAssertNil(next(vm))
    }

    func testAnAnimalWantedByAnOrdersSecondLineDoesNotGetTheNudge() {
        // §10 item 6: the check covers the whole basket, not only the first line.
        let vm = game()
        let tier = sellVsOrderNudgeTierRange.lowerBound
        vm.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: cat, tier: 0, count: 1),
            OrderLine(chainID: dog, tier: tier, count: 1),
        ])]
        vm.boardCellTapped(at: selectSellableAnimal(vm))
        XCTAssertTrue(infoToasts(vm).isEmpty, "an order does want this animal")
        XCTAssertFalse(vm.hasSeenTutorialMoment(.sellVsOrder), "and the nudge is kept for a later animal")
    }

    func testAnAnimalNoLineWantsStillGetsTheNudge() {
        let vm = game()
        vm.adoptionOrders = [AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: cat, tier: 0, count: 1),
        ])]
        vm.boardCellTapped(at: selectSellableAnimal(vm))
        XCTAssertEqual(infoToasts(vm).count, 1)
    }

    // MARK: Spacing and priority

    func testFeatureTipsWaitOutTheGapAfterAnotherTip() {
        let vm = game(testing: .firstCardPack)
        vm.earnCardPack(.star1)
        let now = Date()
        vm.closeCoachMark(.boardFull, now: now)
        XCTAssertNil(next(vm, now: now.addingTimeInterval(1)), "inside the 20 s gap")
        XCTAssertEqual(next(vm, now: now.addingTimeInterval(tutorialMomentGapSeconds + 1)), .firstCardPack)
    }

    func testFeatureTipsWaitWhileAScreenIsUp() {
        let vm = game(testing: .firstCardPack)
        vm.earnCardPack(.star1)
        XCTAssertNil(next(vm, covered: true))
    }

    func testOneFeatureTipShowsAtATimeInDeclarationOrder() {
        let vm = game(testing: .firstCardPack)
        vm.markTutorialMomentSeen(.noMergesLeft)
        vm.seenTutorialMoments.removeAll { $0 == TutorialMoment.freeChest.rawValue }
        vm.freeChestReadyAt = Date().addingTimeInterval(-1)
        vm.earnCardPack(.star1)
        XCTAssertEqual(next(vm), .firstCardPack, "the card pack comes before the chest in the list")
    }

    // MARK: Text and D7

    func testEveryStageFiveBubbleHasTextAndTheSellNudgeHasNone() {
        for moment in bubbleFeatures {
            XCTAssertNotNil(moment.coachMarkText, "\(moment)")
        }
        XCTAssertNil(TutorialMoment.sellVsOrder.coachMarkText)
    }

    func testNoStageFiveTipTargetsAPaidSurface() {
        for moment in bubbleFeatures + [.sellVsOrder] {
            XCTAssertFalse(moment.target.isPaidSurface, "\(moment)")
        }
    }

    func testNoStageFiveTipEverNamesAPurchase() {
        let paid = ["shop", "buy", "dog tag", "watch", "offer", "skip", "refill", "$"]
        for moment in bubbleFeatures {
            let text = (moment.coachMarkText ?? "").lowercased()
            for word in paid { XCTAssertFalse(text.contains(word), "\(moment): \(word)") }
        }
    }
}
