//
//  OrderCoachMarkTests.swift
//  PawSanctuaryTests
//
//  Context tutorial, task 4.3 stage 3 (specs/Spec_ContextTutorial.md §4.2 M3,
//  M4, M5, M7 and §4.3): the order lesson as the view model drives it. The
//  bubbles themselves are checked on the Simulator.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class OrderCoachMarkTests: XCTestCase {

    private let completedKey = "tutorialCompleted"
    private let nudgeKey = "hasShownSellVsOrderNudge"
    private let dog = ContentRegistry.animalChainID(.dog)
    private let cat = ContentRegistry.animalChainID(.cat)

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

    /// A game past the opening tips, with an empty board, no urgent order and
    /// nothing in the order lane, so each test sets up exactly the cards it wants.
    private func gameReadyForOrders() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.markTutorialMomentSeen(.firstSpawn)
        vm.markTutorialMomentSeen(.firstMerge)
        // An empty board has no pair to merge, which is M12's moment; these tests are not about it.
        vm.markTutorialMomentSeen(.noMergesLeft)
        // A new game has a toolbox, a ready chest and maybe a stocked daily task: the
        // feature tips (stage 5) have their own tests in FeatureCoachMarkTests.
        let featureTips: [TutorialMoment] = [.chainViewer, .firstDailyHandIn, .toolbox, .mapAreaAffordable,
                                             .firstCardPack, .freeChest, .firstBubble]
        for moment in featureTips { vm.markTutorialMomentSeen(moment) }
        var board = vm.board
        for r in board.indices { for c in board[r].indices { board[r][c].item = nil } }
        vm.board = board
        vm.boardState.recalc()
        vm.adoptionBoardCoordinator.urgentOrder = nil
        vm.adoptionOrders = []
        return vm
    }

    private func order(_ chain: ChainID, tier: Int, count: Int = 1) -> AdoptionOrder {
        AdoptionOrder(familyIndex: 0, wantedChainID: chain, wantedTier: tier, wantedCount: count)
    }

    private func emptyCells(_ vm: MergeBoardViewModel, _ n: Int) -> [GridPosition] {
        // A plain loop: the chained form timed out the type checker on CI's Xcode.
        var found: [GridPosition] = []
        for row in vm.board {
            for cell in row where cell.isUnlocked && cell.item == nil && cell.producer == nil {
                if found.count == n { return found }
                found.append(cell.position)
            }
        }
        return found
    }

    @discardableResult
    private func hold(_ vm: MergeBoardViewModel, _ chain: ChainID, tier: Int, copies: Int) -> [GridPosition] {
        let cells = emptyCells(vm, copies)
        XCTAssertEqual(cells.count, copies)
        for pos in cells {
            var board = vm.board
            board[pos.row][pos.col].item = BoardItem(chainID: chain, tier: tier)
            vm.board = board
        }
        vm.boardState.recalc()
        return cells
    }

    private func next(_ vm: MergeBoardViewModel) -> TutorialMoment? {
        vm.nextCoachMark(isCoveredByOtherUI: false)
    }

    // MARK: M3, an order on hold

    func testAHeldAnimalOnAPartFilledOrderBringsTheOnHoldTipAndPointsAtTheCardAndTheAnimal() {
        let vm = gameReadyForOrders()
        let o = order(dog, tier: 1, count: 2)
        vm.adoptionOrders = [o]
        let cells = hold(vm, dog, tier: 1, copies: 1)
        XCTAssertEqual(next(vm), .orderOnHold)
        XCTAssertEqual(vm.coachMarkOrderID(for: .orderOnHold), o.id)
        XCTAssertEqual(vm.coachMarkCells(for: .orderOnHold), cells)
    }

    func testNoOnHoldTipWhenTheBoardHoldsNothingTheOrderWants() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1, count: 2)]
        hold(vm, cat, tier: 0, copies: 1)
        XCTAssertNil(next(vm))
    }

    func testAFullyHeldOrderBringsTheDeliverTipNotTheOnHoldTip() {
        let vm = gameReadyForOrders()
        let o = order(dog, tier: 1, count: 2)
        vm.adoptionOrders = [o]
        hold(vm, dog, tier: 1, copies: 2)
        XCTAssertEqual(next(vm), .firstDeliver)
        XCTAssertEqual(vm.coachMarkOrderID(for: .firstDeliver), o.id)
    }

    func testTheOnHoldTipIsShownOnceThenNeverAgain() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1, count: 2)]
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertEqual(next(vm), .orderOnHold)
        vm.closeCoachMark(.orderOnHold)
        XCTAssertNil(next(vm))
    }

    // MARK: M4, the first Deliver

    func testTheDeliverTipAppearsOnceAnOrderIsReady() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1)]
        XCTAssertNil(next(vm), "nothing held yet")
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertEqual(next(vm), .firstDeliver)
    }

    func testAnUrgentOrderThatIsHeldBringsTheSameTips() {
        let vm = gameReadyForOrders()
        let urgent = order(dog, tier: 1, count: 2)
        vm.adoptionBoardCoordinator.urgentOrder = urgent
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 60
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertEqual(next(vm), .orderOnHold)
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertEqual(next(vm), .firstDeliver)
        XCTAssertEqual(vm.coachMarkOrderID(for: .firstDeliver), urgent.id)
    }

    func testAnUrgentOrderWhoseClockRanOutIsNotReadyToDeliver() {
        let vm = gameReadyForOrders()
        vm.adoptionBoardCoordinator.urgentOrder = order(dog, tier: 1)
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 0
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertNil(next(vm))
    }

    func testTwoReadyCardsShowTheDeliverTipOnlyOnce() throws {
        let vm = gameReadyForOrders()
        let first = order(dog, tier: 1), second = order(dog, tier: 1)
        vm.adoptionOrders = [first, second]
        hold(vm, dog, tier: 1, copies: 2)
        XCTAssertEqual(next(vm), .firstDeliver)
        XCTAssertTrue(vm.deliverOrder(id: first.id))
        XCTAssertEqual(next(vm), .afterDeliver)
        vm.closeCoachMark(.afterDeliver)
        // The second card is ready too, but the lesson is learned.
        XCTAssertNil(next(vm))
    }

    // MARK: M5, after Deliver

    func testDeliveringClosesTheDeliverTipAndShowsTheAfterTipOnThatCard() {
        let vm = gameReadyForOrders()
        let o = order(dog, tier: 1)
        vm.adoptionOrders = [o]
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertTrue(vm.deliverOrder(id: o.id))
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstDeliver))
        XCTAssertEqual(next(vm), .afterDeliver)
        XCTAssertEqual(vm.coachMarkOrderID(for: .afterDeliver), o.id)
    }

    func testARefusedDeliveryTeachesNothing() {
        let vm = gameReadyForOrders()
        let o = order(dog, tier: 1, count: 2)
        vm.adoptionOrders = [o]
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertFalse(vm.deliverOrder(id: o.id))
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstDeliver))
        XCTAssertNotEqual(next(vm), .afterDeliver)
    }

    func testTheAfterTipClosesAndDoesNotComeBack() {
        let vm = gameReadyForOrders()
        let o = order(dog, tier: 1)
        vm.adoptionOrders = [o]
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertTrue(vm.deliverOrder(id: o.id))
        vm.closeCoachMark(.afterDeliver)
        XCTAssertNil(next(vm))
    }

    func testDeliveringTheUrgentOrderAlsoShowsTheAfterTip() {
        let vm = gameReadyForOrders()
        let urgent = order(dog, tier: 1)
        vm.adoptionBoardCoordinator.urgentOrder = urgent
        vm.adoptionBoardCoordinator.urgentOrderTimeRemaining = 60
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertTrue(vm.deliverUrgentOrder())
        XCTAssertEqual(next(vm), .afterDeliver)
        XCTAssertEqual(vm.coachMarkOrderID(for: .afterDeliver), urgent.id)
    }

    // MARK: M7, a merge that un-holds a slot

    func testMergingAHeldAnimalAwayBringsTheSplitTipOnThatOrder() {
        let vm = gameReadyForOrders()
        let o = order(dog, tier: 1, count: 2)
        vm.adoptionOrders = [o]
        let cells = hold(vm, dog, tier: 1, copies: 2)
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertEqual(next(vm), .splitWarning)
        XCTAssertEqual(vm.coachMarkOrderID(for: .splitWarning), o.id)
    }

    func testMergingAnAnimalNoOrderWantsShowsNoSplitTip() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(cat, tier: 3)]
        let cells = hold(vm, dog, tier: 0, copies: 2)
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertNil(next(vm))
    }

    func testAMergeThatStillLeavesTheOrderFullyHeldShowsNoSplitTip() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1)]
        let held = hold(vm, dog, tier: 1, copies: 1)
        let pair = hold(vm, dog, tier: 0, copies: 2)
        _ = held
        vm.attemptMergeOrMove(from: pair[0], to: pair[1])   // makes a Lv.2 dog, the held Lv.2 stays
        XCTAssertNotEqual(next(vm), .splitWarning)
    }

    func testTheSplitTipIsShownOnceThenNeverAgain() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1, count: 2)]
        let cells = hold(vm, dog, tier: 1, copies: 2)
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertEqual(next(vm), .splitWarning)
        vm.closeCoachMark(.splitWarning)
        XCTAssertNil(next(vm))
    }

    // MARK: Showing rules and wording

    func testNoOrderTipShowsWhileAnotherScreenCoversTheBoard() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1)]
        hold(vm, dog, tier: 1, copies: 1)
        XCTAssertNil(vm.nextCoachMark(isCoveredByOtherUI: true))
    }

    func testSkipTipsHidesTheOrderTipsToo() {
        let vm = gameReadyForOrders()
        vm.adoptionOrders = [order(dog, tier: 1)]
        hold(vm, dog, tier: 1, copies: 1)
        vm.skipTutorialTips()
        XCTAssertNil(next(vm))
    }

    func testTheOrderTipsUseTheSpecsWording() {
        XCTAssertEqual(TutorialMoment.orderOnHold.coachMarkText,
                       "This family wants that animal. A soft highlight means you already have it on the board. Keep it there!")
        XCTAssertEqual(TutorialMoment.firstDeliver.coachMarkText,
                       "Everything is on the board. Tap Deliver to send the animals home and collect your reward.")
        XCTAssertEqual(TutorialMoment.afterDeliver.coachMarkText,
                       "Delivered animals leave the board. A new family arrives in a moment.")
        XCTAssertEqual(TutorialMoment.splitWarning.coachMarkText,
                       "That animal was on hold for an order. Merging it moved it up a level, so the order needs another one.")
    }

    func testTheShortTipsCloseThemselvesAfterTheSpecsTimes() {
        XCTAssertEqual(TutorialMoment.orderOnHold.autoCloseSeconds, 6)
        XCTAssertEqual(TutorialMoment.afterDeliver.autoCloseSeconds, 4)
        XCTAssertEqual(TutorialMoment.splitWarning.autoCloseSeconds, 6)
        for moment in TutorialMoment.allCases
        where ![.orderOnHold, .afterDeliver, .splitWarning, .firstItemStored, .spawnerResting,
                .firstWildcard].contains(moment) {
            XCTAssertNil(moment.autoCloseSeconds, "\(moment) waits for its action or the x")
        }
    }
}
