//
//  AnimalSpecies.swift  —  Data models & constants
//  PawSanctuary
//

import SwiftUI

// ============================================================
// MARK: - ANIMAL SPECIES
// ============================================================

enum AnimalSpecies: String, CaseIterable, Codable {
    // rawValues are unchanged — existing saves and ChainIDs stay valid.
    // Each case maps to a new animal family; the family name is in `name`.
    case dog, cat, rabbit, bird, hamster, turtle, fox, owl
    case fish, lizard, ferret, parrot, pony, hedgehog, guineaPig

    /// Family display name (shown in the chain list and MergeProgressionView).
    var name: String {
        switch self {
        case .dog:       return "Canines"
        case .cat:       return "Felines"
        case .rabbit:    return "Lagomorphs"
        case .bird:      return "Avians"
        case .hamster:   return "Rodents"
        case .turtle:    return "Reptiles"
        case .fox:       return "Cervids"
        case .owl:       return "Ursids"
        case .fish:      return "Aquatics"
        case .lizard:    return "Amphibians"
        case .ferret:    return "Marsupials"
        case .parrot:    return "Primates"
        case .pony:      return "Equines"
        case .hedgehog:  return "Pachyderms"
        case .guineaPig: return "Bovines"
        }
    }

    /// SF Symbol used as the icon on board tiles for each family.
    var sfSymbol: String {
        switch self {
        case .dog:       return "dog.fill"
        case .cat:       return "cat.fill"
        case .rabbit:    return "hare.fill"
        case .bird:      return "bird.fill"
        case .hamster:   return "pawprint.fill"
        case .turtle:    return "lizard.fill"
        case .fox:       return "leaf.fill"
        case .owl:       return "pawprint.circle.fill"
        case .fish:      return "fish.fill"
        case .lizard:    return "tortoise.fill"
        case .ferret:    return "figure.walk"
        case .parrot:    return "figure.arms.open"
        case .pony:      return "hare.fill"
        case .hedgehog:  return "circle.hexagongrid.fill"
        case .guineaPig: return "horn.blast.fill"
        }
    }

    /// Per-family tint colour so each chain is visually distinct.
    var tintColor: Color {
        switch self {
        case .dog:       return Color(red: 0.60, green: 0.40, blue: 0.20)  // warm brown — Canines
        case .cat:       return Color(red: 0.50, green: 0.50, blue: 0.55)  // slate — Felines
        case .rabbit:    return Color(red: 0.90, green: 0.75, blue: 0.65)  // dusty pink — Lagomorphs
        case .bird:      return Color(red: 0.25, green: 0.55, blue: 0.90)  // sky blue — Avians
        case .hamster:   return Color(red: 0.95, green: 0.70, blue: 0.30)  // amber — Rodents
        case .turtle:    return Color(red: 0.75, green: 0.25, blue: 0.20)  // brick red — Reptiles
        case .fox:       return Color(red: 0.35, green: 0.60, blue: 0.30)  // forest green — Cervids
        case .owl:       return Color(red: 0.55, green: 0.38, blue: 0.22)  // bark brown — Ursids
        case .fish:      return Color(red: 0.20, green: 0.60, blue: 0.80)  // ocean blue — Aquatics
        case .lizard:    return Color(red: 0.30, green: 0.65, blue: 0.50)  // swamp green — Amphibians
        case .ferret:    return Color(red: 0.75, green: 0.42, blue: 0.62)  // dusty rose — Marsupials
        case .parrot:    return Color(red: 0.58, green: 0.32, blue: 0.70)  // plum — Primates
        case .pony:      return Color(red: 0.65, green: 0.48, blue: 0.28)  // tan — Equines
        case .hedgehog:  return Color(red: 0.50, green: 0.48, blue: 0.55)  // grey-purple — Pachyderms
        case .guineaPig: return Color(red: 0.70, green: 0.52, blue: 0.18)  // golden — Bovines
        }
    }

    // MARK: Phase 3 — per-family spawner & sub-object data

    /// Display name of the family-specific spawner object on the board.
    var spawnerName: String {
        switch self {
        case .dog:       return "Antique Dog House"
        case .cat:       return "Scratching Post"
        case .rabbit:    return "Garden Hutch"
        case .bird:      return "Decorative Birdhouse"
        case .hamster:   return "Wooden Burrow"
        case .turtle:    return "Heated Rock"
        case .fox:       return "Forest Thicket"
        case .owl:       return "Hollow Log"
        case .fish:      return "Coral Reef"
        case .lizard:    return "Lily Pad"
        case .ferret:    return "Eucalyptus Branch"
        case .parrot:    return "Tropical Tree"
        case .pony:      return "Stable Gate"
        case .hedgehog:  return "Watering Hole"
        case .guineaPig: return "Rustic Milk Pail"
        }
    }

    /// SF Symbol used to represent the family spawner on the board.
    var spawnerSFSymbol: String {
        switch self {
        case .dog:       return "house.fill"
        case .cat:       return "rectangle.split.3x1.fill"
        case .rabbit:    return "leaf.fill"
        case .bird:      return "bird.fill"
        case .hamster:   return "tunnel.fill"
        case .turtle:    return "oval.fill"
        case .fox:       return "tree.fill"
        case .owl:       return "tree.fill"
        case .fish:      return "water.waves"
        case .lizard:    return "leaf.circle.fill"
        case .ferret:    return "tree.fill"
        case .parrot:    return "tree.circle.fill"
        case .pony:      return "door.garage.closed"
        case .hedgehog:  return "drop.circle.fill"
        case .guineaPig: return "bucket.fill"
        }
    }

    /// The 12 unique tier names for this family, index 0 (smallest) through 11 (top tier).
    ///
    /// Four conceptual eras of three. Phase 2b dropped the fourth era of five
    /// (old indices 9–11) because Phase 2's tuning capped order tiers at 9 against
    /// a 15-tier chain, leaving the top six stages outside the order economy
    /// entirely. At 12 tiers the top item costs 2,048 kibble rather than 16,384 —
    /// about 2.7 days of total income instead of 22 — so it is orderable again.
    var tierNames: [String] {
        switch self {
        case .dog:       return ["Pup", "Kit", "Houndling",
                                 "Terrier", "Spaniel", "Scout",
                                 "Retriever", "Shepherd", "Husky",
                                 "Dire Wolf", "Mythic", "Primordial"]
        case .cat:       return ["Kitten", "Tabby", "Kit",
                                 "Ocelot", "Bobcat", "Lynx",
                                 "Puma", "Jaguar", "Leopard",
                                 "Sabertooth", "Sovereign", "Apex"]
        case .rabbit:    return ["Bunny", "Cottontail", "Rex",
                                 "Angora", "Lop", "Harlequin",
                                 "Hare", "Jackrabbit", "Snow",
                                 "Desert", "Patagonian", "Mara"]
        case .bird:      return ["Hatchling", "Chick", "Fluff",
                                 "Sparrow", "Finch", "Starling",
                                 "Pigeon", "Magpie", "Jay",
                                 "Eagle", "Vulture", "Condor"]
        case .hamster:   return ["Mouse", "Hamster", "Gerbil",
                                 "Chipmunk", "Squirrel", "Rat",
                                 "Chinchilla", "Degu", "Beaver",
                                 "Muskrat", "Porcupine", "Capybara"]
        case .turtle:    return ["Hatch", "Gecko", "Anole",
                                 "Skink", "Racer", "Whiptail",
                                 "Iguana", "Monitor", "Tegu",
                                 "Boa", "Caiman", "Komodo Dragon"]
        case .fox:       return ["Fawn", "Muntjac", "Roe",
                                 "Fallow", "Chital", "Sika",
                                 "Caribou", "Reindeer", "Deer",
                                 "Sambar", "Pere David", "Moose"]
        case .owl:       return ["Cub", "Sun", "Sloth",
                                 "Spectacled", "Moon", "Black",
                                 "Panda", "Cinnamon", "Glacier",
                                 "Polar", "Ancient", "Behemoth"]
        case .fish:      return ["Guppy", "Tetra", "Minnow",
                                 "Clown", "Perch", "Bass",
                                 "Mackerel", "Tuna", "Salmon",
                                 "Shark", "Hammerhead", "Whale Shark"]
        case .lizard:    return ["Tadpole", "Froglet", "Newt",
                                 "Tree Frog", "Poison", "Reed",
                                 "Bullfrog", "Toad", "Horned",
                                 "Hellbender", "Giant", "Goliath"]
        case .ferret:    return ["Joey", "Quokka", "Honey",
                                 "Potoroo", "Bandicoot", "Bilby",
                                 "Wallaby", "Pademelon", "Tree",
                                 "Koala", "Macropod", "Red Kangaroo"]
        case .parrot:    return ["Marmoset", "Tamarin", "Pygmy",
                                 "Squirrel", "Capuchin", "Owl",
                                 "Macaque", "Langur", "Guenon",
                                 "Chimpanzee", "Orangutan", "Gorilla"]
        case .pony:      return ["Foal", "Pony", "Shetland",
                                 "Donkey", "Mule", "Burro",
                                 "Mustang", "Arabian", "Paint",
                                 "Zebra", "Quagga", "Giraffe"]
        case .hedgehog:  return ["Piglet", "Warthog", "Peccary",
                                 "Tapir", "Boar", "Babirusa",
                                 "Hippo", "Pygmy", "Rhino",
                                 "Seal", "African", "Mammoth"]
        case .guineaPig: return ["Calf", "Heifer", "Oxen",
                                 "Steer", "Bull", "Zebu",
                                 "Bison", "Yak", "Muskox",
                                 "Buffalo", "Aurochs", "Titan"]
        }
    }
}

// ============================================================
// MARK: - RESCUE STAGE
// ============================================================

enum RescueStage: Int, CaseIterable, Codable {
    // 9-stage chain — .stray removed; tier names are now per-family (see AnimalSpecies.tierNames).
    // rawValues 1-9 so tierIndex = rawValue - 1 maps to 0-based position in tierNames array.
    case rescued      = 1   // taken into shelter
    case groomed              // cleaned & health-checked
    case vaccinated           // immunised
    case trained              // basic commands mastered
    case foster               // living with a foster family
    case adopted              // placed in a permanent home
    case bondedPair           // inseparable with another adopted animal
    case communityFav         // celebrated local hero
    case ambassador           // top tier – sanctuary ambassador

    /// Full display name — used as fallback in quest descriptions when no tierNames override exists.
    var label: String {
        switch self {
        case .rescued:      return "Rescued"
        case .groomed:      return "Groomed"
        case .vaccinated:   return "Vaccinated"
        case .trained:      return "Trained"
        case .foster:       return "Foster"
        case .adopted:      return "Adopted"
        case .bondedPair:   return "Bonded Pair"
        case .communityFav: return "Community Fav"
        case .ambassador:   return "Ambassador"
        }
    }

    /// Short label that fits inside a 62 pt board cell.
    var shortLabel: String {
        switch self {
        case .rescued:      return "Rescued"
        case .groomed:      return "Groomed"
        case .vaccinated:   return "Vacc'd"
        case .trained:      return "Trained"
        case .foster:       return "Foster"
        case .adopted:      return "Adopted"
        case .bondedPair:   return "Bonded"
        case .communityFav: return "Comm. Fav"
        case .ambassador:   return "Ambass."
        }
    }

    /// Distinct colour for each stage — orange → gold progression.
    var color: Color {
        switch self {
        case .rescued:      return .orange
        case .groomed:      return .blue
        case .vaccinated:   return Color(red: 0.10, green: 0.70, blue: 0.70) // teal
        case .trained:      return Color(red: 0.60, green: 0.30, blue: 0.85) // purple
        case .foster:       return Color(red: 0.80, green: 0.55, blue: 0.10) // amber
        case .adopted:      return .green
        case .bondedPair:   return Color(red: 0.90, green: 0.35, blue: 0.60) // rose
        case .communityFav: return Color(red: 0.95, green: 0.50, blue: 0.10) // coral
        case .ambassador:   return Color(red: 0.95, green: 0.80, blue: 0.10) // gold
        }
    }

    /// SF Symbol representing this stage (used in quest icons).
    var sfSymbol: String {
        switch self {
        case .rescued:      return "heart.fill"
        case .groomed:      return "scissors"
        case .vaccinated:   return "cross.circle.fill"
        case .trained:      return "star.circle.fill"
        case .foster:       return "house.fill"
        case .adopted:      return "checkmark.circle.fill"
        case .bondedPair:   return "person.2.fill"
        case .communityFav: return "crown.fill"
        case .ambassador:   return "medal.fill"
        }
    }

    var next: RescueStage? { RescueStage(rawValue: rawValue + 1) }

    /// 0-based tier index in the generalized chain model (rescued = 0 … ambassador = 8).
    var tierIndex: Int { rawValue - 1 }
}

// ============================================================
// MARK: - PRODUCER TILES
// ============================================================

/// Three-tier merge chain for producer tiles.
/// Two of the same level merge into the next level, Travel Town-style.
enum ProducerLevel: Int, CaseIterable, Codable {
    // Animal rescue producers (merge chain: rescueCrate → shelterPod → fosterHome)
    case rescueCrate = 1   // produces tier 0 (Rescued),  30 s cooldown
    case shelterPod        // produces tier 1 (Groomed),  45 s cooldown
    case fosterHome        // produces tier 2 (Vaccinated), 60 s cooldown

    // Supply producers (Phase 2) — each targets one specific chain; rawValues 10+ avoid
    // colliding with future animal-tier additions and make saves forward-compatible.
    case groomingBox = 10  // produces supply.grooming tier 0, 25 s cooldown, no merge-up
    case feedBox     = 11  // produces supply.food     tier 0, 25 s cooldown, no merge-up
    case shelterBox  = 12  // produces supply.shelter  tier 0, 25 s cooldown, no merge-up

    // Phase 3 — per-family spawner. Uses ProducerTile.species to identify which family.
    // Does NOT appear in the shop (isShopProducer is false) or in the shared per-level
    // producerStorage/overflowProducerStorage — it has its own per-species storage,
    // InventoryStore.familySpawnerStorage, since every family shares this one rawValue.
    case familySpawner = 20

    /// True only for supply producers sold in the Dog Tag shop.
    /// Rescue-tier producers (rescueCrate/shelterPod/fosterHome) are superseded by
    /// family spawners and are excluded; family spawners are earned via the map.
    var isShopProducer: Bool {
        switch self {
        case .groomingBox, .feedBox, .shelterBox: return true
        default: return false
        }
    }

    var displayName: String {
        switch self {
        case .rescueCrate:  return "Rescue Crate"
        case .shelterPod:   return "Shelter Pod"
        case .fosterHome:   return "Foster Home"
        case .groomingBox:  return "Grooming Box"
        case .feedBox:      return "Feed Station"
        case .shelterBox:   return "Supply Crate"
        case .familySpawner: return "Family Spawner"  // display name resolved per-species at call site
        }
    }
    var sfSymbol: String {
        switch self {
        case .rescueCrate:  return "shippingbox.fill"
        case .shelterPod:   return "building.2.fill"
        case .fosterHome:   return "house.and.flag.fill"
        case .groomingBox:  return "comb.fill"
        case .feedBox:      return "bag.fill"
        case .shelterBox:   return "bed.double.fill"
        case .familySpawner: return "house.fill"      // overridden per-species at call site
        }
    }
    var cooldown: Double {
        switch self {
        case .rescueCrate:  return 30; case .shelterPod: return 45; case .fosterHome: return 60
        case .groomingBox, .feedBox, .shelterBox: return 25
        case .familySpawner: return 45
        }
    }
    /// The chain category this producer emits into.
    var targetCategory: ChainCategory {
        switch self {
        case .rescueCrate, .shelterPod, .fosterHome, .familySpawner: return .animal
        case .groomingBox, .feedBox, .shelterBox:                     return .supply
        }
    }
    /// When non-nil, the producer always emits from this specific chain (supply producers).
    /// When nil, a random unlocked chain in `targetCategory` is chosen (animal producers).
    /// Family spawners resolve their chain from ProducerTile.species at the call site.
    var targetChainID: ChainID? {
        switch self {
        case .groomingBox:  return ContentRegistry.groomingChainID
        case .feedBox:      return ContentRegistry.foodChainID
        case .shelterBox:   return ContentRegistry.shelterChainID
        default:            return nil
        }
    }
    /// The tier (0-based) of the item this producer emits.
    var startTier: Int {
        switch self {
        case .rescueCrate: return 0; case .shelterPod: return 1; case .fosterHome: return 2
        case .groomingBox, .feedBox, .shelterBox, .familySpawner: return 0
        }
    }
    var tintColor: Color {
        switch self {
        case .rescueCrate:  return Color(red: 0.60, green: 0.40, blue: 0.20)
        case .shelterPod:   return Color(red: 0.30, green: 0.50, blue: 0.75)
        case .fosterHome:   return Color(red: 0.25, green: 0.60, blue: 0.40)
        case .groomingBox:  return Color(red: 0.25, green: 0.65, blue: 0.60)
        case .feedBox:      return Color(red: 0.80, green: 0.55, blue: 0.18)
        case .shelterBox:   return Color(red: 0.65, green: 0.48, blue: 0.30)
        case .familySpawner: return Color(red: 0.50, green: 0.40, blue: 0.70)
        }
    }
    /// Cost in Dog Tags to buy this producer from the shop (supply/family producers: 0).
    var dogTagCost: Int {
        switch self {
        case .rescueCrate: return 5; case .shelterPod: return 15; case .fosterHome: return 30
        case .groomingBox, .feedBox, .shelterBox, .familySpawner: return 0
        }
    }
    /// Number of times this producer can fire before it disappears from the board.
    var maxCharges: Int {
        switch self {
        case .rescueCrate: return 5; case .shelterPod: return 8; case .fosterHome: return 12
        case .groomingBox, .feedBox, .shelterBox: return 6
        case .familySpawner: return 8
        }
    }
    /// Next tier in the merge chain, or nil if this producer cannot be merged up.
    var next: ProducerLevel? {
        switch self {
        case .rescueCrate: return .shelterPod
        case .shelterPod:  return .fosterHome
        case .fosterHome, .groomingBox, .feedBox, .shelterBox, .familySpawner: return nil
        }
    }

    /// Player level required before this producer's designated storage slot is available.
    var storageUnlockLevel: Int {
        switch self {
        case .rescueCrate:   return 1
        case .shelterPod:    return 4
        case .fosterHome:    return 7
        case .groomingBox:   return 15
        case .feedBox:       return 20
        case .shelterBox:    return 25
        case .familySpawner: return 1   // familySpawnerStorage has no level gate — value unused
        }
    }
}

struct ProducerTile: Identifiable, Equatable, Codable {
    var id: UUID
    var level: ProducerLevel

    /// Wall-clock time this producer's cooldown finishes; a time already in the
    /// past (default `.distantPast`) means ready. Replaces a `cooldownRemaining:
    /// Double` that used to be decremented by hand every second in
    /// `MergeBoardViewModel.tickProducers` — that mattered because `board` is a
    /// plain array on an `@Observable` class, so ticking down a stored countdown
    /// on any *one* producer forced every one of the 63 board cells to
    /// re-render every second, all session, for as long as any non-family-
    /// spawner producer was cooling down (i.e. most of an active session).
    /// Deriving the countdown from a fixed timestamp instead means advancing
    /// time — including catching up after the app was backgrounded — is just
    /// "compare to `Date()`": no per-second board mutation, and no special-
    /// cased offline-progress math either.
    var readyAt: Date = .distantPast
    var chargesRemaining: Int
    /// Non-nil for `.familySpawner` tiles; identifies which family's animal chain this spawner produces.
    var species: AnimalSpecies?

    /// Wall-clock time an active Speed Burst ends; nil (or already past) means
    /// no burst is running. `applySpeedBurst(duration:)` folds the burst's 2x
    /// cooldown rate into `readyAt` in closed form at the moment the burst
    /// starts, for the same reason `readyAt` itself exists — see its doc
    /// comment. Re-applying a burst while one is already active (stacking two
    /// power-ups on the same tile inside the same short window) recomputes
    /// from the then-current remaining time; that's self-consistent and never
    /// makes the cooldown worse, even though it isn't a perfectly exact model
    /// of two overlapping acceleration windows — a rare enough edge case that
    /// the simplification isn't worth the extra bookkeeping.
    var speedBurstEndsAt: Date? = nil
    var nextDropGuaranteedHighTier: Bool = false

    // Phase 6 — Avians Scout preview: non-nil when Scout is unlocked and a spawn has just fired.
    // true = next spawn from this tile will be a sub-object, false = animal.
    var scoutPreviewIsSubObject: Bool? = nil

    init(level: ProducerLevel, cooldownRemaining: Double = 0,
         chargesRemaining: Int? = nil, species: AnimalSpecies? = nil) {
        self.id = UUID()
        self.level = level
        self.readyAt = cooldownRemaining > 0 ? Date().addingTimeInterval(cooldownRemaining) : .distantPast
        self.chargesRemaining = chargesRemaining ?? level.maxCharges
        self.species = species
    }

    private enum CodingKeys: String, CodingKey {
        case id, level, readyAt, chargesRemaining, species, speedBurstEndsAt
        case nextDropGuaranteedHighTier, scoutPreviewIsSubObject
        // Legacy keys — decode-only. Old saves persisted a hand-ticked
        // `cooldownRemaining` Double and `speedBurstActive`/`speedBurstRemaining`
        // instead of the Date-based fields above; encode(to:) never writes
        // these again, matching how v24→v25 dropped superseded reward fields
        // rather than leaving them as unused JSON (see GameStore.swift).
        case cooldownRemaining, speedBurstActive, speedBurstRemaining
    }

    // Custom codable so old saves (missing "species", or still on the legacy
    // cooldownRemaining/speedBurstActive/speedBurstRemaining shape) decode
    // cleanly. No GameStore schema version bump needed — same as the earlier
    // additions here (species, speedBurstActive, ...) — because it's handled
    // locally at this leaf type and every shape a save might carry, old or
    // new, still decodes through the existing version dispatch.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id    = try c.decode(UUID.self,          forKey: .id)
        level = try c.decode(ProducerLevel.self, forKey: .level)
        if let readyAt = try c.decodeIfPresent(Date.self, forKey: .readyAt) {
            self.readyAt = readyAt
        } else {
            let legacyRemaining = try c.decodeIfPresent(Double.self, forKey: .cooldownRemaining) ?? 0
            self.readyAt = legacyRemaining > 0 ? Date().addingTimeInterval(legacyRemaining) : .distantPast
        }
        chargesRemaining = try c.decode(Int.self, forKey: .chargesRemaining)
        species          = try c.decodeIfPresent(AnimalSpecies.self, forKey: .species)
        if let burstEndsAt = try c.decodeIfPresent(Date.self, forKey: .speedBurstEndsAt) {
            self.speedBurstEndsAt = burstEndsAt
        } else if try c.decodeIfPresent(Bool.self, forKey: .speedBurstActive) == true {
            let legacyBurstRemaining = try c.decodeIfPresent(Double.self, forKey: .speedBurstRemaining) ?? 0
            self.speedBurstEndsAt = legacyBurstRemaining > 0 ? Date().addingTimeInterval(legacyBurstRemaining) : nil
        }
        nextDropGuaranteedHighTier = try c.decodeIfPresent(Bool.self, forKey: .nextDropGuaranteedHighTier) ?? false
        scoutPreviewIsSubObject    = try c.decodeIfPresent(Bool.self, forKey: .scoutPreviewIsSubObject)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(level, forKey: .level)
        try c.encode(readyAt, forKey: .readyAt)
        try c.encode(chargesRemaining, forKey: .chargesRemaining)
        try c.encodeIfPresent(species, forKey: .species)
        try c.encodeIfPresent(speedBurstEndsAt, forKey: .speedBurstEndsAt)
        try c.encode(nextDropGuaranteedHighTier, forKey: .nextDropGuaranteedHighTier)
        try c.encodeIfPresent(scoutPreviewIsSubObject, forKey: .scoutPreviewIsSubObject)
    }

    var isReady: Bool { readyAt <= Date() }
    /// Seconds until ready, derived live from `readyAt` — never stale, never ticked by hand.
    var cooldownRemaining: Double { max(0, readyAt.timeIntervalSinceNow) }
    /// 0 = fully charged, 1 = just fired (used to drive the cooldown ring).
    var cooldownFraction: Double { max(0, min(1, cooldownRemaining / level.cooldown)) }
    /// For family spawners: the animal chain this tile produces. Nil for other producer types.
    var animalChainID: ChainID? { species.map { ContentRegistry.animalChainID($0) } }

    var speedBurstActive: Bool { (speedBurstEndsAt ?? .distantPast) > Date() }
    var speedBurstRemaining: Double { max(0, (speedBurstEndsAt ?? .distantPast).timeIntervalSinceNow) }

    /// Starts (or restarts) this producer's cooldown at its level's full duration.
    mutating func startCooldown(now: Date = Date()) {
        readyAt = now.addingTimeInterval(level.cooldown)
    }

    /// Folds an accelerated (2x-rate) window into `readyAt` in one step rather
    /// than needing a per-tick rate multiplier — see `speedBurstEndsAt`'s doc
    /// comment for the reasoning and the reapplication caveat. Closed form:
    /// at 2x rate, `remaining` cooldown-seconds burn down in `remaining / 2`
    /// real seconds; if that's within the burst window, that's the new ready
    /// time. Otherwise the burst only partially covers the cooldown, and the
    /// rest continues at the normal 1x rate after the burst ends.
    mutating func applySpeedBurst(duration: TimeInterval, now: Date = Date()) {
        let remaining = max(0, readyAt.timeIntervalSince(now))
        let newRemaining = remaining <= 2 * duration ? remaining / 2 : remaining - duration
        readyAt = now.addingTimeInterval(newRemaining)
        speedBurstEndsAt = now.addingTimeInterval(duration)
    }
}

// ============================================================
// MARK: - BOARD MODELS
// ============================================================

// (MergeItem removed in Phase 0 — replaced by BoardItem in ItemChain.swift.
//  AnimalSpecies / RescueStage remain as the authoring source for animal chains.)

struct GridPosition: Equatable, Hashable, Codable {
    var row: Int, col: Int
}

struct BoardCell: Identifiable, Codable {
    var position: GridPosition
    var item: BoardItem?           // a merge tile (any chain) — nil when empty or has a producer
    var producer: ProducerTile?    // a generator tile — nil when empty or has an item
    var isUnlocked: Bool

    /// Stable identity for SwiftUI's ForEach diffing — a board cell's identity is its
    /// grid position, not a per-copy UUID (which regenerated on every mutation and broke
    /// merge/unlock animations that rely on identity to interpolate between states).
    var id: GridPosition { position }

    /// A cell is empty when it holds neither an animal nor a producer.
    var isEmpty: Bool { item == nil && producer == nil }
}

// ============================================================
// MARK: - QUEST / CHALLENGE MODELS
// ============================================================

enum QuestDifficulty: String, Codable {
    case easy = "Easy", medium = "Medium", hard = "Hard", legendary = "Legendary"

    var kibbleReward: Int {
        switch self {
        case .easy:      return 2
        case .medium:    return 4
        case .hard:      return 8
        case .legendary: return 20
        }
    }
    /// Coins awarded when the player claims a completed quest of this difficulty.
    ///
    /// Rescaled in Phase 2c. Rationale: a quest spans many merges, so it should
    /// pay more than the single order it competes with for attention — a
    /// legendary quest is worth about 2.5 average orders (~400 coins each), an
    /// easy one about an eighth of that. Was 2/5/10/25, which a single tier-3
    /// order now beats several times over.
    var coinReward: Int {
        switch self {
        case .easy:      return 50
        case .medium:    return 150
        case .hard:      return 400
        case .legendary: return 1_000
        }
    }
    var color: Color {
        switch self {
        case .easy:      return .green
        case .medium:    return .orange
        case .hard:      return .red
        case .legendary: return Color(red: 0.60, green: 0.20, blue: 0.90) // deep purple-gold
        }
    }
    var isLegendary: Bool { self == .legendary }

    /// XP awarded when the player claims a quest of this difficulty.
    var xpReward: Int {
        switch self { case .easy: return 10; case .medium: return 25; case .hard: return 50; case .legendary: return 150 }
    }
}

enum QuestGoal: Codable {
    case mergeAny(count: Int)
    case mergeInChain(ChainID, count: Int)                  // was mergeSpecies(AnimalSpecies)
    case reachTier(ChainCategory, tier: Int, count: Int)    // was reachStage(RescueStage)
    case spawnBase(count: Int)                              // was rescueStrays

    var targetCount: Int {
        switch self {
        case .mergeAny(let c), .mergeInChain(_, let c),
             .reachTier(_, _, let c), .spawnBase(let c): return c
        }
    }
    var description: String {
        switch self {
        case .mergeAny(let c):
            return "Complete \(c) merge\(c == 1 ? "" : "s")"
        case .mergeInChain(let id, let c):
            let name = ContentRegistry.shared.chain(id)?.displayName ?? "animal"
            return "Merge \(c) \(name)\(c == 1 ? "" : "s")"
        case .reachTier(_, let tier, let c):
            // Describe the progression step by its generic stage label plus tier number so it
            // stays readable even though board tile names are now family-specific.
            let stageLabel = QuestGoal.animalTierAppearance(tier: tier).label
            return "Get \(c) animal\(c == 1 ? "" : "s") to \(stageLabel) (Tier \(tier + 1))"
        case .spawnBase(let c):
            return "Rescue \(c) animal\(c == 1 ? "" : "s")"
        }
    }
    /// SF Symbol name for this goal type.
    var icon: String {
        switch self {
        case .mergeAny:                  return "shuffle"
        case .mergeInChain(let id, _):   return ContentRegistry.shared.chain(id)?.tiers.first?.symbol ?? "pawprint.fill"
        case .reachTier(_, let tier, _): return QuestGoal.animalTierAppearance(tier: tier).symbol
        case .spawnBase:                 return "house.fill"
        }
    }
    var iconColor: Color {
        switch self {
        case .mergeAny:                  return .blue
        case .mergeInChain(let id, _):   return ContentRegistry.shared.chain(id)?.tiers.first?.tint ?? .brown
        case .reachTier(_, let tier, _): return QuestGoal.animalTierAppearance(tier: tier).color
        case .spawnBase:                 return .green
        }
    }

    // Deduplication key — two goals with the same key are considered equivalent
    // for the purpose of keeping standing quests varied.
    var dedupeKey: String {
        switch self {
        case .mergeAny:                  return "mergeAny"
        case .mergeInChain(let id, _):   return "mergeInChain:\(id)"
        case .reachTier(_, let tier, _): return "reachTier:\(tier)"
        case .spawnBase:                 return "spawnBase"
        }
    }

    // MARK: Animal tier appearance — covers all 12 tiers (0–11).
    // Tiers 0–8 preserve the original RescueStage colors/symbols; tiers 9–11 use
    // higher-prestige gold tones for the top era.
    //
    // Phase 2b: the era that survived the 15→12 cut is the old top era (indices
    // 12–14), so its appearance moved down with it. Elite/Champion/Legendary went
    // with the dropped era.
    static func animalTierAppearance(tier: Int) -> (label: String, symbol: String, color: Color) {
        switch tier {
        case 0:  return ("Rescued",       "heart.fill",            .orange)
        case 1:  return ("Groomed",       "scissors",              .blue)
        case 2:  return ("Vaccinated",    "cross.circle.fill",     Color(red: 0.10, green: 0.70, blue: 0.70))
        case 3:  return ("Trained",       "star.circle.fill",      Color(red: 0.60, green: 0.30, blue: 0.85))
        case 4:  return ("Foster",        "house.fill",            Color(red: 0.80, green: 0.55, blue: 0.10))
        case 5:  return ("Adopted",       "checkmark.circle.fill", .green)
        case 6:  return ("Bonded",        "person.2.fill",         Color(red: 0.90, green: 0.35, blue: 0.60))
        case 7:  return ("Community Fav", "crown.fill",            Color(red: 0.95, green: 0.50, blue: 0.10))
        case 8:  return ("Ambassador",    "medal.fill",            Color(red: 0.95, green: 0.80, blue: 0.10))
        case 9:  return ("Mythic",        "trophy.fill",           Color(red: 0.85, green: 0.68, blue: 0.10))
        case 10: return ("Ancient",       "crown.circle.fill",     Color(red: 0.90, green: 0.75, blue: 0.08))
        default: return ("Primordial",    "flame.fill",            Color(red: 0.95, green: 0.82, blue: 0.05))
        }
    }

    // Convenience wrappers — kept for backwards-compatible call sites; delegate to animalTierAppearance.
    static func animalTierLabel(_ tier: Int) -> String  { animalTierAppearance(tier: tier).label }
    static func animalTierSymbol(_ tier: Int) -> String { animalTierAppearance(tier: tier).symbol }
    static func animalTierColor(_ tier: Int) -> Color   { animalTierAppearance(tier: tier).color }
}

struct Quest: Identifiable, Codable {
    var id = UUID()
    var goal: QuestGoal
    var difficulty: QuestDifficulty
    var progress: Int = 0
    var dogTagReward: Int
    var kibbleReward: Int
    var isComplete: Bool         { progress >= goal.targetCount }
    var progressFraction: Double { min(Double(progress) / Double(goal.targetCount), 1.0) }
    var progressText: String     { "\(min(progress, goal.targetCount))/\(goal.targetCount)" }
}

struct DailyChallenge: Identifiable, Codable {
    var id = UUID()
    var goal: QuestGoal
    var difficulty: QuestDifficulty
    var progress: Int = 0
    var isComplete: Bool         { progress >= goal.targetCount }
    var progressFraction: Double { min(Double(progress) / Double(goal.targetCount), 1.0) }
    var progressText: String     { "\(min(progress, goal.targetCount))/\(goal.targetCount)" }
}

// ============================================================
// MARK: - ADOPTION ORDER BOARD
// ============================================================

/// A named family or individual who wants to adopt a specific animal.
struct AdoptionFamily {
    let name: String
    let sfSymbol: String
    let color: Color
}

/// The fixed roster of adopting families shown on the order board.
let adoptionFamilies: [AdoptionFamily] = [
    AdoptionFamily(name: "The Chen Family",   sfSymbol: "figure.2.and.child.holdinghands", color: Color(red: 0.25, green: 0.55, blue: 0.85)),
    AdoptionFamily(name: "Dr. Sarah Park",    sfSymbol: "stethoscope",                     color: Color(red: 0.20, green: 0.65, blue: 0.60)),
    AdoptionFamily(name: "Jake & Emma",       sfSymbol: "person.2.fill",                   color: Color(red: 0.90, green: 0.50, blue: 0.15)),
    AdoptionFamily(name: "Grandma Rose",      sfSymbol: "figure.wave",                     color: Color(red: 0.60, green: 0.30, blue: 0.70)),
    AdoptionFamily(name: "The Rivera Kids",   sfSymbol: "figure.play",                     color: Color(red: 0.25, green: 0.65, blue: 0.35)),
    AdoptionFamily(name: "Officer Martinez",  sfSymbol: "shield.fill",                     color: Color(red: 0.20, green: 0.40, blue: 0.75)),
    AdoptionFamily(name: "Coach Thompson",    sfSymbol: "figure.run",                      color: Color(red: 0.85, green: 0.30, blue: 0.25)),
    AdoptionFamily(name: "Artist Luna",       sfSymbol: "paintbrush.pointed.fill",         color: Color(red: 0.85, green: 0.35, blue: 0.65)),
    AdoptionFamily(name: "The Murphy Family", sfSymbol: "house.fill",                      color: Color(red: 0.55, green: 0.40, blue: 0.25)),
    AdoptionFamily(name: "Professor Hayes",   sfSymbol: "book.fill",                       color: Color(red: 0.35, green: 0.40, blue: 0.75)),
    AdoptionFamily(name: "Twins Mia & Leo",   sfSymbol: "person.2.wave.2.fill",            color: Color(red: 0.20, green: 0.70, blue: 0.80)),
    AdoptionFamily(name: "The Singh Seniors", sfSymbol: "figure.walk.motion",              color: Color(red: 0.65, green: 0.45, blue: 0.20)),
]

/// Duration (seconds) an active urgent order stays open before it's missed
/// (Phase 5, Task 5.2). The 4 persistent order slots have no timer at all — this
/// is now the only order-side countdown in the game.
let urgentOrderDuration: Double = 900
/// How long the urgent-order slot sits empty after a miss before a new one
/// spawns. This is the "real stakes" the persistent slots never had: nothing is
/// silently replaced, the player waits.
let urgentOrderRespawnCooldown: Double = 1800
/// Reward bonus on top of a normal order's payout — the urgent order should feel
/// worth rushing for, not just risky.
let urgentOrderRewardMultiplier: Double = 1.5

/// The kind of payload a single `OrderReward` carries.
enum RewardKind: String, Codable, CaseIterable {
    case dogTags
    case coins
    case kibble
    case xp
    case cardPack
    case boardItem     // recirculation — Phase 2
    case material      // wood / metal / cement — Phase 2
    case eventToken    // Phase 6
}

/// A single reward payload attached to an order.
/// `payloadID` / `payloadTier` carry kind-specific detail:
///   .cardPack   → payloadID = CardPackType.rawValue
///   .boardItem  → payloadID = ChainID, payloadTier = tier index
///   .material   → payloadID = material chain ID, payloadTier = tier index
///   .eventToken → payloadID = event token identifier
struct OrderReward: Codable, Equatable {
    var kind: RewardKind
    var amount: Int
    var payloadID: String? = nil
    var payloadTier: Int? = nil
}

/// A specific adoption request from a named family for a particular animal type.
///
/// Carries no timer of its own (Phase 5, Task 5.2) — the 4 board slots this
/// backs are persistent, sitting until fulfilled. The one place a countdown
/// still applies is the separate urgent order (`AdoptionBoard.urgentOrder`),
/// which reuses this same struct for its descriptive/reward data and tracks
/// `urgentOrderTimeRemaining` alongside it rather than on the struct itself.
struct AdoptionOrder: Identifiable, Codable {
    var id = UUID()
    /// Index into the fixed `adoptionFamilies` roster (persisted instead of the
    /// struct itself, which carries a non-Codable `Color`).
    var familyIndex: Int
    var wantedChainID: ChainID       // was wantedSpecies
    var wantedTier: Int              // was wantedStage (0-based)
    var wantedCount: Int             // 1 or 2
    var fulfilled: Int = 0
    var rewards: [OrderReward] = []
    var isClaimed: Bool = false

    /// Resolves the family from the fixed roster (clamped for safety).
    var family: AdoptionFamily {
        adoptionFamilies[max(0, min(familyIndex, adoptionFamilies.count - 1))]
    }

    // Registry-backed display helpers (keep the views free of registry plumbing).
    var iconSymbol: String { ContentRegistry.shared.tier(wantedChainID, wantedTier)?.symbol ?? "pawprint.fill" }
    var iconTint: Color    { ContentRegistry.shared.tier(wantedChainID, wantedTier)?.tint ?? .brown }
    var stageColor: Color  { ContentRegistry.shared.tier(wantedChainID, wantedTier)?.color ?? .gray }
    var stageBadgeSymbol: String { QuestGoal.animalTierSymbol(wantedTier) }

    var isComplete: Bool         { fulfilled >= wantedCount }
    var progressFraction: Double { min(Double(fulfilled) / Double(wantedCount), 1.0) }

    /// Human-readable request line shown on the card, e.g. "a Tabby" or "a Pup".
    var orderDescription: String {
        let prefix = wantedCount == 1 ? "a" : "\(wantedCount)"
        let plural  = wantedCount > 1 ? "s" : ""
        // ChainTier.name is now the family-specific tier name (e.g. "Pup", "Tabby", "Rex").
        let tierName = ContentRegistry.shared.tier(wantedChainID, wantedTier)?.name ?? "animal"
        return "\(prefix) \(tierName)\(plural)"
    }
}

/// Computed accessors preserving the pre-Task-1.1 field names so PanelViews and
/// other UI reading `order.rewardDogTags` / `.rewardCoins` / `.rewardCardPack`
/// compile untouched against the new `rewards: [OrderReward]` list.
extension AdoptionOrder {
    var rewardDogTags: Int { rewards.first { $0.kind == .dogTags }?.amount ?? 0 }
    var rewardCoins: Int   { rewards.first { $0.kind == .coins   }?.amount ?? 0 }
    var rewardCardPack: CardPackType? {
        guard let raw = rewards.first(where: { $0.kind == .cardPack })?.payloadID else { return nil }
        return CardPackType(rawValue: raw)
    }
    /// The hard slot's material reward (Task 5.3), if this order carries one.
    var materialReward: OrderReward? { rewards.first { $0.kind == .material } }
}

// ============================================================
// MARK: - IAP MODELS
// ============================================================

enum IAPProduct: String, CaseIterable {
    case kibbleSmall   = "com.pawsanctuary.kibble.small"
    case kibbleMedium  = "com.pawsanctuary.kibble.medium"
    case kibbleLarge   = "com.pawsanctuary.kibble.large"
    case dogTagsSmall  = "com.pawsanctuary.dogtags.small"
    case dogTagsMedium = "com.pawsanctuary.dogtags.medium"
    case dogTagsLarge  = "com.pawsanctuary.dogtags.large"
    case starterBundle = "com.pawsanctuary.bundle.starter"
    case sanctuaryPass = "com.pawsanctuary.pass.monthly"
    /// Unlocks the paid lane of whichever event is currently active (Phase 6b,
    /// Pass). Deliberately not named/branded like `sanctuaryPass` — that's a
    /// permanent, recurring subscription; this is a per-event, one-time
    /// consumable unlock. See specs/Spec_Phase6b_Pass.md §0/§3.3.
    case eventPass = "com.pawsanctuary.eventpass"
    /// Repeatable — one purchase advances the Reward Ladder by exactly one
    /// rung (Phase 6b, Reward Ladder, D8). Reward comes from
    /// ProgressTrackRegistry at purchase time via the current rung, same
    /// reasoning as eventPass above — no static kibbleAmount/dogTagAmount.
    /// See specs/Spec_Phase6b_RewardLadder.md §3.1.
    case rewardLadderRung = "com.pawsanctuary.rewardladder.rung"
    // Energy Packs — bundle of kibble + dog tags + spawner + card pack
    case energySmall  = "com.pawsanctuary.energy.small"    // ~$0.99
    case energyMedium = "com.pawsanctuary.energy.medium"   // ~$2.99
    case energyLarge  = "com.pawsanctuary.energy.large"    // ~$4.99
    case energyXL     = "com.pawsanctuary.energy.xl"       // ~$9.99

    var displayName: String {
        switch self {
        case .kibbleSmall:   return "Small Kibble Bag"
        case .kibbleMedium:  return "Medium Kibble Bag"
        case .kibbleLarge:   return "Large Kibble Bag"
        case .dogTagsSmall:  return "Dog Tag Pack"
        case .dogTagsMedium: return "Dog Tag Bundle"
        case .dogTagsLarge:  return "Dog Tag Jackpot"
        case .starterBundle: return "Sanctuary Starter Pack"
        case .sanctuaryPass: return "Sanctuary Pass (Monthly)"
        case .eventPass:     return "Event Pass"
        case .rewardLadderRung: return "Reward Ladder"
        case .energySmall:   return "Small Energy Pack"
        case .energyMedium:  return "Medium Energy Pack"
        case .energyLarge:   return "Large Energy Pack"
        case .energyXL:      return "XL Energy Pack"
        }
    }
    var icon: String {
        switch self {
        case .kibbleSmall, .kibbleMedium, .kibbleLarge:    return "pawprint"
        case .dogTagsSmall, .dogTagsMedium, .dogTagsLarge: return "tag.fill"
        case .starterBundle:                               return "gift.fill"
        case .sanctuaryPass:                               return "medal.fill"
        case .eventPass:                                   return "star.circle.fill"
        case .rewardLadderRung:                            return "arrow.up.right.square.fill"
        case .energySmall, .energyMedium,
             .energyLarge, .energyXL:                     return "bolt.circle.fill"
        }
    }
    var kibbleAmount: Int? {
        switch self {
        case .kibbleSmall:   return 60
        case .kibbleMedium:  return 180
        case .kibbleLarge:   return 600
        case .starterBundle: return 100
        default:             return nil
        }
    }
    var dogTagAmount: Int? {
        switch self {
        case .dogTagsSmall:  return 15
        case .dogTagsMedium: return 60
        case .dogTagsLarge:  return 175
        case .starterBundle: return 20
        default:             return nil
        }
    }
    var isSubscription: Bool { self == .sanctuaryPass }

    /// Contents for energy pack IAPs; nil for non-energy-pack products.
    var energyPackContents: EnergyPackContents? {
        switch self {
        case .energySmall:
            return EnergyPackContents(kibble: 25, dogTags: 8,
                                      spawnerLevel: .rescueCrate, spawnerCount: 1,
                                      cardPack: .star2, previewPrice: "$0.99")
        case .energyMedium:
            return EnergyPackContents(kibble: 60, dogTags: 20,
                                      spawnerLevel: .shelterPod, spawnerCount: 1,
                                      cardPack: .star4, previewPrice: "$2.99")
        case .energyLarge:
            return EnergyPackContents(kibble: 120, dogTags: 40,
                                      spawnerLevel: .fosterHome, spawnerCount: 1,
                                      cardPack: .star5, previewPrice: "$4.99")
        case .energyXL:
            return EnergyPackContents(kibble: 250, dogTags: 80,
                                      spawnerLevel: .fosterHome, spawnerCount: 2,
                                      cardPack: .star6, previewPrice: "$9.99")
        default:
            return nil
        }
    }
}

// ============================================================
// MARK: - COMMERCE STATE (Phase 1, Task 1.4)
// ============================================================

/// Behavioural history for offer targeting, difficulty scaling, and the Phase 3
/// first-purchase gate. Recorded starting Phase 1; cannot be backfilled for
/// players who installed before this shipped.
struct PlayerCommerceState: Codable, Equatable {
    var firstLaunchDate: Date? = nil
    var purchaseCount: Int = 0
    /// Total spend in integer micros (USD × 1,000,000) — avoids Double drift.
    var totalSpendMicros: Int = 0
    var lastPurchaseDate: Date? = nil

    /// Times the player has hit zero kibble while trying to act.
    var wallEventsTotal: Int = 0
    var lastWallDate: Date? = nil
    /// What they were blocked on at the most recent wall event.
    var lastWallChainID: String? = nil
    var lastWallTier: Int? = nil

    /// Flips permanently once the player first reaches a genuine wall.
    /// Phase 3 uses this (with player level) to gate monetization surfaces.
    var hasReachedFirstWall: Bool = false

    var hasEverPurchased: Bool { purchaseCount > 0 }
    var averagePurchaseMicros: Int { purchaseCount == 0 ? 0 : totalSpendMicros / purchaseCount }
    var daysSinceLastPurchase: Int? {
        guard let last = lastPurchaseDate else { return nil }
        return Calendar.current.dateComponents([.day], from: last, to: Date()).day
    }
}

// ============================================================
// MARK: - VIP LADDER (Gap_Analysis_Round2 3.7)
// ============================================================
//
// Purchase-progress promotion: lifetime real-money spend climbs a permanent,
// never-expiring ladder — a standard VIP-club convention, chosen deliberately
// over a time-limited grand-prize event (the more aggressive option the
// source doc also offered). Every level stacks the same +1 kibble/regen
// perk used by the Sanctuary Map's own upgrades (`UpgradeBonus.merging`), so
// VIP status and map progression compound through one shared system rather
// than two. One-time rewards scale linearly with level — generous, but never
// close to refunding what was actually spent.

struct VIPTier: Identifiable {
    var id: Int { level }
    let level: Int
    /// Cumulative lifetime spend required, in micros (USD × 1,000,000) — same
    /// unit as `PlayerCommerceState.totalSpendMicros`.
    let thresholdMicros: Int
    let bonus: UpgradeBonus
    let kibbleReward: Int
    let dogTagReward: Int
    let coinReward: Int
}

let vipTiers: [VIPTier] = [
    VIPTier(level: 1,  thresholdMicros: 5_000_000,     bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 50,   dogTagReward: 5,   coinReward: 100),
    VIPTier(level: 2,  thresholdMicros: 15_000_000,    bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 100,  dogTagReward: 10,  coinReward: 200),
    VIPTier(level: 3,  thresholdMicros: 35_000_000,    bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 150,  dogTagReward: 15,  coinReward: 300),
    VIPTier(level: 4,  thresholdMicros: 75_000_000,    bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 200,  dogTagReward: 20,  coinReward: 400),
    VIPTier(level: 5,  thresholdMicros: 150_000_000,   bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 300,  dogTagReward: 30,  coinReward: 600),
    VIPTier(level: 6,  thresholdMicros: 300_000_000,   bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 400,  dogTagReward: 40,  coinReward: 800),
    VIPTier(level: 7,  thresholdMicros: 500_000_000,   bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 500,  dogTagReward: 50,  coinReward: 1000),
    VIPTier(level: 8,  thresholdMicros: 800_000_000,   bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 600,  dogTagReward: 60,  coinReward: 1200),
    VIPTier(level: 9,  thresholdMicros: 1_200_000_000, bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 800,  dogTagReward: 80,  coinReward: 1500),
    VIPTier(level: 10, thresholdMicros: 2_000_000_000, bonus: UpgradeBonus(kibblePerRegen: 1), kibbleReward: 1000, dogTagReward: 100, coinReward: 2000),
]

extension PlayerCommerceState {
    /// The highest tier whose threshold lifetime spend has met. 0 = no tier reached.
    var vipLevel: Int { vipTiers.last(where: { totalSpendMicros >= $0.thresholdMicros })?.level ?? 0 }
}

// ============================================================
// MARK: - CONSTANTS
// ============================================================

// ── Weekly / monthly goal constants ──────────────────────────
//
// Rescaled in Phase 2c. These are thresholds on coins *earned this week*, and
// the coin faucet moved by roughly 45× — the old Bronze 50 would have been
// cleared by a single mid-tier order, silently, because these live here and the
// payout formula lives in AdoptionBoard.
//
// Anchored on mid-game income: a level-30 player fulfilling orders earns roughly
// 3,000 coins/day, so Gold at 12,000 asks for about four days of engagement and
// Bronze lands on day one. The original 1 : 2.4 : 5 spacing is preserved.
let weeklyGoalBronzeCoins  = 2_500
let weeklyGoalSilverCoins  = 6_000
let weeklyGoalGoldCoins    = 12_000
/// Default number of Gold weeks required to complete the monthly goal.
/// Foster Haven T2 can reduce this by 1.
let monthlyGoalWeeksNeeded = 3

// ── Coin rewards ──────────────────────────────────────────────
//
// All rescaled in Phase 2c against the new anchor: an *average* order pays
// roughly 400 coins, and a top-tier one 13,312. Each of these is a bonus on top
// of whatever the player does with the item, so none should rival the item's own
// value — but none should be a rounding error either, which is what they became.

/// Awarded in `triggerTopTierCelebration` when any chain reaches its top tier.
/// Rationale: recognises the achievement without competing with what the item
/// itself is worth (5,632 sold, 13,312 to an order). Was 10 — pure noise.
let coinsPerAmbassadorMerge = 500

/// Coins for clearing all three daily challenges.
/// Rationale: a day's engagement, worth about one average order (~400) — a real
/// top-up that doesn't compete with the main faucet. Was 15.
let coinsPerAllDailyChallenges = 400

/// Multiplier applied to the combined sell value when three top-tier tiles of one
/// species are exchanged together.
///
/// Rationale: this consumes three items outright, so it has to beat selling them
/// individually or it is a trap. It paid a flat 50 coins for three tiles worth
/// 5,632 each — destroying about 16,850 coins of value for anyone who used it.
/// A premium over the sell price makes the trio the best liquidity option for
/// three matching Ambassadors, which is what a "trio bonus" should mean.
let ambassadorTrioExchangeMultiplier = 1.25

// ── Weekly goal tiers ─────────────────────────────────────────

enum WeeklyGoalTier: Int, CaseIterable {
    case bronze = 0, silver, gold

    var baseCoinsNeeded: Int {
        switch self {
        case .bronze: return weeklyGoalBronzeCoins
        case .silver: return weeklyGoalSilverCoins
        case .gold:   return weeklyGoalGoldCoins
        }
    }
    var displayName: String {
        switch self { case .bronze: return "Bronze"; case .silver: return "Silver"; case .gold: return "Gold" }
    }
    var color: Color {
        switch self {
        case .bronze: return Color(red: 0.72, green: 0.45, blue: 0.18)
        case .silver: return Color(red: 0.58, green: 0.60, blue: 0.65)
        case .gold:   return Color(red: 0.85, green: 0.68, blue: 0.10)
        }
    }
    var sfSymbol: String {
        switch self { case .bronze: return "medal.fill"; case .silver: return "medal.fill"; case .gold: return "trophy.fill" }
    }
    /// Kibble in the base chest for this tier. Doubled by Ambassador Hall T2.
    var baseKibbleReward: Int {
        switch self { case .bronze: return 5; case .silver: return 10; case .gold: return 20 }
    }
    var dogTagReward: Int {
        switch self { case .bronze: return 3; case .silver: return 6; case .gold: return 10 }
    }
    /// Number of Toolboxes placed on the board (or distributed directly) as part of this chest.
    var toolboxCount: Int {
        switch self { case .bronze: return 0; case .silver: return 1; case .gold: return 2 }
    }
    /// Board items paid out by this chest — recirculation (Phase 2, Task 2.3b).
    var boardItemCount: Int {
        switch self { case .bronze: return 1; case .silver: return 1; case .gold: return 2 }
    }
    /// How far below `deepestUnlockedTier` this chest's items land. Lower is richer.
    var boardItemTierOffset: Int {
        switch self { case .bronze: return 4; case .silver: return 3; case .gold: return 2 }
    }
    var xpReward: Int {
        switch self { case .bronze: return 15; case .silver: return 35; case .gold: return 75 }
    }
}

// ── Dog Tag → Kibble exchange ─────────────────────────────────

/// A single Dog Tag → Kibble exchange offer.
///
/// Phase 2 (Task 2.4) reversed the shape. It used to be a *volume discount*
/// (40→100, 80→240, 120→480 — 2.5, 3.0, then 4.0 kibble per tag), which rewarded
/// bulk absorption and let a paying player flatten the pacing curve at will.
///
/// The reference games do the opposite: an escalating ladder for an identical
/// amount of energy, resetting daily, which caps how much cheap energy anyone can
/// absorb per day. That cap is what protects the pacing curve.
struct DogTagKibbleExchange {
    let dogTagCost: Int
    let kibbleGain: Int
    /// 0-based position in today's ladder.
    let purchaseIndex: Int
    var label: String { "\(dogTagCost) Dog Tags → \(kibbleGain) Kibble" }

    /// Every rung buys the same kibble; only the price climbs.
    static let kibblePerExchange = 100
    /// Tag cost by purchase number within the day. The last entry repeats forever.
    static let dailyLadder = [15, 30, 60]

    /// The offer a player with `purchasesToday` exchanges already made would see.
    static func offer(purchasesToday: Int) -> DogTagKibbleExchange {
        let i = max(0, purchasesToday)
        let cost = dailyLadder[min(i, dailyLadder.count - 1)]
        return DogTagKibbleExchange(dogTagCost: cost,
                                    kibbleGain: kibblePerExchange,
                                    purchaseIndex: i)
    }

    /// True once the ladder has bottomed out and the rate is flat.
    var isAtFlatRate: Bool { purchaseIndex >= Self.dailyLadder.count - 1 }
}

// ── Dog Tag store stock (Phase 2, Task 2.3c) ──────────────────

/// One purchasable board item in the daily Dog Tag store. Stock is 1 by design;
/// `purchased` is what enforces it until the next daily rotation.
struct DogTagStoreSlot: Codable, Equatable, Identifiable {
    var id = UUID()
    var chainID: ChainID
    var tier: Int
    var priceDogTags: Int
    var purchased: Bool = false
}

let kibbleRegenCap            = 100
let kibbleRegenSecs           = 120
let startingKibble            = 20
let totalInventorySlots       = 18
let freeInventorySlots        = 6
let inventoryRow1Cost         = 10
let inventoryRow2Cost         = 25
let totalProducerOverflowSlots = 4   // Phase 3: overflow for producers retired before slot unlocks
let spotlightWeeklyGoal    = 10
let adoptionSkipCost       = 2   // kibble cost to skip an order you don't want

// ── Rewarded ads ──────────────────────────────────────────────
let maxDailyAdWatches      = 4   // ads available per day (resets at 09:00 UTC)
let adKibbleReward         = 25  // kibble granted per completed ad watch

// ── Monetization gate (D7 / Phase 3, Task 3.4) ──────────────────
//
// "Session-one monetization silence": no offer, no ad, no store push until
// the player has both felt a genuine wall AND reached this level — whichever
// of the two happens later. A level-1 player who empties their starting
// kibble in the first few minutes hasn't earned a "genuine" wall yet; a
// level-5 player who's never run dry hasn't felt scarcity yet either.
let monetizationUnlockLevel = 5

// ── Loyalty Club ─────────────────────────────────────────────
let loyaltyClubLevelRequirement = 20

struct LoyaltyReward {
    let kibble: Int
    let dogTags: Int
    let cardPack: CardPackType?
    let label: String
}

let loyaltyClubCycle: [LoyaltyReward] = [
    LoyaltyReward(kibble: 25, dogTags: 0,  cardPack: nil,    label: "Day 1"),
    LoyaltyReward(kibble: 15, dogTags: 3,  cardPack: nil,    label: "Day 2"),
    LoyaltyReward(kibble: 30, dogTags: 0,  cardPack: .star1, label: "Day 3"),
    LoyaltyReward(kibble: 20, dogTags: 5,  cardPack: nil,    label: "Day 4"),
    LoyaltyReward(kibble: 40, dogTags: 0,  cardPack: nil,    label: "Day 5"),
    LoyaltyReward(kibble: 15, dogTags: 8,  cardPack: nil,    label: "Day 6"),
    LoyaltyReward(kibble: 50, dogTags: 10, cardPack: .star2, label: "Day 7 ★"),
]

// ── Sanctuary Pass ────────────────────────────────────────────
let passDailyKibble        = 20    // kibble granted on each daily pass claim
let passKibbleMultiplier   = 1.5   // multiplier applied to all claimed kibble rewards

// ── Parallel Board energy (Phase 6b, Task 3.2) ──────────────────
// First-cut numbers, not derived from a model — see Spec_Phase6b_ParallelBoard.md §4.
let parallelBoardEnergyCap      = 30
let parallelBoardEnergyRegenSecs = 90   // full refill in 45 minutes

// ── Parallel Board grid + generator (Phase 6b, Task 3.3) ────────
// Same first-cut posture as the energy constants above.
let parallelBoardRows          = 5
let parallelBoardCols          = 5   // 25 cells, fully unlocked from the start — no row-progression
let parallelBoardGeneratorCost = 2   // energy per tap — 15 generations per full energy bar

// ── Parallel Board progress (Phase 6b, Task 3.5) ─────────────────
// No economy model run for this one either — the doc's §4 covers the
// board/energy numbers but not this; a genuinely new first-cut estimate.
let parallelBoardTokensPerCompletion = 10   // per top-tier item, no rider/chance layer needed

// ── Reward Ladder (Phase 6b, Task 3.1) ────────────────────────────
/// Fixed, not date-stamped — the ladder isn't a calendar event instance,
/// just one permanent ProgressTrackRegistry entry (see
/// specs/Spec_Phase6b_RewardLadder.md §0/§2). Real registry content (the 6
/// rungs) lands in Task 3.5.
let rewardLadderTrackID = "reward_ladder"

// ── Board dimensions (fixed — never changes at runtime) ──────
let boardRows = 9   // 9 rows × 7 cols = 63 positions; bottom 6 rows start locked
/// `deepestUnlockedTier` (PlayerProgression) required to unlock each board row
/// (by index). Rows 0–2 start unlocked. Gated on merge tier rather than player
/// level (Gap_Analysis_Round2 §2, C-1): deeper tiers need more staging space,
/// so the reward should arrive with the need, not on a schedule decoupled
/// from it. Open at 3 rows / 21 cells / 33%, full board at tier 10.
let boardRowUnlockTiers: [Int: Int] = [3: 2, 4: 4, 5: 6, 6: 8, 7: 9, 8: 10]

/// Phase 4, Task 4.2: every cell in a locked row is pre-seeded with a visible
/// Kibble-chain cache at this tier, released (made interactive) the instant
/// the row unlocks — `checkTierUnlock` only flips `isUnlocked`; the cache is
/// already sitting there. Authored per row, not derived: deeper unlocks get a
/// richer cache.
let lockedRowCacheTier: [Int: Int] = [3: 0, 4: 0, 5: 1, 6: 1, 7: 2, 8: 3]

// ── Gameplay scaling helpers (package-internal so tests can reach them) ──────

/// Maximum material tier that drops from a Toolbox at `level`.
/// Scales from tier 1 at level 1 up to tier 5 at level 20+, so late-game
/// players collect higher-tier materials and the area grind stays proportional.
func toolboxMaxTier(forPlayerLevel level: Int) -> Int {
    min(5, level / 5 + 1)
}

/// Maximum 0-based animal tier that adoption orders should request at `level`.
/// Early players never receive orders for stages they can't realistically reach,
/// preventing the frustration of watching orders expire unfilled.
///
/// **Phase 2 dial.** Together with `orderDifficultyBands` this is the primary control on
/// the demand/supply ratio — see `EconomySimulation`. Retuned in Phase 2 because
/// under neutral pricing a tier-14 item costs 16,384 kibble (~22 days of a
/// player's entire income); the pre-Phase-2 table was written for the old world
/// where the ×8 multiplier sold tier-7 items for 8 kibble.
func maxAchievableOrderTier(forPlayerLevel level: Int) -> Int {
    switch level {
    case 1...3:   return 2
    case 4...6:   return 3
    case 7...9:   return 4
    case 10...20: return 5
    case 21...30: return 6    // holds through L30 — ratio ~0.56
    case 31...40: return 9    // tightening; ratio ~0.83
    case 41...50: return 10   // the ratio crosses 1.00 here — Phase 3's offer moment
    default:      return 11   // the top of the chain is orderable; ratio ~1.18
    }
}

/// An order slot's fixed difficulty (Phase 5, Task 5.1). Replaces the old
/// uniform tier roll — every slot now draws from its own difficulty's band
/// instead of all slots sharing one distribution, so the board can never show
/// (say) four easy orders at once by chance.
enum OrderDifficulty: String, Codable, CaseIterable {
    case easy, medium, hard
}

/// The fixed per-slot difficulty spread: slot 0 is always easy, slots 1-2
/// medium, slot 3 hard. Slots beyond the base 4 (granted by Sanctuary Map
/// upgrades) repeat the same pattern.
let orderSlotDifficultyPattern: [OrderDifficulty] = [.easy, .medium, .medium, .hard]

/// Per-difficulty tier-weighting table: `(probability, tiers)`, probabilities
/// summing to 1 within each difficulty. A tier above `maxAchievableOrderTier`
/// collapses onto it, same as before.
///
/// **Phase 5 dial**, superseding the old `orderTierBands` — shared by
/// `AdoptionBoard.generateOrder` and `EconomySimulation` so the model can never
/// drift from what the game generates. `.hard` keeps the shape of the old top
/// three bands (still mostly tier 5-6, only occasionally the true top of the
/// chain) rather than jumping straight to the deepest tier every time a hard
/// slot regenerates — a *guaranteed* hard order is a much bigger demand lever
/// than the old ~6% chance of drawing one, so it stays weighted toward the
/// cheaper end of "hard."
let orderDifficultyBands: [OrderDifficulty: [(probability: Double, tiers: [Int])]] = [
    .easy:   [(1.000, [0, 1])],
    .medium: [(1.000, [2, 3])],
    .hard:   [(0.750, [4, 5]), (0.130, [6, 7]), (0.090, [8, 9]), (0.030, [10, 11])],
]

// ── Spawn multiplier pricing (Phase 2, Task 2.1) ──────────────
//
// The multiplier selects a TIER; the tier sets the price. Cost is `2^tier`,
// which is exactly what that item is worth in merge inputs, so no multiplier
// level buys progress at a discount to building it by hand.
//
// Before Phase 2 the tier was `multiplier - 1` at a cost of `multiplier`,
// which made ×8 an 8-kibble purchase of a 128-kibble item — a 16× arbitrage
// that unlocked at level 20 and never closed.

/// Maps a spawn multiplier (1 / 2 / 4 / 8) to the 0-based tier it produces.
/// Total by construction: any unrecognised value falls back to tier 0.
func spawnTierIndex(forMultiplier multiplier: Int) -> Int {
    switch multiplier {
    case 1:  return 0
    case 2:  return 1
    case 4:  return 2
    case 8:  return 3
    default: return 0
    }
}

// ── Bonus spawn layer (Phase 4, Task 4.3) ────────────────────
//
// "The bonus layer is an accelerant dressed as a reward" (Merge2_Reference_
// Blueprint.md §4, measured [M]): "Lucky!"/"Legendary!" bonus spawns fire
// only on boosted taps (×2/×4/×8), never at ×1. Gating the bonus behind the
// multiplier pushes players toward bigger, faster-draining taps — the
// generosity is real, but so is the acceleration.

/// Chance of a bonus extra spawn, keyed by the multiplier's tier index
/// (0/1/2/3 for ×1/×2/×4/×8). Zero at ×1 by construction — that's the point.
func bonusSpawnChance(forMultiplierTier tierIndex: Int) -> Double {
    switch tierIndex {
    case 0:  return 0.00
    case 1:  return 0.10
    case 2:  return 0.25
    default: return 0.40
    }
}

/// Share of triggered bonuses that roll "Legendary!" (one tier richer) rather
/// than the common "Lucky!" (matches the tap's own tier).
let legendaryBonusShare = 0.15

// ── Bubble mechanic (Phase 4, Task 4.4) ──────────────────────
//
// "Bubble: on merge, with probability p, the output is encased. Opened by
// rewarded video (capped ~3/day) or gems, and decays into a lesser reward if
// left. Converts a moment of success into a decision at the instant the
// player feels good. It must decay into something — punishing non-payment
// breaks the genre's core rule." (Merge2_Reference_Blueprint.md §23, measured)
//
// Two states only, not a continuous curve: poppable-for-full-value until
// `bubbleDecaySeconds` elapses, then a single lesser value forever after.
// The decision is made once, at bubble-creation time — "pop now, or risk it."

/// Chance a below-top-tier animal merge gets bubbled instead of landing
/// normally. Top tier is excluded — it has its own Ambassador celebration.
/// Also gated by `bubbleMinTier` and quest/order relevance — see `maybeBubbleMergedItem`.
let bubbleChance = 0.15

/// Minimum 0-based tier before a merge result is eligible to bubble at all — merges
/// below this always land normally. Keeps the mechanic out of the first few stages of
/// every family, before a player has learned the core loop. (Design tuning call,
/// 4 Aug 2026 — the mechanic itself, and the ad/Dog-Tags pop it's gated behind, stay
/// as designed per `Merge2_Reference_Blueprint.md §23`; only the frequency/targeting
/// changed.)
let bubbleMinTier = 5

/// How long a bubble stays poppable for full value before decaying.
let bubbleDecaySeconds: Double = 600   // 10 minutes

/// Coin value fraction once a bubble has decayed — never zero.
let bubbleDecayFloor = 0.50

/// Dog Tags to pop a bubble instantly, scaled like the Dog Tag store's
/// tier-based pricing rather than a flat fee.
func bubblePopDogTagCost(tier: Int) -> Int { 3 + tier }

/// True when landing this (chainID, tier) would help complete an active order or
/// quest — i.e. bubbling it would obstruct near-term progress rather than just
/// interrupt a routine merge. Only items meeting this bar are eligible to bubble
/// once past `bubbleMinTier` (design tuning call, 4 Aug 2026). A free function, not
/// a `MergeBoardViewModel` method, so it's unit-testable against constructed
/// orders/quests without needing a full ViewModel instance.
///
/// - An order (persistent slot or the urgent order) wanting exactly this chain+tier.
/// - An active quest working this exact chain (`.mergeInChain`) — any further merge
///   of it is material toward that quest, not just this one landing spot.
/// - An active quest whose `.reachTier` target is exactly this tier — reaching a
///   *further* tier from here needs this piece free to merge again.
func isBubbleEligibleForQuestOrOrder(chainID: ChainID, tier: Int,
                                     orders: [AdoptionOrder], urgentOrder: AdoptionOrder?,
                                     quests: [Quest]) -> Bool {
    if orders.contains(where: { $0.wantedChainID == chainID && $0.wantedTier == tier }) { return true }
    if let urgent = urgentOrder, urgent.wantedChainID == chainID, urgent.wantedTier == tier { return true }
    return quests.contains { quest in
        guard !quest.isComplete else { return false }
        switch quest.goal {
        case .mergeInChain(let id, _):           return id == chainID
        case .reachTier(let category, let t, _): return category == .animal && t == tier
        default:                                 return false
        }
    }
}

/// Kibble cost of spawning a tier-`tier` item: `2^tier`, the item's merge-input worth.
func spawnCost(forTier tier: Int) -> Int { 1 << max(0, tier) }

/// Top 0-based tier of every animal chain (12 tiers as of Phase 2b).
let animalChainTopTier = 11

/// Phase 2c §5: the "mid-tier" band for the sell-vs-order contextual nudge —
/// low enough to exclude the starter tiers (trivially cheap either way), high
/// enough to exclude the top-tier Ambassador zone (already surfaced via the
/// trio exchange).
let sellVsOrderNudgeTierRange = 3...8

// ── Recirculation (Phase 2, Task 2.3) ─────────────────────────
//
// Under neutral pricing a Stage-15 item costs 16,384 kibble — roughly 22 days of
// a player's *entire* income — so deep tiers cannot be reached by tapping and
// must arrive as items. These are the dials for how much comes back.

/// How far below `deepestUnlockedTier` a granted board item lands.
/// Offset 2 = a quarter of the player's current frontier item.
let recirculationTierOffset = 2

/// Absolute ceiling on any `deepestUnlockedTier`-relative item grant.
///
/// Without this the grant channel is *exponential in tenure*: item worth is `2^tier`,
/// so pegging the payout a fixed number of tiers below the player's frontier doubles
/// it every time they advance one stage. The Phase 2 model showed a deepest-14 player
/// receiving ~7,600 kibble-equivalent per day from Board Item Grants alone, against a
/// total daily income of ~745 — the same unbounded-faucet shape Task 2.2 removed from
/// Spawner Refill, just denominated in items.
///
/// Re-derived in Phase 2b against the 12-tier chain, where the top item costs 2,048
/// rather than 16,384. Tier 6 (64 kibble) keeps the channel meaningful for shallow
/// players — where `deepest − 2` is the binding term — while stopping it outrunning
/// demand in the endgame.
let recirculationMaxItemTier = 6

/// How far below an order's own `wantedTier` its board-item reward lands.
/// Always a fraction of what the order asked for, never the whole thing.
let orderRewardTierOffset = 3

/// One order in this many carries a board-item reward.
let orderBoardItemFrequency = 3

/// Phase 5, Task 5.3: the hard-difficulty slot always carries a material reward
/// too, giving the Sanctuary Map's wood/metal/cement economy a second, reliable
/// faucet alongside quest-driven Toolboxes (today's only source). Deterministic
/// rather than a chance roll, matching the reference blueprint's per-difficulty
/// payout table (easy/medium → COIN, hard → PART) — "its own bottleneck" means
/// dependable, not rare.
///
/// No material-economy model exists yet (unlike the coin economy's
/// `EconomySimulation`), so this quantity/tier is a conservative first cut, not
/// an empirically derived one: 1 item, discounted `materialRewardTierOffset`
/// tiers below what a same-level Toolbox could roll (`toolboxMaxTier`), so a
/// hard order never outpaces the existing Toolbox channel — it supplements it.
let materialRewardCount = 1
let materialRewardTierOffset = 2

// ── Dog Tag store (Phase 2, Task 2.3c) ────────────────────────

/// Board items purchasable with Dog Tags — 3 slots, rotating daily, stock 1 each.
/// Tiers span `deepestUnlockedTier - 4` … `deepestUnlockedTier - 1`.
let dogTagStoreSlotCount   = 3
let dogTagStoreMinOffset   = 4   // deepest − 4 is the cheapest slot on offer
let dogTagStoreMaxOffset   = 1   // deepest − 1 is the dearest
/// Price for the cheapest tier on offer, then +step per tier above it.
/// Anchored against the measured reference band of ~9–70 gems per item.
let dogTagStoreBasePrice   = 15
let dogTagStorePriceStep   = 18

/// Paid reroll price (Gap_Analysis_Round2 3.2). Deliberately priced well below
/// `dogTagStoreBasePrice` — the cheapest slot on offer — so a reroll reads as
/// an impulse buy, not a commitment: every reroll is a fresh shot at the item
/// the player actually wants. The cheapest meaningful Dog Tag sink available.
let dogTagStoreRefreshCost = 5

/// Wildcard price (Gap_Analysis_Round2 3.5). Deliberately well above
/// `dogTagStoreBasePrice`/`dogTagStorePriceStep`'s entire range (max 69,
/// see `DogTagStore.price`) — a wildcard beats any single Item Store slot
/// outright, since the player picks which item it becomes, so it has to cost
/// more than the dearest one. A considered purchase, not an impulse.
let wildcardCostDogTags = 100

// ── The coin economy (Phase 2c) ───────────────────────────────
//
// Coins gate the Sanctuary Map — 291,900 coins across 61 entries — which is the
// game's forever goal. Phases 2 and 2b modelled kibble only; coins were never
// modelled, and the two tables that happened to exist put selling at ~6,500
// coins/day against ~145/day from everything else combined. Selling *was* the
// coin economy, and it is taught nowhere.
//
// Both channels now pay, in proportion to what an item cost to build:
//
//   Fulfil an order  →  6.50 coins per kibble   the efficient path; needs a
//                                                matching order, so costs patience
//   Sell an animal   →  2.75 coins per kibble   instant liquidity, ~2.4× worse
//
// A flat ratio at every tier is deliberate: no tier is relatively better to sell,
// so there is no farming incentive anywhere on the chain, and the tradeoff reads
// the same wherever the player is — always about 2.4× for waiting.
//
// The 6.5 anchor comes from the target of a ~60-day full map build-out:
//   291,900 ÷ 60 days = ~4,865 coins/day, ÷ ~745 kibble/day of orders = ~6.5.

/// Coins paid per kibble of build cost when an adoption order is fulfilled.
let coinsPerKibbleOfOrder = 6.5

/// Coins paid per kibble of build cost when an animal is sold.
let coinsPerKibbleOfSale = 2.75

/// Random spread applied to order payouts so they don't read as mechanical.
/// Small enough that the worst order still beats the best sale by a wide margin.
let orderCoinSpread = 0.10

// ── Piggy bank (Gap_Analysis_Round2 3.4) ───────────────────────
//
// Passive accumulator: a fraction of every coin gain is *also* skimmed in here,
// on top of the direct reward, so it never competes with the coin economy above —
// it's a free bonus layer, not a redistribution of it. Paid to crack once full.

/// Fraction of every `earnCoins` amount skimmed into the bank.
let piggyBankSkimRate = 0.10

/// Fill cap; the bank can only be cracked once full. Anchored against the
/// ~4,865 coins/day target above — a 10% skim fills this in about a day of
/// average play, so cracking reads as a once-a-day top-up, not an instant tap.
let piggyBankCap = 500

/// Dog Tag price to crack a full bank. The coins inside cost the player nothing
/// to accumulate, so any price is a bargain — kept near `dogTagStoreRefreshCost`
/// rather than the store's item prices, since this is a sink on the same impulse
/// tier, not a considered purchase.
let piggyBankCrackCostDogTags = 20

// ── Free chest (Gap_Analysis_Round2 3.6) ───────────────────────
//
// "Free with a wait — a soft speed-up sink carrying no purchase pressure."
// Pairs with 3.3: the reward is a toolbox item, open now for a small payout
// or merge for a bigger one.

/// Hours between free chests. ~2-3 a day for an active player — often enough
/// to be worth checking back for, rare enough to stay a bonus, not a loop.
let freeChestCooldownHours = 4.0

/// Dog Tag price to skip the remaining wait. Kept near `dogTagStoreRefreshCost`
/// (5) rather than scaled to the wait itself — "soft," an impulse for a player
/// already in the shop, not a real alternative to waiting.
let freeChestSkipCostDogTags = 10

/// Kibble cost to build one item at `tier`, times `count` — the quantity both
/// coin channels are denominated in.
func buildCost(tier: Int, count: Int = 1) -> Int {
    spawnCost(forTier: tier) * max(1, count)
}

/// Coins an adoption order pays for the items it asks for.
/// `spreadFactor` is 1.0 for the nominal payout; `generateOrder` randomises it
/// within ±`orderCoinSpread`.
///
/// Proportional rather than a hand-tuned table on purpose: the order tier
/// distribution has already been re-swept twice (Phases 2 and 2b), and a formula
/// stays correct across a re-sweep where a table would need re-deriving.
func orderCoinPayout(tier: Int, count: Int = 1, spreadFactor: Double = 1.0) -> Int {
    max(1, Int((Double(buildCost(tier: tier, count: count))
                * coinsPerKibbleOfOrder * spreadFactor).rounded()))
}

/// Coins paid for selling one animal at `tier`.
func animalSellValue(tier: Int) -> Int {
    max(1, Int((Double(spawnCost(forTier: max(0, tier))) * coinsPerKibbleOfSale).rounded()))
}

/// The sell table, derived rather than authored so it cannot drift from the rate
/// or from the chain length. Tier 0 → 3 coins, tier 11 → 5,632.
let animalSellValues: [Int] = (0...animalChainTopTier).map { animalSellValue(tier: $0) }

// ── Currency chains (Phase 4, Task 4.1) ──────────────────────────
//
// Kibble and Coin merge chains that spawn on the board via family spawners —
// tap to collect the current tier's value, or merge two for a richer one.
// Value pattern follows the measured reference (Merge2_Reference_Blueprint.md
// §21): "Coin (Lvl 1) collects 1; Coin (Lvl 3) collects 7" — tier t (0-indexed)
// collects 2^(t+1) - 1, not a clean doubling. Every merge is worth strictly
// more than the sum of its two inputs, which is what makes "merge for a
// better rate, or collect now for liquidity" a genuine decision rather than
// a wash.
let currencyChainTierCount = 6

func currencyChainBaseValue(tier: Int) -> Int { (1 << (max(0, tier) + 1)) - 1 }

/// Kibble granted when a Kibble-chain item at `tier` is collected.
/// Tier 0 → 1, tier 5 (top) → 63 — roughly two hours of passive regen at cap.
func kibbleCurrencyValue(tier: Int) -> Int { currencyChainBaseValue(tier: tier) }

/// Coins granted when a Coin-chain item at `tier` is collected. Scaled by the
/// same per-kibble sell rate as animals (Phase 2c) so this reads as a small
/// side faucet, not a rival to orders/selling. Tier 0 → 3, tier 5 (top) → 173.
func coinCurrencyValue(tier: Int) -> Int {
    max(1, Int((Double(currencyChainBaseValue(tier: tier)) * coinsPerKibbleOfSale).rounded()))
}

// ── XP constants ──────────────────────────────────────────────
let xpPerMergeBase     = 5    // multiplied by srcItem.stage.rawValue in code
let xpPerRescue        = 2    // player-initiated rescue (kibble spend)
let xpPerOrderFulfil   = 15   // adoption order auto-claimed
let xpDailyComplete    = 30   // all daily challenges done

// ── Level-up system ───────────────────────────────────────────

/// XP required to advance from `level` to `level + 1`.
func xpRequired(forLevel level: Int) -> Int { level * 150 }

/// Rewards the player receives when reaching a new level.
struct LevelUpReward {
    var newSpecies: AnimalSpecies? = nil
    var newProducerTier: ProducerLevel? = nil
    var bonusKibble: Int = 0
    /// A supply chain that unlocks at this level (Phase 2). The matching producer
    /// is derived from the chain ID and placed on the board automatically.
    var newSupplyProducer: ProducerLevel? = nil
    /// Card pack awarded at this level (nil = no pack).
    var cardPack: CardPackType? = nil

    var hasUnlock: Bool {
        newSpecies != nil || newProducerTier != nil || newSupplyProducer != nil
    }

    /// One-line summary for the level-up banner.
    func primaryMessage() -> String {
        if let s = newSpecies         { return "\(s.name)s join the sanctuary!" }
        if let p = newProducerTier    { return "\(p.displayName) now in shop!" }
        if let p = newSupplyProducer  { return "\(p.displayName) placed on your board!" }
        if let p = cardPack           { return "\(p.displayName) added to your collection!" }
        if bonusKibble > 0            { return "+\(bonusKibble) Kibble bonus!" }
        return "Keep rescuing!"
    }
}

/// Returns the reward a player receives upon reaching `level`.
func levelUpReward(for level: Int) -> LevelUpReward {
    var r = LevelUpReward()
    // Animal species are now unlocked by building map areas (family spawner system).
    // Rescue-tier producers (shelterPod/fosterHome) superseded by family spawners.
    // Supply producers unlock via level-up — placed on the board automatically.
    switch level {
    case 15: r.newSupplyProducer = .groomingBox
    case 20: r.newSupplyProducer = .feedBox
    case 25: r.newSupplyProducer = .shelterBox
    default: break
    }
    // Card packs at milestone levels
    switch level {
    case 3, 6:      r.cardPack = .star1
    case 9, 12:     r.cardPack = .star2
    case 15, 18:    r.cardPack = .star3
    case 20, 22:    r.cardPack = .star4
    case 25:        r.cardPack = .star5
    case 30:        r.cardPack = .star6
    default: break
    }
    return r
}

let loginDailyRewards: [(kibble: Int, dogTags: Int, label: String)] = [
    (kibble: 5,  dogTags: 0, label: "Day 1"),
    (kibble: 10, dogTags: 0, label: "Day 2"),
    (kibble: 5,  dogTags: 2, label: "Day 3"),
    (kibble: 15, dogTags: 0, label: "Day 4"),
    (kibble: 10, dogTags: 3, label: "Day 5"),
    (kibble: 20, dogTags: 0, label: "Day 6"),
    (kibble: 15, dogTags: 5, label: "Day 7"),
]
