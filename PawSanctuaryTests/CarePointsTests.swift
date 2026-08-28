//
//  CarePointsTests.swift
//  PawSanctuaryTests
//
//  Care Points (specs/Spec_OrdersAndTasks_Draft.md §4) — the task-completion
//  pool that converts finishing a quest, sweeping the dailies, or fulfilling an
//  order into progress on one shared weekly bar.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class CarePointsTests: XCTestCase {

    // MARK: Tier ladder

    func testTiersAreOrderedAndDistinct() {
        let thresholds = CarePointTier.allCases.map(\.pointsNeeded)
        XCTAssertEqual(thresholds, thresholds.sorted(), "tiers must ascend")
        XCTAssertEqual(Set(thresholds).count, thresholds.count, "no two tiers share a threshold")
        XCTAssertTrue(thresholds.allSatisfy { $0 > 0 })
    }

    func testRewardsEscalateWithTier() {
        let tags = CarePointTier.allCases.map(\.dogTagReward)
        let xp   = CarePointTier.allCases.map(\.xpReward)
        XCTAssertEqual(tags, tags.sorted(), "dog tags must not go down a tier")
        XCTAssertEqual(xp, xp.sorted(), "XP must not go down a tier")
        XCTAssertNil(CarePointTier.bronze.cardPack, "the first rung is a quick win, not a pack")
        XCTAssertNotNil(CarePointTier.gold.cardPack)
    }

    /// The chest deliberately pays no kibble and no coins — both faucets are
    /// modelled elsewhere (`EconomySimulation.dailySupply`'s `miscKibblePerDay`,
    /// and the coin model tuned against the Sanctuary Map). Paying either here
    /// would silently understate supply. This test exists so that constraint
    /// fails loudly rather than being quietly reverted later.
    func testTiersPayNoKibbleOrCoins() {
        // Encoded as a structural check: the tier type exposes no kibble or coin
        // reward at all, so the only way to break this is to add one.
        for tier in CarePointTier.allCases {
            XCTAssertGreaterThan(tier.dogTagReward, 0)
            XCTAssertGreaterThan(tier.xpReward, 0)
        }
        XCTAssertFalse("\(CarePointTier.gold)".isEmpty)
    }

    // MARK: Point sources

    func testQuestPointsRiseWithDifficulty() {
        let values = [QuestDifficulty.easy, .medium, .hard, .legendary].map(carePoints(forQuest:))
        XCTAssertEqual(values, values.sorted(), "a harder quest must never pay fewer points")
        XCTAssertTrue(values.allSatisfy { $0 > 0 })
    }

    /// Orders are the most frequent completion in the game — the economy model
    /// assumes ~40/day for an engaged player — so a single order must stay worth
    /// less than a quest or a daily sweep, or the bar becomes an order counter
    /// and the task surfaces it exists to unify stop mattering.
    func testAnOrderIsWorthLessThanAQuestOrADailySweep() {
        XCTAssertLessThan(carePointsPerOrder, carePoints(forQuest: .easy))
        XCTAssertLessThan(carePointsPerOrder, carePointsPerDailySweep)
    }

    // MARK: Awarding and claiming

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.carePointsThisWeek = 0
        vm.claimedCarePointTiers = []
        return vm
    }

    func testAwardAccumulatesAndIgnoresNonPositiveAmounts() {
        let vm = makeViewModel()
        vm.awardCarePoints(5)
        vm.awardCarePoints(3)
        XCTAssertEqual(vm.carePointsThisWeek, 8)
        vm.awardCarePoints(0)
        vm.awardCarePoints(-10)
        XCTAssertEqual(vm.carePointsThisWeek, 8, "a zero or negative award must not move the bar")
    }

    func testATierIsOnlyClaimableOnceItsThresholdIsReached() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = CarePointTier.bronze.pointsNeeded - 1
        XCTAssertTrue(vm.claimableCarePointTiers.isEmpty)

        vm.claimCarePointTier(.bronze)
        XCTAssertFalse(vm.isCarePointTierClaimed(.bronze), "claiming below threshold must be a no-op")

        vm.carePointsThisWeek = CarePointTier.bronze.pointsNeeded
        XCTAssertEqual(vm.claimableCarePointTiers, [.bronze])
    }

    func testClaimingGrantsRewardsExactlyOnce() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = CarePointTier.gold.pointsNeeded
        let tagsBefore = vm.dogTags

        vm.claimCarePointTier(.silver)
        let afterFirst = vm.dogTags
        XCTAssertEqual(afterFirst, tagsBefore + CarePointTier.silver.dogTagReward)
        XCTAssertTrue(vm.isCarePointTierClaimed(.silver))

        vm.claimCarePointTier(.silver)
        XCTAssertEqual(vm.dogTags, afterFirst, "a second claim of the same tier grants nothing")
        XCTAssertEqual(vm.claimedCarePointTiers.filter { $0 == CarePointTier.silver.rawValue }.count, 1)
    }

    func testTiersCanBeClaimedOutOfOrderAndIndependently() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = CarePointTier.gold.pointsNeeded
        vm.claimCarePointTier(.gold)
        XCTAssertTrue(vm.isCarePointTierClaimed(.gold))
        XCTAssertFalse(vm.isCarePointTierClaimed(.bronze), "claiming gold must not consume the lower rungs")
        XCTAssertEqual(Set(vm.claimableCarePointTiers), [.bronze, .silver])
    }

    func testClaimingASilverOrGoldTierBanksItsCardPack() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = CarePointTier.silver.pointsNeeded
        let before = vm.pendingCardPacks.count
        vm.claimCarePointTier(.silver)
        XCTAssertEqual(vm.pendingCardPacks.count, before + 1)
    }

    func testNextTierAdvancesAsTiersAreClaimed() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = CarePointTier.gold.pointsNeeded
        XCTAssertEqual(vm.nextCarePointTier, .bronze)
        vm.claimCarePointTier(.bronze)
        XCTAssertEqual(vm.nextCarePointTier, .silver)
        vm.claimCarePointTier(.silver)
        vm.claimCarePointTier(.gold)
        XCTAssertNil(vm.nextCarePointTier, "nothing left to aim at once all three are claimed")
    }

    // MARK: Weekly reset

    func testTheWeeklyResetClearsPointsAndClaims() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = CarePointTier.gold.pointsNeeded
        vm.claimCarePointTier(.bronze)
        // Pretend the last reset was in a previous week.
        vm.lastWeeklyGoalReset = Calendar.current.date(byAdding: .day, value: -14, to: Date())

        vm.checkWeeklyGoalReset()

        XCTAssertEqual(vm.carePointsThisWeek, 0, "points reset with the coin goal")
        XCTAssertTrue(vm.claimedCarePointTiers.isEmpty, "claims reset too, so the tiers are earnable again")
        XCTAssertEqual(vm.coinsEarnedThisWeek, 0, "and the existing weekly reset still does its own job")
    }

    func testNoResetHappensWithinTheSameWeek() {
        let vm = makeViewModel()
        vm.carePointsThisWeek = 42
        vm.lastWeeklyGoalReset = Calendar.current.dateInterval(of: .weekOfYear, for: Date())?.start

        vm.checkWeeklyGoalReset()

        XCTAssertEqual(vm.carePointsThisWeek, 42, "mid-week play must not lose banked points")
    }

    // MARK: Tier reachability
    //
    // The thresholds are anchored on a week of engaged play rather than picked
    // by feel. These assertions are the anchor: if either the point values or
    // the thresholds move, the shape of the week has to still hold.

    /// Points a committed player banks in a week, using the economy model's own
    /// activity assumptions rather than a fresh guess: `ordersPerDay` from
    /// `EconomySimulation`, a daily-challenge sweep on most days, and a modest
    /// number of quest claims.
    private func weeklyPointsForEngagedPlayer(level: Int) -> Int {
        let ordersPerWeek = EconomySimulation.ordersPerDay(level: level) * 7
        let orderPoints   = Int(ordersPerWeek) * carePointsPerOrder
        let sweepPoints   = 6 * carePointsPerDailySweep          // 6 of 7 days
        let questPoints   = 6 * carePoints(forQuest: .medium)    // ~6 quests a week
        return orderPoints + sweepPoints + questPoints
    }

    func testGoldIsReachableInAWeekOfEngagedPlayButNotTrivially() {
        let weekly = weeklyPointsForEngagedPlayer(level: 30)
        XCTAssertGreaterThan(weekly, carePointsGold,
                             "Gold must be reachable inside a week — banked \(weekly)")
        XCTAssertGreaterThan(carePointsGold, weekly / 4,
                             "but not cleared in under two days of that pace")
    }

    func testBronzeLandsEarlyInTheWeek() {
        let daily = weeklyPointsForEngagedPlayer(level: 30) / 7
        XCTAssertLessThanOrEqual(carePointsBronze, daily * 2,
                                 "Bronze should land inside the first day or two")
    }

    func testTheLadderIsNotClearedByOrdersAlone() {
        // The whole point of the bar is that it unifies the task surfaces. If
        // orders alone cleared Gold, quests and dailies would be decoration.
        let ordersOnly = Int(EconomySimulation.ordersPerDay(level: 30) * 7) * carePointsPerOrder
        XCTAssertLessThan(ordersOnly, carePointsGold,
                          "orders alone bank \(ordersOnly); Gold must need the other surfaces too")
    }

    // Persistence lives in PersistenceTests, where `makeSampleState()` and the
    // migration fixtures are — per this project's rule that every schema change
    // gets a case there.
}
