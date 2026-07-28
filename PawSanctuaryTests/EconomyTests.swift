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

    /// No multiplier level may buy an item at a discount to building it by hand.
    func testEveryMultiplierIsEnergyNeutral() {
        for multiplier in [1, 2, 4, 8] {
            let tier = spawnTierIndex(forMultiplier: multiplier)
            let cost = spawnCost(forTier: tier)
            let worth = 1 << tier          // merge-input cost of that tier
            XCTAssertEqual(cost, worth,
                           "×\(multiplier) buys tier \(tier) for \(cost) but it is worth \(worth)")
        }
    }

    func testMultiplierMapsToExpectedTiers() {
        XCTAssertEqual(spawnTierIndex(forMultiplier: 1), 0)
        XCTAssertEqual(spawnTierIndex(forMultiplier: 2), 1)
        XCTAssertEqual(spawnTierIndex(forMultiplier: 4), 2)
        XCTAssertEqual(spawnTierIndex(forMultiplier: 8), 3)
        XCTAssertEqual(spawnTierIndex(forMultiplier: 99), 0, "unknown multipliers fall back to tier 0")
    }

    func testSpawnCostDoublesPerTier() {
        XCTAssertEqual(spawnCost(forTier: 0), 1)
        XCTAssertEqual(spawnCost(forTier: 3), 8)
        XCTAssertEqual(spawnCost(forTier: 10), 1024)
        XCTAssertEqual(spawnCost(forTier: 14), 16384)
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

        XCTAssertEqual(first.kibbleGain, second.kibbleGain, "every rung buys the same kibble")
        XCTAssertEqual(second.kibbleGain, third.kibbleGain)
        XCTAssertLessThan(first.dogTagCost, second.dogTagCost, "price must climb, not fall")
        XCTAssertLessThan(second.dogTagCost, third.dogTagCost)
    }

    func testDogTagLadderGoesFlatRatherThanUnbounded() {
        let third  = DogTagKibbleExchange.offer(purchasesToday: 2)
        let tenth  = DogTagKibbleExchange.offer(purchasesToday: 9)
        XCTAssertEqual(third.dogTagCost, tenth.dogTagCost)
        XCTAssertTrue(tenth.isAtFlatRate)
        XCTAssertFalse(DogTagKibbleExchange.offer(purchasesToday: 0).isAtFlatRate)
    }

    /// The old table was a volume discount — the exact shape Phase 2 reverses.
    func testRateWorsensRatherThanImproves() {
        let rates = (0..<3).map { i -> Double in
            let o = DogTagKibbleExchange.offer(purchasesToday: i)
            return Double(o.kibbleGain) / Double(o.dogTagCost)
        }
        XCTAssertEqual(rates, rates.sorted(by: >), "kibble-per-tag must decrease with each purchase")
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

    // MARK: Task 2.3a — orders pay items

    func testOrdersCarryBoardItemRewardsAtRoughlyTheStatedRate() {
        let board = AdoptionBoard()
        let chains = AnimalSpecies.allCases.map { ContentRegistry.animalChainID($0) }
        var withItem = 0
        let sample = 3_000
        for _ in 0..<sample {
            let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 30)
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
        for _ in 0..<500 {
            let order = board.generateOrder(unlockedChainIDs: chains, playerLevel: 40)
            guard let reward = order.rewards.first(where: { $0.kind == .boardItem }),
                  let tier = reward.payloadTier else { continue }
            XCTAssertLessThanOrEqual(tier, max(0, order.wantedTier - orderRewardTierOffset),
                                     "an order must never pay back more than a fraction of its cost")
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
}
