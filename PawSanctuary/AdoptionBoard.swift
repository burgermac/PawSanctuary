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

    var adoptionOrders: [AdoptionOrder] = []

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

        rewards.append(contentsOf: OrderRewardRegistry.riders(playerLevel: playerLevel))

        return AdoptionOrder(
            familyIndex: familyIndex,
            wantedChainID: chainID,
            wantedTier: tier,
            wantedCount: count,
            timeRemaining: adoptionOrderDuration,
            rewards: rewards
        )
    }

    // MARK: Timer tick

    /// Called every second by MergeBoardViewModel's timer.
    func tick(unlockedChainIDs: [ChainID], playerLevel: Int) {
        for i in adoptionOrders.indices {
            guard !adoptionOrders[i].isClaimed else { continue }
            if adoptionOrders[i].isComplete { continue }
            if adoptionOrders[i].timeRemaining > 0 {
                adoptionOrders[i].timeRemaining -= 1
            } else {
                adoptionOrders[i] = generateOrder(unlockedChainIDs: unlockedChainIDs,
                                                  playerLevel: playerLevel, forSlot: i)
            }
        }
    }

    // MARK: Merge updates

    /// Advances order progress for a matching merge. Returns indices of orders that
    /// just became complete so the caller can distribute rewards.
    func updateAfterMerge(chainID: ChainID, tier: Int) -> [Int] {
        var completedIndices: [Int] = []
        for i in adoptionOrders.indices {
            guard !adoptionOrders[i].isClaimed,
                  !adoptionOrders[i].isComplete,
                  adoptionOrders[i].timeRemaining > 0 else { continue }
            if adoptionOrders[i].wantedChainID == chainID &&
               adoptionOrders[i].wantedTier    == tier {
                adoptionOrders[i].fulfilled += 1
                if adoptionOrders[i].isComplete {
                    completedIndices.append(i)
                }
            }
        }
        return completedIndices
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

    func applyOfflineProgress(elapsed: TimeInterval, unlockedChainIDs: [ChainID],
                              playerLevel: Int) {
        let secs = Int(elapsed)
        for i in adoptionOrders.indices {
            guard !adoptionOrders[i].isClaimed, !adoptionOrders[i].isComplete else { continue }
            adoptionOrders[i].timeRemaining -= elapsed
            if adoptionOrders[i].timeRemaining <= 0 {
                adoptionOrders[i] = generateOrder(unlockedChainIDs: unlockedChainIDs,
                                                  playerLevel: playerLevel, forSlot: i)
            }
        }
        _ = secs  // suppress unused warning
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        adoptionOrders = s.adoptionOrders
    }

    func capture(into s: inout GameState) {
        s.adoptionOrders = adoptionOrders
    }
}
