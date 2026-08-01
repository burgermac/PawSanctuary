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
    // Enumerates `AdoptionBoard`'s per-difficulty tier-weighting tables exactly
    // rather than sampling them, so the number is stable and the test can assert on it.

    /// Order slots active at `level`. Base 4 (Task 5.1); Garden Hutch T1 adds one,
    /// modelled as available from L13 — the other four order-slot upgrades
    /// scattered later across the map are not separately modelled, consistent
    /// with this function's pre-5.1 approximation of only the first unlock.
    static func slotCount(level: Int) -> Int {
        level >= 13 ? 5 : 4
    }

    /// Every (tier, probability) pair an order can be generated with at `level`,
    /// averaged across every active slot's fixed difficulty. Mirrors
    /// `AdoptionBoard.difficulty(forSlot:)` + `rollTier(difficulty:)` — keep in step.
    static func tierDistribution(level: Int) -> [(tier: Int, p: Double)] {
        let maxTier = maxAchievableOrderTier(forPlayerLevel: level)
        let slots = slotCount(level: level)
        var weights: [Int: Double] = [:]
        for slotIndex in 0..<slots {
            let difficulty = AdoptionBoard.difficulty(forSlot: slotIndex)
            let bands = orderDifficultyBands[difficulty] ?? []
            for (bandProbability, tiers) in bands {
                let each = bandProbability / Double(tiers.count) / Double(slots)
                for t in tiers { weights[min(t, maxTier), default: 0] += each }
            }
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
        Double(slotCount(level: level)) * Double(orderCyclesPerDay)
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

    // ============================================================
    // MARK: - COIN ECONOMY (Phase 2c)
    // ============================================================
    //
    // Coins gate the Sanctuary Map, the game's forever goal. Phases 2 and 2b
    // modelled kibble only, which is how the coin faucet ended up with selling
    // paying ~45× everything else combined.
    //
    // Assumptions, stated so they can be argued with:
    //  · A player converts kibble into fulfilled orders up to whichever binds
    //    first — what the orders ask for, or what they can afford.
    //  · A "selling" player diverts `sellSurplusFraction` of that production to
    //    sales instead, earning the worse rate on it.
    //  · Quests: ~2 claims/day at mixed difficulty.
    //  · Albums are one-time; amortised over the 60-day target rather than the
    //    projection itself, which would make the calculation circular.

    /// Total coins to build out the whole map — read from the live area roster so
    /// it cannot drift from the content.
    static var mapTotalCoinCost: Int {
        sanctuaryAreas.flatMap(\.upgrades).reduce(0) { $0 + $1.coinCost }
    }

    /// Assumed share of production a "selling" player diverts to sales.
    static let sellSurplusFraction = 0.20

    /// Share of production that actually lands in a completed order.
    ///
    /// Not 1.0: 20% of spawner activations yield sub-objects rather than animals,
    /// orders ask for specific families the player may not be growing, and an
    /// order expires after 15 minutes whether or not the board had room. Assuming
    /// every kibble converts to order coins overstates income by about half again.
    static let orderFulfilmentEfficiency = 0.65
    /// Quest claims per day, and the mixed-difficulty average payout.
    static let questClaimsPerDay = 2.0
    static var averageQuestCoins: Double {
        Double(QuestDifficulty.easy.coinReward
             + QuestDifficulty.medium.coinReward
             + QuestDifficulty.hard.coinReward) / 3.0
    }
    /// Horizon used only to amortise one-time album rewards.
    static let amortisationDays = 60.0

    @MainActor
    struct CoinRow {
        let level: Int
        let fromOrders: Double
        let fromSelling: Double
        let fromOther: Double
        var total: Double { fromOrders + fromSelling + fromOther }
        var daysToFullMap: Double {
            total <= 0 ? .infinity : Double(mapTotalCoinCost) / total
        }
    }

    /// Kibble-equivalent per day that actually becomes completed orders: the
    /// smaller of what orders ask for and what the player can field, discounted
    /// by how much of that production really lands in an order.
    ///
    /// Note the `+ recirculation`: recirculated items fulfil orders too, so order
    /// throughput exceeds raw kibble supply by roughly a quarter in the endgame.
    /// The 6.5 anchor was derived against supply alone, which is why the
    /// projection lands faster than the 60-day target it came from.
    static func kibbleIntoOrders(level: Int) -> Double {
        let r = row(level: level)
        return min(r.grossDemand, Double(r.supply) + r.recirculation) * orderFulfilmentEfficiency
    }

    /// Coins per day from the faucets that aren't the two main channels.
    static func otherCoinIncome(level: Int) -> Double {
        let production = kibbleIntoOrders(level: level)
        let dailies = Double(coinsPerAllDailyChallenges)
        let quests  = questClaimsPerDay * averageQuestCoins
        // A top-tier merge consumes a full top-tier item's worth of production.
        let topTierMergesPerDay = production / Double(spawnCost(forTier: animalChainTopTier))
        let ambassadors = topTierMergesPerDay * Double(coinsPerAmbassadorMerge)
        let albums = Double(CardRegistry.albums.reduce(0) { $0 + $1.rewardCoins }) / amortisationDays
        return dailies + quests + ambassadors + albums
    }

    static func coinRow(level: Int, sells: Bool) -> CoinRow {
        let production = kibbleIntoOrders(level: level)
        let sellShare  = sells ? sellSurplusFraction : 0
        let orderKibble = production * (1 - sellShare)
        let sellKibble  = production * sellShare
        return CoinRow(
            level: level,
            fromOrders:  orderKibble * coinsPerKibbleOfOrder,
            fromSelling: sellKibble * coinsPerKibbleOfSale,
            fromOther:   otherCoinIncome(level: level))
    }

    /// The headline projection. Most of the map is bought in the steady state a
    /// player reaches around the first wall, so the projection is anchored there
    /// rather than on peak endgame income — see `projectionLevel`.
    static let projectionLevel = 45

    static func daysToFullMap(sells: Bool) -> Double {
        coinRow(level: projectionLevel, sells: sells).daysToFullMap
    }

    // MARK: Report

    static func report() -> String {
        var out = "PawSanctuary economy model — Phases 2 / 2b / 2c\n"
        out += "kibble target: <0.70 to L30 · 0.70-0.95 L31-40 · crosses 1.00 at L41-50 · 1.05-1.25 L51+\n\n"
        for level in reportLevels { out += row(level: level).description + "\n" }

        out += "\ncoins — map costs \(mapTotalCoinCost) across "
        out += "\(sanctuaryAreas.flatMap(\.upgrades).count) upgrades\n"
        out += "target: 55-70 days selling \(Int(sellSurplusFraction * 100))% · no worse than ~75 never selling\n\n"
        for level in reportLevels {
            let never = coinRow(level: level, sells: false)
            let sell  = coinRow(level: level, sells: true)
            out += String(format:
                "L%-3d  orders %7.0f  other %5.0f  |  never-sell %7.0f/day → %5.1f days   sell-%d%% %7.0f/day → %5.1f days\n",
                level, never.fromOrders, never.fromOther,
                never.total, never.daysToFullMap,
                Int(sellSurplusFraction * 100), sell.total, sell.daysToFullMap)
        }
        out += String(format: "\nheadline (L%d): never-sell %.1f days · sell %.1f days\n",
                      projectionLevel, daysToFullMap(sells: false), daysToFullMap(sells: true))
        return out
    }

    /// Prints `report()`. Call from a debug menu or a breakpoint.
    static func printReport() { print(report()) }
}
