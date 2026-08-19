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
