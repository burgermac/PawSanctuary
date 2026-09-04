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

    // Spec_DailyHandInTasks.md replaced the two daily-challenge tests that
    // used to live here:
    //
    //  - `testDailyChallengeReachTierAnchorCanTargetTopThreeTiers` — daily
    //    challenges no longer carry `QuestGoal`s at all, so there is no
    //    reachTier anchor to reach the top three tiers. Deep stages are still
    //    reachable, now as basket lines; `DailyHandInTasksTests` covers that
    //    against `maxAchievableOrderTier` instead.
    //  - `testDailyChallengeStaggerLandsInTargetBand` — the shared-anchor
    //    stagger it guarded is deliberately gone (spec D-C, an explicit
    //    override of Gap_Analysis_Round2.md 3.1). Deleting the test with the
    //    mechanic rather than weakening it: a stagger assertion that no longer
    //    has a stagger to assert would be worse than none.
    //
    // The standing-quest reachTier coverage above is untouched — that is where
    // the near-miss psychology still operates.
}
