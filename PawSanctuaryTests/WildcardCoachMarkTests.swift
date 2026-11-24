//
//  WildcardCoachMarkTests.swift
//  PawSanctuaryTests
//
//  Context tutorial, task 4.3 stage 6 (specs/Spec_ContextTutorial.md §4.2 M22,
//  §5, §7): the first-wildcard tip, the only moment of group D. It is checked
//  against D7's gate at fire time, never at queue time. M21 has no tip and M23
//  is not built (owner Q6, answer (a)). The bubble itself is checked on the
//  Simulator.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class WildcardCoachMarkTests: XCTestCase {

    private let completedKey = "tutorialCompleted"
    private let nudgeKey = "hasShownSellVsOrderNudge"
    private let dog = ContentRegistry.animalChainID(.dog)
    private let wildcard = ContentRegistry.wildcardChainID

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

    /// A game past every other tip, with an empty board and nothing in the order
    /// lane, so the wildcard tip is the only thing that can show.
    private func game() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.skipTutorialTips()
        let others: [TutorialMoment] = TutorialMoment.allCases.filter { $0 != .firstWildcard }
        for moment in others { vm.markTutorialMomentSeen(moment) }
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

    private func shutTheGate(_ vm: MergeBoardViewModel) {
        vm.commerce.hasReachedFirstWall = false
        vm.progression.playerLevel = 1
        XCTAssertFalse(vm.isMonetizationUnlocked)
    }

    private func next(_ vm: MergeBoardViewModel, covered: Bool = false, now: Date = Date()) -> TutorialMoment? {
        vm.nextCoachMark(isCoveredByOtherUI: covered, now: now)
    }

    private func placeWildcard(_ vm: MergeBoardViewModel) -> GridPosition {
        let cell = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: wildcard, tier: 0), at: cell)
        return cell
    }

    // MARK: D7, checked when the tip would fire

    func testAWildcardOnTheBoardBringsTheTipOnceTheGateIsOpen() {
        let vm = game()
        openTheGate(vm)
        let cell = placeWildcard(vm)
        XCTAssertEqual(next(vm), .firstWildcard)
        XCTAssertEqual(vm.coachMarkCells(for: .firstWildcard), [cell])
        XCTAssertEqual(TutorialMoment.firstWildcard.target, .wildcardCell)
    }

    func testNoWildcardTipWhileTheGateIsShut() {
        let vm = game()
        shutTheGate(vm)
        _ = placeWildcard(vm)
        XCTAssertNil(next(vm), "group D never fires before D7's gate")
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstWildcard), "and is not used up")
    }

    func testTheGateIsCheckedAtFireTimeNotWhenTheWildcardLands() {
        let vm = game()
        shutTheGate(vm)
        _ = placeWildcard(vm)
        XCTAssertNil(next(vm))
        openTheGate(vm)
        XCTAssertEqual(next(vm), .firstWildcard, "the gate opened later: the tip now fires")
        shutTheGate(vm)
        XCTAssertNil(next(vm), "and a gate that is shut again takes it away")
    }

    // MARK: The trigger

    func testNoWildcardTipWithoutAWildcardOnTheBoard() {
        let vm = game()
        openTheGate(vm)
        XCTAssertNil(next(vm))
        XCTAssertTrue(vm.coachMarkCells(for: .firstWildcard).isEmpty)
    }

    func testAWildcardInStorageIsNotOnTheBoard() {
        let vm = game()
        openTheGate(vm)
        let item = BoardItem(chainID: wildcard, tier: 0)
        XCTAssertTrue(vm.inventoryStore.addItem(item))
        XCTAssertNil(next(vm), "the tip is about the tile on the board")
    }

    func testBuyingAWildcardPutsItOnTheBoardAndBringsTheTip() {
        let vm = game()
        openTheGate(vm)
        vm.kibbleEngine.dogTags = wildcardCostDogTags
        XCTAssertTrue(vm.purchaseWildcard())
        XCTAssertEqual(next(vm), .firstWildcard)
    }

    func testTheWildcardTipFiresOncePerPlayer() {
        let vm = game()
        openTheGate(vm)
        _ = placeWildcard(vm)
        XCTAssertEqual(next(vm), .firstWildcard)
        vm.closeCoachMark(.firstWildcard)
        XCTAssertNil(next(vm, now: Date().addingTimeInterval(tutorialMomentGapSeconds + 1)))
        _ = placeWildcard(vm)
        XCTAssertNil(next(vm, now: Date().addingTimeInterval(tutorialMomentGapSeconds + 1)),
                     "seen once, never again")
    }

    // MARK: Closing

    func testTheCrossClosesTheWildcardTipForGood() {
        let vm = game()
        openTheGate(vm)
        _ = placeWildcard(vm)
        vm.closeCoachMark(.firstWildcard)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstWildcard))
    }

    func testTheWildcardTipClosesItselfLikeTheOtherShortTips() {
        XCTAssertEqual(TutorialMoment.firstWildcard.autoCloseSeconds, 6)
    }

    func testMergingTheWildcardClosesTheTip() {
        let vm = game()
        openTheGate(vm)
        let wild = placeWildcard(vm)
        let target = emptyCells(vm, 1)[0]
        place(vm, BoardItem(chainID: dog, tier: 0), at: target)
        XCTAssertEqual(next(vm), .firstWildcard)
        vm.attemptMergeOrMove(from: wild, to: target)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstWildcard), "the player has used it: the lesson is done")
    }

    func testAnOrdinaryMergeDoesNotUseUpTheWildcardTip() {
        let vm = game()
        openTheGate(vm)
        let cells = emptyCells(vm, 2)
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[1])
        vm.attemptMergeOrMove(from: cells[0], to: cells[1])
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstWildcard))
    }

    // MARK: Spacing and priority

    func testTheWildcardTipWaitsOutTheGapAfterAnotherTip() {
        let vm = game()
        openTheGate(vm)
        _ = placeWildcard(vm)
        let now = Date()
        vm.closeCoachMark(.sellVsOrder, now: now)   // some other tip just closed (already seen: no gap)
        XCTAssertEqual(next(vm, now: now.addingTimeInterval(1)), .firstWildcard,
                       "a tip that was already seen does not start the gap")
        // An unseen tip closing does start it.
        let vm2 = MergeBoardViewModel()
        vm2.loadGame()
        vm2.skipTutorialTips()
        for moment in TutorialMoment.allCases where moment != .firstWildcard && moment != .toolbox {
            vm2.markTutorialMomentSeen(moment)
        }
        vm2.adoptionOrders = []
        vm2.adoptionBoardCoordinator.urgentOrder = nil
        clearItems(vm2)
        openTheGate(vm2)
        _ = placeWildcard(vm2)
        vm2.closeCoachMark(.toolbox, now: now)
        XCTAssertNil(next(vm2, now: now.addingTimeInterval(1)), "inside the 20 s gap")
        XCTAssertEqual(next(vm2, now: now.addingTimeInterval(tutorialMomentGapSeconds + 1)), .firstWildcard)
    }

    func testTheWildcardTipWaitsWhileAScreenIsUp() {
        let vm = game()
        openTheGate(vm)
        _ = placeWildcard(vm)
        XCTAssertNil(next(vm, covered: true))
    }

    // MARK: Text and D7

    func testTheWildcardTipUsesTheSpecsWording() {
        XCTAssertEqual(TutorialMoment.firstWildcard.coachMarkText,
                       "A wildcard merges with any animal. It does not fill an order slot.")
    }

    func testTheWildcardTipNeverNamesAPurchaseOrPointsAtAPaidSurface() {
        let text = (TutorialMoment.firstWildcard.coachMarkText ?? "").lowercased()
        for word in ["shop", "buy", "dog tag", "watch", "offer", "skip", "refill", "$", "price", "cost"] {
            XCTAssertFalse(text.contains(word), word)
        }
        XCTAssertFalse(TutorialMoment.firstWildcard.target.isPaidSurface)
        XCTAssertNotEqual(TutorialMoment.firstWildcard.target, .shopButton)
    }

    func testEveryMomentNowHasABubbleOrIsTheSellToast() {
        for moment in TutorialMoment.allCases {
            if moment == .sellVsOrder { XCTAssertNil(moment.coachMarkText) }
            else { XCTAssertNotNil(moment.coachMarkText, "\(moment)") }
        }
    }

    func testNoShopTipIsBuilt() {
        // M23 (a coach mark on the shop) is not built: owner Q6, answer (a).
        for moment in TutorialMoment.allCases { XCTAssertNotEqual(moment.target, .shopButton, "\(moment)") }
        XCTAssertEqual(TutorialMoment.allCases.filter { $0.group == .afterGate }, [.firstWildcard])
    }
}
