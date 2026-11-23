//
//  TutorialTriggerTests.swift
//  PawSanctuaryTests
//
//  Context tutorial, task 4.3 stage 1 (specs/Spec_ContextTutorial.md §4, §6, §7):
//  the moment list, the pure rule that picks the next one, and the seen-set on
//  the view model. Nothing here draws anything; no view calls the rule yet.
//

import XCTest
@testable import PawSanctuary

final class TutorialTriggerTests: XCTestCase {

    // MARK: Helpers

    /// A snapshot in which only this moment's trigger holds.
    private func snapshot(firing moment: TutorialMoment) -> TutorialSnapshot {
        var s = TutorialSnapshot()
        switch moment {
        case .firstSpawn:         s.hasFamilySpawnerOnBoard = true
        case .firstMerge:         s.hasMergeablePair = true
        case .orderOnHold:        s.hasPartHeldOrder = true
        case .firstDeliver:       s.hasReadyOrder = true
        case .afterDeliver:       s.justDelivered = true
        case .firstQuestClaim:    s.hasClaimableQuest = true
        case .splitWarning:       s.justUnheldAnOrderSlot = true
        case .boardFull:          s.boardFullToastJustShown = true
        case .firstItemStored:    s.itemJustStored = true
        case .spawnerResting:     s.restingSpawnerJustTapped = true
        case .outOfKibble:        s.outOfKibbleSheetJustOpened = true
        case .noMergesLeft:       s.hasNoMergeablePairWithSpawnerReady = true
        case .chainViewer:        s.chainItemIsSelected = true
        case .firstDailyHandIn:   s.hasClaimableDailyTask = true
        case .toolbox:            s.hasToolboxOnBoard = true
        case .mapAreaAffordable:  s.hasAffordableArea = true
        case .firstCardPack:      s.hasPendingCardPack = true
        case .freeChest:          s.freeChestIsReady = true
        case .firstBubble:        s.hasBubbledItem = true
        case .sellVsOrder:        s.sellVsOrderNudgeApplies = true
        case .firstWildcard:      s.hasWildcardOnBoard = true
        }
        // Moments that wait on another one, or on the shop gate, get what they wait on.
        if moment == .chainViewer { s.hasMergedOnce = true }
        if moment.group == .afterGate { s.isMonetizationUnlocked = true }
        return s
    }

    /// What the player has seen once the opening lessons are behind them.
    private let openingDone: Set<TutorialMoment> = [.firstSpawn, .firstMerge]

    // MARK: Each trigger fires on its own condition, once

    func testNothingFiresOnAnEmptySnapshot() {
        XCTAssertNil(nextTutorialMoment(snapshot: TutorialSnapshot(), seen: []))
    }

    func testEveryMomentFiresWhenItsTriggerHolds() {
        for moment in TutorialMoment.allCases {
            let seen: Set<TutorialMoment> = moment == .chainViewer ? openingDone : []
            XCTAssertEqual(nextTutorialMoment(snapshot: snapshot(firing: moment), seen: seen),
                           moment, "\(moment) should fire when only its trigger holds")
        }
    }

    func testNoMomentFiresOnceItIsSeen() {
        for moment in TutorialMoment.allCases {
            var seen: Set<TutorialMoment> = [moment]
            if moment == .chainViewer { seen.formUnion(openingDone) }
            XCTAssertNil(nextTutorialMoment(snapshot: snapshot(firing: moment), seen: seen),
                         "\(moment) must not fire a second time")
        }
    }

    func testAMomentWhoseTriggerEndedBeforeItShowedIsNotMarkedAndFiresNextTime() {
        // The selector is pure: dropping a stale trigger means returning nothing
        // and leaving the seen set alone, so the moment can fire later.
        let seen: Set<TutorialMoment> = []
        XCTAssertNil(nextTutorialMoment(snapshot: TutorialSnapshot(), seen: seen))
        XCTAssertEqual(nextTutorialMoment(snapshot: snapshot(firing: .firstMerge), seen: seen), .firstMerge)
    }

    // MARK: Order and spacing

    func testWhenTwoMomentsAreReadyTheEarlierOneInTheListComesFirst() {
        var s = snapshot(firing: .firstSpawn)
        s.hasMergeablePair = true
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), .firstSpawn)
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: [.firstSpawn]), .firstMerge)
    }

    func testTheDeliverTipComesBeforeTheOneAboutAnOrderOnHold() {
        // A ready card and a part-held card at once: the ready card's Deliver tip
        // is the one that unlocks reward, but the list order is the rule.
        var s = snapshot(firing: .orderOnHold)
        s.hasReadyOrder = true
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), .orderOnHold)
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: [.orderOnHold]), .firstDeliver)
    }

    func testNothingShowsWhileAnotherScreenCoversTheBoard() {
        var s = snapshot(firing: .firstSpawn)
        s.isCoveredByOtherUI = true
        XCTAssertNil(nextTutorialMoment(snapshot: s, seen: []),
                     "a sheet, popup, banner, takeover or the parallel board waits the tip out")
    }

    func testTheNextMomentWaitsForTheGapAfterTheLastOne() {
        var s = snapshot(firing: .firstMerge)
        s.secondsSinceLastMoment = tutorialMomentGapSeconds - 1
        XCTAssertNil(nextTutorialMoment(snapshot: s, seen: []))
        s.secondsSinceLastMoment = tutorialMomentGapSeconds
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), .firstMerge)
    }

    func testTheGapIsATuningConstantWithTheSpecsStartingValue() {
        XCTAssertEqual(tutorialMomentGapSeconds, 20)
    }

    // MARK: Dependencies

    func testTheChainViewerTipWaitsForTheFirstMerge() {
        var s = snapshot(firing: .chainViewer)
        s.hasMergedOnce = false
        XCTAssertNil(nextTutorialMoment(snapshot: s, seen: []))
        s.hasMergedOnce = true
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), .chainViewer)
    }

    func testTheNoMatchesTipNeedsAReadySpawnerAndAnEmptyPairList() {
        var s = TutorialSnapshot()
        s.hasNoMergeablePairWithSpawnerReady = false
        s.hasMergeablePair = false
        XCTAssertNil(nextTutorialMoment(snapshot: s, seen: []))
        s.hasNoMergeablePairWithSpawnerReady = true
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), .noMergesLeft)
    }

    // MARK: D7: nothing leads toward a purchase before the shop opens

    func testGroupDMomentsNeverFireWhileTheGateIsClosed() {
        for moment in TutorialMoment.allCases where moment.group == .afterGate {
            var s = snapshot(firing: moment)
            s.isMonetizationUnlocked = false
            XCTAssertNil(nextTutorialMoment(snapshot: s, seen: []),
                         "\(moment) is a group D moment and needs the gate open")
            s.isMonetizationUnlocked = true
            XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), moment)
        }
    }

    func testTheRestingSpawnerTipOnlyFiresWhileTheGateIsClosed() {
        var s = snapshot(firing: .spawnerResting)
        s.isMonetizationUnlocked = false
        XCTAssertEqual(nextTutorialMoment(snapshot: s, seen: []), .spawnerResting)
        s.isMonetizationUnlocked = true
        XCTAssertNil(nextTutorialMoment(snapshot: s, seen: []),
                     "once the gate is open the existing skip alert explains itself (M21)")
    }

    func testTheMomentsBesideAPaidSurfaceAimAtTheFreeThingOnly() {
        // Spec §5: each tip that sits next to a paid surface is pinned to its free target.
        XCTAssertEqual(TutorialMoment.spawnerResting.target, .spawnerCell)
        XCTAssertEqual(TutorialMoment.outOfKibble.target, .refillOrderFooter)
        XCTAssertEqual(TutorialMoment.freeChest.target, .freeChestTile)
        XCTAssertEqual(TutorialMoment.firstBubble.target, .bubbledCell)
        for moment in TutorialMoment.allCases where moment.group != .afterGate {
            XCTAssertFalse(moment.target.isPaidSurface,
                           "\(moment) must not point at a paid surface before the gate")
        }
    }

    func testWithEverythingTrueAndTheGateClosedTheRuleNeverRepeatsAndNeverPicksGroupD() {
        var s = TutorialSnapshot()
        for moment in TutorialMoment.allCases { s = merged(s, snapshot(firing: moment)) }
        s.isMonetizationUnlocked = false
        var seen: Set<TutorialMoment> = []
        while let next = nextTutorialMoment(snapshot: s, seen: seen) {
            XCTAssertNotEqual(next.group, .afterGate)
            XCTAssertTrue(seen.insert(next).inserted, "the rule must never repeat a moment")
        }
        XCTAssertFalse(seen.isEmpty)
    }

    /// OR of two snapshots' flags, for the "everything true" walk above.
    private func merged(_ a: TutorialSnapshot, _ b: TutorialSnapshot) -> TutorialSnapshot {
        var r = a
        r.hasFamilySpawnerOnBoard = a.hasFamilySpawnerOnBoard || b.hasFamilySpawnerOnBoard
        r.hasMergeablePair = a.hasMergeablePair || b.hasMergeablePair
        r.hasPartHeldOrder = a.hasPartHeldOrder || b.hasPartHeldOrder
        r.hasReadyOrder = a.hasReadyOrder || b.hasReadyOrder
        r.justDelivered = a.justDelivered || b.justDelivered
        r.hasClaimableQuest = a.hasClaimableQuest || b.hasClaimableQuest
        r.justUnheldAnOrderSlot = a.justUnheldAnOrderSlot || b.justUnheldAnOrderSlot
        r.boardFullToastJustShown = a.boardFullToastJustShown || b.boardFullToastJustShown
        r.itemJustStored = a.itemJustStored || b.itemJustStored
        r.restingSpawnerJustTapped = a.restingSpawnerJustTapped || b.restingSpawnerJustTapped
        r.outOfKibbleSheetJustOpened = a.outOfKibbleSheetJustOpened || b.outOfKibbleSheetJustOpened
        r.hasNoMergeablePairWithSpawnerReady = a.hasNoMergeablePairWithSpawnerReady || b.hasNoMergeablePairWithSpawnerReady
        r.chainItemIsSelected = a.chainItemIsSelected || b.chainItemIsSelected
        r.hasMergedOnce = a.hasMergedOnce || b.hasMergedOnce
        r.hasClaimableDailyTask = a.hasClaimableDailyTask || b.hasClaimableDailyTask
        r.hasToolboxOnBoard = a.hasToolboxOnBoard || b.hasToolboxOnBoard
        r.hasAffordableArea = a.hasAffordableArea || b.hasAffordableArea
        r.hasPendingCardPack = a.hasPendingCardPack || b.hasPendingCardPack
        r.freeChestIsReady = a.freeChestIsReady || b.freeChestIsReady
        r.hasBubbledItem = a.hasBubbledItem || b.hasBubbledItem
        r.sellVsOrderNudgeApplies = a.sellVsOrderNudgeApplies || b.sellVsOrderNudgeApplies
        r.hasWildcardOnBoard = a.hasWildcardOnBoard || b.hasWildcardOnBoard
        return r
    }

    // MARK: The list itself

    func testMomentRawValuesArePinned() {
        // These strings are stored in saves. Renaming one silently un-sees a tip
        // for every player, so changing this list needs a migration.
        XCTAssertEqual(TutorialMoment.allCases.map(\.rawValue), [
            "m01_first_spawn", "m02_first_merge", "m03_order_on_hold", "m04_first_deliver",
            "m05_after_deliver", "m06_first_quest_claim", "m07_split_warning",
            "m08_board_full", "m09_first_item_stored", "m10_spawner_resting",
            "m11_out_of_kibble", "m12_no_merges_left",
            "m13_chain_viewer", "m14_first_daily_hand_in", "m15_toolbox",
            "m16_map_area_affordable", "m17_first_card_pack", "m18_free_chest",
            "m19_first_bubble", "m20_sell_vs_order",
            "m22_first_wildcard",
        ])
    }

    func testGroupsMatchTheSpecTables() {
        let a: [TutorialMoment] = [.firstSpawn, .firstMerge, .orderOnHold, .firstDeliver,
                                   .afterDeliver, .firstQuestClaim, .splitWarning]
        let b: [TutorialMoment] = [.boardFull, .firstItemStored, .spawnerResting,
                                   .outOfKibble, .noMergesLeft]
        let c: [TutorialMoment] = [.chainViewer, .firstDailyHandIn, .toolbox, .mapAreaAffordable,
                                   .firstCardPack, .freeChest, .firstBubble, .sellVsOrder]
        XCTAssertEqual(TutorialMoment.allCases.filter { $0.group == .core }, a)
        XCTAssertEqual(TutorialMoment.allCases.filter { $0.group == .friction }, b)
        XCTAssertEqual(TutorialMoment.allCases.filter { $0.group == .features }, c)
        XCTAssertEqual(TutorialMoment.allCases.filter { $0.group == .afterGate }, [.firstWildcard])
    }

    func testSkipTipsMarksExactlyTheCoreGroupSeen() {
        XCTAssertEqual(Set(TutorialMoment.coreGroup), Set(TutorialMoment.allCases.filter { $0.group == .core }))
        XCTAssertEqual(TutorialMoment.coreGroup.count, 7)
    }

    func testSeenIDsThatThisBuildDoesNotKnowAreIgnoredWhenReadingButNotErased() {
        let stored = ["m01_first_spawn", "m99_from_a_later_build"]
        XCTAssertEqual(TutorialMoment.seenSet(from: stored), [.firstSpawn])
    }
}

// MARK: - The seen-set on the view model

@MainActor
final class TutorialSeenStoreTests: XCTestCase {

    private let completedKey = "tutorialCompleted"
    private let nudgeKey = "hasShownSellVsOrderNudge"
    private var savedCompleted: Any?
    private var savedNudge: Any?

    override func setUp() {
        super.setUp()
        GameStore.clear()
        let d = UserDefaults.standard
        savedCompleted = d.object(forKey: completedKey)
        savedNudge = d.object(forKey: nudgeKey)
        d.removeObject(forKey: completedKey)
        d.removeObject(forKey: nudgeKey)
    }

    override func tearDown() {
        let d = UserDefaults.standard
        if let v = savedCompleted { d.set(v, forKey: completedKey) } else { d.removeObject(forKey: completedKey) }
        if let v = savedNudge { d.set(v, forKey: nudgeKey) } else { d.removeObject(forKey: nudgeKey) }
        GameStore.clear()
        super.tearDown()
    }

    func testANewGameHasSeenNothing() {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        XCTAssertTrue(vm.seenTutorialMoments.isEmpty)
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstSpawn))
    }

    func testMarkingAMomentSeenSurvivesARelaunch() {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.markTutorialMomentSeen(.firstMerge)
        vm.markTutorialMomentSeen(.firstMerge)   // twice: stored once
        XCTAssertEqual(vm.seenTutorialMoments, ["m02_first_merge"])
        vm.persistNow()

        let relaunched = MergeBoardViewModel()
        relaunched.loadGame()
        XCTAssertTrue(relaunched.hasSeenTutorialMoment(.firstMerge))
        XCTAssertFalse(relaunched.hasSeenTutorialMoment(.firstSpawn))
    }

    func testSkipTipsMarksTheWholeCoreGroupAndNothingElse() {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.skipTutorialTips()
        for moment in TutorialMoment.allCases {
            XCTAssertEqual(vm.hasSeenTutorialMoment(moment), moment.group == .core, "\(moment)")
        }
    }

    func testAnUnknownStoredIDSurvivesMarkingAnotherMoment() {
        let first = MergeBoardViewModel()
        first.loadGame()
        first.seenTutorialMoments = ["m99_from_a_later_build"]
        first.persistNow()

        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.markTutorialMomentSeen(.firstSpawn)
        XCTAssertEqual(vm.seenTutorialMoments, ["m99_from_a_later_build", "m01_first_spawn"])
    }

    func testTheOldTutorialCompletedFlagMarksTheCoreGroupSeen() {
        UserDefaults.standard.set(true, forKey: completedKey)
        let vm = MergeBoardViewModel()
        vm.loadGame()
        for moment in TutorialMoment.coreGroup { XCTAssertTrue(vm.hasSeenTutorialMoment(moment), "\(moment)") }
        XCTAssertFalse(vm.hasSeenTutorialMoment(.sellVsOrder))
        XCTAssertTrue(UserDefaults.standard.bool(forKey: completedKey), "the old key is left alone")
    }

    func testTheOldSellNudgeFlagMarksThatMomentSeen() {
        UserDefaults.standard.set(true, forKey: nudgeKey)
        let vm = MergeBoardViewModel()
        vm.loadGame()
        XCTAssertTrue(vm.hasSeenTutorialMoment(.sellVsOrder))
        XCTAssertFalse(vm.hasSeenTutorialMoment(.firstSpawn))
    }

    func testResettingToAFreshGameForgetsEverySeenMoment() {
        let vm = MergeBoardViewModel()
        vm.loadGame()
        vm.skipTutorialTips()
        vm.resetToFreshGame()
        XCTAssertTrue(vm.seenTutorialMoments.isEmpty)
    }
}
