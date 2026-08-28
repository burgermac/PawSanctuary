//
//  SmilePointsTests.swift
//  PawSanctuaryTests
//
//  Smile Points (specs/Spec_OrdersAndTasks_Draft.md §2) — the fast repeating
//  loop over orders alone: every fulfilled order banks its visible Smile value,
//  and filling the bar scatters an assortment of board items.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class SmilePointsTests: XCTestCase {

    private var dog: ChainID { ContentRegistry.animalChainID(.dog) }
    private var cat: ChainID { ContentRegistry.animalChainID(.cat) }

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.smilePointsBanked = 0
        return vm
    }

    // MARK: Value banding

    func testSmileValueRisesWithTierAndStaysInRange() {
        let values = (0...animalChainTopTier).map(smilePoints(forTier:))
        XCTAssertEqual(values, values.sorted(), "a deeper order must never be worth fewer smiles")
        XCTAssertTrue(values.allSatisfy { (1...3).contains($0) }, "values stay in 1...3")
        XCTAssertEqual(smilePoints(forTier: 0), 1)
        XCTAssertEqual(smilePoints(forTier: 5), 2)
        XCTAssertEqual(smilePoints(forTier: 11), 3)
    }

    /// A basket is worth what its hardest ask is worth, not its easiest — the
    /// filler lines shouldn't drag a deep order's value down.
    func testAnOrderTakesItsValueFromTheDeepestLine() {
        let basket = AdoptionOrder(familyIndex: 0, lines: [
            OrderLine(chainID: dog, tier: 2, count: 1),   // worth 1 alone
            OrderLine(chainID: cat, tier: 9, count: 1),   // worth 3 alone
        ])
        XCTAssertEqual(basket.smileValue, smilePoints(forTier: 9))

        let shallow = AdoptionOrder(familyIndex: 0, wantedChainID: dog,
                                    wantedTier: 1, wantedCount: 1)
        XCTAssertEqual(shallow.smileValue, 1)
    }

    func testAnEmptyBasketIsWorthTheFloorRatherThanCrashing() {
        let empty = AdoptionOrder(familyIndex: 0, lines: [])
        XCTAssertEqual(empty.smileValue, smilePoints(forTier: 0))
    }

    /// Every generated order shows a value, so the badge is never blank.
    func testEveryGeneratedOrderCarriesAValue() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        for i in 0..<200 {
            let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 45, forSlot: i % 4)
            XCTAssertTrue((1...3).contains(order.smileValue),
                          "slot \(i % 4) produced smileValue \(order.smileValue)")
        }
    }

    // MARK: Banking and claiming

    func testAwardAccumulatesAndIgnoresNonPositiveAmounts() {
        let vm = makeViewModel()
        vm.awardSmilePoints(3)
        vm.awardSmilePoints(2)
        XCTAssertEqual(vm.smilePointsBanked, 5)
        vm.awardSmilePoints(0)
        vm.awardSmilePoints(-4)
        XCTAssertEqual(vm.smilePointsBanked, 5)
    }

    func testBundleIsNotClaimableBeforeTheBarFills() {
        let vm = makeViewModel()
        vm.smilePointsBanked = smilePointsGoal - 1
        XCTAssertFalse(vm.isSmileBundleReady)
        XCTAssertTrue(vm.claimSmileBundle().isEmpty, "claiming early grants nothing")
        XCTAssertEqual(vm.smilePointsBanked, smilePointsGoal - 1, "and takes nothing")
    }

    func testClaimingGrantsTheBundleAndStartsTheNextCycle() {
        let vm = makeViewModel()
        vm.smilePointsBanked = smilePointsGoal
        let granted = vm.claimSmileBundle()
        XCTAssertEqual(granted.count, smileBundleTierOffsets.count,
                       "one item per offset, board space permitting")
        XCTAssertEqual(vm.smilePointsBanked, 0)
        XCTAssertFalse(vm.isSmileBundleReady, "the next cycle starts empty")
    }

    /// The reference resets to 0/12; carrying is strictly kinder and costs
    /// nothing, so overshoot is banked toward the next bundle rather than lost.
    func testClaimingCarriesTheRemainderRatherThanZeroing() {
        let vm = makeViewModel()
        vm.smilePointsBanked = smilePointsGoal + 7
        vm.claimSmileBundle()
        XCTAssertEqual(vm.smilePointsBanked, 7, "the overshoot survives into the next bar")
    }

    func testTwoFullBarsWorthClaimsTwiceRatherThanOnce() {
        let vm = makeViewModel()
        vm.smilePointsBanked = smilePointsGoal * 2
        XCTAssertFalse(vm.claimSmileBundle().isEmpty)
        XCTAssertTrue(vm.isSmileBundleReady, "a second full bundle is still owed")
        XCTAssertFalse(vm.claimSmileBundle().isEmpty)
        XCTAssertFalse(vm.isSmileBundleReady)
    }

    func testProgressFractionIsClampedForTheBar() {
        let vm = makeViewModel()
        vm.smilePointsBanked = smilePointsGoal * 3
        XCTAssertEqual(vm.smileProgressFraction, 1.0, accuracy: 0.0001,
                       "an overfull bar must not draw past its own width")
    }

    // MARK: Bundle contents

    func testBundleItemsRespectTheirOwnLowerTierCap() {
        XCTAssertLessThan(smileBundleMaxItemTier, recirculationMaxItemTier,
                          "smile bundles are a garnish on the order loop, not a rival to the chests")
        let vm = makeViewModel()
        vm.deepestUnlockedTier = animalChainTopTier
        vm.smilePointsBanked = smilePointsGoal
        for item in vm.claimSmileBundle() {
            XCTAssertLessThanOrEqual(item.tier, smileBundleMaxItemTier)
        }
    }

    // MARK: Cadence and economy safety
    //
    // These exist because the first two drafts of this feature were wrong in a
    // way only the model could show: at the reference's goal of 12, bundles
    // landed ~5x a day and the recirculation wiped out the Phase 3 wall
    // entirely (L45-L60 fell from 1.14/1.30 to 0.78/0.93).

    /// Expected Smile points banked per order at `level`, from the same tier
    /// distribution the economy model uses for demand.
    private func expectedSmilePerOrder(level: Int) -> Double {
        EconomySimulation.tierDistribution(level: level).reduce(0.0) { total, entry in
            total + entry.p * Double(smilePoints(forTier: entry.tier))
        }
    }

    func testBundlesLandAboutOnceADayForAnEngagedPlayer() {
        let level = 45
        let perDay = EconomySimulation.ordersPerDay(level: level)
                   * expectedSmilePerOrder(level: level) / Double(smilePointsGoal)
        XCTAssertGreaterThan(perDay, 0.5,
                             "rarer than every other day stops reading as a live loop — \(perDay)/day")
        XCTAssertLessThan(perDay, 2.0,
                          "more than twice a day makes it a firehose, not a payoff — \(perDay)/day")
    }

    func testSmileBundlesStayAMinorityOfTotalRecirculation() {
        // The order rider, power-up grants and chests are the designed
        // recirculation channels. This one is a garnish; if it ever dominates,
        // the wall is being set by a reward loop rather than by the economy.
        for level in [35, 45, 60] {
            let deepest = maxAchievableOrderTier(forPlayerLevel: level)
            let total = EconomySimulation.recirculation(level: level, deepestTier: deepest)
            let orders = EconomySimulation.ordersPerDay(level: level)
            let bundles = orders * expectedSmilePerOrder(level: level) / Double(smilePointsGoal)
            let perBundle = smileBundleTierOffsets.reduce(0.0) { sum, offset in
                sum + Double(spawnCost(forTier: min(max(0, deepest - offset), smileBundleMaxItemTier)))
            }
            let share = (bundles * perBundle) / total
            XCTAssertLessThan(share, 0.35,
                              "L\(level): smile bundles are \(Int(share * 100))% of recirculation")
        }
    }
}
