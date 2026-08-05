//
//  InventoryStore.swift
//  PawSanctuary
//
//  Owns all inventory storage state: animal slots, material accumulator, and producer
//  slots. Methods that require placing items onto the board or checking board fullness
//  remain in MergeBoardViewModel, which calls into this store to consume or add items.
//

import SwiftUI
import Observation

@Observable
@MainActor
class InventoryStore {

    // MARK: Stored state

    var inventory: [BoardItem?] = Array(repeating: nil, count: totalInventorySlots)
    var inventoryRow1Unlocked: Bool = false
    var inventoryRow2Unlocked: Bool = false

    /// Power-up consumable storage (Phase 2, data layer).
    /// UI and persistence wired in Phase 4. Items here are dragged onto spawners to activate.
    var powerUpInventory: [BoardItem?] = Array(repeating: nil, count: 6)

    /// Limitless accumulator for build materials.
    /// Keys are chain IDs; values are per-tier counts (index == tier, 0…5).
    /// The cascade runs automatically after every add, so tier 5 always holds completed materials.
    var materialCounts: [ChainID: [Int]] = InventoryStore.emptyMaterialCounts()

    static func emptyMaterialCounts() -> [ChainID: [Int]] {
        [ContentRegistry.woodChainID:   Array(repeating: 0, count: 6),
         ContentRegistry.metalChainID:  Array(repeating: 0, count: 6),
         ContentRegistry.cementChainID: Array(repeating: 0, count: 6)]
    }

    /// Designated producer storage: one slot per ProducerLevel, keyed by rawValue.
    /// Never holds `.familySpawner` tiles — see `familySpawnerStorage`.
    var producerStorage: [Int: ProducerTile] = [:]
    /// Overflow: up to `totalProducerOverflowSlots` slots for producers retired before
    /// their designated slot unlocks. Never holds `.familySpawner` tiles.
    var overflowProducerStorage: [ProducerTile?] = Array(repeating: nil, count: totalProducerOverflowSlots)
    /// Per-species storage for family spawners, keyed by `AnimalSpecies.rawValue`. A
    /// dedicated slot per family — `producerStorage`'s per-level keying can't be reused
    /// here because every family spawner shares the single `.familySpawner` rawValue.
    var familySpawnerStorage: [String: ProducerTile] = [:]

    var showInventory: Bool = false

    // Selection state
    var selectedInventorySlot: Int? = nil
    var selectedProducerLevel: ProducerLevel? = nil
    var selectedOverflowProducerSlot: Int? = nil
    var selectedFamilySpawnerSpecies: AnimalSpecies? = nil

    // Cached counts (private setter; only updated by recalc helpers)
    private(set) var inventoryOccupied: Int = 0
    private(set) var producerStorageOccupied: Int = 0

    // MARK: Computed capacity

    var inventoryCapacity: Int {
        freeInventorySlots
            + (inventoryRow1Unlocked ? 6 : 0)
            + (inventoryRow2Unlocked ? 6 : 0)
    }
    var producerOverflowCapacity: Int { totalProducerOverflowSlots }

    // MARK: Cached recalc

    func recalcInventoryOccupied() {
        inventoryOccupied = (0..<inventoryCapacity).compactMap { inventory[$0] }.count
    }

    func recalcProducerStorageOccupied() {
        producerStorageOccupied = producerStorage.count
            + overflowProducerStorage.compactMap { $0 }.count
            + familySpawnerStorage.count
    }

    // MARK: Material accumulator

    /// Absorbs a batch of material items into the accumulator, then cascades all chains.
    func absorbMaterialItems(_ items: [BoardItem]) {
        for item in items {
            guard ContentRegistry.shared.chain(item.chainID)?.category == .material,
                  materialCounts[item.chainID] != nil else { continue }
            let tier = max(0, min(item.tier, 5))
            materialCounts[item.chainID]?[tier] += 1
        }
        for chainID in materialCounts.keys { cascadeMaterial(chainID: chainID) }
    }

    private func cascadeMaterial(chainID: ChainID) {
        guard materialCounts[chainID] != nil else { return }
        for tier in 0..<5 {
            while (materialCounts[chainID]?[tier] ?? 0) >= 2 {
                materialCounts[chainID]?[tier] -= 2
                materialCounts[chainID]?[tier + 1] += 1
            }
        }
    }

    /// Completed (top-tier) count for a material chain.
    func completedCount(chainID: ChainID) -> Int { materialCounts[chainID]?[5] ?? 0 }

    /// All six tier counts for a chain — used by the inventory display.
    func tierCounts(chainID: ChainID) -> [Int] {
        materialCounts[chainID] ?? Array(repeating: 0, count: 6)
    }

    // MARK: Adding items

    /// Routes an item to the correct store. Material items go to the accumulator (always
    /// succeeds). Tool items (toolboxes) are absorbed on the board — discard here safely.
    /// Sub-objects and power-ups go to powerUpInventory (6 slots); falls back to animal
    /// inventory if full. Returns `true` on success.
    @discardableResult
    func addItem(_ item: BoardItem) -> Bool {
        let category = ContentRegistry.shared.chain(item.chainID)?.category
        switch category {
        case .material:
            absorbMaterialItems([item])
            return true   // limitless — always succeeds
        case .tool:
            return true   // toolboxes are consumed on the board tap; discard if they reach here
        case .subObject:
            // Only a completed sub-object (one carrying a rolled effect) is a
            // usable power-up. Tiers 0–2 are inert intermediates and belong in
            // the animal inventory, not in the 6 power-up slots.
            guard item.rarity != nil else { return addToAnimalInventory(item) }
            return addToPowerUpInventory(item) || addToAnimalInventory(item)
        case .powerUp:
            return addToPowerUpInventory(item)
        case .currency:
            // Phase 4, Task 4.1: currency items are collected by tapping them on the
            // board (MergeBoardViewModel.collectCurrencyItem), which every path that
            // could reach here (drag-to-storage, sell) intercepts first. This is a
            // defensive fallback only — reaching it means the value was already lost
            // upstream, so it just no-ops rather than silently discarding again.
            return true
        default:
            return addToAnimalInventory(item)
        }
    }

    @discardableResult
    private func addToAnimalInventory(_ item: BoardItem) -> Bool {
        for i in 0..<inventoryCapacity where inventory[i] == nil {
            inventory[i] = item
            recalcInventoryOccupied()
            return true
        }
        return false
    }

    @discardableResult
    private func addToPowerUpInventory(_ item: BoardItem) -> Bool {
        for i in 0..<powerUpInventory.count where powerUpInventory[i] == nil {
            powerUpInventory[i] = item
            return true
        }
        return false
    }

    // MARK: Animal inventory interaction

    func inventorySlotTapped(_ slot: Int) {
        guard slot < inventoryCapacity else { return }
        if let sel = selectedInventorySlot {
            if sel == slot { selectedInventorySlot = nil }
            else { inventory.swapAt(sel, slot); selectedInventorySlot = nil }
        } else if inventory[slot] != nil {
            selectedInventorySlot = slot
        }
    }

    /// Removes and returns the item in the selected animal slot, clearing selection.
    /// Returns `nil` if nothing is selected.
    func consumeSelectedInventoryItem() -> BoardItem? {
        guard let slot = selectedInventorySlot, let item = inventory[slot] else { return nil }
        inventory[slot] = nil
        selectedInventorySlot = nil
        recalcInventoryOccupied()
        return item
    }

    func unlockRow1(deductingFrom dogTags: inout Int) {
        guard !inventoryRow1Unlocked, dogTags >= inventoryRow1Cost else { return }
        dogTags -= inventoryRow1Cost
        inventoryRow1Unlocked = true
        recalcInventoryOccupied()
    }

    func unlockRow2(deductingFrom dogTags: inout Int) {
        guard inventoryRow1Unlocked, !inventoryRow2Unlocked,
              dogTags >= inventoryRow2Cost else { return }
        dogTags -= inventoryRow2Cost
        inventoryRow2Unlocked = true
        recalcInventoryOccupied()
    }

    // MARK: Material consumption (area building)

    /// Consumes one completed (top-tier) material of the given chain. Used by area building.
    @discardableResult
    func consumeFromToolInventory(chainID: ChainID, tier: Int) -> Bool {
        guard tier >= 0 && tier <= 5,
              (materialCounts[chainID]?[tier] ?? 0) > 0 else { return false }
        materialCounts[chainID]?[tier] -= 1
        return true
    }

    func countMaterial(chainID: ChainID, tier: Int) -> Int {
        guard tier >= 0 && tier <= 5 else { return 0 }
        return materialCounts[chainID]?[tier] ?? 0
    }

    // MARK: Producer storage interaction

    /// Retires a producer from the board into storage.
    /// Returns `false` if there's nowhere to put it (family spawner slot already
    /// occupied for that species, or both the designated slot and overflow are full).
    func retireProducer(_ producer: ProducerTile, playerLevel: Int) -> Bool {
        if producer.level == .familySpawner {
            guard let species = producer.species, familySpawnerStorage[species.rawValue] == nil else { return false }
            familySpawnerStorage[species.rawValue] = producer
            recalcProducerStorageOccupied()
            return true
        }
        let level = producer.level
        let key   = level.rawValue
        if playerLevel >= level.storageUnlockLevel && producerStorage[key] == nil {
            producerStorage[key] = producer
        } else if let overflowSlot = overflowProducerStorage.indices
                      .first(where: { overflowProducerStorage[$0] == nil }) {
            overflowProducerStorage[overflowSlot] = producer
        } else {
            return false
        }
        recalcProducerStorageOccupied()
        return true
    }

    func designatedSlotTapped(level: ProducerLevel, playerLevel: Int) {
        guard playerLevel >= level.storageUnlockLevel,
              producerStorage[level.rawValue] != nil else { return }
        selectedProducerLevel = selectedProducerLevel == level ? nil : level
        selectedOverflowProducerSlot = nil
        selectedFamilySpawnerSpecies = nil
    }

    func overflowSlotTapped(_ slot: Int) {
        guard slot < totalProducerOverflowSlots,
              overflowProducerStorage[slot] != nil else { return }
        selectedOverflowProducerSlot = selectedOverflowProducerSlot == slot ? nil : slot
        selectedProducerLevel = nil
        selectedFamilySpawnerSpecies = nil
    }

    func familySpawnerSlotTapped(species: AnimalSpecies) {
        guard familySpawnerStorage[species.rawValue] != nil else { return }
        selectedFamilySpawnerSpecies = selectedFamilySpawnerSpecies == species ? nil : species
        selectedProducerLevel = nil
        selectedOverflowProducerSlot = nil
    }

    /// Removes and returns the selected family spawner.
    func consumeSelectedFamilySpawner() -> ProducerTile? {
        guard let species = selectedFamilySpawnerSpecies,
              let producer = familySpawnerStorage[species.rawValue] else { return nil }
        familySpawnerStorage.removeValue(forKey: species.rawValue)
        selectedFamilySpawnerSpecies = nil
        recalcProducerStorageOccupied()
        return producer
    }

    /// Removes and returns the selected designated-slot producer.
    /// If `playerLevel` now qualifies for migration of an overflow producer, that
    /// case is handled in MergeBoardViewModel.placeOverflowProducerOnBoard().
    func consumeSelectedDesignatedProducer() -> ProducerTile? {
        guard let level = selectedProducerLevel,
              let producer = producerStorage[level.rawValue] else { return nil }
        producerStorage.removeValue(forKey: level.rawValue)
        selectedProducerLevel = nil
        recalcProducerStorageOccupied()
        return producer
    }

    /// Removes and returns the selected overflow producer.
    /// Returns `(producer, shouldMigrateToDesignated)` so the caller can decide
    /// whether to place it on the board or migrate it to the designated slot.
    func consumeSelectedOverflowProducer(playerLevel: Int) -> (ProducerTile, Bool)? {
        guard let slot = selectedOverflowProducerSlot,
              let producer = overflowProducerStorage[slot] else { return nil }
        let level = producer.level
        let key   = level.rawValue
        let migrate = playerLevel >= level.storageUnlockLevel && producerStorage[key] == nil

        if migrate {
            producerStorage[key] = producer
            overflowProducerStorage[slot] = nil
            selectedOverflowProducerSlot = nil
            recalcProducerStorageOccupied()
            return (producer, true)
        }
        overflowProducerStorage[slot] = nil
        selectedOverflowProducerSlot = nil
        recalcProducerStorageOccupied()
        return (producer, false)
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        inventory               = s.inventory
        inventoryRow1Unlocked   = s.inventoryRow1Unlocked
        inventoryRow2Unlocked   = s.inventoryRow2Unlocked
        materialCounts          = s.materialCounts
        // Ensure all three chains are present even when loading an older migrated save
        for chainID in [ContentRegistry.woodChainID, ContentRegistry.metalChainID, ContentRegistry.cementChainID] {
            if materialCounts[chainID] == nil { materialCounts[chainID] = Array(repeating: 0, count: 6) }
        }
        producerStorage         = s.producerStorage
        overflowProducerStorage = s.overflowProducerStorage
        familySpawnerStorage    = s.familySpawnerStorage
        // Pad/trim in case the saved array predates the current slot count.
        var slots = s.powerUpInventory
        if slots.count < 6 { slots.append(contentsOf: Array(repeating: nil, count: 6 - slots.count)) }
        powerUpInventory        = Array(slots.prefix(6))
        recalcInventoryOccupied()
        recalcProducerStorageOccupied()
    }

    func capture(into s: inout GameState) {
        s.inventory               = inventory
        s.inventoryRow1Unlocked   = inventoryRow1Unlocked
        s.inventoryRow2Unlocked   = inventoryRow2Unlocked
        s.materialCounts          = materialCounts
        s.producerStorage         = producerStorage
        s.overflowProducerStorage = overflowProducerStorage
        s.familySpawnerStorage    = familySpawnerStorage
        s.powerUpInventory        = powerUpInventory
    }
}
