//
//  CardSystem.swift
//  PawSanctuary
//
//  Card packs, collectible albums, star shop, and energy pack IAP bundles.
//

import SwiftUI

// ============================================================
// MARK: - RARITY
// ============================================================

enum CardRarity: String, CaseIterable, Codable {
    case common
    case rare

    var displayName: String { self == .common ? "Common" : "Rare" }
    var duplicateStars: Int { self == .rare ? 5 : 1 }

    var borderColor: Color {
        self == .rare
            ? Color(red: 0.88, green: 0.68, blue: 0.15)
            : Color(red: 0.62, green: 0.62, blue: 0.68)
    }
    var glowColor: Color {
        self == .rare
            ? Color(red: 0.88, green: 0.68, blue: 0.15).opacity(0.35)
            : .clear
    }
}

// ============================================================
// MARK: - CARD DEFINITION
// ============================================================

struct CardDefinition: Identifiable, Equatable {
    let id: String
    let albumID: String
    let name: String
    let rarity: CardRarity
    let sfSymbol: String
}

// ============================================================
// MARK: - ALBUM DEFINITION
// ============================================================

struct CardAlbumDefinition: Identifiable {
    let id: String
    let name: String
    let description: String
    let sfSymbol: String
    let cardIDs: [String]
    let rewardKibble: Int
    let rewardDogTags: Int
    let rewardCoins: Int
}

// ============================================================
// MARK: - PACK TYPE  (1-star through 6-star)
// ============================================================

enum CardPackType: String, CaseIterable, Codable {
    case star1, star2, star3, star4, star5, star6

    // MARK: Custom Codable — remaps legacy rawValues from v10 saves
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        let remapped: String
        switch raw {
        case "basic": remapped = "star2"
        case "star":  remapped = "star4"
        case "mega":  remapped = "star6"
        default:      remapped = raw
        }
        guard let value = CardPackType(rawValue: remapped) else {
            throw DecodingError.dataCorruptedError(in: container,
                debugDescription: "Unknown CardPackType: \(raw)")
        }
        self = value
    }

    var stars: Int {
        switch self { case .star1: return 1; case .star2: return 2; case .star3: return 3
                      case .star4: return 4; case .star5: return 5; case .star6: return 6 }
    }

    var displayName: String { "\(stars)-Star Pack" }

    var sfSymbol: String {
        switch stars {
        case 1, 2: return "star.fill"
        case 3, 4: return "star.circle.fill"
        default:   return "sparkles"
        }
    }

    var accentColor: Color {
        switch self {
        case .star1: return Color(red: 0.50, green: 0.55, blue: 0.70)
        case .star2: return Color(red: 0.30, green: 0.55, blue: 0.75)
        case .star3: return Color(red: 0.40, green: 0.65, blue: 0.40)
        case .star4: return Color(red: 0.70, green: 0.50, blue: 0.15)
        case .star5: return Color(red: 0.78, green: 0.35, blue: 0.12)
        case .star6: return Color(red: 0.65, green: 0.20, blue: 0.75)
        }
    }

    /// Cards drawn per pack.
    var totalCards: Int {
        switch self {
        case .star1, .star2: return 2
        case .star3:         return 3
        case .star4:         return 4
        case .star5:         return 5
        case .star6:         return 6
        }
    }

    /// Draws that are guaranteed to be rare.
    var guaranteedRares: Int {
        switch self {
        case .star1, .star2, .star3: return 0
        case .star4:                 return 1
        case .star5:                 return 2
        case .star6:                 return 3
        }
    }

    /// Probability that a non-guaranteed draw is rare.
    var rareDrawChance: Double {
        switch self {
        case .star1: return 0.05
        case .star2: return 0.15
        case .star3: return 0.25
        case .star4: return 0.30
        case .star5: return 0.40
        case .star6: return 0.50
        }
    }

    /// Star shop cost, or nil if this tier is not buyable with stars.
    var starShopCost: Int? {
        switch self {
        case .star1: return 20
        case .star2: return 35
        case .star3: return 55
        default:     return nil   // 4★–6★ earned through gameplay / IAP only
        }
    }
}

// ============================================================
// MARK: - STAR SHOP ITEM
// ============================================================

enum StarShopItem: String, CaseIterable {
    case pack1Star, pack2Star, pack3Star
    case jokerCard, rareJokerCard

    var displayName: String {
        switch self {
        case .pack1Star:     return "1-Star Pack"
        case .pack2Star:     return "2-Star Pack"
        case .pack3Star:     return "3-Star Pack"
        case .jokerCard:     return "Joker Card"
        case .rareJokerCard: return "Rare Joker"
        }
    }
    var description: String {
        switch self {
        case .pack1Star:     return "2 random cards"
        case .pack2Star:     return "2 cards, better odds"
        case .pack3Star:     return "3 cards"
        case .jokerCard:     return "Fills any missing common"
        case .rareJokerCard: return "Fills any missing rare"
        }
    }
    var starCost: Int {
        switch self {
        case .pack1Star:     return 20
        case .pack2Star:     return 35
        case .pack3Star:     return 55
        case .jokerCard:     return 40
        case .rareJokerCard: return 120
        }
    }
    var sfSymbol: String {
        switch self {
        case .pack1Star, .pack2Star, .pack3Star: return "star.circle.fill"
        case .jokerCard, .rareJokerCard:         return "j.circle.fill"
        }
    }
    var sfSymbolColor: Color {
        switch self {
        case .pack1Star:     return Color(red: 0.50, green: 0.55, blue: 0.70)
        case .pack2Star:     return Color(red: 0.30, green: 0.55, blue: 0.75)
        case .pack3Star:     return Color(red: 0.40, green: 0.65, blue: 0.40)
        case .jokerCard:     return Color(red: 0.25, green: 0.60, blue: 0.40)
        case .rareJokerCard: return Color(red: 0.88, green: 0.68, blue: 0.15)
        }
    }
    /// The pack type granted when this shop item is bought (nil for jokers).
    var grantsPack: CardPackType? {
        switch self {
        case .pack1Star: return .star1
        case .pack2Star: return .star2
        case .pack3Star: return .star3
        default:         return nil
        }
    }
}

// ============================================================
// MARK: - ENERGY PACK CONTENTS  (used by IAP energy packs)
// ============================================================

struct EnergyPackContents {
    let kibble: Int
    let dogTags: Int
    let spawnerLevel: ProducerLevel
    let spawnerCount: Int
    let cardPack: CardPackType
    let previewPrice: String   // display-only placeholder; real price from StoreKit
}

// ============================================================
// MARK: - OPENED CARD  (transient result of opening a pack)
// ============================================================

struct OpenedCard: Identifiable {
    let id = UUID()
    let definition: CardDefinition
    let wasDuplicate: Bool
    let starsEarned: Int
}

// ============================================================
// MARK: - CARD REGISTRY  (54 cards across 6 albums — placeholder names)
// ============================================================

enum CardRegistry {

    // MARK: Albums

    static let albums: [CardAlbumDefinition] = [
        CardAlbumDefinition(
            id: "album.rescue",
            name: "Rescue Profiles",
            description: "Stories from the rescue journey",
            sfSymbol: "pawprint.fill",
            cardIDs: allCards.filter { $0.albumID == "album.rescue" }.map(\.id),
            rewardKibble: 30, rewardDogTags: 5, rewardCoins: 0
        ),
        CardAlbumDefinition(
            id: "album.sanctuary",
            name: "Sanctuary Friends",
            description: "The people and places that make it happen",
            sfSymbol: "house.fill",
            cardIDs: allCards.filter { $0.albumID == "album.sanctuary" }.map(\.id),
            rewardKibble: 0, rewardDogTags: 8, rewardCoins: 50
        ),
        CardAlbumDefinition(
            id: "album.wildlife",
            name: "Animal Kingdom",
            description: "Portraits of the residents",
            sfSymbol: "hare.fill",
            cardIDs: allCards.filter { $0.albumID == "album.wildlife" }.map(\.id),
            rewardKibble: 40, rewardDogTags: 10, rewardCoins: 100
        ),
        CardAlbumDefinition(
            id: "album.vet",
            name: "Vet Records",
            description: "The medical side of rescue",
            sfSymbol: "cross.fill",
            cardIDs: allCards.filter { $0.albumID == "album.vet" }.map(\.id),
            rewardKibble: 50, rewardDogTags: 12, rewardCoins: 75
        ),
        CardAlbumDefinition(
            id: "album.adventures",
            name: "Adventures Abroad",
            description: "Field rescues and outreach events",
            sfSymbol: "map.fill",
            cardIDs: allCards.filter { $0.albumID == "album.adventures" }.map(\.id),
            rewardKibble: 60, rewardDogTags: 15, rewardCoins: 150
        ),
        CardAlbumDefinition(
            id: "album.fame",
            name: "Hall of Fame",
            description: "The sanctuary's most legendary animals",
            sfSymbol: "crown.fill",
            cardIDs: allCards.filter { $0.albumID == "album.fame" }.map(\.id),
            rewardKibble: 100, rewardDogTags: 25, rewardCoins: 250
        ),
    ]

    static let albumsByID: [String: CardAlbumDefinition] =
        Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })

    // MARK: Cards  (7 common + 2 rare per album = 54 total)

    static let allCards: [CardDefinition] = [

        // ── Album 1: Rescue Profiles ─────────────────────────
        CardDefinition(id: "rescue.c1", albumID: "album.rescue", name: "Stray Found",    rarity: .common, sfSymbol: "pawprint.fill"),
        CardDefinition(id: "rescue.c2", albumID: "album.rescue", name: "Health Check",   rarity: .common, sfSymbol: "heart.fill"),
        CardDefinition(id: "rescue.c3", albumID: "album.rescue", name: "Shelter Spot",   rarity: .common, sfSymbol: "house.fill"),
        CardDefinition(id: "rescue.c4", albumID: "album.rescue", name: "Bath Day",       rarity: .common, sfSymbol: "drop.fill"),
        CardDefinition(id: "rescue.c5", albumID: "album.rescue", name: "Playtime",       rarity: .common, sfSymbol: "star.fill"),
        CardDefinition(id: "rescue.c6", albumID: "album.rescue", name: "Training Day",   rarity: .common, sfSymbol: "graduationcap.fill"),
        CardDefinition(id: "rescue.c7", albumID: "album.rescue", name: "Foster Home",    rarity: .common, sfSymbol: "person.fill"),
        CardDefinition(id: "rescue.r1", albumID: "album.rescue", name: "Adoption Day!",  rarity: .rare,   sfSymbol: "sparkles"),
        CardDefinition(id: "rescue.r2", albumID: "album.rescue", name: "Ambassador",     rarity: .rare,   sfSymbol: "medal.fill"),

        // ── Album 2: Sanctuary Friends ───────────────────────
        CardDefinition(id: "sanctuary.c1", albumID: "album.sanctuary", name: "Volunteer",    rarity: .common, sfSymbol: "person.fill"),
        CardDefinition(id: "sanctuary.c2", albumID: "album.sanctuary", name: "Vet Visit",    rarity: .common, sfSymbol: "cross.fill"),
        CardDefinition(id: "sanctuary.c3", albumID: "album.sanctuary", name: "Feeding Time", rarity: .common, sfSymbol: "fork.knife"),
        CardDefinition(id: "sanctuary.c4", albumID: "album.sanctuary", name: "Sun & Play",   rarity: .common, sfSymbol: "sun.max.fill"),
        CardDefinition(id: "sanctuary.c5", albumID: "album.sanctuary", name: "Nap Time",     rarity: .common, sfSymbol: "moon.fill"),
        CardDefinition(id: "sanctuary.c6", albumID: "album.sanctuary", name: "New Arrival",  rarity: .common, sfSymbol: "shippingbox.fill"),
        CardDefinition(id: "sanctuary.c7", albumID: "album.sanctuary", name: "Daily Rounds", rarity: .common, sfSymbol: "doc.fill"),
        CardDefinition(id: "sanctuary.r1", albumID: "album.sanctuary", name: "Top Volunteer", rarity: .rare,  sfSymbol: "rosette"),
        CardDefinition(id: "sanctuary.r2", albumID: "album.sanctuary", name: "Legend",        rarity: .rare,  sfSymbol: "trophy.fill"),

        // ── Album 3: Animal Kingdom ──────────────────────────
        CardDefinition(id: "wildlife.c1", albumID: "album.wildlife", name: "Puppy",         rarity: .common, sfSymbol: "pawprint.circle.fill"),
        CardDefinition(id: "wildlife.c2", albumID: "album.wildlife", name: "Kitten",        rarity: .common, sfSymbol: "hare.fill"),
        CardDefinition(id: "wildlife.c3", albumID: "album.wildlife", name: "Rabbit",        rarity: .common, sfSymbol: "leaf.fill"),
        CardDefinition(id: "wildlife.c4", albumID: "album.wildlife", name: "Song Bird",     rarity: .common, sfSymbol: "bird.fill"),
        CardDefinition(id: "wildlife.c5", albumID: "album.wildlife", name: "Hamster",       rarity: .common, sfSymbol: "tortoise.fill"),
        CardDefinition(id: "wildlife.c6", albumID: "album.wildlife", name: "Turtle",        rarity: .common, sfSymbol: "fish.fill"),
        CardDefinition(id: "wildlife.c7", albumID: "album.wildlife", name: "Fox",           rarity: .common, sfSymbol: "flame.fill"),
        CardDefinition(id: "wildlife.r1", albumID: "album.wildlife", name: "Owl at Dusk",   rarity: .rare,   sfSymbol: "moon.stars.fill"),
        CardDefinition(id: "wildlife.r2", albumID: "album.wildlife", name: "Perfect Rescue", rarity: .rare,  sfSymbol: "crown.fill"),

        // ── Album 4: Vet Records ─────────────────────────────
        CardDefinition(id: "vet.c1", albumID: "album.vet", name: "First Exam",      rarity: .common, sfSymbol: "stethoscope"),
        CardDefinition(id: "vet.c2", albumID: "album.vet", name: "X-Ray",           rarity: .common, sfSymbol: "waveform.path.ecg"),
        CardDefinition(id: "vet.c3", albumID: "album.vet", name: "Vaccine Day",     rarity: .common, sfSymbol: "syringe.fill"),
        CardDefinition(id: "vet.c4", albumID: "album.vet", name: "Recovery Ward",   rarity: .common, sfSymbol: "bed.double.fill"),
        CardDefinition(id: "vet.c5", albumID: "album.vet", name: "Microchipped",    rarity: .common, sfSymbol: "cpu.fill"),
        CardDefinition(id: "vet.c6", albumID: "album.vet", name: "Clean Bill",      rarity: .common, sfSymbol: "checkmark.seal.fill"),
        CardDefinition(id: "vet.c7", albumID: "album.vet", name: "Follow-Up",       rarity: .common, sfSymbol: "calendar.badge.checkmark"),
        CardDefinition(id: "vet.r1", albumID: "album.vet", name: "Miracle Case",    rarity: .rare,   sfSymbol: "staroflife.fill"),
        CardDefinition(id: "vet.r2", albumID: "album.vet", name: "Chief of Staff",  rarity: .rare,   sfSymbol: "person.badge.shield.checkmark.fill"),

        // ── Album 5: Adventures Abroad ───────────────────────
        CardDefinition(id: "adventure.c1", albumID: "album.adventures", name: "Field Call",      rarity: .common, sfSymbol: "map.fill"),
        CardDefinition(id: "adventure.c2", albumID: "album.adventures", name: "Rescue Van",      rarity: .common, sfSymbol: "car.fill"),
        CardDefinition(id: "adventure.c3", albumID: "album.adventures", name: "Net Cast",        rarity: .common, sfSymbol: "wind"),
        CardDefinition(id: "adventure.c4", albumID: "album.adventures", name: "Night Rescue",    rarity: .common, sfSymbol: "flashlight.on.fill"),
        CardDefinition(id: "adventure.c5", albumID: "album.adventures", name: "Park Patrol",     rarity: .common, sfSymbol: "figure.walk"),
        CardDefinition(id: "adventure.c6", albumID: "album.adventures", name: "Community Fair",  rarity: .common, sfSymbol: "building.2.fill"),
        CardDefinition(id: "adventure.c7", albumID: "album.adventures", name: "Safe Return",     rarity: .common, sfSymbol: "house.and.flag.fill"),
        CardDefinition(id: "adventure.r1", albumID: "album.adventures", name: "Hero of the Day", rarity: .rare,   sfSymbol: "bolt.shield.fill"),
        CardDefinition(id: "adventure.r2", albumID: "album.adventures", name: "Grand Rescue",    rarity: .rare,   sfSymbol: "flag.2.crossed.fill"),

        // ── Album 6: Hall of Fame ────────────────────────────
        CardDefinition(id: "fame.c1", albumID: "album.fame", name: "First 100",         rarity: .common, sfSymbol: "100.circle.fill"),
        CardDefinition(id: "fame.c2", albumID: "album.fame", name: "Speed Record",      rarity: .common, sfSymbol: "bolt.fill"),
        CardDefinition(id: "fame.c3", albumID: "album.fame", name: "Media Feature",     rarity: .common, sfSymbol: "newspaper.fill"),
        CardDefinition(id: "fame.c4", albumID: "album.fame", name: "Community Award",   rarity: .common, sfSymbol: "rosette"),
        CardDefinition(id: "fame.c5", albumID: "album.fame", name: "Top Adopter",       rarity: .common, sfSymbol: "person.2.fill"),
        CardDefinition(id: "fame.c6", albumID: "album.fame", name: "Five-Star Review",  rarity: .common, sfSymbol: "star.leadinghalf.filled"),
        CardDefinition(id: "fame.c7", albumID: "album.fame", name: "The Comeback",      rarity: .common, sfSymbol: "arrow.circlepath"),
        CardDefinition(id: "fame.r1", albumID: "album.fame", name: "Sanctuary of Year", rarity: .rare,   sfSymbol: "building.columns.fill"),
        CardDefinition(id: "fame.r2", albumID: "album.fame", name: "Legendary Bond",    rarity: .rare,   sfSymbol: "heart.fill"),
    ]

    static let cardsByID: [String: CardDefinition] =
        Dictionary(uniqueKeysWithValues: allCards.map { ($0.id, $0) })

    static let commonCards: [CardDefinition] = allCards.filter { $0.rarity == .common }
    static let rareCards:   [CardDefinition] = allCards.filter { $0.rarity == .rare }

    // MARK: Drawing

    static func drawCards(from type: CardPackType) -> [CardDefinition] {
        var drawn: [CardDefinition] = []

        for _ in 0..<type.guaranteedRares {
            if let card = rareCards.randomElement() { drawn.append(card) }
        }

        let remaining = type.totalCards - type.guaranteedRares
        for _ in 0..<remaining {
            let hitRare = Double.random(in: 0..<1) < type.rareDrawChance
            let pool: [CardDefinition] = hitRare ? rareCards : commonCards
            if let card = pool.randomElement() { drawn.append(card) }
        }

        return drawn.shuffled()
    }
}
