//
//  PlayerProgression.swift
//  PawSanctuary
//
//  Owns player level, XP, unlocked chains/producers, and spawn multiplier.
//  `grantXP(_:)` returns any LevelUpReward items earned so MergeBoardViewModel
//  can apply the cross-domain effects (board expansion, producer placement, etc.).
//

import SwiftUI
import Observation

@Observable
@MainActor
class PlayerProgression {

    // MARK: Stored state

    var playerLevel: Int = 1
    var playerXP: Int = 0
    var unlockedChainIDs: [ChainID] = startingChainIDs
    var unlockedProducerShopTiers: Set<ProducerLevel> = [.rescueCrate]
    var spawnMultiplier: Int = 1

    /// Deepest 0-based animal tier the player has ever produced by merging.
    /// Drives how recirculation scales with tenure (Phase 2): board item grants,
    /// chest payloads, and the Dog Tag store's stock all key off it.
    /// Only ever increases.
    var deepestUnlockedTier: Int = 0

    // Level-up banner state (drives the view directly through forwarding props)
    var showLevelUpBanner: Bool = false
    var levelUpBannerTitle: String = ""
    var levelUpBannerDetail: String = ""

    // MARK: Computed

    var unlockedAnimalChainIDs: [ChainID] {
        unlockedChainIDs.filter { ContentRegistry.shared.chain($0)?.category == .animal }
    }
    var unlockedSupplyChainIDs: [ChainID] {
        unlockedChainIDs.filter { ContentRegistry.shared.chain($0)?.category == .supply }
    }
    var unlockedMergeableChainIDs: [ChainID] {
        unlockedChainIDs.filter {
            let cat = ContentRegistry.shared.chain($0)?.category
            return cat == .animal || cat == .supply
        }
    }

    var unlockedMultipliers: [Int] {
        var result = [1]
        if playerLevel >= 5  { result.append(2) }
        if playerLevel >= 10 { result.append(4) }
        if playerLevel >= 20 { result.append(8) }
        return result
    }

    var xpToNextLevel: Int { xpRequired(forLevel: playerLevel) }
    var xpProgressFraction: Double { min(Double(playerXP) / Double(xpToNextLevel), 1.0) }

    var isInviteUnlocked: Bool { playerLevel >= 5 }
    var isLoyaltyClubUnlocked: Bool { playerLevel >= loyaltyClubLevelRequirement }

    // MARK: Spawn multiplier

    func cycleSpawnMultiplier() {
        let options = unlockedMultipliers
        let idx = options.firstIndex(of: spawnMultiplier) ?? 0
        spawnMultiplier = options[(idx + 1) % options.count]
    }

    // MARK: XP & levelling
    //
    // Returns any LevelUpReward items earned so the caller (MergeBoardViewModel)
    // can apply cross-domain effects such as expanding the board, placing a
    // producer reward, granting bonus kibble, and awarding card packs.

    func grantXP(_ amount: Int) -> [LevelUpReward] {
        guard amount > 0 else { return [] }
        playerXP += amount
        return collectLevelUps()
    }

    private func collectLevelUps() -> [LevelUpReward] {
        var rewards: [LevelUpReward] = []
        while playerXP >= xpToNextLevel {
            playerXP -= xpToNextLevel
            playerLevel += 1
            let reward = levelUpReward(for: playerLevel)
            applyProgressionUnlocks(reward)
            rewards.append(reward)
        }
        return rewards
    }

    /// Applies the unlocks that PlayerProgression owns directly (chains, producer tiers).
    /// Cross-domain effects (board row, producer tile, kibble) are left for the caller.
    private func applyProgressionUnlocks(_ reward: LevelUpReward) {
        if let s = reward.newSpecies {
            let id = ContentRegistry.animalChainID(s)
            if !unlockedChainIDs.contains(id) { unlockedChainIDs.append(id) }
        }
        if let p = reward.newProducerTier { unlockedProducerShopTiers.insert(p) }
        if let p = reward.newSupplyProducer {
            if let chainID = p.targetChainID, !unlockedChainIDs.contains(chainID) {
                unlockedChainIDs.append(chainID)
            }
        }
        // Clamp spawnMultiplier to newly-unlocked options.
        if !unlockedMultipliers.contains(spawnMultiplier) { spawnMultiplier = 1 }

        // Show the level-up banner (auto-dismisses after 3 s).
        levelUpBannerTitle  = "Level \(playerLevel)!"
        levelUpBannerDetail = reward.primaryMessage()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            showLevelUpBanner = true
        }
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.4)) { self?.showLevelUpBanner = false }
        }
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        playerLevel              = s.playerLevel
        playerXP                 = s.playerXP
        unlockedChainIDs         = s.unlockedChainIDs.isEmpty ? startingChainIDs : s.unlockedChainIDs
        spawnMultiplier          = unlockedMultipliers.contains(s.spawnMultiplier)
                                   ? s.spawnMultiplier : 1
        deepestUnlockedTier      = s.deepestUnlockedTier

        // Supply producer shop tiers are a pure function of level — re-derive on load.
        // Rescue-tier producers are superseded by family spawners (earned via the map).
        unlockedProducerShopTiers = []
        if playerLevel >= 15 { unlockedProducerShopTiers.insert(.groomingBox) }
        if playerLevel >= 20 { unlockedProducerShopTiers.insert(.feedBox) }
        if playerLevel >= 25 { unlockedProducerShopTiers.insert(.shelterBox) }
    }

    func capture(into s: inout GameState) {
        s.playerLevel      = playerLevel
        s.playerXP         = playerXP
        s.unlockedChainIDs = unlockedChainIDs
        s.spawnMultiplier  = spawnMultiplier
        s.deepestUnlockedTier = deepestUnlockedTier
    }
}
