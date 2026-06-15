//
//  InventoryStore.swift
//  PawSanctuary
//
//  Owns all inventory storage state: animal slots, tool/material slots, producer
//  designated slots, and overflow slots. Methods that require placing items onto
//  the board or checking board fullness remain in MergeBoardViewModel, which calls
//  into this store to consume or add items on the storage side.
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

    var toolInventory: [BoardItem?] = Array(repeating: nil, count: totalToolInventorySlots)

    /// Designated producer storage: one slot per ProducerLevel, keyed by rawValue.
    var producerStorage: [Int: ProducerTile] = [:]
    /// Overflow: up to `totalProducerOverflowSlots` slots for producers retired before
    /// their designated slot unlocks.
    var overflowProducerStorage: [ProducerTile?] = Array(repeating: nil, count: totalProducerOverflowSlots)

    var showInventory: Bool = false

    // Selection state
    var selectedInventorySlot: Int? = nil
    var selectedToolSlot: Int? = nil
    var selectedProducerLevel: ProducerLevel? = nil
    var selectedOverflowProducerSlot: Int? = nil

    // Cached counts (private setter; only updated by recalc helpers)
    private(set) var inventoryOccupied: Int = 0
    private(set) var toolInventoryOccupied: Int = 0
    private(set) var producerStorageOccupied: Int = 0

    // MARK: Computed capacity

    var inventoryCapacity: Int {
        freeInventorySlots
            + (inventoryRow1Unlocked ? 6 : 0)
            + (inventoryRow2Unlocked ? 6 : 0)
    }
    var toolInventoryCapacity: Int { totalToolInventorySlots }
    var producerOverflowCapacity: Int { totalProducerOverflowSlots }

    // MARK: Cached recalc

    func recalcInventoryOccupied() {
        inventoryOccupied = (0..<inventoryCapacity).compactMap { inventory[$0] }.count
    }

    func recalcToolInventoryOccupied() {
        toolInventoryOccupied = toolInventory.compactMap { $0 }.count
    }

    func recalcProducerStorageOccupied() {
        producerStorageOccupied = producerStorage.count
            + overflowProducerStorage.compactMap { $0 }.count
    }

    // MARK: Adding items

    /// Routes the item to the correct storage tab based on its chain category.
    /// Returns `true` on success.
    @discardableResult
    func addItem(_ item: BoardItem) -> Bool {
        let category = ContentRegistry.shared.chain(item.chainID)?.category
        switch category {
        case .tool, .material:
            return addToToolInventory(item)
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
    func addToToolInventory(_ item: BoardItem) -> Bool {
        for i in 0..<toolInventoryCapacity where toolInventory[i] == nil {
            toolInventory[i] = item
            recalcToolInventoryOccupied()
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

    // MARK: Tool inventory interaction

    func toolSlotTapped(_ slot: Int) {
        guard slot < toolInventoryCapacity else { return }
        if let sel = selectedToolSlot {
            if sel == slot { selectedToolSlot = nil }
            else { toolInventory.swapAt(sel, slot); selectedToolSlot = nil }
        } else if toolInventory[slot] != nil {
            selectedToolSlot = slot
        }
    }

    /// Removes and returns the item in the selected tool slot, clearing selection.
    func consumeSelectedToolItem() -> BoardItem? {
        guard let slot = selectedToolSlot, let item = toolInventory[slot] else { return nil }
        toolInventory[slot] = nil
        selectedToolSlot = nil
        recalcToolInventoryOccupied()
        return item
    }

    /// Consumes one item of a given chain+tier from tool storage (Phase 4 area hook).
    @discardableResult
    func consumeFromToolInventory(chainID: ChainID, tier: Int) -> Bool {
        guard let slot = toolInventory.indices.first(where: {
            toolInventory[$0]?.chainID == chainID && toolInventory[$0]?.tier == tier
        }) else { return false }
        toolInventory[slot] = nil
        recalcToolInventoryOccupied()
        return true
    }

    func countMaterial(chainID: ChainID, tier: Int) -> Int {
        toolInventory.compactMap { $0 }
            .filter { $0.chainID == chainID && $0.tier == tier }.count
    }

    // MARK: Producer storage interaction

    /// Retires a producer from the board into storage.
    /// Returns `false` if both the designated slot and overflow are full.
    func retireProducer(_ producer: ProducerTile, playerLevel: Int) -> Bool {
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
    }

    func overflowSlotTapped(_ slot: Int) {
        guard slot < totalProducerOverflowSlots,
              overflowProducerStorage[slot] != nil else { return }
        selectedOverflowProducerSlot = selectedOverflowProducerSlot == slot ? nil : slot
        selectedProducerLevel = nil
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
        toolInventory           = s.toolInventory
        producerStorage         = s.producerStorage
        overflowProducerStorage = s.overflowProducerStorage
        recalcInventoryOccupied()
        recalcToolInventoryOccupied()
        recalcProducerStorageOccupied()
    }

    func capture(into s: inout GameState) {
        s.inventory               = inventory
        s.inventoryRow1Unlocked   = inventoryRow1Unlocked
        s.inventoryRow2Unlocked   = inventoryRow2Unlocked
        s.toolInventory           = toolInventory
        s.producerStorage         = producerStorage
        s.overflowProducerStorage = overflowProducerStorage
    }
}
