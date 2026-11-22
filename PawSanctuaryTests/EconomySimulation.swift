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

    // MARK: What-if levers (proposals only; never applied to the game)
    //
    // The order tier cap and the order cycles per day are the two dials this
    // model's header allows ("tune order tiers"; `orderCyclesPerDay` is a
    // claim-cadence assumption). They are read through the two helpers below so
    // a proposed change can be costed here, with its own before/after numbers,
    // WITHOUT editing the app's `maxAchievableOrderTier` or this file's
    // `orderCyclesPerDay`. Outside `withLevers` both helpers return the real
    // values, so every existing assertion is unaffected.

    struct Levers {
        /// Replacement for `maxAchievableOrderTier(forPlayerLevel:)`.
        var tierCap: ((Int) -> Int)? = nil
        /// Replacement for `orderCyclesPerDay`.
        var cyclesPerDay: Int? = nil
    }

    private static var activeLevers = Levers()

    static func orderTierCap(level: Int) -> Int {
        activeLevers.tierCap?(level) ?? maxAchievableOrderTier(forPlayerLevel: level)
    }
    static var effectiveCyclesPerDay: Int { activeLevers.cyclesPerDay ?? orderCyclesPerDay }

    /// Runs `body` with `levers` in force and restores the real values after.
    static func withLevers<T>(_ levers: Levers, _ body: () -> T) -> T {
        let saved = activeLevers
        activeLevers = levers
        defer { activeLevers = saved }
        return body()
    }

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
        let maxTier = orderTierCap(level: level)
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
        let maxTier = orderTierCap(level: level)
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
    // **Two views of the same item cost, depending on which rule is in force.**
    //
    // Under D12 (orders credit when an item is *produced* and nothing leaves
    // the board) this section carried no demand-side term, and said so: an
    // order paid out the instant its item was built and the item then stayed
    // put, so a daily hand-in spent that same item a second time. Counting its
    // build cost again would have reported a wall the game did not have.
    //
    // Under D14 (Spec_HeldItemOrders.md: orders are filled from items HELD on
    // the board, and delivery consumes them) that premise is gone. An order now
    // removes the items it takes, so an item handed in to a daily task is an
    // item that is no longer there to fill an order, and the other way round.
    // The two channels compete for one stock of items, and a daily task's item
    // cost is real kibble demand on top of the orders'.
    //
    // The D12 model (`grossDemand`, `row`) is kept as it was, so the existing
    // ratio assertions still describe the rule they were written for. The D14
    // model is a separate set of quantities (`grossDemandHeldItem`,
    // `heldItemRow`) that adds `dailyTaskKibbleHandedIn` as a demand term.
    //
    // What the flow model still cannot express: *which* copy goes where. A held
    // item can be wanted by an order and a daily task at once and only one of
    // them gets it (first delivery wins), and the displaced card then needs a
    // second copy. That is a stock effect; the model charges each card its own
    // full build cost, which is the right charge when the two never share a
    // copy and a slight overcharge when they could (see `d12SharedCreditBound`
    // for the order-to-order version of the same question). No overlap fraction
    // is applied: that would be tuning the ratio to taste, which the supply
    // model's own header forbids.
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
        let maxTier = orderTierCap(level: level)

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
        Double(slotCount(level: level) + 1) * Double(effectiveCyclesPerDay)   // + the urgent order
    }

    /// Kibble the **orders alone** ask for per day: every order generated is
    /// charged the full build cost `2^tier` of every item on every line.
    ///
    /// This is the D12 model's demand and is kept unchanged. See
    /// `grossDemandHeldItem` for the D14 (held-item) model, which adds the daily
    /// tasks. The formula itself is still the right charge under D14 for orders;
    /// what changes is the meaning, not the arithmetic — under D12 it was an
    /// upper bound on what orders really cost the player (one produced item
    /// could credit several orders), under D14 every delivered item is consumed
    /// by exactly one order, so it is the real charge.
    static func grossDemand(level: Int) -> Double {
        ordersPerDay(level: level) * expectedOrderCost(level: level)
    }

    // MARK: Demand under held-item delivery (D14, Spec_HeldItemOrders.md §6)

    /// Kibble per day the three daily hand-in tasks consume, on top of the
    /// orders. Equal to `dailyTaskKibbleHandedIn`; named separately so the demand
    /// build-up reads as "orders + daily tasks".
    ///
    /// Assumes the player clears all three tasks every day. For a *demand* term
    /// that is the upper-bound direction (a player who skips a task asks the
    /// economy for less), so the D14 ratio below is, if anything, slightly high.
    static func dailyTaskDemand(level: Int) -> Double {
        dailyTaskKibbleHandedIn(level: level)
    }

    /// Kibble per day asked for under D14: orders plus daily tasks.
    static func grossDemandHeldItem(level: Int) -> Double {
        grossDemand(level: level) + dailyTaskDemand(level: level)
    }

    /// The D14 counterpart of `Row`. Supply and recirculation are identical to
    /// the D12 row (they are supply-side and the rule change does not touch
    /// them); only the demand differs.
    struct HeldItemRow {
        let level: Int
        let supply: Int
        let orderDemand: Double
        let dailyTaskDemand: Double
        let recirculation: Double
        var grossDemand: Double { orderDemand + dailyTaskDemand }
        var netDemand: Double { max(0, grossDemand - recirculation) }
        var ratio: Double { supply == 0 ? .infinity : netDemand / Double(supply) }

        var description: String {
            String(format: "L%-3d  supply %4d   orders %8.0f  +dailies %6.0f = demand %8.0f   recirc %7.0f   net %8.0f   ratio %5.2f",
                   level, supply, orderDemand, dailyTaskDemand, grossDemand, recirculation, netDemand, ratio)
        }
    }

    static func heldItemRow(level: Int) -> HeldItemRow {
        HeldItemRow(level: level,
                    supply: dailySupply(level: level),
                    orderDemand: grossDemand(level: level),
                    dailyTaskDemand: dailyTaskDemand(level: level),
                    recirculation: recirculation(level: level,
                                                 deepestTier: assumedDeepestTier(level: level)))
    }

    // MARK: How much did D12 overstate order demand? (a bound, not a correction)

    /// Deterministic generator so the bound below is reproducible run to run.
    struct SplitMix64: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    /// Upper bound on the share of order kibble that D12 let the player skip,
    /// as a fraction of what `grossDemand` charges. **Printed for information;
    /// never applied to the ratio** (an overlap fraction fed into the ratio would
    /// be tuning it to taste, which this model's header forbids).
    ///
    /// Under D12 a produced item credits *every* open order that wants it, and
    /// building a tier-T item passes through lower tiers of the same chain on
    /// the way, so those lower tiers credit open orders too. The most favourable
    /// case for the player is therefore: of all open lines on one chain, only
    /// the costliest one (`2^tier × count`) has to be built, and every other
    /// line on that chain is paid for as a by-product. Under D14 each line must
    /// be a separate held item and is consumed on delivery, so nothing is free.
    ///
    /// Method: sample the set of orders open at once (the persistent slots plus
    /// the urgent order) with the real band tables, line counts and count roll,
    /// assign each line a chain uniformly from `families` unlocked chains, and
    /// compare the sum of line costs (D14) with the sum over chains of the
    /// costliest line (D12, best case). `families` is an input, not derived,
    /// because which chains a player has unlocked is the material faucet's
    /// question and this model does not invent a curve for it.
    ///
    /// What this cannot express: it looks at one snapshot of the open orders.
    /// Under D12 a *leftover* item kept on the board after its order paid out
    /// could also feed a later order, a stock effect across time that a
    /// per-snapshot flow model does not see. The true D12 saving could
    /// therefore be somewhat larger than this bound in a long play session;
    /// it cannot be smaller than zero and is not a number to tune against.
    static func d12SharedCreditBound(level: Int, families: Int,
                                     trials: Int = 20_000,
                                     seed: UInt64 = 0x5041_5753) -> Double {
        let maxTier = orderTierCap(level: level)
        var rng = SplitMix64(state: seed &+ UInt64(level) &* 7919 &+ UInt64(families))
        let persistentSlots = slotCount(level: level)
        let chains = max(1, families)

        func rollTier(_ difficulty: OrderDifficulty, _ rng: inout SplitMix64) -> Int {
            var roll = Double.random(in: 0..<1, using: &rng)
            let bands = orderDifficultyBands[difficulty] ?? []
            for band in bands {
                roll -= band.probability
                if roll < 0 { return min(band.tiers.randomElement(using: &rng) ?? 0, maxTier) }
            }
            return min(bands.last?.tiers.last ?? 0, maxTier)
        }

        var paidD14 = 0.0
        var paidD12Best = 0.0
        for _ in 0..<trials {
            var difficulties = (0..<persistentSlots).map { AdoptionBoard.difficulty(forSlot: $0) }
            difficulties.append(.medium)   // the urgent order
            var costliestPerChain: [Int: Double] = [:]
            for difficulty in difficulties {
                let lineCount = Int.random(in: orderBasketLineCounts[difficulty] ?? 1...1, using: &rng)
                let tiers = (0..<lineCount).map { index in
                    rollTier(index == 0 ? difficulty : difficulty.basketFillerDifficulty, &rng)
                }
                var counts = [Int](repeating: 1, count: lineCount)
                if lineCount == 1, tiers[0] <= 5, Int.random(in: 1...3, using: &rng) == 1 { counts[0] = 2 }
                for (tier, count) in zip(tiers, counts) {
                    let cost = Double(spawnCost(forTier: tier) * count)
                    paidD14 += cost
                    let chain = Int.random(in: 0..<chains, using: &rng)
                    costliestPerChain[chain] = max(costliestPerChain[chain] ?? 0, cost)
                }
            }
            paidD12Best += costliestPerChain.values.reduce(0, +)
        }
        guard paidD14 > 0 else { return 0 }
        return 1 - paidD12Best / paidD14
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
        let maxTier = orderTierCap(level: level)
        var expectedTier = 0.0
        for (bandProbability, tiers) in orderDifficultyBands[.hard] ?? [] {
            let each = bandProbability / Double(tiers.count)
            for t in tiers { expectedTier += each * Double(min(t, maxTier)) }
        }
        return expectedTier + 1.0
    }

    /// Expected items (= board cells) one order of `difficulty` asks for at
    /// `level`: the basket's line count, plus the single-line "bring me two of
    /// these" roll (count 2 one time in three, tiers 0...5 only), which is the
    /// one place an order line carries more than one item.
    ///
    /// Counts items, not kibble, for the same reason `dailyTaskHoldCells` does.
    /// Unlike a daily task there is no duplicate-collapse step to reason about:
    /// two lines of one chain and tier on an order stay two lines, still two
    /// items.
    static func expectedOrderItems(difficulty: OrderDifficulty, level: Int) -> Double {
        let sizes = Array(orderBasketLineCounts[difficulty] ?? 1...1)
        guard !sizes.isEmpty else { return 0 }
        let maxTier = orderTierCap(level: level)
        // Probability that a single-line order's one line is eligible for the roll.
        var pEligible = 0.0
        for (bandProbability, tiers) in orderDifficultyBands[difficulty] ?? [] {
            let each = bandProbability / Double(tiers.count)
            for t in tiers where min(t, maxTier) <= 5 { pEligible += each }
        }
        let singleLineItems = 1.0 + pEligible / 3.0
        return sizes.reduce(0.0) { $0 + ($1 == 1 ? singleLineItems : Double($1)) } / Double(sizes.count)
    }

    /// Cells the open orders ask the player to hold at once, under D14
    /// (Spec_HeldItemOrders.md §6 point 5): the persistent slots plus the urgent
    /// order, if the player is working toward all of them.
    ///
    /// Same convention as `dailyTaskHoldCells`: it counts what the cards *want*
    /// standing on the board simultaneously, not what a player has built so far,
    /// so it is an upper bound on the cells held at any one instant. The urgent
    /// order is counted as always present; after a miss it is absent for the
    /// cooldown, so this slightly overstates.
    ///
    /// Under D12 this number was effectively zero: an order took nothing from
    /// the board, and an item's job was done the moment it was made.
    static func openOrderHoldCells(level: Int) -> Double {
        var total = 0.0
        for slotIndex in 0..<slotCount(level: level) {
            total += expectedOrderItems(difficulty: AdoptionBoard.difficulty(forSlot: slotIndex),
                                        level: level)
        }
        total += expectedOrderItems(difficulty: .medium, level: level)   // the urgent order
        return total
    }

    // ============================================================
    // MARK: - MATERIAL FAUCET
    // ============================================================
    //
    // The open item `Spec_DailyHandInTasks.md` §5b left: the congestion model
    // found a spawner-choke corner but could not say whether it is *reachable*,
    // because family spawners come from map areas and map areas are bought with
    // **materials** — a faucet nothing modelled.
    //
    // Materials are the third currency, alongside kibble and coins, and the only
    // one that gates content rather than pace. `InventoryStore.absorbMaterialItems`
    // auto-cascades the accumulator (two of tier N become one of tier N+1), so
    // the whole economy collapses to a single scalar: **tier-0 equivalents**,
    // where one tier-N material is worth 2^N of them. Everything below is
    // denominated that way.

    /// Tier-0 equivalents one material at `tier` is worth. Materials cascade
    /// 2-for-1 without limit, so this is exact rather than an approximation.
    /// Coincides numerically with `spawnCost(forTier:)` — both are 2^tier — but
    /// they are different quantities and are kept separate deliberately.
    static func materialUnits(tier: Int) -> Int { 1 << max(0, tier) }

    /// Expected tier-0 equivalents in one item rolled by `weightedToolboxTier`,
    /// whose weights run `maxTier + 1 - tier` (so tier 0 is likeliest).
    static func expectedToolboxItemUnits(level: Int, chestTier: Int = 0) -> Double {
        let maxTier = min(5, toolboxMaxTier(forPlayerLevel: level) + chestTier)
        let weights = (0...maxTier).map { Double(maxTier + 1 - $0) }
        let total   = weights.reduce(0, +)
        guard total > 0 else { return 0 }
        return zip(0...maxTier, weights).reduce(0.0) { running, pair in
            running + pair.1 / total * Double(materialUnits(tier: pair.0))
        }
    }

    /// Expected tier-0 equivalents in one whole toolbox.
    ///
    /// Mirrors `buildToolboxLot`: three chains, `Int.random(in: 1...3) + chestTier`
    /// items each (expected 2 at chest tier 0), every item rolled independently.
    static func expectedToolboxUnits(level: Int, chestTier: Int = 0) -> Double {
        let itemsPerChain = 2.0 + Double(chestTier)
        return 3.0 * itemsPerChain * expectedToolboxItemUnits(level: level, chestTier: chestTier)
    }

    /// Toolboxes dropped per quest claim, from `claimQuest`'s difficulty switch
    /// (easy 1-in-4, medium 1, hard 2, legendary 3) weighted by `generateQuest`'s
    /// actual d20 roll — 45/30/20/5 — with the same level capping it applies.
    static func expectedToolboxesPerQuestClaim(level: Int) -> Double {
        var weights: [QuestDifficulty: Double] = [:]
        for (raw, p) in [(QuestDifficulty.easy, 0.45), (.medium, 0.30),
                         (.hard, 0.20), (.legendary, 0.05)] {
            let capped: QuestDifficulty
            switch level {
            case 1...2: capped = .easy
            case 3...4: capped = (raw == .hard || raw == .legendary) ? .medium : raw
            case 5...7: capped = (raw == .legendary) ? .hard : raw
            default:    capped = raw
            }
            weights[capped, default: 0] += p
        }
        let perDifficulty: [QuestDifficulty: Double] = [
            .easy: 0.25, .medium: 1, .hard: 2, .legendary: 3,
        ]
        return weights.reduce(0.0) { $0 + $1.value * (perDifficulty[$1.key] ?? 0) }
    }

    /// Hard-slot orders completed per day. `orderSlotDifficultyPattern` is
    /// easy/medium/medium/hard, so one slot in four is hard; the urgent order is
    /// always `.medium` and pays no material.
    static func hardOrdersPerDay(level: Int) -> Double {
        let hardSlots = (0..<slotCount(level: level))
            .filter { AdoptionBoard.difficulty(forSlot: $0) == .hard }.count
        return Double(hardSlots) * Double(effectiveCyclesPerDay)
    }

    /// Tier-0 material equivalents earned per day.
    ///
    /// Two faucets, both real code paths: quest-claim toolboxes (`claimQuest`)
    /// and the hard order slot's guaranteed material (`generateOrder`, Task 5.3
    /// — "a dedicated bottleneck beyond quest-driven Toolboxes"). The ambassador
    /// -merge toolbox is deliberately **not** counted: it fires on a top-tier
    /// merge, which is days of work, and counting it would flatter the faucet.
    static func materialUnitsPerDay(level: Int) -> Double {
        let fromToolboxes = questClaimsPerDay
                          * expectedToolboxesPerQuestClaim(level: level)
                          * expectedToolboxUnits(level: level)
        let orderMaterialTier = max(0, toolboxMaxTier(forPlayerLevel: level) - materialRewardTierOffset)
        let fromOrders = hardOrdersPerDay(level: level)
                       * Double(materialRewardCount)
                       * Double(materialUnits(tier: orderMaterialTier))
        return fromToolboxes + fromOrders
    }

    /// Tier-0 equivalents to complete one area — the cost that grants its family
    /// spawner. Upgrades are excluded: they cost coins and materials of their
    /// own but grant no spawner, so they do not gate `familiesOwned`.
    static func areaMaterialCost(_ area: SanctuaryArea) -> Int {
        area.costs.reduce(0) { $0 + materialUnits(tier: $1.tier) * $1.count }
    }

    /// Running total to complete the first N areas, in order — `requiresPrevious`
    /// makes the map strictly sequential, so a prefix sum is the real cost.
    static var cumulativeAreaMaterialCost: [Int] {
        var running = 0
        return sanctuaryAreas.map { running += areaMaterialCost($0); return running }
    }

    /// Family spawners owned after `days` of play at `level`'s material income.
    ///
    /// This is what closes §5b's open item: `familiesOwned` stops being a free
    /// input and becomes a derived quantity. +1 for the Canines spawner every
    /// save starts with.
    static func familiesOwned(level: Int, days: Double) -> Int {
        let banked = materialUnitsPerDay(level: level) * days
        let areasDone = cumulativeAreaMaterialCost.filter { Double($0) <= banked }.count
        // The tutorial area grants no spawner; every later one does.
        return min(totalFamilySpawners, 1 + max(0, areasDone - 1))
    }

    /// Days of play at `level`'s income to own every family.
    static func daysToAllFamilies(level: Int) -> Double {
        let total = cumulativeAreaMaterialCost.last ?? 0
        let rate  = materialUnitsPerDay(level: level)
        return rate <= 0 ? .infinity : Double(total) / rate
    }

    struct CongestionRow {
        let level: Int
        let familiesOwned: Int
        let capacity: Int
        let spawners: Int
        let supplyProducers: Int
        let hold: Double
        let staging: Double
        /// Cells held by open adoption orders. Zero in the D12 model (orders took
        /// nothing from the board); set by `congestionRowHeldItem` for D14.
        var orderHold: Double = 0

        /// Cells left to merge in once everything with a claim on the board has
        /// taken its share.
        var workingCells: Double {
            Double(capacity - spawners - supplyProducers) - hold - orderHold - staging
        }
        var occupancy: Double {
            capacity == 0 ? 1 : (Double(spawners + supplyProducers) + hold + orderHold + staging) / Double(capacity)
        }

        var description: String {
            let orders = orderHold > 0 ? String(format: "  orders %4.1f", orderHold) : ""
            return String(format: "L%-3d fam %2d  cap %2d  spawners %2d  supply %d  hold %4.1f%@  staging %4.1f  |  working %5.1f  occupancy %3.0f%%",
                          level, familiesOwned, capacity, spawners, supplyProducers,
                          hold, orders, staging, workingCells, occupancy * 100)
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

    /// The D14 board: the D12 row plus the cells the open orders now hold.
    ///
    /// Staging is left as the D12 row has it (one deep build at a time, taken
    /// over the hard band). The hard order and the hard daily task both draw
    /// from that band, but a player stages one deep build at once, so a second
    /// staging term would double-count the same working space.
    static func congestionRowHeldItem(level: Int, familiesOwned: Int) -> CongestionRow {
        var row = congestionRow(level: level, familiesOwned: familiesOwned)
        row.orderHold = openOrderHoldCells(level: level)
        return row
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

    /// `worstCaseCongestion`, on the D14 board.
    static func worstCaseCongestionHeldItem() -> CongestionRow {
        var worst = congestionRowHeldItem(level: 1, familiesOwned: 1)
        for level in reportLevels {
            for families in 1...totalFamilySpawners {
                let row = congestionRowHeldItem(level: level, familiesOwned: families)
                if row.workingCells < worst.workingCells { worst = row }
            }
        }
        return worst
    }

    // MARK: Report

    /// Deepest tier a player at `level` is assumed to have reached. Recirculation
    /// scales off this, so the model needs a value per level band.
    static func assumedDeepestTier(level: Int) -> Int {
        orderTierCap(level: level)
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

    /// Kibble per day from the card-album set ramp (`albumSetRewardRamp`),
    /// amortised over `amortisationDays`. Deliberately NOT part of
    /// `dailySupply`, which is pinned to measured reference values
    /// (`testSupplyMatchesTheMeasuredReference`). Before the Pass bonus.
    ///
    /// Ramp kibble only. The whole-collection grand prize
    /// (Spec_AlbumGrandPrize.md §11 Task 2) is not built yet and is excluded;
    /// Task 2 adds its kibble here.
    static var albumKibblePerDay: Double {
        Double(albumSetRewardRamp.reduce(0) { $0 + $1.kibble }) / amortisationDays
    }

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
        let albums = Double(albumSetRewardRamp.reduce(0) { $0 + $1.coins }) / amortisationDays
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

        out += "\nmaterial faucet — tier-0 equivalents; areas cost "
        out += "\(cumulativeAreaMaterialCost.last ?? 0) to complete all \(sanctuaryAreas.count)\n"
        out += "(one tier-5 material = 32 units; the accumulator cascades 2-for-1 without limit)\n\n"
        for level in reportLevels {
            let rate = materialUnitsPerDay(level: level)
            out += String(format: "L%-3d  units/day %7.0f  |  families after 7d %2d · 30d %2d · 60d %2d  |  all 15 in %6.1f days\n",
                          level, rate,
                          familiesOwned(level: level, days: 7),
                          familiesOwned(level: level, days: 30),
                          familiesOwned(level: level, days: 60),
                          daysToAllFamilies(level: level))
        }

        out += "\nis the spawner-choke corner reachable? (families derived, not swept)\n\n"
        for level in reportLevels {
            for days in [30.0, 60.0] {
                let fam = familiesOwned(level: level, days: days)
                out += String(format: "  %3.0fd  ", days)
                out += congestionRow(level: level, familiesOwned: fam).description + "\n"
            }
        }
        return out
    }

    /// Prints `report()`. Call from a debug menu or a breakpoint.
    static func printReport() { print(report()) }

    // MARK: Target bands (the ones `testDemandSupplyRatioMatchesTheTargetCurve` pins)

    /// Whether a ratio at `level` sits inside the target band for that level.
    /// Mirrors `EconomyTests.testDemandSupplyRatioMatchesTheTargetCurve`; keep in step.
    /// Levels the test does not pin (for example L15, L25, L45) return `nil`.
    static func targetBandAllows(ratio: Double, level: Int) -> Bool? {
        switch level {
        case 1, 5, 10, 20, 30: return ratio < 0.70
        case 35, 40:           return ratio >= 0.60 && ratio < 1.00
        case 50:               return ratio > 1.00
        case 55, 60:           return ratio > 1.00 && ratio < 1.35
        default:               return nil
        }
    }

    /// The levels the target-band test pins, in order.
    static let bandLevels = [1, 5, 10, 20, 30, 35, 40, 50, 55, 60]

    /// Levels at which the D14 ratio breaks its band.
    static func heldItemBandBreaks() -> [Int] {
        bandLevels.filter { targetBandAllows(ratio: heldItemRow(level: $0).ratio, level: $0) == false }
    }

    // MARK: Proposed levers (costed here, NOT applied)

    static let proposedLevers: [(name: String, levers: Levers)] = [
        ("A: orderCyclesPerDay 8 -> 7 (model assumption, no game change)",
         Levers(cyclesPerDay: 7)),
        ("B: order tier cap L31-40 9 -> 8, L51+ 11 -> 10",
         Levers(tierCap: { l in
             if (31...40).contains(l) { return 8 }
             if l >= 51 { return 10 }
             return maxAchievableOrderTier(forPlayerLevel: l)
         })),
        ("C: B, and L21-30 6 -> 5",
         Levers(tierCap: { l in
             if (21...30).contains(l) { return 5 }
             if (31...40).contains(l) { return 8 }
             if l >= 51 { return 10 }
             return maxAchievableOrderTier(forPlayerLevel: l)
         })),
    ]

    /// Whether the D14 ratio never falls as level rises across `reportLevels`
    /// (the property `EconomyTests.testRatioIsMonotonicallyNonDecreasing` pins for D12).
    static func heldItemRatioIsMonotone() -> Bool {
        let ratios = reportLevels.map { heldItemRow(level: $0).ratio }
        return zip(ratios, ratios.dropFirst()).allSatisfy { $0 <= $1 + 0.001 }
    }

    static func leverReport() -> String {
        var out = "PROPOSED LEVERS (D14 model; costed in the model, NOT applied to the game)\n"
        out += "ratio = orders + daily tasks, net of recirculation. Coin days are the Phase 2c projection under the same lever.\n\n"
        out += "ratios at " + bandLevels.map { "L\($0)" }.joined(separator: " ") + "\n"
        func line(_ name: String) -> String {
            let ratios = bandLevels.map { String(format: "%4.2f", heldItemRow(level: $0).ratio) }.joined(separator: " ")
            let breaks = heldItemBandBreaks()
            let verdict = (breaks.isEmpty ? "all bands hold" : "breaks " + breaks.map { "L\($0)" }.joined(separator: ","))
                        + (heldItemRatioIsMonotone() ? ", monotone" : ", NOT monotone")
            return name + "\n    " + ratios + "   | " + verdict
                + String(format: "   | coin days never-sell %.1f / sell-20%% %.1f\n",
                         daysToFullMap(sells: false), daysToFullMap(sells: true))
        }
        out += line("current tuning (D14 model, no lever)")
        for (name, levers) in proposedLevers {
            out += withLevers(levers) { line(name) }
        }
        out += "\nboard under each lever (reachable board: families after 60 days), D14 rows\n"
        for (name, levers) in [("current tuning", Levers())] + proposedLevers {
            out += withLevers(levers) {
                var l = "  \(name)\n"
                for level in [20, 30, 35, 55] {
                    l += "    " + congestionRowHeldItem(level: level, familiesOwned: familiesOwned(level: level, days: 60)).description + "\n"
                }
                return l
            }
        }
        return out
    }

    // MARK: Report — D12 against D14 (task 1.2)

    /// Before/after for the held-item rule: the D12 model (orders only) against
    /// the D14 model (orders plus daily tasks), plus congestion with and without
    /// the open orders' held cells. Printed, not asserted; the assertions live in
    /// `EconomyTests`.
    static func heldItemReport() -> String {
        var out = "PawSanctuary economy model — D12 (before) vs D14 held-item delivery (after)\n"
        out += "before = orders only (D12: orders credit on production, take nothing)\n"
        out += "after  = orders + the three daily hand-in tasks (D14: delivery consumes the items)\n"
        out += "bands: <0.70 to L30 · 0.60-1.00 L35/40 · >1.00 at L50 · 1.00-1.35 at L55/60\n\n"

        out += "KIBBLE DEMAND ÷ SUPPLY\n"
        out += "level supply | before: demand  recirc    net  ratio | dailies | after: demand    net  ratio | delta\n"
        for level in reportLevels {
            let before = row(level: level)
            let after  = heldItemRow(level: level)
            out += String(format: "L%-3d  %5d  |        %6.0f  %6.0f  %6.0f  %5.2f | %7.0f |       %6.0f  %6.0f  %5.2f | %+5.2f\n",
                          level, before.supply, before.grossDemand, before.recirculation,
                          before.netDemand, before.ratio,
                          after.dailyTaskDemand, after.grossDemand, after.netDemand, after.ratio,
                          after.ratio - before.ratio)
        }

        out += "\nTARGET BANDS (the levels EconomyTests pins), ratio to 3 places\n"
        for level in bandLevels {
            let before = row(level: level).ratio
            let after  = heldItemRow(level: level).ratio
            func verdict(_ r: Double) -> String {
                (targetBandAllows(ratio: r, level: level) ?? true) ? "in band" : "BREAKS BAND"
            }
            out += String(format: "L%-3d  before %.3f (%@)   after %.3f (%@)\n", level,
                          before, verdict(before) as NSString, after, verdict(after) as NSString)
        }

        out += "\nHOW MUCH D12 OVERSTATED ORDER DEMAND (upper bound, best-case play, not applied to the ratio)\n"
        out += "share of order kibble that one produced item could pay for twice, by families unlocked\n"
        out += "level   1 family   4 families   15 families\n"
        for level in reportLevels {
            out += String(format: "L%-3d     %5.1f%%       %5.1f%%        %5.1f%%\n", level,
                          d12SharedCreditBound(level: level, families: 1) * 100,
                          d12SharedCreditBound(level: level, families: 4) * 100,
                          d12SharedCreditBound(level: level, families: 15) * 100)
        }

        out += "\nBOARD CONGESTION — cells spoken for (upper bound: every card worked toward at once)\n"
        out += String(format: "daily tasks hold %.1f cells; open orders hold %.1f cells at L1-12 and %.1f at L13+\n",
                      dailyTaskHoldCells(), openOrderHoldCells(level: 1), openOrderHoldCells(level: 13))
        out += "(each row: BEFORE = D12 board, AFTER = D14 board with open orders holding cells)\n\n"
        for level in reportLevels {
            for families in [1, totalFamilySpawners / 2, totalFamilySpawners] {
                out += "before " + congestionRow(level: level, familiesOwned: families).description + "\n"
                out += "after  " + congestionRowHeldItem(level: level, familiesOwned: families).description + "\n"
            }
        }
        out += "\nworst corner before: " + worstCaseCongestion().description + "\n"
        out += "worst corner after:  " + worstCaseCongestionHeldItem().description + "\n"

        out += "\nREACHABLE BOARD (families derived from the material faucet after 60 days)\n"
        for level in reportLevels {
            let fam = familiesOwned(level: level, days: 60)
            out += "before " + congestionRow(level: level, familiesOwned: fam).description + "\n"
            out += "after  " + congestionRowHeldItem(level: level, familiesOwned: fam).description + "\n"
        }
        return out
    }
}
