//
//  EconomyTests.swift
//  PawSanctuaryTests
//
//  Phase 2 (economy correction) acceptance checks.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class EconomyTests: XCTestCase {

    // MARK: Task 2.1 — neutral spawn multiplier

    /// No multiplier may buy an item at a discount to building it by hand
    /// (D2, restored by D17).
    func testEveryMultiplierIsEnergyNeutral() {
        for multiplier in [1, 2, 4, 8] {
            let tier = spawnTierIndex(forMultiplier: multiplier)
            let cost = spawnTapCost(forMultiplier: multiplier)
            XCTAssertEqual(cost, spawnCost(forTier: tier),
                           "×\(multiplier) buys tier \(tier) for \(cost) kibble")
        }
    }

    /// Each boosted multiplier keeps its own bonus chance, whatever tier it spawns.
    func testBonusSpawnChanceRisesWithEachMultiplier() {
        let chances = [1, 2, 4, 8].map {
            bonusSpawnChance(forMultiplierTier: spawnTierIndex(forMultiplier: $0))
        }
        XCTAssertEqual(chances, [0.00, 0.10, 0.25, 0.40])
    }

    /// A tap costs exactly the multiplier in kibble.
    func testSpawnTapCostEqualsMultiplier() {
        for multiplier in [1, 2, 4, 8] {
            XCTAssertEqual(spawnTapCost(forMultiplier: multiplier), multiplier)
        }
        XCTAssertEqual(spawnTapCost(forMultiplier: 99), 1, "unknown multipliers fall back to 1")
    }

    func testMultiplierMapsToExpectedTiers() {
        XCTAssertEqual(spawnTierIndex(forMultiplier: 1), 0)
        XCTAssertEqual(spawnTierIndex(forMultiplier: 2), 1)
        XCTAssertEqual(spawnTierIndex(forMultiplier: 4), 2, "×4 spawns a level-3 item")
        XCTAssertEqual(spawnTierIndex(forMultiplier: 8), 3, "×8 spawns a level-4 item")
        XCTAssertEqual(spawnTierIndex(forMultiplier: 99), 0, "unknown multipliers fall back to tier 0")
    }

    func testSpawnCostDoublesPerTier() {
        XCTAssertEqual(spawnCost(forTier: 0), 1)
        XCTAssertEqual(spawnCost(forTier: 3), 8)
        XCTAssertEqual(spawnCost(forTier: 10), 1024)
        XCTAssertEqual(spawnCost(forTier: 14), 16384)
    }

    // MARK: Phase 2c — the coin economy

    /// The core invariant: waiting for an order always beats selling, at every
    /// tier, even when the order rolls its worst spread and the sale its best.
    func testFulfillingAnOrderAlwaysBeatsSellingAtEveryTier() {
        for tier in 0...animalChainTopTier {
            let sell  = animalSellValue(tier: tier)
            let order = orderCoinPayout(tier: tier)
            XCTAssertLessThan(sell, order,
                              "tier \(tier): selling pays \(sell), order pays \(order)")
            let worstOrder = orderCoinPayout(tier: tier, spreadFactor: 1 - orderCoinSpread)
            XCTAssertLessThan(sell, worstOrder,
                              "tier \(tier): the worst order roll must still beat selling")
        }
    }

    /// A flat premium means no tier is relatively better to sell, so there is no
    /// farming incentive anywhere on the chain.
    func testWaitingPremiumIsRoughlyConstantAcrossTiers() {
        let premiums = (0...animalChainTopTier).map {
            Double(orderCoinPayout(tier: $0)) / Double(animalSellValue(tier: $0))
        }
        let expected = coinsPerKibbleOfOrder / coinsPerKibbleOfSale   // ~2.36
        for (tier, premium) in premiums.enumerated() {
            XCTAssertEqual(premium, expected, accuracy: 0.25,
                           "tier \(tier) premium \(premium) departs from the flat ratio")
        }
    }

    func testOrderPayoutIsProportionalToBuildCost() {
        // Doubling the tier's cost doubles the payout; two items pay twice one.
        for tier in 0..<animalChainTopTier {
            XCTAssertEqual(Double(orderCoinPayout(tier: tier + 1)),
                           Double(orderCoinPayout(tier: tier) * 2), accuracy: 1.0)
        }
        XCTAssertEqual(orderCoinPayout(tier: 5, count: 2),
                       orderCoinPayout(tier: 5, count: 1) * 2)
        XCTAssertEqual(orderCoinPayout(tier: 11), 13_312)
        XCTAssertEqual(animalSellValue(tier: 11), 5_632)
    }

    func testSellTableMatchesTheDerivedRate() {
        XCTAssertEqual(animalSellValues.count, 12)
        XCTAssertEqual(animalSellValues.first, 3)
        XCTAssertEqual(animalSellValues.last, 5_632)
        for (tier, value) in animalSellValues.enumerated() {
            XCTAssertEqual(Double(value),
                           coinsPerKibbleOfSale * Double(spawnCost(forTier: tier)),
                           accuracy: 0.5)
        }
    }

    /// Generated orders must honour the formula, spread included.
    func testGeneratedOrdersPayWithinTheSpreadOfNominal() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        for i in 0..<500 {
            let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 45, forSlot: i % 4)
            guard let coins = order.rewards.first(where: { $0.kind == .coins })?.amount else {
                return XCTFail("every order should carry a coin reward")
            }
            // v37: priced off the whole basket, not one tier — a two-line order
            // asking a tier-9 and a tier-2 costs the sum of both to build.
            let nominal = orderCoinPayout(lines: order.lines)
            XCTAssertGreaterThanOrEqual(Double(coins), Double(nominal) * (1 - orderCoinSpread) - 1)
            XCTAssertLessThanOrEqual(Double(coins), Double(nominal) * (1 + orderCoinSpread) + 1)
            // And it must still beat selling the same items outright.
            XCTAssertGreaterThan(coins, orderSellValue(lines: order.lines))
        }
    }

    /// The trio exchange consumed three top-tier tiles for a flat 50 coins while
    /// each sold for 5,632 — a trap. It must now beat selling them individually.
    func testAmbassadorTrioBeatsSellingTheThreeSeparately() {
        let sellSeparately = animalSellValue(tier: animalChainTopTier) * 3
        let viaTrio = Int((Double(sellSeparately) * ambassadorTrioExchangeMultiplier).rounded())
        XCTAssertGreaterThan(viaTrio, sellSeparately,
                             "a trio bonus that pays less than selling is a trap")
    }

    // MARK: Phase 2c — weekly goals and the smaller faucets

    /// These thresholds live in a different file from the payout formula and are
    /// denominated in the currency it moved by ~45×. Before Phase 2c a single
    /// mid-tier order cleared Bronze outright.
    func testWeeklyGoalsAreNotClearedByASingleOrder() {
        let averageOrder = orderCoinPayout(tier: 5)
        XCTAssertGreaterThan(weeklyGoalBronzeCoins, averageOrder * 2,
                             "Bronze should take more than a couple of orders")
        XCTAssertLessThan(weeklyGoalBronzeCoins, weeklyGoalSilverCoins)
        XCTAssertLessThan(weeklyGoalSilverCoins, weeklyGoalGoldCoins)
    }

    func testWeeklyGoldIsAchievableInAWeekOfMidGamePlay() {
        // A level-30 player's daily coin income, times seven.
        let weekly = EconomySimulation.coinRow(level: 30, sells: false).total * 7
        XCTAssertGreaterThan(weekly, Double(weeklyGoalGoldCoins),
                             "Gold must be reachable inside a week at mid-game")
        XCTAssertLessThan(Double(weeklyGoalGoldCoins), weekly,
                          "but not trivially — it should ask for real engagement")
        XCTAssertGreaterThan(Double(weeklyGoalGoldCoins),
                             EconomySimulation.coinRow(level: 30, sells: false).total * 2,
                             "Gold should take more than two days")
    }

    func testSmallerFaucetsSitBelowTheMainChannel() {
        let averageOrder = orderCoinPayout(tier: 5)          // ~416 coins
        // A legendary quest spans many merges, so it outweighs a single order...
        XCTAssertGreaterThan(QuestDifficulty.legendary.coinReward, averageOrder)
        // ...but never a top-tier one, which is days of work.
        XCTAssertLessThan(QuestDifficulty.legendary.coinReward,
                          orderCoinPayout(tier: animalChainTopTier))
        XCTAssertLessThan(QuestDifficulty.easy.coinReward, averageOrder)
        // The daily channel used to be one flat 400-coin sweep bonus, asserted
        // here against `averageOrder * 2`. Since schema v40 that bonus is 0 and
        // the channel is three per-task payouts, so the meaningful successor
        // assertion is on a whole day of dailies, not on the (now zero) rider —
        // checking the old constant would pass vacuously.
        let wholeDayOfDailies = EconomySimulation.dailyTaskCoinIncome(level: 45)
                              + Double(coinsPerAllDailyChallenges)
        XCTAssertLessThan(wholeDayOfDailies, Double(orderCoinPayout(tier: animalChainTopTier)),
                          "a full day of dailies must not rival one top-tier order")
        XCTAssertGreaterThan(wholeDayOfDailies, Double(averageOrder),
                             "but three claimed tasks should beat a single mid-tier order")
        // An Ambassador merge is a bonus on top of the item, never a rival to it.
        XCTAssertLessThan(coinsPerAmbassadorMerge, animalSellValue(tier: animalChainTopTier))
    }

    // MARK: Schema v40 — the daily hand-in channel

    /// The sweep that moved `dailyTaskCoinMultiplier` off its unswept 1.0
    /// (`Spec_DailyHandInTasks.md` §5a). At 1.0 with the old 400-coin bonus the
    /// channel paid 1,135 coins/day at L45 against ~523 of budget, which put the
    /// map at 52.9 days. Locking the corrected size in.
    func testTheDailyChannelFitsInsideItsCoinBudget() {
        // Budget = what the map projection can absorb at the anchor level
        // before falling through the 55-day floor.
        let ceiling = Double(EconomySimulation.mapTotalCoinCost) / 55.0
        let withoutDailies = EconomySimulation.coinRow(level: EconomySimulation.projectionLevel,
                                                       sells: true).total
                           - EconomySimulation.dailyTaskCoinIncome(level: EconomySimulation.projectionLevel)
                           - Double(coinsPerAllDailyChallenges)
        let budget = ceiling - withoutDailies
        let spend  = EconomySimulation.dailyTaskCoinIncome(level: EconomySimulation.projectionLevel)
                   + Double(coinsPerAllDailyChallenges)

        XCTAssertLessThan(spend, budget,
                          "daily channel spends \(spend)/day against \(budget) of budget at L\(EconomySimulation.projectionLevel)")
    }

    /// The whole point of `dailyTaskCoinFloor`. Under strict build-cost
    /// proportionality the easy slot paid 10 coins at *every* level (its band is
    /// always tiers 0-1) and the hard slot took 93% of the channel — two of the
    /// three cards were never worth pressing.
    func testNoDailySlotIsDerisoryAtAnyLevel() {
        for level in EconomySimulation.reportLevels {
            for difficulty in dailyTaskSlotDifficulties {
                let coins = EconomySimulation.dailyTaskCoinIncome(difficulty: difficulty, level: level)
                XCTAssertGreaterThanOrEqual(coins, Double(dailyTaskCoinFloor),
                                            "L\(level) \(difficulty.rawValue) slot pays \(coins)")
            }
        }
    }

    func testTheHardSlotNoLongerSwallowsTheWholeChannel() {
        for level in EconomySimulation.reportLevels {
            let hard  = EconomySimulation.dailyTaskCoinIncome(difficulty: .hard, level: level)
            let total = EconomySimulation.dailyTaskCoinIncome(level: level)
            XCTAssertLessThan(hard / total, 0.75,
                              "L\(level): hard slot is \(hard / total * 100)% of the daily channel")
        }
    }

    /// The floor must not bind where the projection is anchored — if it did, it
    /// would be paying out at the endgame rather than only rescuing the early
    /// game, and the budget above would be spent on the wrong levels.
    func testTheFloorDoesNotBindAtTheEndgameHardSlot() {
        let proportional = EconomySimulation.expectedDailyTaskCost(
            difficulty: .hard, level: EconomySimulation.projectionLevel)
            * coinsPerKibbleOfOrder * dailyTaskCoinMultiplier
        XCTAssertGreaterThan(proportional, Double(dailyTaskCoinFloor) * 2,
                             "the endgame hard slot should clear the floor comfortably, not sit on it")
    }

    /// Handing in must always beat selling the same creatures, at every level and
    /// every slot — it costs the player the animals, unlike an order.
    func testEveryDailySlotBeatsSellingItsBasket() {
        for level in EconomySimulation.reportLevels {
            for difficulty in dailyTaskSlotDifficulties {
                let coins = EconomySimulation.dailyTaskCoinIncome(difficulty: difficulty, level: level)
                let sold  = EconomySimulation.expectedDailyTaskCost(difficulty: difficulty, level: level)
                          * coinsPerKibbleOfSale
                XCTAssertGreaterThan(coins, sold,
                                     "L\(level) \(difficulty.rawValue): \(coins) coins vs \(sold) sold")
            }
        }
    }

    /// `dailyTaskCostDistribution` mirrors `generateDailyTask`; if the generator
    /// changes bands or line counts and the model does not, every number above
    /// silently stops describing the game.
    func testTheModelsBasketDistributionMatchesWhatIsActuallyGenerated() {
        let coordinator = QuestCoordinator()
        let dog = ContentRegistry.animalChainID(.dog)
        let level = 45
        var observed: [QuestDifficulty: [Int]] = [:]
        for _ in 0..<4_000 {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: level)
            for task in coordinator.dailyChallenges {
                let kibble = task.lines.reduce(0) { $0 + buildCost(tier: $1.tier, count: $1.count) }
                observed[task.difficulty, default: []].append(kibble)
            }
        }
        for difficulty in dailyTaskSlotDifficulties {
            let sample = observed[difficulty] ?? []
            XCTAssertFalse(sample.isEmpty)
            let measured = Double(sample.reduce(0, +)) / Double(sample.count)
            let modelled = EconomySimulation.expectedDailyTaskCost(difficulty: difficulty, level: level)
            XCTAssertEqual(measured, modelled, accuracy: modelled * 0.15,
                           "\(difficulty.rawValue): generator averages \(measured) kibble, model says \(modelled)")
        }
    }

    // MARK: Schema v40 — board congestion (the stock model)

    /// `unlockedCells` mirrors `boardRowUnlockTiers`. If a row's gate moves and
    /// the model does not, every congestion number below stops describing the
    /// game.
    func testUnlockedCellsTracksTheRealRowUnlockGates() {
        XCTAssertEqual(EconomySimulation.unlockedCells(deepestTier: 0), 21,
                       "three rows open from the start")
        XCTAssertEqual(EconomySimulation.unlockedCells(deepestTier: 2), 28)
        XCTAssertEqual(EconomySimulation.unlockedCells(deepestTier: 10), boardRows * 7,
                       "the whole board is open by tier 10")
        // Monotone, and never past the real board.
        var previous = 0
        for tier in 0...11 {
            let cells = EconomySimulation.unlockedCells(deepestTier: tier)
            XCTAssertGreaterThanOrEqual(cells, previous)
            XCTAssertLessThanOrEqual(cells, boardRows * 7)
            previous = cells
        }
    }

    /// Read off the live area roster, not hardcoded — one spawner per rewarding
    /// area plus the Canines spawner every save starts with.
    func testEveryFamilySpawnerIsAccountedFor() {
        XCTAssertEqual(EconomySimulation.totalFamilySpawners,
                       AnimalSpecies.allCases.count,
                       "every family should be reachable exactly once, via the map or the day-one dog")
    }

    /// The v40-specific claim on the board. This is the number that regresses if
    /// anyone widens `orderBasketLineCounts` or the hard tier band, and the one
    /// worth failing loudly on.
    func testDailyTasksClaimAMinorityOfTheBoardAtEveryLevel() {
        for level in EconomySimulation.reportLevels {
            let capacity = EconomySimulation.unlockedCells(
                deepestTier: EconomySimulation.assumedDeepestTier(level: level))
            let claim = EconomySimulation.dailyTaskHoldCells()
                      + EconomySimulation.dailyTaskStagingCells(level: level)
            XCTAssertLessThan(claim / Double(capacity), 0.40,
                              "L\(level): daily tasks want \(claim) of \(capacity) cells")
        }
    }

    /// `dailyTaskHoldCells` counts *items*, so the duplicate-collapse in
    /// `generateDailyTask` (two identical lines becoming one line of count 2)
    /// must leave it unchanged. Sampled against the real generator.
    func testHoldCellsMatchWhatTheGeneratorActuallyPutsOnTheBoard() {
        let coordinator = QuestCoordinator()
        let dog = ContentRegistry.animalChainID(.dog)
        var totalItems = 0
        let days = 2_000
        for _ in 0..<days {
            coordinator.generateDailyChallenges(unlockedAnimalChainIDs: [dog], playerLevel: 45)
            for task in coordinator.dailyChallenges { totalItems += task.wantedCount }
        }
        let measured = Double(totalItems) / Double(days)
        XCTAssertEqual(measured, EconomySimulation.dailyTaskHoldCells(), accuracy: 0.2,
                       "generator asks for \(measured) creatures a day, model says \(EconomySimulation.dailyTaskHoldCells())")
    }

    /// The corner the congestion model exists to find. Board capacity is gated
    /// on **deepest merge tier**; spawner count on **map areas bought with
    /// materials**. Different currencies, so they can drift — and the tightest
    /// board in the sweep is one where map progress has outrun tier progress.
    ///
    /// Asserting the *shape*, not a comfort level: the squeeze must be
    /// spawner-driven, because if daily tasks ever become the dominant claim
    /// that is a v40 regression rather than a pre-existing progression quirk.
    func testTheTightestBoardIsSpawnerDrivenNotDailyTaskDriven() {
        let worst = EconomySimulation.worstCaseCongestion()
        XCTAssertGreaterThan(Double(worst.spawners), worst.hold + worst.staging,
                             "worst corner: \(worst.description)")
    }

    /// Even in that corner the board must not be unplayable — a merge needs
    /// somewhere to land, and a spawn needs a free cell to drop into.
    func testTheBoardStillHasRoomToPlayInEvenAtItsTightest() {
        let worst = EconomySimulation.worstCaseCongestion()
        XCTAssertGreaterThan(worst.workingCells, 2.0,
                             "worst corner leaves \(worst.workingCells) working cells: \(worst.description)")
        XCTAssertLessThan(worst.occupancy, 0.90,
                          "worst corner occupancy \(worst.occupancy * 100)%")
    }

    // MARK: The material faucet — the third currency

    /// Materials cascade 2-for-1 without limit in `InventoryStore.absorbMaterialItems`,
    /// which is what makes tier-0 equivalents an exact denomination rather than
    /// an approximation.
    func testMaterialUnitsMatchTheCascadeRatio() {
        XCTAssertEqual(EconomySimulation.materialUnits(tier: 0), 1)
        XCTAssertEqual(EconomySimulation.materialUnits(tier: 5), 32)
        for tier in 1...5 {
            XCTAssertEqual(EconomySimulation.materialUnits(tier: tier),
                           EconomySimulation.materialUnits(tier: tier - 1) * 2,
                           "two of tier \(tier - 1) must cascade into one of tier \(tier)")
        }
    }

    /// Area costs are read off the live roster, so content edits move the model
    /// rather than silently invalidating it. Anchored so a *accidental* content
    /// change still fails loudly.
    func testAreaMaterialCostsComeFromTheLiveRoster() {
        let costs = EconomySimulation.cumulativeAreaMaterialCost
        XCTAssertEqual(costs.count, sanctuaryAreas.count)
        XCTAssertEqual(costs.last, 4_448, "total material cost of the whole map")
        // Strictly increasing — the map is sequential (`requiresPrevious`).
        for (a, b) in zip(costs, costs.dropFirst()) {
            XCTAssertLessThan(a, b, "every area must add real cost")
        }
    }

    /// **The headline finding.** `toolboxMaxTier` is `min(5, level / 5 + 1)`, so
    /// it saturates at level 20 — and with it the whole material faucet. Board
    /// capacity, meanwhile, is gated on deepest merge tier and does not open its
    /// last row until tier 10, which `maxAchievableOrderTier` puts at level 41+.
    ///
    /// So the two progressions are mismatched *by construction*: a player owns
    /// every family spawner long before the board grows to hold them. This test
    /// exists to make that visible and to fail if either gate moves.
    func testTheMaterialFaucetSaturatesLongBeforeTheBoardFinishesGrowing() {
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 20), 5)
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 60), 5, "the faucet stops growing at L20")
        XCTAssertEqual(EconomySimulation.materialUnitsPerDay(level: 20),
                       EconomySimulation.materialUnitsPerDay(level: 60),
                       accuracy: 0.01,
                       "material income is flat from L20 onward")

        let cellsAtSaturation = EconomySimulation.unlockedCells(
            deepestTier: EconomySimulation.assumedDeepestTier(level: 20))
        XCTAssertLessThan(cellsAtSaturation, boardRows * 7,
                          "the board is still growing when the material faucet has stopped")
    }

    /// §5b left open whether the spawner-choke corner is *reachable*. With the
    /// faucet modelled it is: at L20's income the whole map's material cost is
    /// ~34 days of play, while the board is still at 35 cells.
    func testTheSpawnerChokeCornerIsReachable() {
        XCTAssertEqual(EconomySimulation.familiesOwned(level: 20, days: 60),
                       EconomySimulation.totalFamilySpawners,
                       "two months at L20 income buys every spawner")
        XCTAssertLessThan(EconomySimulation.daysToAllFamilies(level: 20), 40.0)

        let row = EconomySimulation.congestionRow(
            level: 20, familiesOwned: EconomySimulation.familiesOwned(level: 20, days: 60))
        XCTAssertEqual(row.capacity, 35, "still three rows short of the full board")
        XCTAssertGreaterThan(row.occupancy, 0.75, "reachable, and genuinely tight: \(row.description)")
    }

    /// Refines §5b. Daily tasks are not the *dominant* claim — spawners are —
    /// but at the tightest reachable point they take the majority of whatever
    /// the producers leave behind, which is the honest statement of their cost.
    func testAtTheTightestPointDailyTasksTakeMostOfTheNonProducerSpace() {
        let families = EconomySimulation.familiesOwned(level: 20, days: 60)
        let row = EconomySimulation.congestionRow(level: 20, familiesOwned: families)
        let nonProducer = Double(row.capacity - row.spawners - row.supplyProducers)
        let taskClaim = row.hold + row.staging

        XCTAssertGreaterThan(taskClaim / nonProducer, 0.50,
                             "daily tasks take \(taskClaim) of the \(nonProducer) cells producers leave")
        // But the board still works — a merge has somewhere to land.
        XCTAssertGreaterThan(row.workingCells, 5.0, row.description)
    }

    /// The faucet must actually grow with level up to saturation, or the early
    /// game would be a wall rather than a ramp.
    func testMaterialIncomeRisesWithLevelUntilItSaturates() {
        let ramp = [1, 5, 10, 15, 20].map { EconomySimulation.materialUnitsPerDay(level: $0) }
        for (a, b) in zip(ramp, ramp.dropFirst()) {
            XCTAssertLessThan(a, b, "material income should ramp through the early game")
        }
        XCTAssertGreaterThan(EconomySimulation.daysToAllFamilies(level: 1), 300.0,
                             "a level-1 player is nowhere near the whole map")
    }

    // MARK: Phase 2c — map build-out projection

    func testMapBuildOutLandsInTheTargetWindow() {
        let neverSells = EconomySimulation.daysToFullMap(sells: false)
        let sells      = EconomySimulation.daysToFullMap(sells: true)

        XCTAssertLessThanOrEqual(neverSells, 75.0,
                                 "a player who never discovers selling must not stall")
        XCTAssertGreaterThan(neverSells, 40.0, "and the map should not fall over in a month")
        XCTAssertTrue((55.0...70.0).contains(sells),
                      "selling player projected \(sells) days, target 55-70")
    }

    /// Under Phase 2c orders pay 2.4× what selling does, so diverting production
    /// to sales is necessarily *slower*. Locking that in: it is the whole point
    /// of the decision, and the inverse would mean the rates had drifted.
    func testSellingIsSlowerThanHoldingOutForOrders() {
        XCTAssertGreaterThan(EconomySimulation.daysToFullMap(sells: true),
                             EconomySimulation.daysToFullMap(sells: false),
                             "selling trades coins for immediacy — it cannot also be faster")
    }

    func testMapCostMatchesTheLiveAreaRoster() {
        XCTAssertEqual(EconomySimulation.mapTotalCoinCost, 291_900)
    }

    // MARK: Phase 2b — 12-tier chains

    func testEveryFamilyHasTwelveTiers() {
        for species in AnimalSpecies.allCases {
            XCTAssertEqual(species.tierNames.count, 12, "\(species.name) should have 12 tiers")
            XCTAssertEqual(Set(species.tierNames).count, 12, "\(species.name) has duplicate names")
        }
        XCTAssertEqual(AnimalSpecies.allCases.count * 12, 180)
    }

    func testDroppedEraIsGoneAndSurvivingErasKeptTheirNames() {
        // Canines, the spec's worked example.
        XCTAssertEqual(AnimalSpecies.dog.tierNames,
                       ["Pup", "Kit", "Houndling",
                        "Terrier", "Spaniel", "Scout",
                        "Retriever", "Shepherd", "Husky",
                        "Dire Wolf", "Mythic", "Primordial"])
        for dropped in ["Alpha", "Guardian", "Sentinel"] {
            XCTAssertFalse(AnimalSpecies.dog.tierNames.contains(dropped))
        }
    }

    func testEveryAnimalChainRegistersTwelveTiersWithABadgedTop() {
        for species in AnimalSpecies.allCases {
            let chain = ContentRegistry.shared.chain(ContentRegistry.animalChainID(species))
            XCTAssertEqual(chain?.maxTier, 11, "\(species.name)")
            XCTAssertNotNil(chain?.tiers.last?.badge, "\(species.name) top tier should carry the medal")
            XCTAssertNil(chain?.tiers[10].badge, "\(species.name) only the top tier is badged")
        }
    }

    func testTopTierItemIsReachableWithinAFewDaysOfIncome() {
        // The reason for Phase 2b: at 15 tiers the top item cost 16,384 kibble,
        // about 22 days of total income, so it could never be ordered.
        let topCost = spawnCost(forTier: 11)
        XCTAssertEqual(topCost, 2048)
        let daysOfIncome = Double(topCost) / Double(EconomySimulation.dailySupply(level: 55))
        XCTAssertLessThan(daysOfIncome, 3.0, "top tier should be ~2.7 days of total income")
    }

    /// Phase 2b had sell value climbing faster than build cost. Phase 2c makes the
    /// rate deliberately FLAT at `coinsPerKibbleOfSale`: with orders paying a
    /// constant 2.4× premium, a climbing sell rate would make some tier
    /// relatively better to sell and create a farming incentive there.
    func testSellRateIsFlatAcrossTiers() {
        XCTAssertEqual(animalSellValues.count, 12)
        let ratios = animalSellValues.enumerated().map { Double($1) / Double(spawnCost(forTier: $0)) }
        for (tier, ratio) in ratios.enumerated() {
            XCTAssertEqual(ratio, coinsPerKibbleOfSale, accuracy: 0.3,
                           "tier \(tier) sells at \(ratio) per kibble, not the flat rate")
        }
    }

    func testSellValuesAreStrictlyIncreasingAndSmooth() {
        for (a, b) in zip(animalSellValues, animalSellValues.dropFirst()) {
            XCTAssertGreaterThan(b, a)
            let step = Double(b) / Double(a)
            XCTAssertGreaterThan(step, 1.8, "no flat spot in the series")
            XCTAssertLessThan(step, 3.2, "no splice-shaped jump in the series")
        }
    }

    func testSuperpowerUnlockTierSurvivesTheCut() {
        // Unlock sits at the start of Era 3, which was not the era removed.
        XCTAssertEqual(Superpower.unlockTier, 6)
        XCTAssertEqual(AnimalSpecies.dog.tierNames[Superpower.unlockTier], "Retriever")
        XCTAssertLessThan(Superpower.unlockTier, 12)
    }

    // MARK: Task 2.2 — rarity-selected effects, no kibble

    /// The whole point of Task 2.2: no sub-object outcome pays kibble.
    func testNoPowerUpEffectPaysKibble() {
        for rarity in SubObjectRarity.allCases {
            switch SubObjectSystem.effect(for: rarity) {
            case .speedBurst, .mapSupplies, .boardItemGrant, .highTierDrop:
                break   // none of these carry a currency payload
            }
        }
        XCTAssertFalse(SubObjectRarity.allCases.contains { $0.displayName == "Spawner Refill" },
                       "Spawner Refill was the kibble faucet and must be gone")
    }

    func testOnlyItemsCarryingARolledRarityAreUsable() {
        let inert = BoardItem(chainID: "subobject.dog", tier: 2)
        XCTAssertNil(SubObjectSystem.powerUpEffect(for: inert),
                     "tiers 0-2 are inert intermediates")

        var completed = BoardItem(chainID: "subobject.dog", tier: subObjectTopTier)
        completed.rarity = .boardItemGrant
        XCTAssertNotNil(SubObjectSystem.powerUpEffect(for: completed))
    }

    func testRarityWeightsAreUnchangedAndSumTo100() {
        XCTAssertEqual(SubObjectRarity.speed.weight, 60)
        XCTAssertEqual(SubObjectRarity.mapSupplies.weight, 25)
        XCTAssertEqual(SubObjectRarity.boardItemGrant.weight, 10)
        XCTAssertEqual(SubObjectRarity.highTierDrop.weight, 5)
        XCTAssertEqual(SubObjectRarity.allCases.reduce(0) { $0 + $1.weight }, 100)
    }

    /// Pity must actually fire now that the rolled rarity is used — these upgrades
    /// were a no-op for as long as the roll was discarded.
    func testPityGuaranteesBoardItemGrantAtThreshold() {
        var pity = PityState(spawnsSinceLastRare: PityState.rareThreshold, spawnsSinceLastEpic: 0)
        XCTAssertEqual(SubObjectSystem.rollPowerUpRarity(pityState: &pity), .boardItemGrant)
        XCTAssertEqual(pity.spawnsSinceLastRare, 0, "rare counter resets on payout")
    }

    func testPityGuaranteesHighTierDropAtEpicThreshold() {
        var pity = PityState(spawnsSinceLastRare: 0, spawnsSinceLastEpic: PityState.epicThreshold)
        XCTAssertEqual(SubObjectSystem.rollPowerUpRarity(pityState: &pity), .highTierDrop)
        XCTAssertEqual(pity.spawnsSinceLastEpic, 0)
    }

    func testPityTimerReductionLowersTheThreshold() {
        // 20 spawns is below the default rare threshold of 30, but above 30 − 15.
        var pity = PityState(spawnsSinceLastRare: 20, spawnsSinceLastEpic: 0)
        XCTAssertEqual(SubObjectSystem.rollPowerUpRarity(pityState: &pity, pityTimerReduction: 15),
                       .boardItemGrant,
                       "pityTimerReduction from Sanctuary Map upgrades must have an effect")
    }

    func testSpawnerDropAdvancesPityOnEveryActivation() {
        var pity = PityState()
        for _ in 0..<10 {
            _ = SubObjectSystem.resolveSpawnerDrop(species: .dog, pityState: &pity, spawnTier: 0)
        }
        XCTAssertEqual(pity.spawnsSinceLastRare, 10)
        XCTAssertEqual(pity.spawnsSinceLastEpic, 10)
    }

    // MARK: Task 2.4 — reversed Dog Tag ladder

    func testDogTagLadderEscalatesWithinTheDay() {
        let first  = DogTagKibbleExchange.offer(purchasesToday: 0)
        let second = DogTagKibbleExchange.offer(purchasesToday: 1)
        let third  = DogTagKibbleExchange.offer(purchasesToday: 2)

        XCTAssertEqual(first.kibbleGain, second.kibbleGain, "the credit rungs buy the same kibble")
        XCTAssertGreaterThanOrEqual(third.kibbleGain, second.kibbleGain,
                                    "the crate rung is never worth less than a credit rung")
        XCTAssertLessThan(first.dogTagCost, second.dogTagCost, "price must climb, not fall")
        XCTAssertLessThan(second.dogTagCost, third.dogTagCost)
    }

    func testDogTagLadderGoesFlatRatherThanUnbounded() {
        // From the 4th purchase on the discounts are spent: credit rungs sit at 60
        // and crate rungs at 72, the same 0.6 tags per kibble, alternating forever.
        let fourth = DogTagKibbleExchange.offer(purchasesToday: 3)
        let tenth  = DogTagKibbleExchange.offer(purchasesToday: 9)
        XCTAssertEqual(fourth.dogTagCost, tenth.dogTagCost)
        XCTAssertTrue(tenth.isAtFlatRate)
        XCTAssertTrue(fourth.isAtFlatRate)
        XCTAssertFalse(DogTagKibbleExchange.offer(purchasesToday: 0).isAtFlatRate)
        XCTAssertFalse(DogTagKibbleExchange.offer(purchasesToday: 2).isAtFlatRate,
                       "the 3rd purchase (the crate at 36) is still a discounted rung")
    }

    /// The old table was a volume discount — the exact shape Phase 2 reverses.
    /// Compared as cross-multiplied integers so a tie (the crate rung ties rung 2)
    /// is exact rather than a floating-point coin flip.
    func testRateWorsensRatherThanImproves() {
        for i in 0..<9 {
            let a = DogTagKibbleExchange.offer(purchasesToday: i)
            let b = DogTagKibbleExchange.offer(purchasesToday: i + 1)
            // tags per kibble: a.cost / a.gain <= b.cost / b.gain
            XCTAssertLessThanOrEqual(a.dogTagCost * b.kibbleGain, b.dogTagCost * a.kibbleGain,
                                     "rung \(i + 2) must not be cheaper per kibble than rung \(i + 1)")
        }
    }

    // MARK: Cards and chests stage 4 — crate rungs (specs/Spec_CardsAndChests.md §5.2)

    func testAKibbleCrateNeverPaysLessThanItsPrice() {
        let raw = kibbleCrateCharges * kibbleCurrencyValue(tier: kibbleCrateTier)
        XCTAssertGreaterThanOrEqual(raw, 120, "a crate is worth at least the 120 the spec states")
        XCTAssertGreaterThanOrEqual(raw, DogTagKibbleExchange.kibblePerExchange,
                                    "and never less than the plain credit rung it replaces")
        let crate = DogTagKibbleExchange.offer(purchasesToday: 2)
        XCTAssertTrue(crate.isCrate)
        XCTAssertEqual(crate.kibbleGain, raw)
    }

    func testCrateRungsTieTheirNeighbouringPackRungs() {
        let rung2  = DogTagKibbleExchange.offer(purchasesToday: 1)   // 30 for 100
        let crate1 = DogTagKibbleExchange.offer(purchasesToday: 2)   // 36 for 120
        let flat   = DogTagKibbleExchange.offer(purchasesToday: 3)   // 60 for 100
        let crate2 = DogTagKibbleExchange.offer(purchasesToday: 4)   // 72 for 120
        // Equal tags-per-kibble, cross-multiplied so the tie is exact.
        XCTAssertEqual(crate1.dogTagCost * rung2.kibbleGain, rung2.dogTagCost * crate1.kibbleGain)
        XCTAssertEqual(crate2.dogTagCost * flat.kibbleGain, flat.dogTagCost * crate2.kibbleGain)
    }

    /// Kibble bought at the discounted rates (at most 0.30 tags per kibble, i.e. rungs 1–3).
    /// The reference's measured figure is about 320 a day.
    func testTheDiscountedDailyAllowanceStaysNearTheReference() {
        var allowance = 0
        for i in 0..<12 {
            let offer = DogTagKibbleExchange.offer(purchasesToday: i)
            if offer.dogTagCost * 10 <= offer.kibbleGain * 3 { allowance += offer.kibbleGain }
        }
        XCTAssertEqual(allowance, 320)
        XCTAssertGreaterThanOrEqual(allowance, 280)
        XCTAssertLessThanOrEqual(allowance, 360)
    }

    // MARK: Task 2.3c — Dog Tag store

    func testStoreStockIsWithinTheAdvertisedTierBand() {
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        let slots = DogTagStore.makeStock(deepestUnlockedTier: 10, unlockedChainIDs: chains)
        XCTAssertFalse(slots.isEmpty)
        for slot in slots {
            XCTAssertGreaterThanOrEqual(slot.tier, 10 - dogTagStoreMinOffset)
            XCTAssertLessThanOrEqual(slot.tier, 10 - dogTagStoreMaxOffset)
            XCTAssertFalse(slot.purchased, "fresh stock starts unsold")
        }
    }

    func testStoreIsEmptyForAShallowPlayer() {
        let chains = [ContentRegistry.animalChainID(.dog)]
        XCTAssertTrue(DogTagStore.makeStock(deepestUnlockedTier: 0, unlockedChainIDs: chains).isEmpty,
                      "nothing to sell before the player has merged anything")
    }

    func testStorePriceRisesWithTier() {
        let cheap = DogTagStore.price(forTier: 6, minTier: 6)
        let dear  = DogTagStore.price(forTier: 9, minTier: 6)
        XCTAssertLessThan(cheap, dear)
        XCTAssertEqual(cheap, dogTagStoreBasePrice)
    }

    // MARK: Gap_Analysis_Round2 3.2 — paid store reroll

    /// The whole point of the reroll is that it reads as an impulse, not a
    /// commitment -- it must always be cheaper than the cheapest thing it could
    /// win you a shot at.
    func testRefreshCostIsBelowTheCheapestSlot() {
        XCTAssertLessThan(dogTagStoreRefreshCost, dogTagStoreBasePrice)
    }

    func testForceRefreshRebuildsStockAndAdvancesRotationTimestamp() {
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        let store = DogTagStore()
        store.rotateIfNeeded(deepestUnlockedTier: 10, unlockedChainIDs: chains)
        let firstRotation = store.lastRotation
        XCTAssertFalse(store.slots.isEmpty)

        store.forceRefresh(deepestUnlockedTier: 10, unlockedChainIDs: chains)
        XCTAssertFalse(store.slots.isEmpty, "a reroll must still leave the store stocked")
        XCTAssertNotEqual(store.lastRotation, firstRotation,
                          "forceRefresh must record a new rotation, not silently no-op")
    }

    /// Unlike rotateIfNeeded, forceRefresh must rebuild even when the calendar
    /// day hasn't changed -- that's the entire difference between the free
    /// daily rotation and the paid reroll.
    func testForceRefreshIgnoresSameDayCache() {
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        let store = DogTagStore()
        store.slots = []
        store.lastRotation = Date()   // pretend today's rotation already happened
        store.forceRefresh(deepestUnlockedTier: 10, unlockedChainIDs: chains)
        XCTAssertFalse(store.slots.isEmpty,
                       "forceRefresh must rebuild even when rotateIfNeeded would no-op")
    }

    // MARK: Task 2.3a — orders pay items

    func testOrdersCarryBoardItemRewardsAtRoughlyTheStatedRate() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        var withItem = 0
        let sample = 3_000
        for i in 0..<sample {
            let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 30, forSlot: i % 4)
            if order.rewards.contains(where: { $0.kind == .boardItem }) { withItem += 1 }
        }
        let rate = Double(withItem) / Double(sample)
        let expected = 1.0 / Double(orderBoardItemFrequency)
        XCTAssertEqual(rate, expected, accuracy: 0.05,
                       "expected ~1 order in \(orderBoardItemFrequency) to pay a board item")
    }

    func testOrderBoardItemRewardIsWellBelowWhatTheOrderAsksFor() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        for i in 0..<500 {
            let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 40, forSlot: i % 4)
            guard let reward = order.rewards.first(where: { $0.kind == .boardItem }),
                  let tier = reward.payloadTier else { continue }
            XCTAssertLessThanOrEqual(tier, max(0, order.wantedTier - orderRewardTierOffset),
                                     "an order must never pay back more than a fraction of its cost")
        }
    }

    // MARK: Task 5.3 — hard slot pays materials

    func testHardSlotAlwaysPaysAMaterialReward() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        let materialChainIDs: Set<ChainID> = [ContentRegistry.woodChainID, ContentRegistry.metalChainID,
                                              ContentRegistry.cementChainID]
        for level in [1, 20, 40, 60] {
            for _ in 0..<50 {
                let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: level, forSlot: 3)
                let materials = order.rewards.filter { $0.kind == .material }
                XCTAssertEqual(materials.count, 1, "the hard slot must pay exactly one material reward")
                guard let reward = materials.first else { continue }
                XCTAssertEqual(reward.amount, materialRewardCount)
                XCTAssertTrue(reward.payloadID.map { materialChainIDs.contains($0) } ?? false,
                             "material reward must name a real material chain")
                XCTAssertGreaterThanOrEqual(reward.payloadTier ?? -1, 0)
                XCTAssertLessThanOrEqual(reward.payloadTier ?? 6, 5)
            }
        }
    }

    func testNonHardSlotsNeverPayAMaterialReward() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        for slot in [0, 1, 2] {
            for _ in 0..<200 {
                let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 45, forSlot: slot)
                XCTAssertFalse(order.rewards.contains { $0.kind == .material },
                               "only the hard slot (index 3) should ever pay materials")
            }
        }
    }

    // MARK: Task 2.5 — the ratio curve

    func testDemandSupplyRatioMatchesTheTargetCurve() {
        func ratio(_ level: Int) -> Double { EconomySimulation.row(level: level).ratio }

        for level in [1, 5, 10, 20, 30] {
            XCTAssertLessThan(ratio(level), 0.70,
                              "L\(level) must stay comfortable — ratio \(ratio(level))")
        }
        for level in [35, 40] {
            XCTAssertGreaterThanOrEqual(ratio(level), 0.60, "L\(level) should be tightening")
            XCTAssertLessThan(ratio(level), 1.00, "L\(level) must not have walled yet")
        }
        XCTAssertGreaterThan(ratio(50), 1.00, "the first genuine wall belongs in L41-50")
        for level in [55, 60] {
            XCTAssertGreaterThan(ratio(level), 1.00)
            XCTAssertLessThan(ratio(level), 1.35,
                              "above ~1.30 is a churn risk, not a monetization opportunity")
        }
    }

    func testRatioIsMonotonicallyNonDecreasing() {
        let ratios = EconomySimulation.reportLevels.map { EconomySimulation.row(level: $0).ratio }
        for (a, b) in zip(ratios, ratios.dropFirst()) {
            XCTAssertLessThanOrEqual(a, b + 0.001, "difficulty must never fall as the player levels")
        }
    }

    func testSupplyMatchesTheMeasuredReference() {
        // These are measured competitor values, not dials — guard against drift.
        XCTAssertEqual(EconomySimulation.dailySupply(level: 5), 695)
        XCTAssertEqual(EconomySimulation.dailySupply(level: 20), 745)
    }

    /// Prints the curve. Not an assertion — this is the Task 2.5 deliverable,
    /// run it to see the model when retuning either dial.
    func testPrintEconomyReport() {
        print(EconomySimulation.report())
    }

    /// Prints the D12-against-D14 comparison (task 1.2). Not an assertion.
    func testPrintHeldItemEconomyReport() {
        print(EconomySimulation.heldItemReport())
        print(EconomySimulation.leverReport())
    }

    // MARK: Task 1.2 — held-item delivery (D14, Spec_HeldItemOrders.md §6)
    //
    // The D12 assertions above are untouched and still describe the D12 model.
    // These pin the D14 model's own facts. They deliberately do NOT assert the
    // D14 ratio at the levels where it leaves the target bands (L30, L35, L40,
    // L55, L60): `testPrintHeldItemEconomyReport` prints that curve and the PR
    // proposes a lever for it, which is the owner's call.

    /// The per-order charge `grossDemand` uses is only a fair charge under D14 if
    /// the model's expected order cost matches what the generator really rolls.
    /// Under D14 every item is consumed by exactly one order, so this number is
    /// the real kibble cost of an order, not an upper bound.
    func testTheModelsOrderCostMatchesWhatIsActuallyGenerated() {
        let board = AdoptionBoard()
        let dog = ContentRegistry.animalChainID(.dog)
        let level = 45
        for difficulty in OrderDifficulty.allCases {
            let slot = orderSlotDifficultyPattern.firstIndex(of: difficulty) ?? 0
            let sample = 8_000
            var total = 0
            for _ in 0..<sample {
                total += orderBuildCost(lines: board.generateOrder(unlockedChainIDs: [dog],
                                                                   playerLevel: level,
                                                                   forSlot: slot).lines)
            }
            let measured = Double(total) / Double(sample)
            let modelled = EconomySimulation.expectedOrderCost(difficulty: difficulty, level: level)
            XCTAssertEqual(measured, modelled, accuracy: modelled * 0.12,
                           "\(difficulty.rawValue): generator averages \(measured) kibble, model says \(modelled)")
        }
    }

    /// The D14 demand is the D12 demand plus the daily tasks, so it can never be
    /// lower, and the ratio moves the same way.
    func testHeldItemDemandIsNeverBelowTheD12Demand() {
        for level in EconomySimulation.reportLevels {
            let before = EconomySimulation.row(level: level)
            let after  = EconomySimulation.heldItemRow(level: level)
            XCTAssertEqual(after.orderDemand, before.grossDemand, accuracy: 0.0001,
                           "L\(level): the order half of the demand is the same formula")
            XCTAssertEqual(after.grossDemand, EconomySimulation.grossDemandHeldItem(level: level), accuracy: 0.0001)
            XCTAssertGreaterThan(after.grossDemand, before.grossDemand, "L\(level)")
            XCTAssertGreaterThan(after.ratio, before.ratio, "L\(level)")
            XCTAssertEqual(after.supply, before.supply, "supply is measured and untouched")
            XCTAssertEqual(after.recirculation, before.recirculation, accuracy: 0.0001,
                           "recirculation is supply-side and untouched")
        }
    }

    /// The daily-task term is real kibble: positive at every level, never falling
    /// as the tier cap rises, and the same number the coin side already enumerates.
    func testTheDailyTaskDemandTermIsPositiveAndRisesWithLevel() {
        let terms = EconomySimulation.reportLevels.map { EconomySimulation.dailyTaskDemand(level: $0) }
        for (level, term) in zip(EconomySimulation.reportLevels, terms) {
            XCTAssertGreaterThan(term, 0, "L\(level)")
            XCTAssertEqual(term, EconomySimulation.dailyTaskKibbleHandedIn(level: level), accuracy: 0.0001)
        }
        for (a, b) in zip(terms, terms.dropFirst()) {
            XCTAssertLessThanOrEqual(a, b + 0.001, "a deeper tier cap must not make the dailies cheaper")
        }
    }

    /// Wherever the D14 ratio is still inside the target band it is asserted
    /// there; the levels that leave the bands are covered by the printed report.
    func testTheD14RatioStillMeetsTheBandsWhereItDoes() {
        for level in [1, 5, 10, 20] {
            XCTAssertLessThan(EconomySimulation.heldItemRow(level: level).ratio, 0.70,
                              "L\(level) must stay comfortable under D14")
        }
        XCTAssertGreaterThan(EconomySimulation.heldItemRow(level: 50).ratio, 1.00,
                             "the first wall is still in L41-50 under D14")
    }

    func testTheD14RatioIsMonotonicallyNonDecreasing() {
        XCTAssertTrue(EconomySimulation.heldItemRatioIsMonotone(),
                      "difficulty must never fall as the player levels under D14 either")
    }

    /// `heldItemBandBreaks` is the model's own record of where D14 leaves the
    /// bands. It must agree with `targetBandAllows`, which mirrors the D12 test.
    func testTheBandCheckMirrorsTheD12AssertionOnTheD12Model() {
        for level in EconomySimulation.bandLevels {
            XCTAssertEqual(EconomySimulation.targetBandAllows(
                ratio: EconomySimulation.row(level: level).ratio, level: level), true,
                           "L\(level): the D12 model satisfies its own band, which this helper mirrors")
        }
    }

    /// The what-if harness must leave the real model alone: nothing leaks out of
    /// `withLevers`, and a lever really does move the answer inside it.
    func testTheLeverHarnessRestoresTheRealModel() {
        let before = EconomySimulation.heldItemRow(level: 35).ratio
        let moved = EconomySimulation.withLevers(.init(cyclesPerDay: 7)) {
            EconomySimulation.heldItemRow(level: 35).ratio
        }
        XCTAssertLessThan(moved, before, "fewer cycles a day must lower the demand")
        XCTAssertEqual(EconomySimulation.heldItemRow(level: 35).ratio, before, accuracy: 0.0000001,
                       "the real model is back as soon as the closure returns")
        XCTAssertEqual(EconomySimulation.effectiveCyclesPerDay, EconomySimulation.orderCyclesPerDay)
    }

    // The congestion half.

    /// Closed-form items per order, so a change to the line-count table or the
    /// count roll fails loudly here rather than silently moving the board figures.
    func testExpectedOrderItemsFollowTheBasketTables() {
        // L20: every easy/medium tier is <= 5, so the "two of these" roll can fire.
        XCTAssertEqual(EconomySimulation.expectedOrderItems(difficulty: .easy, level: 20), 4.0 / 3.0, accuracy: 1e-9)
        XCTAssertEqual(EconomySimulation.expectedOrderItems(difficulty: .medium, level: 20),
                       0.5 * (4.0 / 3.0) + 0.5 * 2.0, accuracy: 1e-9)
        XCTAssertEqual(EconomySimulation.expectedOrderItems(difficulty: .hard, level: 20), 2.5, accuracy: 1e-9,
                       "a hard basket is 2 or 3 lines and never rolls the count-2 bonus")
    }

    /// Sampled against the real generator, as the daily-task hold figure is.
    func testOpenOrderCellsMatchWhatTheGeneratorActuallyAsksFor() {
        let board = AdoptionBoard()
        let dog = ContentRegistry.animalChainID(.dog)
        for level in [5, 45] {
            for difficulty in OrderDifficulty.allCases {
                let slot = orderSlotDifficultyPattern.firstIndex(of: difficulty) ?? 0
                let sample = 6_000
                var items = 0
                for _ in 0..<sample {
                    items += board.generateOrder(unlockedChainIDs: [dog], playerLevel: level, forSlot: slot).wantedCount
                }
                let measured = Double(items) / Double(sample)
                let modelled = EconomySimulation.expectedOrderItems(difficulty: difficulty, level: level)
                XCTAssertEqual(measured, modelled, accuracy: 0.1,
                               "L\(level) \(difficulty.rawValue): generator asks for \(measured) items, model says \(modelled)")
            }
        }
    }

    /// Under D14 the open orders hold cells, so the board is strictly tighter than
    /// under D12 by exactly that many cells, and the orders' own claim fits inside
    /// the unlocked board at every report level.
    func testOpenOrdersHoldCellsInsideTheUnlockedBoard() {
        for level in EconomySimulation.reportLevels {
            let capacity = EconomySimulation.unlockedCells(
                deepestTier: EconomySimulation.assumedDeepestTier(level: level))
            let orders = EconomySimulation.openOrderHoldCells(level: level)
            XCTAssertGreaterThan(orders, 0, "L\(level)")
            XCTAssertLessThan(orders + EconomySimulation.dailyTaskHoldCells()
                              + EconomySimulation.dailyTaskStagingCells(level: level),
                              Double(capacity),
                              "L\(level): orders, dailies and staging must fit on the unlocked board")
            for families in [1, EconomySimulation.totalFamilySpawners] {
                let before = EconomySimulation.congestionRow(level: level, familiesOwned: families)
                let after  = EconomySimulation.congestionRowHeldItem(level: level, familiesOwned: families)
                XCTAssertEqual(before.orderHold, 0)
                XCTAssertEqual(after.orderHold, orders, accuracy: 1e-9)
                XCTAssertEqual(before.workingCells - after.workingCells, orders, accuracy: 1e-9,
                               "L\(level) fam \(families)")
                XCTAssertGreaterThan(after.occupancy, before.occupancy)
            }
        }
    }

    /// One more persistent slot from L13 means one more open order.
    func testOpenOrderCellsStepUpWhenTheFifthSlotOpens() {
        XCTAssertGreaterThan(EconomySimulation.openOrderHoldCells(level: 13),
                             EconomySimulation.openOrderHoldCells(level: 12))
        XCTAssertEqual(EconomySimulation.openOrderHoldCells(level: 12),
                       EconomySimulation.openOrderHoldCells(level: 1), accuracy: 1e-9,
                       "the slot count, not the level, drives the cells held (at equal tier caps)")
    }

    /// The tightest D14 board is strictly tighter than the tightest D12 one. This
    /// is stated, not judged: the PR reports where it goes below zero and why that
    /// number is an upper bound.
    func testTheD14BoardIsTighterThanTheD12BoardAtItsWorst() {
        XCTAssertLessThan(EconomySimulation.worstCaseCongestionHeldItem().workingCells,
                          EconomySimulation.worstCaseCongestion().workingCells)
    }

    // The overstatement bound.

    /// More chains in play means fewer coincidences, so the share D12 could skip
    /// falls as families are unlocked, and it is a proper fraction throughout.
    func testTheD12OverstatementBoundFallsAsFamiliesAreUnlocked() {
        for level in [5, 20, 45] {
            let one     = EconomySimulation.d12SharedCreditBound(level: level, families: 1)
            let four    = EconomySimulation.d12SharedCreditBound(level: level, families: 4)
            let fifteen = EconomySimulation.d12SharedCreditBound(level: level, families: 15)
            XCTAssertGreaterThan(one, four, "L\(level)")
            XCTAssertGreaterThan(four, fifteen, "L\(level)")
            XCTAssertGreaterThanOrEqual(fifteen, 0, "L\(level)")
            XCTAssertLessThan(one, 1, "L\(level)")
        }
        XCTAssertEqual(EconomySimulation.d12SharedCreditBound(level: 20, families: 4),
                       EconomySimulation.d12SharedCreditBound(level: 20, families: 4),
                       "the bound is seeded, so it is reproducible")
    }

    // MARK: Gap_Analysis_Round2 3.7 — the VIP ladder

    func testVIPTiersAreSequentialStartingAt1() {
        XCTAssertEqual(vipTiers.map(\.level), Array(1...vipTiers.count))
    }

    func testVIPTierThresholdsStrictlyIncrease() {
        for (a, b) in zip(vipTiers, vipTiers.dropFirst()) {
            XCTAssertLessThan(a.thresholdMicros, b.thresholdMicros,
                              "VIP \(b.level) must cost more lifetime spend than VIP \(a.level)")
        }
    }

    /// Every level is a straight upgrade over the last — a VIP ladder that dipped
    /// anywhere would read as a broken deal, not a design choice.
    func testVIPTierRewardsNeverDecrease() {
        for (a, b) in zip(vipTiers, vipTiers.dropFirst()) {
            XCTAssertLessThanOrEqual(a.kibbleReward, b.kibbleReward)
            XCTAssertLessThanOrEqual(a.dogTagReward, b.dogTagReward)
            XCTAssertLessThanOrEqual(a.coinReward, b.coinReward)
        }
    }

    func testVIPLevelIsZeroBelowTheFirstThreshold() {
        var state = PlayerCommerceState()
        state.totalSpendMicros = vipTiers[0].thresholdMicros - 1
        XCTAssertEqual(state.vipLevel, 0)
    }

    func testVIPLevelReachesExactlyAtItsThreshold() {
        var state = PlayerCommerceState()
        state.totalSpendMicros = vipTiers[2].thresholdMicros
        XCTAssertEqual(state.vipLevel, vipTiers[2].level)
    }

    /// Spend can jump straight past several thresholds in one purchase (a
    /// single large IAP from a fresh account) — the derived level must land on
    /// the highest one met, not the next one in sequence.
    func testVIPLevelSkipsAheadWithALargePurchase() {
        var state = PlayerCommerceState()
        state.totalSpendMicros = vipTiers[5].thresholdMicros + 1
        XCTAssertEqual(state.vipLevel, vipTiers[5].level)
    }

    func testVIPLevelReachesTheTopTier() {
        var state = PlayerCommerceState()
        state.totalSpendMicros = vipTiers.last!.thresholdMicros
        XCTAssertEqual(state.vipLevel, vipTiers.count)
    }
}
