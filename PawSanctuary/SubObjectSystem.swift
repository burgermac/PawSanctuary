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

enum SubObjectRarity: String, CaseIterable, Codable {
    case speed          // 60% — 2x Speed Burst (30s)
    case mapSupplies    // 25% — Map Supplies drop
    case spawnerRefill  // 10% — Spawner Refill
    case highTierDrop   // 5%  — High-Tier Drop Guarantee

    var weight: Double {
        switch self {
        case .speed:         return 60
        case .mapSupplies:   return 25
        case .spawnerRefill: return 10
        case .highTierDrop:  return 5
        }
    }
    var displayName: String {
        switch self {
        case .speed:         return "Speed Burst"
        case .mapSupplies:   return "Map Supplies"
        case .spawnerRefill: return "Spawner Refill"
        case .highTierDrop:  return "High-Tier Drop"
        }
    }
}

enum PowerUpEffect: Codable {
    case speedBurst(duration: Double)      // seconds
    case mapSupplies
    case spawnerRefill
    case highTierDrop
}

enum SpawnDropResult {
    case animal(tier: Int)
    case subObject(chainID: String, rarity: SubObjectRarity)
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

// MARK: — Drop Resolution

enum SubObjectSystem {
    /// Resolve what a family spawner produces. Updates pityState in place.
    /// `dropRateBonus` adds percentage points to the 20% base sub-object chance.
    /// `pityTimerReduction` lowers both pity thresholds by that many spawns (min 5/10).
    static func resolveSpawnerDrop(
        species: AnimalSpecies,
        pityState: inout PityState,
        spawnTier: Int,
        dropRateBonus: Int = 0,
        pityTimerReduction: Int = 0
    ) -> SpawnDropResult {
        let effectiveChance = SubObjectDropConfig.baseSubObjectChance + Double(dropRateBonus) / 100.0
        let rareThreshold   = max(5,  PityState.rareThreshold  - pityTimerReduction)
        let epicThreshold   = max(10, PityState.epicThreshold  - pityTimerReduction)

        // Determine if this spawn produces a sub-object at all
        let roll = Double.random(in: 0..<1)
        guard roll < effectiveChance else {
            // Animal drop — still advance pity counters
            pityState.spawnsSinceLastRare  += 1
            pityState.spawnsSinceLastEpic  += 1
            return .animal(tier: spawnTier)
        }

        // Resolve rarity (pity guarantees override random roll)
        let rarity: SubObjectRarity
        if pityState.spawnsSinceLastEpic >= epicThreshold {
            rarity = .highTierDrop
        } else if pityState.spawnsSinceLastRare >= rareThreshold {
            rarity = .spawnerRefill
        } else {
            rarity = weightedRarityRoll()
        }

        // Update pity counters
        switch rarity {
        case .highTierDrop:
            pityState.spawnsSinceLastRare = 0
            pityState.spawnsSinceLastEpic = 0
        case .spawnerRefill:
            pityState.spawnsSinceLastRare = 0
            pityState.spawnsSinceLastEpic += 1
        default:
            pityState.spawnsSinceLastRare += 1
            pityState.spawnsSinceLastEpic += 1
        }

        let chainID = "subobject.\(species.rawValue)"
        return .subObject(chainID: chainID, rarity: rarity)
    }

    // MARK: — Power-up application

    /// Maps a power-up BoardItem's tier to the PowerUpEffect it carries.
    /// Convention: tier 0 = Speed Burst, 1 = Map Supplies, 2 = Spawner Refill, 3 = High-Tier Drop.
    static func powerUpEffect(for item: BoardItem) -> PowerUpEffect? {
        switch item.tier {
        case 0: return .speedBurst(duration: 30)
        case 1: return .mapSupplies
        case 2: return .spawnerRefill
        case 3: return .highTierDrop
        default: return nil
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

        case .spawnerRefill:
            // Family spawners have unlimited charges; grant bonus kibble instead.
            viewModel.kibble += 20

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
