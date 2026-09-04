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

    /// Order cycles an engaged player actually engages with per day — how often
    /// a slot is completed and replaced, not a timer (Phase 5, Task 5.2 made the
    /// 4 persistent slots timerless; this was always a claim-cadence assumption,
    /// unaffected by that split). 8 cycles ≈ 2 h of active play.
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
    /// averaged across every active persistent slot's fixed difficulty plus the
    /// single urgent order (Task 5.2), which always rolls `.medium` — see
    /// `AdoptionBoard.generateUrgentOrder`. Mirrors
    /// `AdoptionBoard.difficulty(forSlot:)` + `rollTier(difficulty:)` — keep in step.
    static func tierDistribution(level: Int) -> [(tier: Int, p: Double)] {
        let maxTier = maxAchievableOrderTier(forPlayerLevel: level)
        let persistentSlots = slotCount(level: level)
        let totalSlots = persistentSlots + 1   // + the urgent order
        var weights: [Int: Double] = [:]
        func add(_ bands: [(probability: Double, tiers: [Int])]) {
            for (bandProbability, tiers) in bands {
                let each = bandProbability / Double(tiers.count) / Double(totalSlots)
                for t in tiers { weights[min(t, maxTier), default: 0] += each }
            }
        }
        for slotIndex in 0..<persistentSlots {
            add(orderDifficultyBands[AdoptionBoard.difficulty(forSlot: slotIndex)] ?? [])
        }
        add(orderDifficultyBands[.medium] ?? [])
        return weights.map { (tier: $0.key, p: $0.value) }.sorted { $0.tier < $1.tier }
    }

    /// Expected kibble cost of one basket line drawn from `difficulty`'s band.
    /// `applyCountRoll` models the single-line "bring me two of these" roll,
    /// which `AdoptionBoard.generateOrder` applies only when the basket has
    /// exactly one line, and only for tiers 0...5.
    static func expectedLineCost(difficulty: OrderDifficulty,
                                 level: Int,
                                 applyCountRoll: Bool) -> Double {
        let maxTier = maxAchievableOrderTier(forPlayerLevel: level)
        var total = 0.0
        for (bandProbability, tiers) in orderDifficultyBands[difficulty] ?? [] {
            let each = bandProbability / Double(tiers.count)
            for t in tiers {
                let tier = min(t, maxTier)
                // count = 2 one time in three, but only for tiers 0...5
                let expectedCount = (applyCountRoll && tier <= 5) ? (1.0 + 1.0 / 3.0) : 1.0
                total += each * Double(spawnCost(forTier: tier)) * expectedCount
            }
        }
        return total
    }

    /// Expected kibble cost of one order generated for a slot of `difficulty`,
    /// across the basket sizes that slot can roll (schema v37).
    ///
    /// Mirrors `AdoptionBoard.generateOrder`: line 0 draws the slot's own band,
    /// any further lines draw `basketFillerDifficulty`, and the count roll
    /// applies only to single-line baskets. Keep in step with it.
    static func expectedOrderCost(difficulty: OrderDifficulty, level: Int) -> Double {
        let sizes = Array(orderBasketLineCounts[difficulty] ?? 1...1)
        guard !sizes.isEmpty else { return 0 }
        let pEach = 1.0 / Double(sizes.count)
        let filler = expectedLineCost(difficulty: difficulty.basketFillerDifficulty,
                                      level: level, applyCountRoll: false)
        return sizes.reduce(0.0) { total, lineCount in
            let headline = expectedLineCost(difficulty: difficulty, level: level,
                                            applyCountRoll: lineCount == 1)
            return total + pEach * (headline + Double(lineCount - 1) * filler)
        }
    }

    /// Expected kibble cost of one generated order, averaged across every active
    /// persistent slot's fixed difficulty plus the urgent order (always `.medium`).
    static func expectedOrderCost(level: Int) -> Double {
        let persistentSlots = slotCount(level: level)
        var total = 0.0
        for slotIndex in 0..<persistentSlots {
            total += expectedOrderCost(difficulty: AdoptionBoard.difficulty(forSlot: slotIndex),
                                       level: level)
        }
        total += expectedOrderCost(difficulty: .medium, level: level)   // the urgent order
        return total / Double(persistentSlots + 1)
    }

    // MARK: Daily hand-in tasks (Spec_DailyHandInTasks.md)
    //
    // **Coin side only, deliberately — there is no demand-side term below.**
    //
    // A daily task destroys board items, which looks like kibble demand. It is
    // not, in this model's terms, because PawSanctuary's orders credit on
    // *merge* and never consume: an order pays out the moment the item is
    // built, and the item then stays on the board. The kibble that built it is
    // already counted in `grossDemand`. A hand-in spends that same item a
    // second time, so counting its build cost again would double-count the
    // build and report a wall the game does not have.
    //
    // What a hand-in really is here is a **sink on the item stock** — a reason
    // for the board to clear, which is the thing this economy was previously
    // short of. `Row`/`ratio` is a flow model (kibble per day in, kibble per
    // day asked for), so it has nowhere to express a stock drain, and inventing
    // an overlap fraction to smuggle one in would be tuning the ratio to taste
    // — exactly what the supply model's own header forbids.
    //
    // The coin side has no such ambiguity: the coins are simply paid.

    /// Every (basket kibble cost, probability) a daily task of `difficulty` can
    /// roll at `level`.
    ///
    /// Enumerated rather than averaged because `dailyTaskCoinFloor` binds on
    /// *individual* baskets: E[max(floor, cost)] > max(floor, E[cost]), so
    /// applying the floor to an average would understate the faucet — the
    /// unsafe direction for a coin source.
    ///
    /// Mirrors `QuestCoordinator.generateDailyTask`: the slot's difficulty maps
    /// to an order band, line 0 draws that band, further lines draw
    /// `basketFillerDifficulty` independently, and — unlike an order — there is
    /// **no** "bring me two of these" count roll. Keep in step with it.
    static func dailyTaskCostDistribution(difficulty: QuestDifficulty,
                                          level: Int) -> [(cost: Double, p: Double)] {
        let band    = difficulty.dailyTaskOrderBand
        let maxTier = maxAchievableOrderTier(forPlayerLevel: level)

        func tierOutcomes(_ d: OrderDifficulty) -> [(cost: Double, p: Double)] {
            var weights: [Int: Double] = [:]
            for (bandProbability, tiers) in orderDifficultyBands[d] ?? [] {
                let each = bandProbability / Double(tiers.count)
                for t in tiers { weights[min(t, maxTier), default: 0] += each }
            }
            return weights.map { (cost: Double(spawnCost(forTier: $0.key)), p: $0.value) }
        }

        let headline = tierOutcomes(band)
        let filler   = tierOutcomes(band.basketFillerDifficulty)
        let sizes    = Array(orderBasketLineCounts[band] ?? 1...1)
        guard !sizes.isEmpty else { return [] }
        let pSize = 1.0 / Double(sizes.count)

        var result: [(cost: Double, p: Double)] = []
        for lineCount in sizes {
            var acc = headline.map { (cost: $0.cost, p: $0.p * pSize) }
            for _ in 0..<max(0, lineCount - 1) {
                acc = acc.flatMap { a in
                    filler.map { f in (cost: a.cost + f.cost, p: a.p * f.p) }
                }
            }
            result += acc
        }
        return result
    }

    /// Expected kibble value of one daily task's basket at `level`.
    static func expectedDailyTaskCost(difficulty: QuestDifficulty, level: Int) -> Double {
        dailyTaskCostDistribution(difficulty: difficulty, level: level)
            .reduce(0.0) { $0 + $1.p * $1.cost }
    }

    /// Kibble value handed in per day across all three slots, assuming the
    /// player clears them.
    ///
    /// Full clearance rather than a completion rate: on a faucet, assuming
    /// players earn *less* is the assumption that hides an overpay, so the
    /// safe direction here is to assume they earn all of it.
    static func dailyTaskKibbleHandedIn(level: Int) -> Double {
        dailyTaskSlotDifficulties.reduce(0.0) {
            $0 + expectedDailyTaskCost(difficulty: $1, level: level)
        }
    }

    /// Coins one daily slot pays per day, floor included.
    static func dailyTaskCoinIncome(difficulty: QuestDifficulty, level: Int) -> Double {
        dailyTaskCostDistribution(difficulty: difficulty, level: level).reduce(0.0) { total, outcome in
            total + outcome.p * max(Double(dailyTaskCoinFloor),
                                    outcome.cost * coinsPerKibbleOfOrder * dailyTaskCoinMultiplier)
        }
    }

    /// Coins per day from claiming all three daily tasks — the per-task payouts
    /// only. The flat all-three sweep bonus is counted separately in
    /// `otherCoinIncome`, as it was before this channel existed.
    static func dailyTaskCoinIncome(level: Int) -> Double {
        dailyTaskSlotDifficulties.reduce(0.0) {
            $0 + dailyTaskCoinIncome(difficulty: $1, level: level)
        }
    }

    static func ordersPerDay(level: Int) -> Double {
        Double(slotCount(level: level) + 1) * Double(orderCyclesPerDay)   // + the urgent order
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

        // §2 — Smile point bundles. Every fulfilled order banks its Smile value
        // (1/2/3 by the deepest tier it asks for); each full bar scatters one
        // item per `smileBundleTierOffsets` entry. Modelled here because this is
        // a real board-material faucet — leaving it out would understate
        // recirculation and report a wall that is tighter than the game's.
        let smilePerOrder = tierDistribution(level: level).reduce(0.0) { total, entry in
            total + entry.p * Double(smilePoints(forTier: entry.tier))
        }
        let bundlesPerDay = orders * smilePerOrder / Double(smilePointsGoal)
        let perBundle = smileBundleTierOffsets.reduce(0.0) { total, offset in
            total + Double(spawnCost(forTier:
                min(max(0, deepestTier - offset), smileBundleMaxItemTier)))
        }
        let fromSmiles = bundlesPerDay * perBundle

        // 3b — weekly and monthly chests, amortised per day.
        let weeklyChests = WeeklyGoalTier.allCases.reduce(0.0) { total, tier in
            total + Double(tier.boardItemCount) * Double(spawnCost(forTier:
                min(max(0, deepestTier - tier.boardItemTierOffset), recirculationMaxItemTier)))
        } / 7.0
        let monthlyChest = 2.0 * Double(spawnCost(forTier:
            min(max(0, deepestTier - 1), recirculationMaxItemTier))) / 30.0

        return fromOrders + fromGrants + fromSmiles + weeklyChests + monthlyChest
    }

    // ============================================================
    // MARK: - BOARD CONGESTION (schema v40)
    // ============================================================
    //
    // The gap `Spec_DailyHandInTasks.md` §5a left open. The coin model above is
    // a **flow** model — kibble per day in against kibble per day asked for —
    // and a daily hand-in drains a **stock**: cells on the board. There is
    // nowhere in `Row`/`ratio` to express that, which is why the sweep
    // deliberately added no demand-side term. This section is the stock model
    // that belongs beside it.
    //
    // It asks one question: **how much of the board is spoken for, and how much
    // is left to actually play in?**
    //
    // Why this became worth modelling at v40. Before v40 nothing made the player
    // *hold* anything. Orders credit on merge and never consume, so an item's
    // job was done the instant it existed and the board tended to drain —
    // merging is a strict sink (two cells become one). A hand-in task is the
    // first mechanic in the game that requires specific creatures to be standing
    // on the board *simultaneously*, and that is a genuine claim on cells.
    //
    // Everything here is derived from live content and code except where a
    // comment says otherwise.

    /// Board cells unlocked at `deepestTier`.
    ///
    /// Rows 0-2 are open from the start; rows 3-8 unlock on
    /// `boardRowUnlockTiers` (2/4/6/8/9/10). Deliberately keyed to deepest tier
    /// rather than level, because that is what the game itself gates on
    /// (Gap_Analysis_Round2 §2, C-1: "deeper tiers need more staging space, so
    /// the reward should arrive with the need").
    static func unlockedCells(deepestTier: Int) -> Int {
        let columns = 7
        let unlockedRows = 3 + boardRowUnlockTiers.values.filter { $0 <= deepestTier }.count
        return min(boardRows, unlockedRows) * columns
    }

    /// Every family spawner the game can ever grant: one per map area that
    /// rewards one, plus the Canines spawner every save starts with
    /// (`MergeBoardViewModel.freshStart`). Read from the live area roster so it
    /// cannot drift from the content, the same way `mapTotalCoinCost` is.
    static var totalFamilySpawners: Int {
        sanctuaryAreas.filter { $0.reward.newFamilySpawner != nil }.count + 1
    }

    /// Cells permanently consumed by family spawners.
    ///
    /// **Permanent is the operative word.** Family spawners are unlimited — the
    /// charge decrement in `activateProducer` is on the legacy rescue-tier and
    /// supply-producer branches, not theirs (`MergeBoardViewModel.swift:1599`
    /// says so explicitly). They auto-place on completing a map area and only
    /// overflow to storage if the board is already full, so the default state of
    /// a progressing save is every spawner it owns sitting on the board forever.
    ///
    /// `familiesOwned` is an **input, not a derived value**: map areas are
    /// gated on *materials* (`SanctuaryArea.costs`), not coins, and this model
    /// does not model the material faucet. Deriving a families-per-level curve
    /// would mean inventing one, so the report sweeps the range instead.
    static func spawnerCells(familiesOwned: Int) -> Int {
        max(0, min(familiesOwned, totalFamilySpawners))
    }

    /// Supply producers (grooming/feed/shelter box) auto-place on level-up at
    /// L15/20/25 (`levelUpReward`). Unlike family spawners these *are* consumed
    /// — 6 charges, then the tile is removed — so they occupy cells only
    /// intermittently. Counted at their unlocked count as an upper bound.
    static func supplyProducerCells(level: Int) -> Int {
        (level >= 15 ? 1 : 0) + (level >= 20 ? 1 : 0) + (level >= 25 ? 1 : 0)
    }

    /// Expected creatures the three daily tasks require standing on the board at
    /// once, if the player is working toward all three.
    ///
    /// This is a count of *items*, not kibble — the duplicate-collapse in
    /// `generateDailyTask` turns two identical lines into one line of count 2,
    /// which leaves the item total unchanged, so the basket's line count is the
    /// cell count.
    static func dailyTaskHoldCells() -> Double {
        dailyTaskSlotDifficulties.reduce(0.0) { total, difficulty in
            let sizes = Array(orderBasketLineCounts[difficulty.dailyTaskOrderBand] ?? 1...1)
            guard !sizes.isEmpty else { return total }
            return total + Double(sizes.reduce(0, +)) / Double(sizes.count)
        }
    }

    /// Peak extra cells needed *while building* the deepest creature a daily
    /// task asks for, on top of what is already being held.
    ///
    /// Merging greedily, building one tier-N item from tier-0 spawns needs at
    /// most N+1 cells at any instant — one partial per tier, the binary-counter
    /// bound — not the 2^N inputs, because each merge frees a cell as it goes.
    /// Taken over the hard slot only: a player stages one deep build at a time
    /// and the easy/medium asks are shallow enough to sit inside its shadow.
    static func dailyTaskStagingCells(level: Int) -> Double {
        let maxTier = maxAchievableOrderTier(forPlayerLevel: level)
        var expectedTier = 0.0
        for (bandProbability, tiers) in orderDifficultyBands[.hard] ?? [] {
            let each = bandProbability / Double(tiers.count)
            for t in tiers { expectedTier += each * Double(min(t, maxTier)) }
        }
        return expectedTier + 1.0
    }

    struct CongestionRow {
        let level: Int
        let familiesOwned: Int
        let capacity: Int
        let spawners: Int
        let supplyProducers: Int
        let hold: Double
        let staging: Double

        /// Cells left to merge in once everything with a claim on the board has
        /// taken its share.
        var workingCells: Double {
            Double(capacity - spawners - supplyProducers) - hold - staging
        }
        var occupancy: Double {
            capacity == 0 ? 1 : (Double(spawners + supplyProducers) + hold + staging) / Double(capacity)
        }

        var description: String {
            String(format: "L%-3d fam %2d  cap %2d  spawners %2d  supply %d  hold %4.1f  staging %4.1f  |  working %5.1f  occupancy %3.0f%%",
                   level, familiesOwned, capacity, spawners, supplyProducers,
                   hold, staging, workingCells, occupancy * 100)
        }
    }

    static func congestionRow(level: Int, familiesOwned: Int) -> CongestionRow {
        CongestionRow(level: level,
                      familiesOwned: familiesOwned,
                      capacity: unlockedCells(deepestTier: assumedDeepestTier(level: level)),
                      spawners: spawnerCells(familiesOwned: familiesOwned),
                      supplyProducers: supplyProducerCells(level: level),
                      hold: dailyTaskHoldCells(),
                      staging: dailyTaskStagingCells(level: level))
    }

    /// The corner this model exists to find: capacity is gated on **deepest
    /// merge tier**, spawner count on **map areas bought with materials**. They
    /// are different currencies, so they can drift apart — and a save that has
    /// bought a lot of map without deepening its chains is spawner-choked.
    static func worstCaseCongestion() -> CongestionRow {
        var worst = congestionRow(level: 1, familiesOwned: 1)
        for level in reportLevels {
            for families in 1...totalFamilySpawners {
                let row = congestionRow(level: level, familiesOwned: families)
                if row.workingCells < worst.workingCells { worst = row }
            }
        }
        return worst
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
        // Schema v40: the three daily slots now pay per-task coins for the
        // creatures handed in, on top of the flat all-three sweep bonus. Before
        // v40 they paid nothing individually, which is why this line used to be
        // the sweep bonus alone.
        let dailies = Double(coinsPerAllDailyChallenges) + dailyTaskCoinIncome(level: level)
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

        out += "\ndaily hand-in tasks — multiplier \(dailyTaskCoinMultiplier), "
        out += "sweep bonus \(coinsPerAllDailyChallenges)\n"
        for level in reportLevels {
            let easy   = dailyTaskCoinIncome(difficulty: .easy,   level: level)
            let medium = dailyTaskCoinIncome(difficulty: .medium, level: level)
            let hard   = dailyTaskCoinIncome(difficulty: .hard,   level: level)
            let total  = easy + medium + hard
            out += String(format:
                "L%-3d  easy %6.0f  medium %6.0f  hard %7.0f  |  per-task total %7.0f  + sweep %d = %7.0f  (hard is %3.0f%%)\n",
                level, easy, medium, hard, total,
                coinsPerAllDailyChallenges, total + Double(coinsPerAllDailyChallenges),
                total == 0 ? 0 : hard / total * 100)
        }
        out += "\nboard congestion — \(totalFamilySpawners) spawners exist; "
        out += "hold \(String(format: "%.1f", dailyTaskHoldCells())) cells\n"
        out += "capacity is gated on deepest merge tier; spawners on map areas (materials) — different currencies\n\n"
        for level in reportLevels {
            // Sweep the plausible span of families owned at this level rather
            // than inventing a families-per-level curve (see `spawnerCells`).
            for families in [1, totalFamilySpawners / 2, totalFamilySpawners] {
                out += congestionRow(level: level, familiesOwned: families).description + "\n"
            }
        }
        out += "\nworst corner: " + worstCaseCongestion().description + "\n"
        return out
    }

    /// Prints `report()`. Call from a debug menu or a breakpoint.
    static func printReport() { print(report()) }
}
