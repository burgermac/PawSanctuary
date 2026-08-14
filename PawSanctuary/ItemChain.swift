//
//  ItemChain.swift  —  Generalized data-driven merge model (Phase 0)
//  PawSanctuary
//
//  Replaces the hardcoded `MergeItem(species, stage)` model. An item is now a
//  position in a *chain*: `BoardItem(chainID, tier)`. Chains are defined as data
//  in `ContentRegistry`, so new content (tools, materials, new animal lines,
//  level-50 items) is authored, not coded.
//

import SwiftUI

// ============================================================
// MARK: - CHAIN IDENTITY
// ============================================================

/// Stable identifier for a chain, e.g. "animal.dog", "material.plank".
/// Stability matters: it's the only chain reference stored in saves.
typealias ChainID = String

/// What kind of content a chain holds — drives storage tab + behaviour.
enum ChainCategory: String, Codable, CaseIterable {
    case animal      // the rescue chains (current gameplay)
    case spawner     // producers (Phase 1 makes them finite/charge-based)
    case supply      // grooming / food / shelter supplies (Phase 2)
    case tool        // toolbox chest chain — tap any tier to open, or merge two for a richer one (Gap_Analysis_Round2 3.3)
    case material    // wood / metal / cement building supplies (Phase 3)
    case subObject   // per-family 4-stage merge chain; top tier becomes a power-up consumable
    case powerUp     // power-up consumable item (drag onto spawner to apply)
    case currency    // kibble / coin chains that spawn on the board — Phase 4
    case superpower  // single-use active-superpower piece; drag onto an eligible board item to spend it
    case wildcard    // single-use board item that merges with anything (Gap_Analysis_Round2 3.5)
}

// ============================================================
// MARK: - CHAIN DEFINITIONS (not persisted — looked up at runtime)
// ============================================================

/// One rung of a chain. Holds display + gameplay data. Never saved, so it can
/// carry non-Codable `Color` directly.
struct ChainTier {
    let name: String          // "Groomed Dog"
    let shortLabel: String    // "Groomed"  (fits a 62 pt cell)
    let symbol: String        // SF Symbol
    let color: Color          // tier accent
    let tint: Color?          // secondary tint (species colour for animals)
    let badge: String?        // e.g. "medal.fill" on the top tier
    let scoreValue: Int       // score awarded when merging two items AT this tier
    let xpValue: Int          // xp awarded likewise
}

/// An ordered chain: merging two items at tier T yields one at tier T+1.
struct MergeChain: Identifiable {
    let id: ChainID
    let category: ChainCategory
    let displayName: String
    let tiers: [ChainTier]    // index 0 = base item
    var maxTier: Int { tiers.count - 1 }
}

// ============================================================
// MARK: - BOARD ITEM (persisted)
// ============================================================

/// A live item on the board / in inventory. The save stores only `chainID`
/// (a stable String) + `tier` (an Int); all display data is looked up from the
/// registry, which keeps saves tiny and survivable across content additions.
struct BoardItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var chainID: ChainID
    var tier: Int

    /// For completed (top-tier) sub-objects only: the effect rolled when this
    /// item was merged into existence. `nil` for every other item, and for the
    /// inert tier 0–2 intermediates. Optional so pre-v27 saves still decode.
    var rarity: SubObjectRarity? = nil

    /// Phase 4, Task 4.4: non-nil while this item is encased in a bubble —
    /// the `Date.timeIntervalSince1970` it was bubbled at. `nil` for every
    /// normal item. See `bubbleDecaySeconds` for how long it stays poppable
    /// for full value before decaying into a lesser, auto-collectible reward.
    var bubbledAt: Double? = nil

    /// The tier definition (display + values). `nil` only if a save references a
    /// chain this build doesn't know — callers treat that as an empty cell.
    var def: ChainTier? { ContentRegistry.shared.tier(chainID, tier) }
    var chain: MergeChain? { ContentRegistry.shared.chain(chainID) }
    var isTopTier: Bool { chain.map { tier >= $0.maxTier } ?? false }

    /// True once a bubbled item has passed `bubbleDecaySeconds` without being
    /// popped — it can still be collected, just for less.
    func isBubbleDecayed(now: Double = Date().timeIntervalSince1970) -> Bool {
        guard let bubbledAt else { return false }
        return now - bubbledAt >= bubbleDecaySeconds
    }
}

// ============================================================
// MARK: - CONTENT REGISTRY
// ============================================================

/// The single source of truth for all chain definitions. Code-defined for now;
/// the lookup boundary is kept clean so a later phase can load it from JSON
/// without touching gameplay.
/// Only Canines at start. Each additional family is unlocked when its map area is built,
/// which auto-places that family's spawner and adds the chain to unlockedChainIDs.
let startingChainIDs: [ChainID] = [ContentRegistry.animalChainID(.dog)]

struct ContentRegistry {
    static let shared = ContentRegistry()

    private(set) var chains: [ChainID: MergeChain] = [:]
    /// Stable, display-ordered list (useful for legends / debug).
    private(set) var orderedChainIDs: [ChainID] = []

    private init() {
        for species in AnimalSpecies.allCases { register(Self.makeAnimalChain(species)) }
        for chain in [Self.makeGroomingChain(), Self.makeFoodChain(), Self.makeShelterChain()] { register(chain) }
        // Toolbox (consumable) is registered so BoardItem.def resolves correctly.
        for chain in [Self.makeWoodChain(), Self.makeMetalChain(), Self.makeCementChain(), Self.makeToolboxChain()] { register(chain) }
        // Phase 2: per-family 4-stage sub-object chains (data layer only — no drops yet).
        for species in AnimalSpecies.allCases { register(Self.makeSubObjectChain(species)) }
        // Phase 4, Task 4.1: kibble/coin merge chains that spawn on the board.
        for chain in [Self.makeKibbleCurrencyChain(), Self.makeCoinCurrencyChain()] { register(chain) }
        // Active-superpower consumable pieces — one per family with an active ability.
        for species in AnimalSpecies.allCases where species.superpower.isActive {
            register(Self.makeSuperpowerChain(species))
        }
        register(Self.makeWildcardChain())
    }

    private mutating func register(_ chain: MergeChain) {
        chains[chain.id] = chain
        orderedChainIDs.append(chain.id)
    }

    // MARK: Lookups

    func chain(_ id: ChainID) -> MergeChain? { chains[id] }
    func tier(_ id: ChainID, _ t: Int) -> ChainTier? {
        guard let c = chains[id], c.tiers.indices.contains(t) else { return nil }
        return c.tiers[t]
    }
    /// The next tier index, or `nil` if already at the top of the chain.
    func nextTier(_ id: ChainID, after t: Int) -> Int? {
        guard let c = chains[id], t + 1 <= c.maxTier else { return nil }
        return t + 1
    }
    func chains(in category: ChainCategory) -> [MergeChain] {
        orderedChainIDs.compactMap { chains[$0] }.filter { $0.category == category }
    }
    func chainIDs(in category: ChainCategory) -> [ChainID] {
        chains(in: category).map(\.id)
    }

    // MARK: Authoring helpers

    /// Stable chain id for an animal species, e.g. "animal.dog".
    static func animalChainID(_ s: AnimalSpecies) -> ChainID { "animal.\(s.rawValue)" }

    /// Stable chain id for an active-superpower piece, e.g. "superpower.cat".
    /// Only defined for species whose `superpower.isActive` is true.
    static func superpowerChainID(_ s: AnimalSpecies) -> ChainID { "superpower.\(s.rawValue)" }

    /// Stable chain ids for the three supply chains.
    static let groomingChainID: ChainID = "supply.grooming"
    static let foodChainID:     ChainID = "supply.food"
    static let shelterChainID:  ChainID = "supply.shelter"

    /// Stable chain ids for the three material chains and the toolbox consumable (Phase 3).
    static let woodChainID:    ChainID = "material.wood"
    static let metalChainID:   ChainID = "material.metal"
    static let cementChainID:  ChainID = "material.cement"
    /// Toolbox is a single-tier consumable (category .tool) awarded by quests.
    /// Double-tapping it on the board distributes random materials to the Materials tab.
    static let toolboxChainID: ChainID = "tool.toolbox"

    /// Stable chain ids for the two currency chains (Phase 4, Task 4.1).
    static let kibbleCurrencyChainID: ChainID = "currency.kibble"
    static let coinCurrencyChainID:   ChainID = "currency.coin"

    /// Single-tier consumable that merges with anything (Gap_Analysis_Round2 3.5).
    /// Bought with Dog Tags, never earned — see `purchaseWildcard`.
    static let wildcardChainID: ChainID = "wildcard.wildcard"

    /// Convenience: a random chain id from a category, drawn from a candidate list.
    static func randomChainID(in category: ChainCategory, from candidates: [ChainID]) -> ChainID? {
        candidates.filter { shared.chain($0)?.category == category }.randomElement()
    }

    // MARK: Supply chain builders (Phase 2)

    private static func makeGroomingChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Brush",             "Brush",   "comb",                  Color(red: 0.55, green: 0.80, blue: 0.75), 30),
            ("Shampoo",           "Shampoo", "drop.fill",             Color(red: 0.35, green: 0.72, blue: 0.70), 65),
            ("Grooming Kit",      "Kit",     "scissors",              Color(red: 0.25, green: 0.65, blue: 0.60), 110),
            ("Spa Kit",           "Spa",     "sparkles",              Color(red: 0.20, green: 0.58, blue: 0.70), 170),
            ("Deluxe Spa",        "Deluxe",  "star.circle.fill",      Color(red: 0.15, green: 0.50, blue: 0.75), 245),
            ("Grooming Station",  "Station", "house.lodge.fill",      Color(red: 0.10, green: 0.42, blue: 0.68), 340),
        ]
        return MergeChain(id: groomingChainID, category: .supply,
                          displayName: "Grooming",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "Station" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    private static func makeFoodChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Kibble Scoop",  "Scoop",   "circle.grid.2x2.fill", Color(red: 0.90, green: 0.75, blue: 0.35), 30),
            ("Kibble Bag",    "Bag",     "bag.fill",              Color(red: 0.88, green: 0.65, blue: 0.25), 65),
            ("Premium Food",  "Premium", "cart.fill",             Color(red: 0.85, green: 0.55, blue: 0.18), 110),
            ("Gourmet Mix",   "Gourmet", "star.fill",             Color(red: 0.80, green: 0.48, blue: 0.12), 170),
            ("Chef's Choice", "Chef's",  "crown.fill",            Color(red: 0.75, green: 0.40, blue: 0.08), 245),
            ("Luxury Feast",  "Feast",   "trophy.fill",           Color(red: 0.70, green: 0.32, blue: 0.05), 340),
        ]
        return MergeChain(id: foodChainID, category: .supply,
                          displayName: "Food",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "Feast" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    private static func makeShelterChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Blanket",          "Blanket", "bed.double.fill",       Color(red: 0.80, green: 0.62, blue: 0.45), 30),
            ("Kennel Pad",       "Pad",     "square.fill",           Color(red: 0.72, green: 0.55, blue: 0.38), 65),
            ("Cozy Kennel",      "Kennel",  "house.fill",            Color(red: 0.65, green: 0.48, blue: 0.30), 110),
            ("Suite",            "Suite",   "house.lodge.fill",      Color(red: 0.58, green: 0.42, blue: 0.22), 170),
            ("Premium Suite",    "P.Suite", "building.columns.fill", Color(red: 0.50, green: 0.36, blue: 0.15), 245),
            ("Luxury Habitat",   "Habitat", "sparkles",              Color(red: 0.42, green: 0.30, blue: 0.10), 340),
        ]
        return MergeChain(id: shelterChainID, category: .supply,
                          displayName: "Shelter",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "Habitat" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    // MARK: Material & consumable chain builders (Phase 3)

    private static func makeWoodChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Log",          "Log",     "leaf.fill",         Color(red: 0.62, green: 0.48, blue: 0.28), 20),
            ("Plank",        "Plank",   "rectangle.fill",    Color(red: 0.65, green: 0.50, blue: 0.24), 45),
            ("Lumber",       "Lumber",  "square.stack.fill", Color(red: 0.58, green: 0.44, blue: 0.20), 80),
            ("Timber",       "Timber",  "archivebox.fill",   Color(red: 0.52, green: 0.38, blue: 0.16), 130),
            ("Framework",    "Frame",   "building.2.fill",   Color(red: 0.46, green: 0.33, blue: 0.13), 200),
            ("Hardwood Kit", "H. Kit",  "house.fill",        Color(red: 0.38, green: 0.27, blue: 0.10), 290),
        ]
        return MergeChain(id: woodChainID, category: .material, displayName: "Wood",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "H. Kit" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    private static func makeMetalChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Nail",         "Nail",    "oval.fill",              Color(red: 0.55, green: 0.58, blue: 0.65), 20),
            ("Bolt",         "Bolt",    "bolt.fill",              Color(red: 0.48, green: 0.52, blue: 0.62), 45),
            ("Rod",          "Rod",     "minus.square.fill",      Color(red: 0.40, green: 0.45, blue: 0.58), 80),
            ("Pipe",         "Pipe",    "capsule.fill",           Color(red: 0.34, green: 0.40, blue: 0.54), 130),
            ("I-Beam",       "I-Beam",  "building.columns.fill",  Color(red: 0.28, green: 0.34, blue: 0.50), 200),
            ("Steel Girder", "Girder",  "gearshape.fill",         Color(red: 0.22, green: 0.28, blue: 0.44), 290),
        ]
        return MergeChain(id: metalChainID, category: .material, displayName: "Metal",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "Girder" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    private static func makeCementChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Pebble",         "Pebble",  "circle.fill",    Color(red: 0.65, green: 0.63, blue: 0.59), 20),
            ("Gravel",         "Gravel",  "seal.fill",      Color(red: 0.58, green: 0.56, blue: 0.52), 45),
            ("Stone",          "Stone",   "hexagon.fill",   Color(red: 0.50, green: 0.48, blue: 0.44), 80),
            ("Mortar",         "Mortar",  "drop.fill",      Color(red: 0.44, green: 0.42, blue: 0.38), 130),
            ("Concrete Block", "Block",   "square.fill",    Color(red: 0.38, green: 0.36, blue: 0.32), 200),
            ("Foundation Kit", "F. Kit",  "hammer.fill",    Color(red: 0.32, green: 0.30, blue: 0.26), 290),
        ]
        return MergeChain(id: cementChainID, category: .material, displayName: "Cement",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "F. Kit" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    /// Quests award only the base tier. Tapping any tier opens it immediately
    /// for that tier's random assortment of wood/metal/cement items; merging
    /// two of the same tier trades the immediate (smaller) payout for a
    /// richer one at the next tier (Gap_Analysis_Round2 3.3) — the reward
    /// container is a chain item, so opening now vs. merging for more is a
    /// real decision, not just a tap target.
    private static func makeToolboxChain() -> MergeChain {
        let tiers: [(name: String, symbol: String, color: Color, tint: Color, badge: String?)] = [
            ("Toolbox",      "shippingbox.fill", Color(red: 0.72, green: 0.50, blue: 0.18),
                                                  Color(red: 0.88, green: 0.68, blue: 0.30), nil),
            ("Supply Crate", "cube.box.fill",     Color(red: 0.62, green: 0.42, blue: 0.14),
                                                  Color(red: 0.80, green: 0.58, blue: 0.22), nil),
            ("Cargo Chest",  "archivebox.fill",   Color(red: 0.52, green: 0.34, blue: 0.10),
                                                  Color(red: 0.95, green: 0.78, blue: 0.20), "sparkles"),
        ]
        return MergeChain(id: toolboxChainID, category: .tool,
                          displayName: "Tap to collect, or merge for more!",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.name, symbol: t.symbol,
                      color: t.color, tint: t.tint, badge: t.badge,
                      scoreValue: 0, xpValue: 0)
        })
    }

    // MARK: Active-superpower piece builder

    /// Single-tier collectible for an active superpower — reuses that family's
    /// existing `Superpower` icon/name/tint, so no new art is needed. Never merges
    /// with itself (single-tier); spent by dragging onto an eligible board item.
    private static func makeSuperpowerChain(_ species: AnimalSpecies) -> MergeChain {
        let sp = species.superpower
        let tier = ChainTier(
            name: sp.name, shortLabel: sp.name,
            symbol: sp.sfSymbol,
            color: species.tintColor,
            tint: species.tintColor,
            badge: nil,
            scoreValue: 0, xpValue: 0
        )
        return MergeChain(id: superpowerChainID(species), category: .superpower,
                          displayName: sp.name, tiers: [tier])
    }

    // MARK: Wildcard builder (Gap_Analysis_Round2 3.5)

    /// Single-tier, never merges with itself — dragging it onto any other item
    /// advances that item's own chain by one tier, as if it were a second copy.
    private static func makeWildcardChain() -> MergeChain {
        let tier = ChainTier(
            name: "Wildcard", shortLabel: "Wild",
            symbol: "wand.and.stars",
            color: Color(red: 0.62, green: 0.30, blue: 0.78),
            tint: Color(red: 0.80, green: 0.55, blue: 0.92),
            badge: "sparkles",
            scoreValue: 0, xpValue: 0
        )
        return MergeChain(id: wildcardChainID, category: .wildcard,
                          displayName: "Merges with anything", tiers: [tier])
    }

    // MARK: Currency chain builders (Phase 4, Task 4.1)

    /// Kibble and Coin merge chains that spawn on the board via family spawners
    /// (`SubObjectSystem.resolveSpawnerDrop`), independent of which animal chains
    /// are unlocked. Merge two to reach a richer tier, or tap to collect the
    /// current tier's value immediately — the same sell-vs-order shaped tradeoff
    /// as Phase 2c, one level down. See `kibbleCurrencyValue`/`coinCurrencyValue`
    /// in AnimalSpecies.swift for the payout formula and its rationale.
    private static func makeKibbleCurrencyChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Kibble Scoop", "Scoop", "pawprint",         Color(red: 0.72, green: 0.58, blue: 0.38), 20),
            ("Kibble Bowl",  "Bowl",  "pawprint.fill",    Color(red: 0.64, green: 0.50, blue: 0.30), 45),
            ("Kibble Bag",   "Bag",   "bag.fill",         Color(red: 0.56, green: 0.42, blue: 0.24), 80),
            ("Kibble Sack",  "Sack",  "shippingbox.fill", Color(red: 0.48, green: 0.34, blue: 0.18), 130),
            ("Kibble Crate", "Crate", "archivebox.fill",  Color(red: 0.40, green: 0.27, blue: 0.13), 200),
            ("Kibble Vault", "Vault", "cube.box.fill",    Color(red: 0.32, green: 0.20, blue: 0.09), 290),
        ]
        return MergeChain(id: kibbleCurrencyChainID, category: .currency, displayName: "Kibble",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "Vault" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    private static func makeCoinCurrencyChain() -> MergeChain {
        let tiers: [(name: String, short: String, symbol: String, color: Color, score: Int)] = [
            ("Copper Coin", "Copper", "circle.fill",      Color(red: 0.80, green: 0.62, blue: 0.20), 20),
            ("Coin Stack",  "Stack",  "coin.fill",        Color(red: 0.85, green: 0.68, blue: 0.15), 45),
            ("Coin Pouch",  "Pouch",  "bag.fill",         Color(red: 0.78, green: 0.58, blue: 0.10), 80),
            ("Coin Purse",  "Purse",  "shippingbox.fill", Color(red: 0.68, green: 0.48, blue: 0.06), 130),
            ("Coin Chest",  "Chest",  "archivebox.fill",  Color(red: 0.58, green: 0.40, blue: 0.04), 200),
            ("Coin Vault",  "Vault",  "cube.box.fill",    Color(red: 0.46, green: 0.32, blue: 0.02), 290),
        ]
        return MergeChain(id: coinCurrencyChainID, category: .currency, displayName: "Coins",
                          tiers: tiers.map { t in
            ChainTier(name: t.name, shortLabel: t.short, symbol: t.symbol,
                      color: t.color, tint: nil,
                      badge: t.short == "Vault" ? "checkmark.seal.fill" : nil,
                      scoreValue: t.score, xpValue: t.score / 5)
        })
    }

    // MARK: Sub-object chain builders (Phase 2)

    /// Builds a 4-tier sub-object chain for a species. The top tier (index 3) is a
    /// power-up consumable (badged with "bolt.fill"). All tiers share the species tintColor.
    private static func makeSubObjectChain(_ species: AnimalSpecies) -> MergeChain {
        let stages: [(name: String, short: String)] = {
            switch species {
            case .dog:       return [("Biscuit", "Biscuit"), ("Bone", "Bone"),
                                     ("Chew Toy", "Chew Toy"), ("Golden Ball", "G. Ball")]
            case .cat:       return [("Bell", "Bell"), ("Feather Wand", "F. Wand"),
                                     ("Yarn Ball", "Yarn Ball"), ("Laser Pointer", "Laser Ptr")]
            case .rabbit:    return [("Lettuce", "Lettuce"), ("Carrot", "Carrot"),
                                     ("Cabbage", "Cabbage"), ("Turnip", "Turnip")]
            case .bird:      return [("Down", "Down"), ("Plume", "Plume"),
                                     ("Quill", "Quill"), ("Iridescent Tail", "Irid. Tail")]
            case .hamster:   return [("Seed", "Seed"), ("Nut", "Nut"),
                                     ("Berry", "Berry"), ("Corn Cob", "Corn Cob")]
            case .turtle:    return [("Pebble", "Pebble"), ("Sand", "Sand"),
                                     ("Warm Moss", "Warm Moss"), ("Heat Lamp", "Heat Lamp")]
            case .fox:       return [("Leaf", "Leaf"), ("Sprout", "Sprout"),
                                     ("Twig", "Twig"), ("Antler", "Antler")]
            case .owl:       return [("Honey Comb", "Honey Cmb"), ("Salmon", "Salmon"),
                                     ("Wild Hive", "Wild Hive"), ("Berry Bush", "B. Bush")]
            case .fish:      return [("Shell", "Shell"), ("Pearl", "Pearl"),
                                     ("Starfish", "Starfish"), ("Treasure Chest", "T. Chest")]
            case .lizard:    return [("Duckweed", "Duckweed"), ("Reeds", "Reeds"),
                                     ("Lotus Flower", "Lotus Fl."), ("Algae Bloom", "Algae Bl.")]
            case .ferret:    return [("Bud", "Bud"), ("Flower", "Flower"),
                                     ("Leaf Bundle", "L. Bundle"), ("Bark", "Bark")]
            case .parrot:    return [("Banana", "Banana"), ("Mango", "Mango"),
                                     ("Papaya", "Papaya"), ("Jungle Vine", "J. Vine")]
            case .pony:      return [("Curry Comb", "Curry Cmb"), ("Brush", "Brush"),
                                     ("Sponge", "Sponge"), ("Trophy", "Trophy")]
            case .hedgehog:  return [("Puddle", "Puddle"), ("Mud Clump", "Mud Clump"),
                                     ("Clay Mound", "Clay Mnd"), ("Rainfall", "Rainfall")]
            case .guineaPig: return [("Clover", "Clover"), ("Hay Bale", "Hay Bale"),
                                     ("Salt Lick", "Salt Lick"), ("Water Trough", "W. Trough")]
            }
        }()

        let scores  = [20, 45, 80, 130]
        let symbols = ["circle.fill", "circle.hexagongrid.fill",
                       "star.fill", "bolt.circle.fill"]
        let tint    = species.tintColor

        let tiers = stages.enumerated().map { (i, stage) in
            ChainTier(
                name:       stage.name,
                shortLabel: stage.short,
                symbol:     symbols[i],
                color:      tint,
                tint:       tint,
                badge:      i == 3 ? "bolt.fill" : nil,
                scoreValue: scores[i],
                xpValue:    scores[i] / 5
            )
        }
        return MergeChain(
            id:          "subobject.\(species.rawValue)",
            category:    .subObject,
            displayName: "\(species.name) Token",
            tiers:       tiers
        )
    }

    /// Builds an animal chain from a species — one tier per entry in `tierNames`
    /// (12 as of Phase 2b).
    /// scoreValue = (index + 1) * 25, xpValue = (index + 1) * xpPerMergeBase (1-based).
    /// Badge ("medal.fill") is on the top tier. Colors come from
    /// QuestGoal.animalTierAppearance so every tier has a distinct hue.
    private static func makeAnimalChain(_ s: AnimalSpecies) -> MergeChain {
        let topIndex = s.tierNames.count - 1
        let tiers = s.tierNames.enumerated().map { (index, tierName) -> ChainTier in
            ChainTier(
                name: tierName,
                shortLabel: tierName,
                symbol: s.sfSymbol,
                color: QuestGoal.animalTierAppearance(tier: index).color,
                tint: s.tintColor,
                badge: index == topIndex ? "medal.fill" : nil,
                scoreValue: (index + 1) * 25,
                xpValue: (index + 1) * xpPerMergeBase
            )
        }
        return MergeChain(id: animalChainID(s),
                          category: .animal,
                          displayName: s.name,
                          tiers: tiers)
    }
}
