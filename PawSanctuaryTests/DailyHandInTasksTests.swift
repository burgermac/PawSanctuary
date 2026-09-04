//
//  DailyHandInTasksTests.swift
//  PawSanctuaryTests
//
//  Spec_DailyHandInTasks.md — daily challenges as baskets of specific
//  creatures the player holds on the board and hands in for coins.
//
//  Split by the three things that can independently go wrong: what gets
//  generated, what the board census counts, and what a claim actually does to
//  the board and the wallet.
//

import XCTest
import SwiftUI
@testable import PawSanctuary

// ============================================================
// MARK: - GENERATION
// ============================================================

@MainActor
final class DailyHandInTaskGenerationTests: XCTestCase {

    private let dog = ContentRegistry.animalChainID(.dog)
    private let cat = ContentRegistry.animalChainID(.cat)

    func testGeneratesOneTaskPerFixedDifficultySlot() {
        let coordinator = QuestCoordinator()
        coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: 30)

        XCTAssertEqual(coordinator.dailyChallenges.map(\.difficulty), [.easy, .medium, .hard],
                       "the slot spread is fixed so a day can never roll three easy tasks by chance")
    }

    func testEveryLineComesFromAChainThePlayerHasUnlocked() {
        let coordinator = QuestCoordinator()
        for _ in 0..<300 {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog, cat], playerLevel: 60)
            for task in coordinator.dailyChallenges {
                for line in task.lines {
                    XCTAssertTrue([dog, cat].contains(line.chainID),
                                  "a task must never ask for a family the player cannot spawn")
                }
            }
        }
    }

    /// The whole "not all final merge stage creatures" requirement: a task must
    /// never ask for a stage the player's level cannot reach.
    func testNoLineEverExceedsTheLevelCappedMaximumTier() {
        let coordinator = QuestCoordinator()
        for level in [1, 5, 12, 25, 45] {
            let cap = maxAchievableOrderTier(forPlayerLevel: level)
            for _ in 0..<200 {
                coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: level)
                for task in coordinator.dailyChallenges {
                    for line in task.lines {
                        XCTAssertLessThanOrEqual(line.tier, cap,
                                                 "level \(level) must never be asked for tier \(line.tier)")
                        XCTAssertGreaterThanOrEqual(line.tier, 0)
                    }
                }
            }
        }
    }

    /// Replaces `QuestCoordinatorTests.testDailyChallengeReachTierAnchorCanTargetTopThreeTiers`.
    /// Deep stages stay reachable — as basket lines now, not as a reachTier anchor.
    func testAMaxLevelPlayerEventuallySeesDeepStagesAsked() {
        let coordinator = QuestCoordinator()
        var seenDeep: Set<Int> = []
        for _ in 0..<3_000 {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: 60)
            for task in coordinator.dailyChallenges {
                for line in task.lines where line.tier >= 9 { seenDeep.insert(line.tier) }
            }
        }
        XCTAssertEqual(seenDeep, [9, 10, 11],
                       "the hard band's tail must still reach the top of the chain")
    }

    /// A mix of stages is the point — a day that only ever asked for tier 0
    /// would be the same complaint the counted-event dailies drew.
    func testATaskSetSpansMoreThanOneStage() {
        let coordinator = QuestCoordinator()
        var seenTiers: Set<Int> = []
        for _ in 0..<200 {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: 30)
            for task in coordinator.dailyChallenges {
                for line in task.lines { seenTiers.insert(line.tier) }
            }
        }
        XCTAssertGreaterThan(seenTiers.count, 3,
                             "tasks should span several merge stages, not cluster on one")
    }

    func testNoTaskEverListsTheSameCreatureTwice() {
        let coordinator = QuestCoordinator()
        for _ in 0..<500 {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: 3)
            for task in coordinator.dailyChallenges {
                let keys = task.lines.map(\.key)
                XCTAssertEqual(Set(keys).count, keys.count,
                               "duplicate (chain, stage) lines must collapse into one with a higher count")
            }
        }
    }

    func testFallsBackToAStarterChainRatherThanGeneratingAnEmptyBasket() {
        let coordinator = QuestCoordinator()
        coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [], playerLevel: 1)

        for task in coordinator.dailyChallenges {
            XCTAssertFalse(task.lines.isEmpty,
                           "an empty basket would read as instantly claimable and pay out for free")
        }
    }

    /// The invariant `orderSellValue` exists to enforce for orders, and it
    /// bites harder here because a daily task genuinely takes the creatures.
    func testThePayoutAlwaysBeatsSellingTheSameCreaturesOutright() {
        let coordinator = QuestCoordinator()
        for _ in 0..<300 {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog, cat], playerLevel: 45)
            for task in coordinator.dailyChallenges {
                XCTAssertGreaterThan(task.coinReward, dailyTaskSellValue(lines: task.lines),
                                     "handing in must never be worse than selling — that would be a trap")
            }
        }
    }
}

// ============================================================
// MARK: - CENSUS & HIGHLIGHT
// ============================================================

@MainActor
final class DailyHandInTaskCensusTests: XCTestCase {

    private let dog = ContentRegistry.animalChainID(.dog)

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        return vm
    }

    private func place(_ vm: MergeBoardViewModel, tier: Int, at col: Int, bubbled: Bool = false) {
        vm.boardState.setItem(
            BoardItem(chainID: dog, tier: tier,
                      bubbledAt: bubbled ? Date().timeIntervalSince1970 : nil),
            at: GridPosition(row: 0, col: col))
    }

    func testCountsUnlockedBoardCellsByChainAndStage() {
        let vm = makeViewModel()
        place(vm, tier: 0, at: 0)
        place(vm, tier: 0, at: 1)
        place(vm, tier: 3, at: 2)

        let census = vm.boardTaskCensus
        XCTAssertEqual(census[ChainTierKey(chainID: dog, tier: 0)], 2)
        XCTAssertEqual(census[ChainTierKey(chainID: dog, tier: 3)], 1)
        XCTAssertNil(census[ChainTierKey(chainID: dog, tier: 1)])
    }

    /// Hand-in asks the player to hold the creature *on the board* — that
    /// board-space pressure is the mechanic. `mergeReadyKeys` counts inventory
    /// because "can I merge this next" genuinely spans both; this must not.
    func testDoesNotCountInventory() {
        let vm = makeViewModel()
        XCTAssertTrue(vm.addToInventory(BoardItem(chainID: dog, tier: 0)))

        XCTAssertNil(vm.boardTaskCensus[ChainTierKey(chainID: dog, tier: 0)],
                     "a creature stashed in inventory is not standing on the board")
    }

    func testDoesNotCountBubbledItems() {
        let vm = makeViewModel()
        place(vm, tier: 0, at: 0, bubbled: true)

        XCTAssertNil(vm.boardTaskCensus[ChainTierKey(chainID: dog, tier: 0)],
                     "a creature still encased is not yet the player's to give")
    }

    func testDoesNotCountLockedCells() {
        let vm = makeViewModel()
        place(vm, tier: 0, at: 0)
        vm.board[0][0].isUnlocked = false

        XCTAssertNil(vm.boardTaskCensus[ChainTierKey(chainID: dog, tier: 0)])
    }

    func testHighlightIsMutedWhileATaskIsShortAndBrightOnceItIsStocked() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 2)],
                           difficulty: .easy, coinReward: 10),
        ]
        let key = ChainTierKey(chainID: dog, tier: 0)

        place(vm, tier: 0, at: 0)
        XCTAssertEqual(vm.dailyTaskHighlights[key], .wanted)

        place(vm, tier: 0, at: 1)
        XCTAssertEqual(vm.dailyTaskHighlights[key], .stocked,
                       "the tint brightens only once every line of the task is stocked")
    }

    func testAStockedTaskOutranksAnUnfinishedOneOnASharedCreature() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                           difficulty: .easy, coinReward: 10),
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1),
                                   DailyTaskLine(chainID: dog, tier: 5, count: 1)],
                           difficulty: .hard, coinReward: 900),
        ]
        place(vm, tier: 0, at: 0)

        XCTAssertEqual(vm.dailyTaskHighlights[ChainTierKey(chainID: dog, tier: 0)], .stocked,
                       "a creature serving one ready task should read as ready to hand in")
    }

    func testAClaimedTaskStopsHighlightingAnything() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                           difficulty: .easy, coinReward: 10, isClaimed: true),
        ]
        place(vm, tier: 0, at: 0)

        XCTAssertTrue(vm.dailyTaskHighlights.isEmpty)
    }

    func testAnEmptyBasketIsNeverStocked() {
        let task = DailyChallenge(lines: [], difficulty: .easy, coinReward: 10)
        XCTAssertFalse(task.isStocked(census: [:]))
    }
}

// ============================================================
// MARK: - CLAIM
// ============================================================

@MainActor
final class DailyHandInTaskClaimTests: XCTestCase {

    private let dog = ContentRegistry.animalChainID(.dog)
    private let cat = ContentRegistry.animalChainID(.cat)

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        return vm
    }

    private func place(_ vm: MergeBoardViewModel, _ chainID: ChainID, tier: Int,
                       row: Int = 0, col: Int) {
        vm.boardState.setItem(BoardItem(chainID: chainID, tier: tier),
                              at: GridPosition(row: row, col: col))
    }

    private func boardCount(_ vm: MergeBoardViewModel, _ chainID: ChainID, tier: Int) -> Int {
        vm.boardTaskCensus[ChainTierKey(chainID: chainID, tier: tier)] ?? 0
    }

    func testClaimingSurrendersExactlyWhatWasAskedForAndNoMore() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 2)],
                                  difficulty: .easy, coinReward: 50)
        vm.quests.dailyChallenges = [task]
        for col in 0..<4 { place(vm, dog, tier: 0, col: col) }

        vm.claimDailyTask(id: task.id)

        XCTAssertEqual(boardCount(vm, dog, tier: 0), 2,
                       "4 on the board minus the 2 the task asked for — surplus must survive")
    }

    func testClaimingTakesFromEveryLineOfABasket() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1),
                                          DailyTaskLine(chainID: cat, tier: 2, count: 2)],
                                  difficulty: .hard, coinReward: 400)
        vm.quests.dailyChallenges = [task]
        place(vm, dog, tier: 0, col: 0)
        place(vm, cat, tier: 2, col: 1)
        place(vm, cat, tier: 2, col: 2)

        vm.claimDailyTask(id: task.id)

        XCTAssertEqual(boardCount(vm, dog, tier: 0), 0)
        XCTAssertEqual(boardCount(vm, cat, tier: 2), 0)
    }

    func testClaimingPaysTheCardsCoinsAndMarksTheTaskHandedIn() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                                  difficulty: .easy, coinReward: 137)
        // Two unreachable companions so claiming this one does not also trip
        // the all-three sweep bonus, whose 400 coins would mask the payout
        // under test. The sweep has its own tests below.
        vm.quests.dailyChallenges = [
            task,
            DailyChallenge(lines: [DailyTaskLine(chainID: cat, tier: 9, count: 1)],
                           difficulty: .medium, coinReward: 500),
            DailyChallenge(lines: [DailyTaskLine(chainID: cat, tier: 10, count: 1)],
                           difficulty: .hard, coinReward: 900),
        ]
        place(vm, dog, tier: 0, col: 0)
        let coinsBefore = vm.coins

        vm.claimDailyTask(id: task.id)

        XCTAssertEqual(vm.coins, coinsBefore + 137,
                       "the payout must be the number the card showed, not a recomputed one")
        XCTAssertTrue(vm.quests.dailyChallenges[0].isClaimed)
    }

    func testAShortTaskCannotBeClaimedAndTakesNothing() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 3)],
                                  difficulty: .easy, coinReward: 90)
        vm.quests.dailyChallenges = [task]
        place(vm, dog, tier: 0, col: 0)
        let coinsBefore = vm.coins

        vm.claimDailyTask(id: task.id)

        XCTAssertFalse(vm.quests.dailyChallenges[0].isClaimed)
        XCTAssertEqual(vm.coins, coinsBefore)
        XCTAssertEqual(boardCount(vm, dog, tier: 0), 1,
                       "a refused claim must not eat the pieces it could not complete")
    }

    /// The card can sit on screen while the board changes under it, so the
    /// stock check re-runs against the live census at claim time.
    func testATaskThatWasStockedButNoLongerIsCannotBeClaimed() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                                  difficulty: .easy, coinReward: 90)
        vm.quests.dailyChallenges = [task]
        place(vm, dog, tier: 0, col: 0)
        XCTAssertTrue(vm.isDailyTaskStocked(task))

        vm.boardState.clearItem(at: GridPosition(row: 0, col: 0))
        let coinsBefore = vm.coins
        vm.claimDailyTask(id: task.id)

        XCTAssertFalse(vm.quests.dailyChallenges[0].isClaimed)
        XCTAssertEqual(vm.coins, coinsBefore)
    }

    func testATaskCannotBeClaimedTwice() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                                  difficulty: .easy, coinReward: 60)
        vm.quests.dailyChallenges = [task]
        place(vm, dog, tier: 0, col: 0)
        place(vm, dog, tier: 0, col: 1)

        vm.claimDailyTask(id: task.id)
        let coinsAfterFirst = vm.coins
        vm.claimDailyTask(id: task.id)

        XCTAssertEqual(vm.coins, coinsAfterFirst, "a claimed task must not pay again")
        XCTAssertEqual(boardCount(vm, dog, tier: 0), 1,
                       "and must not take a second creature either")
    }

    func testClaimingNeverTakesABubbledCreature() {
        let vm = makeViewModel()
        let task = DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                                  difficulty: .easy, coinReward: 60)
        vm.quests.dailyChallenges = [task]
        // Bubbled one sits earlier in scan order than the free one.
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 0,
                                        bubbledAt: Date().timeIntervalSince1970),
                              at: GridPosition(row: 0, col: 0))
        place(vm, dog, tier: 0, col: 1)

        vm.claimDailyTask(id: task.id)

        XCTAssertNotNil(vm.boardState.item(at: GridPosition(row: 0, col: 0))?.bubbledAt,
                        "the bubbled creature must be skipped, not surrendered")
        XCTAssertNil(vm.boardState.item(at: GridPosition(row: 0, col: 1)))
    }

    /// The sweep now fires on the third *claim*, not the third counter filling.
    func testClaimingAllThreeStillPaysTheExistingSweepBonus() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = (0..<3).map { i in
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                           difficulty: [.easy, .medium, .hard][i], coinReward: 20)
        }
        for col in 0..<3 { place(vm, dog, tier: 0, col: col) }
        let dogTagsBefore = vm.dogTags
        XCTAssertFalse(vm.quests.dailyChallengeBonusClaimed)

        for task in vm.quests.dailyChallenges { vm.claimDailyTask(id: task.id) }

        XCTAssertTrue(vm.quests.dailyChallengeBonusClaimed)
        XCTAssertGreaterThan(vm.dogTags, dogTagsBefore,
                             "the all-three bonus is unchanged — only its trigger moved to the claim")
    }

    func testTheSweepDoesNotFireUntilTheLastTaskIsActuallyClaimed() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = (0..<3).map { i in
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                           difficulty: [.easy, .medium, .hard][i], coinReward: 20)
        }
        for col in 0..<3 { place(vm, dog, tier: 0, col: col) }

        vm.claimDailyTask(id: vm.quests.dailyChallenges[0].id)
        vm.claimDailyTask(id: vm.quests.dailyChallenges[1].id)

        XCTAssertFalse(vm.quests.dailyChallengeBonusClaimed,
                       "all three stocked is not the trigger — all three handed in is")
    }
}
