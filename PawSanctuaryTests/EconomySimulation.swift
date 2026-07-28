//
//  EconomySimulation.swift
//  PawSanctuaryTests
//
//  Economy model (Phase 2, Task 2.5). Lives in the TEST target, so it can never
//  ship in the app binary — this project defines no DEBUG compilation condition,
//  so an `#if DEBUG` guard here would compile to nothing instead.
//
//  Answers one question: at a given player level, how does the kibble the game
//  ASKS FOR compare to the kibble it GIVES? Everything is denominated in kibble
//  under Task 2.1's neutral pricing, where an item at 0-based tier `t` costs
//  exactly `2^t` to build from scratch.
//
//  The ratio it reports is demand ÷ supply:
//    < 1.00  the player can fill everything they're offered
//    = 1.00  the first genuine wall
//    > 1.00  a persistent shortfall — orders start expiring unfilled
//
//  Target curve (from the measured competitor set):
//    L1–30   < 0.70    comfortable; required for "no monetization in session one"
//    L31–40  0.70→0.95 tightening
//    L41–50  crosses 1.00
//    L51+    1.05–1.25 persistent, never punitive
//

import Foundation
@testable import PawSanctuary

@MainActor
struct EconomySimulation {

    // MARK: Supply model
    //
    // These are MEASURED reference values, not dials. Per the Phase 2 spec they
    // are correct and must not be tuned to fix the ratio — tune order tiers instead.

    /// Daily kibble from passive regen. Below the theoretical 720 (86,400s ÷ 120s)
    /// because a player at cap earns nothing until they spend.
    static let regenPerDayAtCap100 = 520
    /// The 150 cap (level 10+) wastes less to overflow.
    static let regenPerDayAtCap150 = 570
    /// Login bonus, Loyalty Club, quests, daily challenges, weekly goals.
    static let miscKibblePerDay = 75

    /// Order cycles an engaged player actually engages with per day.
    /// Orders run `adoptionOrderDuration` (900 s), so 8 cycles ≈ 2 h of play.
    static let orderCyclesPerDay = 8

    // MARK: Row

    struct Row {
        let level: Int
        let supply: Int
        let grossDemand: Double
        let recirculation: Double
        var netDemand: Double { max(0, grossDemand - recirculation) }
        var ratio: Double { supply == 0 ? .infinity : netDemand / Double(supply) }

        var description: String {
            String(format: "L%-3d  supply %4d   demand %8.0f   recirc %7.0f   net %8.0f   ratio %5.2f",
                   level, supply, grossDemand, recirculation, netDemand, ratio)
        }
    }

    // MARK: Supply

    static func dailySupply(level: Int) -> Int {
        let regen = level >= 10 ? regenPerDayAtCap150 : regenPerDayAtCap100
        let ads   = maxDailyAdWatches * adKibbleReward
        return regen + ads + miscKibblePerDay
    }

    // MARK: Demand
    //
    // Enumerates `AdoptionBoard.generateOrder`'s tier-weighting table exactly
    // rather than sampling it, so the number is stable and the test can assert on it.

    /// Every (tier, probability) pair an order can be generated with at `level`.
    /// Mirrors the `roll` switch in `AdoptionBoard.generateOrder` — keep in step.
    static func tierDistribution(level: Int) -> [(tier: Int, p: Double)] {
        let maxTier = maxAchievableOrderTier(forPlayerLevel: level)
        var weights: [Int: Double] = [:]
        for (bandProbability, tiers) in orderTierBands {
            let each = bandProbability / Double(tiers.count)
            for t in tiers { weights[min(t, maxTier), default: 0] += each }
        }
        return weights.map { (tier: $0.key, p: $0.value) }.sorted { $0.tier < $1.tier }
    }

    /// Expected kibble cost of one generated order, counting `wantedCount`.
    static func expectedOrderCost(level: Int) -> Double {
        tierDistribution(level: level).reduce(0) { total, entry in
            // count = 2 one time in three, but only for tiers 0...5
            let expectedCount = entry.tier <= 5 ? (1.0 + 1.0 / 3.0) : 1.0
            return total + entry.p * Double(spawnCost(forTier: entry.tier)) * expectedCount
        }
    }

    static func ordersPerDay(level: Int) -> Double {
        // Base 2 slots; Garden Hutch T1 adds one, modelled as available from L13.
        let slots = level >= 13 ? 3.0 : 2.0
        return slots * Double(orderCyclesPerDay)
    }

    static func grossDemand(level: Int) -> Double {
        ordersPerDay(level: level) * expectedOrderCost(level: level)
    }

    // MARK: Recirculation
    //
    // Kibble-equivalent value of the items handed back per day. This is what makes
    // the deep chain reachable: a Stage-15 item costs 16,384 kibble, roughly 22 days
    // of a player's entire income, so it cannot come from tapping.

    static func recirculation(level: Int, deepestTier: Int) -> Double {
        let orders = ordersPerDay(level: level)
        let dist   = tierDistribution(level: level)

        // 3a — one order in `orderBoardItemFrequency` pays an item at wantedTier − offset.
        let perOrderItem = dist.reduce(0.0) { total, entry in
            total + entry.p * Double(spawnCost(forTier: max(0, entry.tier - orderRewardTierOffset)))
        }
        let fromOrders = orders / Double(orderBoardItemFrequency) * perOrderItem

        // 2.2 — Board Item Grant power-ups. Upper bound: the player spends their
        // entire income on tier-0 taps, which maximises sub-object drops.
        let spawnsPerDay      = Double(dailySupply(level: level))
        let subObjectsPerDay  = spawnsPerDay * SubObjectDropConfig.baseSubObjectChance
        // A 4-tier chain merged 2-to-1 needs 2^3 = 8 tier-0s per completed sub-object.
        let completedPerDay   = subObjectsPerDay / 8.0
        let grantsPerDay      = completedPerDay * (SubObjectRarity.boardItemGrant.weight / 100.0)
        let fromGrants        = grantsPerDay * Double(spawnCost(forTier:
            min(max(0, deepestTier - recirculationTierOffset), recirculationMaxItemTier)))

        // 3b — weekly and monthly chests, amortised per day.
        let weeklyChests = WeeklyGoalTier.allCases.reduce(0.0) { total, tier in
            total + Double(tier.boardItemCount) * Double(spawnCost(forTier:
                min(max(0, deepestTier - tier.boardItemTierOffset), recirculationMaxItemTier)))
        } / 7.0
        let monthlyChest = 2.0 * Double(spawnCost(forTier:
            min(max(0, deepestTier - 1), recirculationMaxItemTier))) / 30.0

        return fromOrders + fromGrants + weeklyChests + monthlyChest
    }

    // MARK: Report

    /// Deepest tier a player at `level` is assumed to have reached. Recirculation
    /// scales off this, so the model needs a value per level band.
    static func assumedDeepestTier(level: Int) -> Int {
        maxAchievableOrderTier(forPlayerLevel: level)
    }

    static func row(level: Int) -> Row {
        let deepest = assumedDeepestTier(level: level)
        return Row(level: level,
                   supply: dailySupply(level: level),
                   grossDemand: grossDemand(level: level),
                   recirculation: recirculation(level: level, deepestTier: deepest))
    }

    static let reportLevels = [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60]

    static func report() -> String {
        var out = "PawSanctuary economy model — Phase 2\n"
        out += "target: <0.70 to L30 · 0.70-0.95 L31-40 · crosses 1.00 at L41-50 · 1.05-1.25 L51+\n\n"
        for level in reportLevels { out += row(level: level).description + "\n" }
        return out
    }

    /// Prints `report()`. Call from a debug menu or a breakpoint.
    static func printReport() { print(report()) }
}
