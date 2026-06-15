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
        adoptionOrders = (0..<max(2, count)).map { _ in
            generateOrder(unlockedChainIDs: unlockedChainIDs, playerLevel: playerLevel)
        }
    }

    /// Ensures the orders array matches the current slot count after an upgrade.
    func syncOrderSlots(count: Int, unlockedChainIDs: [ChainID], playerLevel: Int) {
        while adoptionOrders.count < count {
            adoptionOrders.append(generateOrder(unlockedChainIDs: unlockedChainIDs,
                                                playerLevel: playerLevel))
        }
    }

    // MARK: Generation

    func generateOrder(unlockedChainIDs: [ChainID], playerLevel: Int) -> AdoptionOrder {
        let animalChainIDs = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .animal
        }
        let familyIndex = Int.random(in: 0..<adoptionFamilies.count)
        let chainID     = animalChainIDs.randomElement() ?? ContentRegistry.animalChainID(.dog)

        let roll = Int.random(in: 1...10)
        let rawStage: RescueStage
        switch roll {
        case 1...2: rawStage = [.rescued, .groomed].randomElement()!
        case 3...4: rawStage = [.vaccinated, .trained].randomElement()!
        case 5...6: rawStage = [.foster, .adopted].randomElement()!
        case 7...8: rawStage = .bondedPair
        case 9:     rawStage = .communityFav
        default:    rawStage = .ambassador
        }
        let maxTier = maxAchievableOrderTier(forPlayerLevel: playerLevel)
        let stage   = RescueStage(rawValue: min(rawStage.rawValue, maxTier + 1)) ?? rawStage
        let count   = (stage.rawValue <= 5 && Int.random(in: 1...3) == 1) ? 2 : 1

        let tags      = max(1, stage.rawValue / 2) + Int.random(in: 0...2)
        let orderCoins = stage.rawValue * 2 + Int.random(in: 0...2)
        let packReward: CardPackType? = tags >= 7 ? .star3
                                      : tags >= 5 ? .star2
                                      : tags >= 3 ? .star1
                                      : nil

        return AdoptionOrder(
            familyIndex: familyIndex,
            wantedChainID: chainID,
            wantedTier: stage.tierIndex,
            wantedCount: count,
            timeRemaining: adoptionOrderDuration,
            rewardDogTags: tags,
            rewardCoins: orderCoins,
            rewardCardPack: packReward
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
                                                  playerLevel: playerLevel)
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
                                              playerLevel: playerLevel)
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
                                              playerLevel: playerLevel)
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
                                                  playerLevel: playerLevel)
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
