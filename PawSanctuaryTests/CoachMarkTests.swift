//
//  CoachMarkTests.swift
//  PawSanctuaryTests
//
//  Context tutorial, task 4.3 stage 2 (specs/Spec_ContextTutorial.md §4, §7):
//  the first three coach marks (spawn, merge, quest claim) as the view model
//  drives them. The bubble view itself is checked on the Simulator.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class CoachMarkTests: XCTestCase {

    private let completedKey = "tutorialCompleted"
    private let nudgeKey = "hasShownSellVsOrderNudge"

    override func setUp() {
        super.setUp()
        GameStore.clear()
        // Start with neither old flag set, and put both back afterwards.
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

    private func freshGame() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        return vm
    }

    private func spawnerPosition(_ vm: MergeBoardViewModel) -> GridPosition? {
        for row in vm.board { for cell in row where cell.producer?.level == .familySpawner { return cell.position } }
        return nil
    }

    /// Removes every animal and toolbox so each test sets up exactly the pair it wants.
    private func clearItems(_ vm: MergeBoardViewModel) {
        var board = vm.board
        for r in board.indices { for c in board[r].indices { board[r][c].item = nil } }
        vm.board = board
        vm.boardState.recalc()
    }

    private func emptyUnlockedCells(_ vm: MergeBoardViewModel, _ count: Int) -> [GridPosition] {
        var found: [GridPosition] = []
        for row in vm.board {
            for cell in row where cell.isUnlocked && cell.item == nil && cell.producer == nil {
                found.append(cell.position)
                if found.count == count { return found }
            }
        }
        return found
    }

    private func place(_ vm: MergeBoardViewModel, _ item: BoardItem, at pos: GridPosition) {
        var board = vm.board
        board[pos.row][pos.col].item = item
        vm.board = board
        vm.boardState.recalc()
    }

    /// Two matching dogs on empty cells; returns where they are.
    private func placeAPair(_ vm: MergeBoardViewModel) throws -> (GridPosition, GridPosition) {
        clearItems(vm)
        let cells = emptyUnlockedCells(vm, 2)
        XCTAssertEqual(cells.count, 2)
        let dog = ContentRegistry.animalChainID(.dog)
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: dog, tier: 0), at: cells[1])
        return (cells[0], cells[1])
    }

    private func makeAQuestClaimable(_ vm: MergeBoardViewModel) throws -> Quest {
        var quest = try XCTUnwrap(vm.quests.activeQuests.first, "a fresh game has quests")
        quest.progress = quest.goal.targetCount
        vm.quests.activeQuests[0] = quest
        return quest
    }

    // MARK: Spawn tip

    func testAFreshGameShowsTheSpawnerTipFirstAndPointsAtTheSpawner() throws {
        let vm = freshGame()
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        XCTAssertEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstSpawn)
        XCTAssertEqual(vm.coachMarkCells(for: .firstSpawn), [spawner])
    }

    func testTheFirstSpawnTapClosesTheSpawnerTip() throws {
        let vm = freshGame()
        clearItems(vm)
        let spawner = try XCTUnwrap(spawnerPosition(vm))
        vm.activateProducer(at: spawner)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstSpawn))
        XCTAssertNotEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstSpawn)
    }

    // MARK: Merge tip

    func testAMatchingPairBringsTheMergeTipAndPointsAtBothAnimals() throws {
        let vm = freshGame()
        vm.markTutorialMomentSeen(.firstSpawn)
        let pair = try placeAPair(vm)
        XCTAssertEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstMerge)
        XCTAssertEqual(vm.coachMarkCells(for: .firstMerge), [pair.0, pair.1])
    }

    func testNoMergeTipWithoutAMatchingPair() throws {
        let vm = freshGame()
        vm.markTutorialMomentSeen(.firstSpawn)
        clearItems(vm)
        let cells = emptyUnlockedCells(vm, 2)
        place(vm, BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: 0), at: cells[0])
        place(vm, BoardItem(chainID: ContentRegistry.animalChainID(.cat), tier: 0), at: cells[1])
        XCTAssertNil(vm.nextCoachMark(isCoveredByOtherUI: false))
    }

    func testTheFirstMergeClosesTheMergeTip() throws {
        let vm = freshGame()
        vm.markTutorialMomentSeen(.firstSpawn)
        let pair = try placeAPair(vm)
        vm.attemptMergeOrMove(from: pair.0, to: pair.1)
        XCTAssertGreaterThan(vm.mergeCount, 0)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstMerge))
    }

    func testAMoveThatIsNotAMergeDoesNotCloseTheMergeTip() throws {
        let vm = freshGame()
        vm.markTutorialMomentSeen(.firstSpawn)
        _ = try placeAPair(vm)
        let spare = emptyUnlockedCells(vm, 1)
        let mover = try XCTUnwrap(vm.board.flatMap { $0 }.first { $0.item != nil }?.position)
        vm.attemptMergeOrMove(from: mover, to: spare[0])
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstMerge))
    }

    // MARK: Quest tip

    func testAClaimableQuestBringsTheClaimTipOnceTheOpeningTipsAreDone() throws {
        let vm = freshGame()
        _ = try makeAQuestClaimable(vm)
        XCTAssertEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstSpawn, "the opening tips come first")
        vm.markTutorialMomentSeen(.firstSpawn)
        vm.markTutorialMomentSeen(.firstMerge)
        XCTAssertEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstQuestClaim)
    }

    func testClaimingAQuestClosesTheClaimTip() throws {
        let vm = freshGame()
        let quest = try makeAQuestClaimable(vm)
        vm.claimQuest(id: quest.id)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstQuestClaim))
    }

    // MARK: Showing rules

    func testNothingShowsWhileAnotherScreenCoversTheBoard() {
        let vm = freshGame()
        XCTAssertNil(vm.nextCoachMark(isCoveredByOtherUI: true))
        XCTAssertEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstSpawn)
    }

    func testClosingATipWithTheCrossMarksItSeenAndMovesOn() throws {
        let vm = freshGame()
        vm.closeCoachMark(.firstSpawn)
        XCTAssertTrue(vm.hasSeenTutorialMoment(.firstSpawn))
        XCTAssertNotEqual(vm.nextCoachMark(isCoveredByOtherUI: false), .firstSpawn)
    }

    func testTheOpeningTipsFollowEachOtherWithoutAWait() throws {
        let vm = freshGame()
        let closedAt = Date()
        vm.closeCoachMark(.firstSpawn, now: closedAt)
        _ = try placeAPair(vm)
        XCTAssertEqual(vm.nextCoachMark(isCoveredByOtherUI: false, now: closedAt.addingTimeInterval(1)),
                       .firstMerge)
    }

    func testSkipTipsHidesEveryOpeningTip() throws {
        let vm = freshGame()
        _ = try makeAQuestClaimable(vm)
        vm.skipTutorialTips()
        XCTAssertNil(vm.nextCoachMark(isCoveredByOtherUI: false))
    }

    func testAPlayerWhoFinishedTheOldTutorialSeesNoOpeningTips() throws {
        UserDefaults.standard.set(true, forKey: completedKey)
        let vm = freshGame()
        _ = try makeAQuestClaimable(vm)
        XCTAssertNil(vm.nextCoachMark(isCoveredByOtherUI: false))
    }

    // MARK: Wording

    func testTheThreeOpeningTipsUseTheSpecsWording() {
        XCTAssertEqual(TutorialMoment.firstSpawn.coachMarkText,
                       "Tap the spawner to rescue an animal. Each rescue costs kibble; kibble refills by itself.")
        XCTAssertEqual(TutorialMoment.firstMerge.coachMarkText,
                       "Drag an animal onto a matching one to merge it into the next level.")
        XCTAssertEqual(TutorialMoment.firstQuestClaim.coachMarkText,
                       "Quest complete! Tap Claim for your reward. Quests count what you do; orders and daily tasks want animals you hold.")
    }

    func testTipsThatAreNotBuiltYetHaveNoBubbleText() {
        // Stage 2 builds three tips; the rest get their text in their own stage.
        let built: Set<TutorialMoment> = [.firstSpawn, .firstMerge, .firstQuestClaim]
        for moment in TutorialMoment.allCases where !built.contains(moment) {
            XCTAssertNil(moment.coachMarkText, "\(moment)")
        }
    }

    func testNoTipTextMentionsAPaidThing() {
        let paid = ["shop", "buy", "dog tag", "ad ", "watch", "offer", "pass", "$"]
        for moment in TutorialMoment.allCases {
            guard let text = moment.coachMarkText?.lowercased() else { continue }
            for word in paid { XCTAssertFalse(text.contains(word), "\(moment) mentions \(word)") }
        }
    }

    func testTheThemeSheetWaitsForTheSpawnAndMergeTips() {
        let vm = freshGame()
        XCTAssertFalse(vm.isOpeningTutorialDone)
        vm.markTutorialMomentSeen(.firstSpawn)
        XCTAssertFalse(vm.isOpeningTutorialDone)
        vm.markTutorialMomentSeen(.firstMerge)
        XCTAssertTrue(vm.isOpeningTutorialDone)
    }
}
