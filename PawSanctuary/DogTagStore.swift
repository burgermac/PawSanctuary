//
//  DogTagStore.swift
//  PawSanctuary
//
//  Board items purchasable with Dog Tags — the third recirculation channel
//  (Phase 2, Task 2.3c), per recorded decision D3.
//
//  Three slots, rotating daily, stock 1 each. Deliberately stock-limited: this is
//  a release valve for a player blocked on one specific item, not a way to buy the
//  chain outright. It is also the highest-intent conversion moment in the game —
//  the player already knows exactly which item they want.
//

import SwiftUI
import Observation

@Observable
@MainActor
class DogTagStore {

    // MARK: Stored state

    var slots: [DogTagStoreSlot] = []
    var lastRotation: Date? = nil

    // MARK: Rotation

    /// Rebuilds the day's stock if it has never been built or the calendar day
    /// has rolled over. Cheap and idempotent — safe to call on every appearance.
    func rotateIfNeeded(deepestUnlockedTier: Int, unlockedChainIDs: [ChainID]) {
        if let last = lastRotation, Calendar.current.isDateInToday(last), !slots.isEmpty { return }
        slots = Self.makeStock(deepestUnlockedTier: deepestUnlockedTier,
                               unlockedChainIDs: unlockedChainIDs)
        lastRotation = Date()
    }

    /// Builds `dogTagStoreSlotCount` offers spanning `deepest − 4` … `deepest − 1`.
    /// Returns an empty list for a player who hasn't merged deep enough for the
    /// range to contain anything worth selling.
    static func makeStock(deepestUnlockedTier: Int,
                          unlockedChainIDs: [ChainID]) -> [DogTagStoreSlot] {
        let animalChainIDs = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .animal
        }
        guard !animalChainIDs.isEmpty else { return [] }

        let minTier = deepestUnlockedTier - dogTagStoreMinOffset
        let maxTier = deepestUnlockedTier - dogTagStoreMaxOffset
        guard maxTier >= 0, minTier <= maxTier else { return [] }

        let tiers = Array(max(0, minTier)...maxTier)
        return (0..<dogTagStoreSlotCount).compactMap { i in
            // Evenly spread the slots across the full band, including its last
            // (dearest) index — reading tiers[0..<slotCount] directly left the last
            // tier of a fully-populated 4-wide band structurally unreachable.
            let spread = dogTagStoreSlotCount > 1
                ? Int((Double(i) * Double(tiers.count - 1) / Double(dogTagStoreSlotCount - 1)).rounded())
                : 0
            guard let tier = tiers.indices.contains(spread) ? tiers[spread] : tiers.last else { return nil }
            guard let chainID = animalChainIDs.randomElement() else { return nil }
            let chainMaxTier = ContentRegistry.shared.chain(chainID)?.maxTier ?? 0
            return DogTagStoreSlot(chainID: chainID,
                                   tier: min(tier, chainMaxTier),
                                   priceDogTags: price(forTier: tier, minTier: max(0, minTier)))
        }
    }

    /// Linear in tier above the cheapest slot, anchored on the measured reference
    /// band of roughly 9–70 gems per mid-tier item.
    ///
    /// Deliberately *not* kibble-equivalent: at neutral pricing a tier-13 item is
    /// worth 8,192 kibble, which no Dog Tag income could ever cover. Selling items
    /// below their merge cost is the point of a recirculation channel.
    static func price(forTier tier: Int, minTier: Int) -> Int {
        dogTagStoreBasePrice + dogTagStorePriceStep * max(0, tier - minTier)
    }

    // MARK: Purchase

    /// Marks a slot sold. The caller owns deducting tags and delivering the item.
    func markPurchased(slotID: UUID) {
        guard let i = slots.firstIndex(where: { $0.id == slotID }) else { return }
        slots[i].purchased = true
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        slots        = s.dogTagStoreSlots
        lastRotation = s.lastDogTagStoreRotation
    }

    func capture(into s: inout GameState) {
        s.dogTagStoreSlots         = slots
        s.lastDogTagStoreRotation  = lastRotation
    }
}
