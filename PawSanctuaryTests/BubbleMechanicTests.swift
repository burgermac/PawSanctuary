import XCTest
@testable import PawSanctuary

@MainActor
final class BubbleMechanicTests: XCTestCase {
    private func chainID(_ s: AnimalSpecies) -> ChainID { ContentRegistry.animalChainID(s) }

    private func makeOrder(chainID: ChainID, tier: Int) -> AdoptionOrder {
        AdoptionOrder(familyIndex: 0, wantedChainID: chainID, wantedTier: tier, wantedCount: 1)
    }

    private func makeQuest(goal: QuestGoal, progress: Int = 0) -> Quest {
        Quest(goal: goal, difficulty: .medium, progress: progress, dogTagReward: 3, kibbleReward: 4)
    }

    func testNoOrdersOrQuestsIsNotEligible() {
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 3, orders: [], urgentOrder: nil, quests: [])
        XCTAssertFalse(result)
    }

    func testOrderWantingExactChainAndTierIsEligible() {
        let order = makeOrder(chainID: chainID(.cat), tier: 3)
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 3, orders: [order], urgentOrder: nil, quests: [])
        XCTAssertTrue(result)
    }

    func testOrderWantingSameChainDifferentTierIsNotEligible() {
        let order = makeOrder(chainID: chainID(.cat), tier: 2)
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 3, orders: [order], urgentOrder: nil, quests: [])
        XCTAssertFalse(result)
    }

    func testUrgentOrderWantingExactChainAndTierIsEligible() {
        let urgent = makeOrder(chainID: chainID(.dog), tier: 5)
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.dog), tier: 5, orders: [], urgentOrder: urgent, quests: [])
        XCTAssertTrue(result)
    }

    func testMergeInChainQuestMatchesAnyTier() {
        let quest = makeQuest(goal: .mergeInChain(chainID(.cat), count: 4))
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 7, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertTrue(result)
    }

    func testMergeInChainQuestForDifferentChainIsNotEligible() {
        let quest = makeQuest(goal: .mergeInChain(chainID(.dog), count: 4))
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 7, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertFalse(result)
    }

    func testReachTierQuestMatchingTierIsEligible() {
        let quest = makeQuest(goal: .reachTier(.animal, tier: 6, count: 1))
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 6, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertTrue(result)
    }

    func testReachTierQuestNonMatchingTierIsNotEligible() {
        let quest = makeQuest(goal: .reachTier(.animal, tier: 6, count: 1))
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 5, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertFalse(result)
    }

    func testReachTierQuestForNonAnimalCategoryIsNotEligible() {
        let quest = makeQuest(goal: .reachTier(.supply, tier: 6, count: 1))
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 6, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertFalse(result)
    }

    func testCompletedQuestDoesNotCount() {
        let quest = makeQuest(goal: .mergeInChain(chainID(.cat), count: 4), progress: 4)
        XCTAssertTrue(quest.isComplete)
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 7, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertFalse(result)
    }

    func testMergeAnyGoalIsNeverEligible() {
        let quest = makeQuest(goal: .mergeAny(count: 4))
        let result = isBubbleEligibleForQuestOrOrder(
            chainID: chainID(.cat), tier: 7, orders: [], urgentOrder: nil, quests: [quest])
        XCTAssertFalse(result)
    }
}
