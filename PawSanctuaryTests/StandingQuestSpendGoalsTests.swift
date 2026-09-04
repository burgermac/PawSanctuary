//
//  StandingQuestSpendGoalsTests.swift
//  PawSanctuaryTests
//
//  D6 follow-up (Spec_StandingQuestSpendGoals.md) Task 3.1 — the eight new
//  .spendCurrency pool entries added to generateQuest's four per-difficulty
//  pools. Mirrors the statistical style QuestCoordinatorTests.swift already
//  uses for anchor/pool reachability (e.g.
//  testLegendaryQuestPoolCanTargetTopThreeTiers) rather than trying to force
//  a specific difficulty/goal deterministically — generateQuest's difficulty
//  roll and pool selection are both genuinely random by design.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class StandingQuestSpendGoalsTests: XCTestCase {

    private func anySpendCurrency(_ goal: QuestGoal) -> RewardKind? {
        if case .spendCurrency(let kind, _) = goal { return kind }
        return nil
    }

    /// playerLevel: 60 uncapped (matches the existing legendary-reachability
    /// test's own choice) so every difficulty, including legendary (roll==20,
    /// ~5% per generation), is reachable across enough iterations.
    func testBothCurrenciesAreReachableAtEveryDifficulty() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        var seenKinds: [QuestDifficulty: Set<RewardKind>] = [:]

        for _ in 0..<4000 {
            let quest = coordinator.generateQuest(unlockedChainIDs: [dogID], playerLevel: 60)
            if let kind = anySpendCurrency(quest.goal) {
                seenKinds[quest.difficulty, default: []].insert(kind)
            }
        }

        let allDifficulties: [QuestDifficulty] = [.easy, .medium, .hard, .legendary]
        for difficulty in allDifficulties {
            XCTAssertEqual(seenKinds[difficulty], [.kibble, .dogTags],
                           "both currencies must be independently reachable at \(difficulty)")
        }
    }

    func testTargetCountsMatchSection4ExactlyAtEveryDifficulty() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        let expectedKibble: [QuestDifficulty: Int]  = [.easy: 40, .medium: 70, .hard: 110, .legendary: 220]
        let expectedDogTags: [QuestDifficulty: Int] = [.easy: 8,  .medium: 14, .hard: 22,  .legendary: 44]

        for _ in 0..<4000 {
            let quest = coordinator.generateQuest(unlockedChainIDs: [dogID], playerLevel: 60)
            guard let kind = anySpendCurrency(quest.goal) else { continue }
            let expected = kind == .kibble ? expectedKibble[quest.difficulty] : expectedDogTags[quest.difficulty]
            XCTAssertEqual(quest.goal.targetCount, expected,
                           "\(kind) target at \(quest.difficulty) must match spec §4 exactly")
        }
    }

    /// The existing dedupeKey-based exclusion (generateQuest/setupQuests/
    /// claimAndReplace, unmodified by this task) must still work for the new
    /// case — a kibble-spend goal can be excluded independently of a
    /// dog-tag-spend goal, since dedupeKey keys on currency, not count.
    func testExcludingOneCurrencysDedupeKeyNeverProducesThatCurrencyButStillAllowsTheOther() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        var sawDogTagsSpend = false

        for _ in 0..<2000 {
            let quest = coordinator.generateQuest(unlockedChainIDs: [dogID], playerLevel: 60,
                                                   excluding: ["spendCurrency:kibble"])
            if let kind = anySpendCurrency(quest.goal) {
                XCTAssertNotEqual(kind, .kibble, "excluded dedupeKey must never be generated")
                if kind == .dogTags { sawDogTagsSpend = true }
            }
        }

        XCTAssertTrue(sawDogTagsSpend, "excluding kibble's dedupeKey must not also suppress dog tags")
    }
}

/// Task 3.2 — QuestCoordinator.updateQuestsAfterSpend, mirroring
/// updateQuestsAfterMerge's shape and D6's own updateDailyChallengesAfterSpend
/// (SpendQuotaDailiesTests.swift's SpendQuotaDailiesProgressTests) exactly,
/// but against activeQuests instead of dailyChallenges.
@MainActor
final class StandingQuestSpendGoalsProgressTests: XCTestCase {

    private func makeQuest(goal: QuestGoal, progress: Int = 0) -> Quest {
        Quest(goal: goal, difficulty: .medium, progress: progress, dogTagReward: 3, kibbleReward: 4)
    }

    func testAdvancesByTheFullAmountNotOne() {
        let coordinator = QuestCoordinator()
        coordinator.activeQuests = [makeQuest(goal: .spendCurrency(.kibble, count: 70))]

        coordinator.updateQuestsAfterSpend(kind: .kibble, amount: 15)

        XCTAssertEqual(coordinator.activeQuests[0].progress, 15,
                       "must add the real spend amount, not +1 the way merge-based quest updates do")
    }

    func testOnlyAdvancesQuestsMatchingTheSpentCurrency() {
        let coordinator = QuestCoordinator()
        coordinator.activeQuests = [
            makeQuest(goal: .spendCurrency(.kibble, count: 70)),
            makeQuest(goal: .spendCurrency(.dogTags, count: 14)),
        ]

        coordinator.updateQuestsAfterSpend(kind: .dogTags, amount: 5)

        XCTAssertEqual(coordinator.activeQuests[0].progress, 0, "a dog-tag spend must not advance a kibble quest")
        XCTAssertEqual(coordinator.activeQuests[1].progress, 5)
    }

    func testIgnoresNonSpendGoals() {
        let coordinator = QuestCoordinator()
        coordinator.activeQuests = [makeQuest(goal: .mergeAny(count: 3))]

        coordinator.updateQuestsAfterSpend(kind: .kibble, amount: 100)

        XCTAssertEqual(coordinator.activeQuests[0].progress, 0)
    }

    func testSkipsAlreadyCompleteQuests() {
        let coordinator = QuestCoordinator()
        coordinator.activeQuests = [makeQuest(goal: .spendCurrency(.kibble, count: 70), progress: 70)]

        coordinator.updateQuestsAfterSpend(kind: .kibble, amount: 10)

        XCTAssertEqual(coordinator.activeQuests[0].progress, 70,
                       "an already-complete quest must not keep accumulating")
    }
}

/// Task 3.2 — the updateAllAfterSpend chokepoint (MergeBoardViewModel) now
/// reaches activeQuests too, not just dailyChallenges. The dailyChallenges
/// side of this chokepoint is already covered by
/// SpendQuotaDailiesChokepointTests; this only needs to prove the new line
/// fires and doesn't disturb that existing behavior.
@MainActor
final class StandingQuestSpendGoalsChokepointTests: XCTestCase {

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    func testAdvancesAMatchingActiveQuest() {
        let vm = makeViewModel()
        vm.quests.activeQuests = [
            Quest(goal: .spendCurrency(.kibble, count: 70), difficulty: .medium,
                  dogTagReward: 3, kibbleReward: 4),
        ]

        vm.updateAllAfterSpend(kind: .kibble, amount: 70)

        XCTAssertTrue(vm.quests.activeQuests[0].isComplete)
    }

    /// Replaces `testStillAdvancesAMatchingDailyChallengeAlongsideTheQuest`.
    /// Daily challenges stopped being counted-event goals in
    /// Spec_DailyHandInTasks.md, so there is no longer a daily line in
    /// `updateAllAfterSpend` for the quest line to coexist with. What the
    /// original test was really guarding — that the quest line is reached
    /// through the chokepoint rather than only in the coordinator — is kept.
    func testTheQuestLineIsReachedThroughTheViewModelChokepointNotOnlyTheCoordinator() {
        let vm = makeViewModel()
        vm.quests.activeQuests = [
            Quest(goal: .spendCurrency(.kibble, count: 70), difficulty: .medium,
                  dogTagReward: 3, kibbleReward: 4),
            Quest(goal: .spendCurrency(.dogTags, count: 14), difficulty: .medium,
                  dogTagReward: 3, kibbleReward: 4),
        ]

        vm.updateAllAfterSpend(kind: .kibble, amount: 40)

        XCTAssertEqual(vm.quests.activeQuests[0].progress, 40)
        XCTAssertEqual(vm.quests.activeQuests[1].progress, 0,
                       "a kibble spend must not advance a dog-tag goal")
    }
}
