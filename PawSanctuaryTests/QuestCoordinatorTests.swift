//
//  QuestCoordinatorTests.swift
//  PawSanctuaryTests
//
//  Covers the fix for the top-of-chain quest gap: RescueStage (the legacy
//  quest-tier enum) only reaches tierIndex 8, but Phase 2b's animal chains run
//  0...11, so tiers 9-11 ("Mythic"/"Ancient"/"Primordial") had no quest-
//  generation path even though QuestGoal.animalTierAppearance already had
//  labels ready for them. See TODO.md / docs/CODE_HEALTH.md.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class QuestCoordinatorTests: XCTestCase {

    func testReachTierDescribesTheTopThreeTiers() {
        XCTAssertEqual(QuestGoal.reachTier(.animal, tier: 9, count: 1).description,
                       "Get 1 animal to Mythic (Tier 10)")
        XCTAssertEqual(QuestGoal.reachTier(.animal, tier: 10, count: 1).description,
                       "Get 1 animal to Ancient (Tier 11)")
        XCTAssertEqual(QuestGoal.reachTier(.animal, tier: 11, count: 1).description,
                       "Get 1 animal to Primordial (Tier 12)")
    }

    func testLegendaryQuestPoolCanTargetTopThreeTiers() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        var seenTopTiers: Set<Int> = []
        for _ in 0..<2000 {
            let quest = coordinator.generateQuest(unlockedChainIDs: [dogID], playerLevel: 60)
            if case .reachTier(.animal, let tier, _) = quest.goal, tier >= 9 {
                seenTopTiers.insert(tier)
            }
        }
        XCTAssertEqual(seenTopTiers, [9, 10, 11],
                       "A max-level player's legendary quests should eventually cover all three top tiers")
    }

    func testDailyChallengeReachTierAnchorCanTargetTopThreeTiers() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        var seenTopTiers: Set<Int> = []
        for _ in 0..<2000 {
            coordinator.generateDailyChallenges(unlockedChainIDs: [dogID])
            for challenge in coordinator.dailyChallenges {
                if case .reachTier(.animal, let tier, _) = challenge.goal, tier >= 9 {
                    seenTopTiers.insert(tier)
                }
            }
        }
        XCTAssertEqual(seenTopTiers, [9, 10, 11],
                       "Daily challenges should eventually cover all three top tiers via the reachTier anchor")
    }

    // Gap_Analysis_Round2.md 3.1: the daily-challenge stagger's whole point is
    // that medium/hard are already 60-90% along the instant the slot below
    // them completes, since all three share one anchor goal tracked in
    // lockstep. Verify the guarantee holds across many generated days, not
    // just by inspection of the formula.
    func testDailyChallengeStaggerLandsInTargetBand() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        for _ in 0..<500 {
            coordinator.generateDailyChallenges(unlockedChainIDs: [dogID])
            let easy   = coordinator.dailyChallenges[0].goal.targetCount
            let medium = coordinator.dailyChallenges[1].goal.targetCount
            let hard   = coordinator.dailyChallenges[2].goal.targetCount
            let easyToMedium = Double(easy) / Double(medium)
            let mediumToHard = Double(medium) / Double(hard)
            // A little wider than the [0.6, 0.9] target band to absorb rounding at
            // the small counts daily challenges actually use, without flaking.
            XCTAssertTrue((0.55...0.92).contains(easyToMedium),
                           "medium should be well underway (\(easy)/\(medium)) when easy completes")
            XCTAssertTrue((0.55...0.92).contains(mediumToHard),
                           "hard should be well underway (\(medium)/\(hard)) when medium completes")
        }
    }
}
