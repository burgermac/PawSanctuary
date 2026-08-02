//
//  SubObjectSystem.swift  —  Sub-object drop resolution
//  PawSanctuary
//
//  Defines rarity tiers, pity tracking, drop resolution, and power-up
//  application for per-family sub-object chains.
//

import Foundation
import SwiftUI

// MARK: — Rarity & Effects

/// The effect a completed (tier-3) sub-object carries. Rolled once, at the
/// moment the sub-object is merged to its top tier, and then stored on the
/// `BoardItem` so it survives save/load — see `SubObjectSystem.rollPowerUpRarity`.
///
/// Phase 2 (Task 2.2) replaced `spawnerRefill` (+20 kibble) with `boardItemGrant`.
/// A per-tap *currency* rebate is unbounded under the neutral pricing introduced
/// by Task 2.1: at the base 20% drop rate it returned exactly 1.00 kibble per
/// activation, and up to 6.50 with full area upgrades and the Rodents Hoard
/// superpower. An *item* payload is immune to that arithmetic and doubles as a
/// recirculation channel, which is what the endgame needs.
enum SubObjectRarity: String, CaseIterable, Codable {
    case speed           // 60% — 2x Speed Burst (30s)
    case mapSupplies     // 25% — Map Supplies drop
    case boardItemGrant  // 10% — one board item, scaled to the player's deepest tier
    case highTierDrop    // 5%  — High-Tier Drop Guarantee

    var weight: Double {
        switch self {
        case .speed:          return 60
        case .mapSupplies:    return 25
        case .boardItemGrant: return 10
        case .highTierDrop:   return 5
        }
    }
    var displayName: String {
        switch self {
        case .speed:          return "Speed Burst"
        case .mapSupplies:    return "Map Supplies"
        case .boardItemGrant: return "Board Item"
        case .highTierDrop:   return "High-Tier Drop"
        }
    }
}

enum PowerUpEffect: Codable {
    case speedBurst(duration: Double)      // seconds
    case mapSupplies
    case boardItemGrant
    case highTierDrop
}

enum SpawnDropResult {
    case animal(tier: Int)
    case subObject(chainID: String)
    case currency(chainID: ChainID, tier: Int)
}

// MARK: — Pity State

struct PityState: Codable {
    var spawnsSinceLastRare: Int = 0
    var spawnsSinceLastEpic: Int = 0
    static let rareThreshold  = 30
    static let epicThreshold  = 60
}

// MARK: — Drop Config

struct SubObjectDropConfig {
    static let baseSubObjectChance: Double = 0.20   // 20% of spawns produce a sub-object
}

/// Phase 4, Task 4.1: a slice of spawns produce a currency item (kibble or coin
/// chain) instead of an animal. Independent of `dropRateBonus` — that dial is
/// specifically tuned for sub-object recirculation, not this.
let baseCurrencyChance: Double = 0.10   // 10% of spawns produce a currency item

/// Top tier of every per-family sub-object chain. Only an item at this tier
/// carries a rolled effect and counts as a usable power-up (Task 2.2).
let subObjectTopTier = 3

// MARK: — Drop Resolution

enum SubObjectSystem {
    /// Resolve what a family spawner produces, and advance that family's pity
    /// counters by one spawn. `dropRateBonus` adds percentage points to the 20%
    /// base sub-object chance.
    ///
    /// This no longer picks a rarity. Before Task 2.2 it rolled one here and the
    /// call site discarded it — the effect was really chosen by which tier the
    /// player stopped merging at. The roll now happens once, when a sub-object
    /// is completed: see `rollPowerUpRarity`.
    static func resolveSpawnerDrop(
        species: AnimalSpecies,
        pityState: inout PityState,
        spawnTier: Int,
        dropRateBonus: Int = 0
    ) -> SpawnDropResult {
        let subObjectChance = SubObjectDropConfig.baseSubObjectChance + Double(dropRateBonus) / 100.0

        // Every activation counts toward pity, whatever it produces.
        pityState.spawnsSinceLastRare += 1
        pityState.spawnsSinceLastEpic += 1

        let roll = Double.random(in: 0..<1)
        if roll < subObjectChance {
            return .subObject(chainID: "subobject.\(species.rawValue)")
        }
        if roll < subObjectChance + baseCurrencyChance {
            let chainID = Bool.random() ? ContentRegistry.kibbleCurrencyChainID
                                         : ContentRegistry.coinCurrencyChainID
            return .currency(chainID: chainID, tier: 0)
        }
        return .animal(tier: spawnTier)
    }

    /// Rolls the effect a just-completed sub-object will carry, consuming the
    /// family's accumulated pity. Call this once, when a sub-object reaches its
    /// top tier; store the result on the item.
    ///
    /// `pityTimerReduction` lowers both thresholds by that many spawns (floored
    /// at 5 / 15). These are the Sanctuary Map upgrades that were a no-op for as
    /// long as the rarity was discarded — they do something again as of Task 2.2.
    static func rollPowerUpRarity(
        pityState: inout PityState,
        pityTimerReduction: Int = 0
    ) -> SubObjectRarity {
        let rareThreshold = max(5,  PityState.rareThreshold - pityTimerReduction)
        let epicThreshold = max(15, PityState.epicThreshold - pityTimerReduction)

        let rarity: SubObjectRarity
        if pityState.spawnsSinceLastEpic >= epicThreshold {
            rarity = .highTierDrop
        } else if pityState.spawnsSinceLastRare >= rareThreshold {
            rarity = .boardItemGrant
        } else {
            rarity = weightedRarityRoll()
        }

        switch rarity {
        case .highTierDrop:
            pityState.spawnsSinceLastRare = 0
            pityState.spawnsSinceLastEpic = 0
        case .boardItemGrant:
            pityState.spawnsSinceLastRare = 0
        case .speed, .mapSupplies:
            break   // neither counter resets on a common roll
        }
        return rarity
    }

    // MARK: — Power-up application

    /// The effect a power-up item carries, or `nil` if it isn't usable.
    ///
    /// Only a completed sub-object is usable, and its effect is whatever was
    /// rolled and stored when it was completed. Tiers 0–2 are inert intermediates
    /// and return `nil`, so the UI can refuse to apply them.
    static func powerUpEffect(for item: BoardItem) -> PowerUpEffect? {
        guard let rarity = item.rarity else { return nil }
        return effect(for: rarity)
    }

    static func effect(for rarity: SubObjectRarity) -> PowerUpEffect {
        switch rarity {
        case .speed:          return .speedBurst(duration: 30)
        case .mapSupplies:    return .mapSupplies
        case .boardItemGrant: return .boardItemGrant
        case .highTierDrop:   return .highTierDrop
        }
    }

    /// Applies `effect` to `producer` in-place and triggers any view-model side effects.
    /// `powerUpDurationBonus` (seconds) is added to Speed Burst duration.
    /// Call site must write the mutated producer back to the board.
    @MainActor
    static func applyPowerUp(
        effect: PowerUpEffect,
        to producer: inout ProducerTile,
        viewModel: MergeBoardViewModel,
        powerUpDurationBonus: Double = 0
    ) {
        switch effect {
        case .speedBurst(let duration):
            producer.speedBurstActive    = true
            producer.speedBurstRemaining = duration + powerUpDurationBonus

        case .boardItemGrant:
            // Recirculation, not a rebate. One item from a random unlocked animal
            // chain, two tiers below the player's deepest — meaningful progress
            // without ever paying out more than the merge it replaces.
            viewModel.grantRecirculatedBoardItem()

        case .highTierDrop:
            producer.nextDropGuaranteedHighTier = true

        case .mapSupplies:
            // Award 4 random material items (wood / metal / cement, tier 0–2).
            let chains = [ContentRegistry.woodChainID,
                          ContentRegistry.metalChainID,
                          ContentRegistry.cementChainID]
            let items = (0..<4).map { _ in
                BoardItem(chainID: chains.randomElement()!, tier: Int.random(in: 0...2))
            }
            viewModel.inventoryStore.absorbMaterialItems(items)
        }
    }

    private static func weightedRarityRoll() -> SubObjectRarity {
        let total = SubObjectRarity.allCases.reduce(0) { $0 + $1.weight }
        var roll  = Double.random(in: 0..<total)
        for rarity in SubObjectRarity.allCases {
            roll -= rarity.weight
            if roll < 0 { return rarity }
        }
        return .speed
    }
}
