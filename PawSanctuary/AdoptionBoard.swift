//
//  AdoptionBoard.swift
//  PawSanctuary
//
//  Owns adoption order state and all order-generation / countdown logic.
//  Reward distribution (kibble, dog tags, XP, coins, card packs) is handled by
//  MergeBoardViewModel so AdoptionBoard stays free of cross-domain dependencies.
//

import SwiftUI
import Observation

@Observable
@MainActor
class AdoptionBoard {

    // MARK: Stored state

    /// Persistent — no timer. Sits until fulfilled (Phase 5, Task 5.2).
    var adoptionOrders: [AdoptionOrder] = []

    /// The one order that carries real urgency. `nil` while waiting out
    /// `urgentOrderCooldownRemaining` after a miss — that empty gap is the
    /// consequence; nothing about it silently regenerates.
    var urgentOrder: AdoptionOrder? = nil
    var urgentOrderTimeRemaining: Double = 0
    var urgentOrderCooldownRemaining: Double = 0

    // MARK: Setup

    func setupOrders(count: Int, unlockedChainIDs: [ChainID], playerLevel: Int) {
        adoptionOrders = (0..<max(orderSlotDifficultyPattern.count, count)).map { i in
            generateOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel, forSlot: i)
        }
    }

    /// Ensures the orders array matches the current slot count after an upgrade.
    func syncOrderSlots(count: Int, unlockedChainIDs: [ChainID], playerLevel: Int) {
        while adoptionOrders.count < count {
            adoptionOrders.append(generateOrder(unlockedChainIDs: unlockedChainIDs,
                                                playerLevel: playerLevel,
                                                forSlot: adoptionOrders.count))
        }
    }

    // MARK: Generation

    /// The fixed difficulty for a given slot index (Task 5.1) — cycles
    /// `orderSlotDifficultyPattern` so slots added by Sanctuary Map upgrades
    /// beyond the base 4 keep following the same easy/medium/medium/hard spread.
    static func difficulty(forSlot index: Int) -> OrderDifficulty {
        orderSlotDifficultyPattern[index % orderSlotDifficultyPattern.count]
    }

    /// Draws an uncapped tier from `orderDifficultyBands[difficulty]`.
    static func rollTier(difficulty: OrderDifficulty) -> Int {
        let bands = orderDifficultyBands[difficulty] ?? []
        var roll = Double.random(in: 0..<1)
        for band in bands {
            roll -= band.probability
            if roll < 0 { return band.tiers.randomElement() ?? 0 }
        }
        return bands.last?.tiers.last ?? 0
    }

    func generateOrder(unlockedChainIDs: [ChainID], playerLevel: Int, forSlot index: Int) -> AdoptionOrder {
        let animalChainIDs = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .animal
        }
        let familyIndex = Int.random(in: 0..<adoptionFamilies.count)
        let chainID     = animalChainIDs.randomElement() ?? ContentRegistry.animalChainID(.dog)

        // Tier weighting comes from the shared `orderDifficultyBands` table so the
        // economy model in EconomySimulation can never drift from what is
        // actually generated here. All tiers are capped by maxAchievableOrderTier.
        let difficulty = Self.difficulty(forSlot: index)
        let rawTier = Self.rollTier(difficulty: difficulty)
        let maxTier = maxAchievableOrderTier(forPlayerLevel: playerLevel)
        let tier    = min(rawTier, maxTier)
        let count   = (tier <= 5 && Int.random(in: 1...3) == 1) ? 2 : 1

        let tags = max(1, (tier + 1) / 2) + Int.random(in: 0...2)
        // Task 2c: coins scale with what the order actually costs to fulfil, so a
        // deep order is worth the days of kibble it takes to build. The previous
        // `(tier + 1) * 2` paid 9–25 coins against a map costing 291,900.
        let orderCoins = orderCoinPayout(
            tier: tier,
            count: count,
            spreadFactor: Double.random(in: (1 - orderCoinSpread)...(1 + orderCoinSpread))
        )
        let packReward: CardPackType? = tags >= 7 ? .star3
                                      : tags >= 5 ? .star2
                                      : tags >= 3 ? .star1
                                      : nil

        var rewards: [OrderReward] = [
            OrderReward(kind: .dogTags, amount: tags),
            OrderReward(kind: .coins,   amount: orderCoins)
        ]
        if let pack = packReward {
            rewards.append(OrderReward(kind: .cardPack, amount: 1, payloadID: pack.rawValue))
        }

        // Recirculation (Task 2.3a): one order in `orderBoardItemFrequency` pays a
        // board item as well as currency. The item is always well below what the
        // order asked for, so fulfilling an order never returns more than it cost —
        // but it is what makes the deepest tiers reachable at all, since building a
        // Stage-15 from taps alone costs ~22 days of total income.
        if Int.random(in: 0..<orderBoardItemFrequency) == 0 {
            let rewardChainID = animalChainIDs.randomElement() ?? chainID
            let rewardMaxTier = ContentRegistry.shared.chain(rewardChainID)?.maxTier ?? 0
            let rewardTier = min(max(0, tier - orderRewardTierOffset), rewardMaxTier)
            rewards.append(OrderReward(kind: .boardItem, amount: 1,
                                       payloadID: rewardChainID, payloadTier: rewardTier))
        }

        // Task 5.3: the hard slot always pays a material too, so the Sanctuary
        // Map economy has a dedicated bottleneck beyond quest-driven Toolboxes.
        if difficulty == .hard {
            let materialChainIDs = [ContentRegistry.woodChainID, ContentRegistry.metalChainID,
                                    ContentRegistry.cementChainID]
            let materialChainID = materialChainIDs.randomElement() ?? ContentRegistry.woodChainID
            let materialTier = max(0, toolboxMaxTier(forPlayerLevel: playerLevel) - materialRewardTierOffset)
            rewards.append(OrderReward(kind: .material, amount: materialRewardCount,
                                       payloadID: materialChainID, payloadTier: materialTier))
        }

        rewards.append(contentsOf: OrderRewardRegistry.riders(playerLevel: playerLevel))

        return AdoptionOrder(
            familyIndex: familyIndex,
            wantedChainID: chainID,
            wantedTier: tier,
            wantedCount: count,
            rewards: rewards
        )
    }

    // MARK: Urgent order (Task 5.2)

    /// Rolls a `.medium`-difficulty order (slot 1 of the fixed spread — an
    /// achievable-in-a-session target, not the rare top-of-chain ask) and scales
    /// its guaranteed currency rewards up, so the urgent order both carries the
    /// stakes and is worth rushing for.
    private func generateUrgentOrder(unlockedChainIDs: [ChainID], playerLevel: Int) -> AdoptionOrder {
        var order = generateOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel, forSlot: 1)
        order.rewards = order.rewards.map { reward in
            guard reward.kind == .dogTags || reward.kind == .coins else { return reward }
            var scaled = reward
            scaled.amount = Int((Double(reward.amount) * urgentOrderRewardMultiplier).rounded())
            return scaled
        }
        return order
    }

    /// Spawns a fresh urgent order if none is active and no cooldown is pending.
    /// Covers a brand-new game and an existing save loading for the first time
    /// after this feature shipped (both start with `urgentOrder == nil` and
    /// `urgentOrderCooldownRemaining == 0`).
    func ensureUrgentOrder(unlockedChainIDs: [ChainID], playerLevel: Int) {
        guard urgentOrder == nil, urgentOrderCooldownRemaining <= 0 else { return }
        urgentOrder = generateUrgentOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel)
        urgentOrderTimeRemaining = urgentOrderDuration
    }

    /// Called every second by MergeBoardViewModel's timer. Returns `true` when
    /// the urgent order's identity just changed (missed, or respawned after
    /// cooldown) so the caller knows to reschedule its expiry notification.
    @discardableResult
    func tickUrgentOrder(unlockedChainIDs: [ChainID], playerLevel: Int) -> Bool {
        if let order = urgentOrder {
            guard !order.isComplete else { return false }
            if urgentOrderTimeRemaining > 0 {
                urgentOrderTimeRemaining -= 1
                return false
            }
            // Missed: no partial credit, rewards forfeited, real cooldown before
            // a new one appears — this is the stakes the persistent slots lack.
            urgentOrder = nil
            urgentOrderCooldownRemaining = urgentOrderRespawnCooldown
            return true
        } else if urgentOrderCooldownRemaining > 0 {
            urgentOrderCooldownRemaining -= 1
            if urgentOrderCooldownRemaining <= 0 {
                ensureUrgentOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel)
                return true
            }
        }
        return false
    }

    // MARK: Merge updates

    /// Advances order progress for a matching merge. Returns indices of orders that
    /// just became complete so the caller can distribute rewards.
    func updateAfterMerge(chainID: ChainID, tier: Int) -> [Int] {
        var completedIndices: [Int] = []
        for i in adoptionOrders.indices {
            guard !adoptionOrders[i].isClaimed, !adoptionOrders[i].isComplete else { continue }
            if creditLine(in: &adoptionOrders[i], chainID: chainID, tier: tier),
               adoptionOrders[i].isComplete {
                completedIndices.append(i)
            }
        }
        return completedIndices
    }

    /// Advances the urgent order's progress for a matching merge. Returns `true`
    /// if it just became complete.
    func updateUrgentOrderAfterMerge(chainID: ChainID, tier: Int) -> Bool {
        guard var order = urgentOrder,
              !order.isComplete, urgentOrderTimeRemaining > 0,
              creditLine(in: &order, chainID: chainID, tier: tier) else { return false }
        urgentOrder = order
        return order.isComplete
    }

    /// Credits one delivered item to the first unfilled line matching
    /// `chainID`/`tier`, returning whether anything was credited.
    ///
    /// Only ever advances **one** line per delivered item: a basket that happens
    /// to list the same item twice (two lines of one Pup rather than one line of
    /// two) must still consume two Pups, not be filled by one.
    private func creditLine(in order: inout AdoptionOrder, chainID: ChainID, tier: Int) -> Bool {
        guard let lineIndex = order.lines.firstIndex(where: {
            $0.chainID == chainID && $0.tier == tier && !$0.isComplete
        }) else { return false }
        order.lines[lineIndex].fulfilled += 1
        return true
    }

    /// Marks an order as claimed. MergeBoardViewModel queues the replacement.
    func markClaimed(at index: Int) {
        guard adoptionOrders.indices.contains(index) else { return }
        adoptionOrders[index].isClaimed = true
    }

    /// Replaces the order at `index` with a fresh one (called after the claim delay).
    func replaceOrder(at index: Int, unlockedChainIDs: [ChainID], playerLevel: Int) {
        guard adoptionOrders.indices.contains(index) else { return }
        adoptionOrders[index] = generateOrder(unlockedChainIDs: unlockedChainIDs,
                                              playerLevel: playerLevel, forSlot: index)
    }

    // MARK: Skip

    /// Returns true if the skip was allowed (caller deducts kibble on true).
    func canSkip(at index: Int, kibbleCost: Int, currentKibble: Int) -> Bool {
        adoptionOrders.indices.contains(index)
            && !adoptionOrders[index].isClaimed
            && currentKibble >= kibbleCost
    }

    func skipOrder(at index: Int, unlockedChainIDs: [ChainID], playerLevel: Int) {
        guard adoptionOrders.indices.contains(index),
              !adoptionOrders[index].isClaimed else { return }
        adoptionOrders[index] = generateOrder(unlockedChainIDs: unlockedChainIDs,
                                              playerLevel: playerLevel, forSlot: index)
    }

    // MARK: Offline progress

    /// Persistent orders need no offline handling — they have no timer. Only the
    /// urgent order's timer/cooldown advances, potentially cycling through
    /// several miss-then-respawn rounds if the player was away a long time.
    /// Bounded to guard against a runaway loop; each round consumes at least
    /// `min(urgentOrderDuration, urgentOrderRespawnCooldown)` seconds, so a
    /// month-long gap is only a few thousand iterations.
    func applyOfflineProgress(elapsed: TimeInterval, unlockedChainIDs: [ChainID],
                              playerLevel: Int) {
        var remaining = elapsed
        var iterations = 0
        while remaining > 0 && iterations < 10_000 {
            iterations += 1
            if let order = urgentOrder {
                guard !order.isComplete else { return }   // waiting to be claimed
                if urgentOrderTimeRemaining > remaining {
                    urgentOrderTimeRemaining -= remaining
                    return
                }
                remaining -= urgentOrderTimeRemaining
                urgentOrder = nil
                urgentOrderCooldownRemaining = urgentOrderRespawnCooldown
            } else if urgentOrderCooldownRemaining > 0 {
                if urgentOrderCooldownRemaining > remaining {
                    urgentOrderCooldownRemaining -= remaining
                    return
                }
                remaining -= urgentOrderCooldownRemaining
                urgentOrderCooldownRemaining = 0
                ensureUrgentOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel)
            } else {
                ensureUrgentOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel)
            }
        }
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        adoptionOrders = s.adoptionOrders
        urgentOrder = s.urgentOrder
        urgentOrderTimeRemaining = s.urgentOrderTimeRemaining
        urgentOrderCooldownRemaining = s.urgentOrderCooldownRemaining
    }

    func capture(into s: inout GameState) {
        s.adoptionOrders = adoptionOrders
        s.urgentOrder = urgentOrder
        s.urgentOrderTimeRemaining = urgentOrderTimeRemaining
        s.urgentOrderCooldownRemaining = urgentOrderCooldownRemaining
    }
}
