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

    /// The 15 unique tier names for this family, index 0 (smallest) through 14 (top tier).
    var tierNames: [String] {
        switch self {
        case .dog:       return ["Pup", "Kit", "Houndling",
                                 "Terrier", "Spaniel", "Scout",
                                 "Retriever", "Shepherd", "Husky",
                                 "Alpha", "Guardian", "Sentinel",
                                 "Dire Wolf", "Mythic", "Primordial"]
        case .cat:       return ["Kitten", "Tabby", "Kit",
                                 "Ocelot", "Bobcat", "Lynx",
                                 "Puma", "Jaguar", "Leopard",
                                 "Panther", "Tiger", "Lion",
                                 "Sabertooth", "Sovereign", "Apex"]
        case .rabbit:    return ["Bunny", "Cottontail", "Rex",
                                 "Angora", "Lop", "Harlequin",
                                 "Hare", "Jackrabbit", "Snow",
                                 "Flemish", "Belgian", "Giant",
                                 "Desert", "Patagonian", "Mara"]
        case .bird:      return ["Hatchling", "Chick", "Fluff",
                                 "Sparrow", "Finch", "Starling",
                                 "Pigeon", "Magpie", "Jay",
                                 "Falcon", "Hawk", "Owl",
                                 "Eagle", "Vulture", "Condor"]
        case .hamster:   return ["Mouse", "Hamster", "Gerbil",
                                 "Chipmunk", "Squirrel", "Rat",
                                 "Chinchilla", "Degu", "Beaver",
                                 "Prairie Dog", "Marmot", "Nutria",
                                 "Muskrat", "Porcupine", "Capybara"]
        case .turtle:    return ["Hatch", "Gecko", "Anole",
                                 "Skink", "Racer", "Whiptail",
                                 "Iguana", "Monitor", "Tegu",
                                 "Gila", "Spiny", "Python",
                                 "Boa", "Caiman", "Komodo Dragon"]
        case .fox:       return ["Fawn", "Muntjac", "Roe",
                                 "Fallow", "Chital", "Sika",
                                 "Caribou", "Reindeer", "Deer",
                                 "Red", "Wapiti", "Elk",
                                 "Sambar", "Pere David", "Moose"]
        case .owl:       return ["Cub", "Sun", "Sloth",
                                 "Spectacled", "Moon", "Black",
                                 "Panda", "Cinnamon", "Glacier",
                                 "Brown", "Kodiak", "Grizzly",
                                 "Polar", "Ancient", "Behemoth"]
        case .fish:      return ["Guppy", "Tetra", "Minnow",
                                 "Clown", "Perch", "Bass",
                                 "Mackerel", "Tuna", "Salmon",
                                 "Sword", "Sail", "Marlin",
                                 "Shark", "Hammerhead", "Whale Shark"]
        case .lizard:    return ["Tadpole", "Froglet", "Newt",
                                 "Tree Frog", "Poison", "Reed",
                                 "Bullfrog", "Toad", "Horned",
                                 "Salamander", "Axolotl", "Mud",
                                 "Hellbender", "Giant", "Goliath"]
        case .ferret:    return ["Joey", "Quokka", "Honey",
                                 "Potoroo", "Bandicoot", "Bilby",
                                 "Wallaby", "Pademelon", "Tree",
                                 "Devil", "Quoll", "Wombat",
                                 "Koala", "Macropod", "Red Kangaroo"]
        case .parrot:    return ["Marmoset", "Tamarin", "Pygmy",
                                 "Squirrel", "Capuchin", "Owl",
                                 "Macaque", "Langur", "Guenon",
                                 "Baboon", "Mandrill", "Gibbon",
                                 "Chimpanzee", "Orangutan", "Gorilla"]
        case .pony:      return ["Foal", "Pony", "Shetland",
                                 "Donkey", "Mule", "Burro",
                                 "Mustang", "Arabian", "Paint",
                                 "Thoroughbred", "Shire", "Clydesdale",
                                 "Zebra", "Quagga", "Giraffe"]
        case .hedgehog:  return ["Piglet", "Warthog", "Peccary",
                                 "Tapir", "Boar", "Babirusa",
                                 "Hippo", "Pygmy", "Rhino",
                                 "White Rhino", "Black", "Indian",
                                 "Seal", "African", "Mammoth"]
        case .guineaPig: return ["Calf", "Heifer", "Oxen",
                                 "Steer", "Bull", "Zebu",
                                 "Bison", "Yak", "Muskox",
                                 "Highland", "Longhorn", "Gaur",
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
    // Does NOT appear in the shop or producer storage (use isShopProducer to gate).
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
        case .familySpawner: return 1   // not in storage — value unused
        }
    }
}

struct ProducerTile: Identifiable, Equatable, Codable {
    var id: UUID
    var level: ProducerLevel
    var cooldownRemaining: Double
    var chargesRemaining: Int
    /// Non-nil for `.familySpawner` tiles; identifies which family's animal chain this spawner produces.
    var species: AnimalSpecies?

    // Phase 4 buff state — persisted so buffs survive saves/restores.
    var speedBurstActive: Bool = false
    var speedBurstRemaining: Double = 0      // seconds remaining
    var nextDropGuaranteedHighTier: Bool = false

    // Phase 6 — Avians Scout preview: non-nil when Scout is unlocked and a spawn has just fired.
    // true = next spawn from this tile will be a sub-object, false = animal.
    var scoutPreviewIsSubObject: Bool? = nil

    init(level: ProducerLevel, cooldownRemaining: Double = 0,
         chargesRemaining: Int? = nil, species: AnimalSpecies? = nil) {
        self.id = UUID()
        self.level = level
        self.cooldownRemaining = cooldownRemaining
        self.chargesRemaining = chargesRemaining ?? level.maxCharges
        self.species = species
    }

    // Custom decoder so old saves (without the "species" key) still decode cleanly.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,         forKey: .id)
        level            = try c.decode(ProducerLevel.self, forKey: .level)
        cooldownRemaining = try c.decode(Double.self,       forKey: .cooldownRemaining)
        chargesRemaining = try c.decode(Int.self,           forKey: .chargesRemaining)
        species              = try c.decodeIfPresent(AnimalSpecies.self, forKey: .species)
        speedBurstActive     = try c.decodeIfPresent(Bool.self,         forKey: .speedBurstActive)     ?? false
        speedBurstRemaining  = try c.decodeIfPresent(Double.self,       forKey: .speedBurstRemaining)  ?? 0
        nextDropGuaranteedHighTier = try c.decodeIfPresent(Bool.self,   forKey: .nextDropGuaranteedHighTier) ?? false
        scoutPreviewIsSubObject    = try c.decodeIfPresent(Bool.self,   forKey: .scoutPreviewIsSubObject)
    }

    var isReady: Bool { cooldownRemaining <= 0 }
    /// 0 = fully charged, 1 = just fired (used to drive the cooldown ring).
    var cooldownFraction: Double { max(0, min(1, cooldownRemaining / level.cooldown)) }
    /// For family spawners: the animal chain this tile produces. Nil for other producer types.
    var animalChainID: ChainID? { species.map { ContentRegistry.animalChainID($0) } }
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
    var coinReward: Int {
        switch self {
        case .easy:      return 2
        case .medium:    return 5
        case .hard:      return 10
        case .legendary: return 25
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

    // MARK: Animal tier appearance — covers all 15 tiers (0–14).
    // Tiers 0–8 preserve the original RescueStage colors/symbols; tiers 9–14 use
    // higher-prestige purple/gold tones for the extended chain.
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
        case 9:  return ("Elite",         "bolt.circle.fill",      Color(red: 0.60, green: 0.20, blue: 0.90))
        case 10: return ("Champion",      "sparkles",              Color(red: 0.50, green: 0.18, blue: 0.82))
        case 11: return ("Legendary",     "seal.fill",             Color(red: 0.70, green: 0.50, blue: 0.90))
        case 12: return ("Mythic",        "trophy.fill",           Color(red: 0.85, green: 0.68, blue: 0.10))
        case 13: return ("Ancient",       "crown.circle.fill",     Color(red: 0.90, green: 0.75, blue: 0.08))
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

/// Duration (seconds) before an unfulfilled order expires and is replaced.
let adoptionOrderDuration: Double = 900

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
struct AdoptionOrder: Identifiable, Codable {
    var id = UUID()
    /// Index into the fixed `adoptionFamilies` roster (persisted instead of the
    /// struct itself, which carries a non-Codable `Color`).
    var familyIndex: Int
    var wantedChainID: ChainID       // was wantedSpecies
    var wantedTier: Int              // was wantedStage (0-based)
    var wantedCount: Int             // 1 or 2
    var fulfilled: Int = 0
    var timeRemaining: Double
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
    var timeFraction: Double     { timeRemaining / adoptionOrderDuration }
    var isUrgent: Bool           { timeRemaining < 120 && !isComplete }
    var timeText: String {
        let s = Int(timeRemaining)
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60 > 0 ? "\(s % 60)s" : "")"
    }

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
// MARK: - CONSTANTS
// ============================================================

// ── Weekly / monthly goal constants ──────────────────────────
let weeklyGoalBronzeCoins  = 50
let weeklyGoalSilverCoins  = 120
let weeklyGoalGoldCoins    = 250
/// Default number of Gold weeks required to complete the monthly goal.
/// Foster Haven T2 can reduce this by 1.
let monthlyGoalWeeksNeeded = 3

// ── Coin rewards ──────────────────────────────────────────────
let coinsPerAmbassadorMerge   = 10  // awarded in triggerTopTierCelebration
/// Bonus coins for exchanging a trio of Ambassador-tier tiles of the same species.
/// The player already earned coinsPerAmbassadorMerge × 3 = 30 from merging them up —
/// this is the extra reward for holding three and cashing them in together.
let ambassadorTrioExchangeCoins = 50

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
    var xpReward: Int {
        switch self { case .bronze: return 15; case .silver: return 35; case .gold: return 75 }
    }
}

// ── Dog Tag → Kibble exchange ─────────────────────────────────

struct DogTagKibbleExchange {
    let dogTagCost: Int
    let kibbleGain: Int
    var label: String { "\(dogTagCost) Dog Tags → \(kibbleGain) Kibble" }

    static let all: [DogTagKibbleExchange] = [
        DogTagKibbleExchange(dogTagCost:  40, kibbleGain: 100),
        DogTagKibbleExchange(dogTagCost:  80, kibbleGain: 240),
        DogTagKibbleExchange(dogTagCost: 120, kibbleGain: 480),
    ]
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

// ── Board dimensions (fixed — never changes at runtime) ──────
let boardRows = 9   // 9 rows × 7 cols = 63 positions; bottom 2 rows start locked
/// Level at which each board row (by index) unlocks. Rows 0–6 start unlocked.
let boardRowUnlockLevels: [Int: Int] = [7: 3, 8: 8]

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
func maxAchievableOrderTier(forPlayerLevel level: Int) -> Int {
    switch level {
    case 1...3:   return 2
    case 4...6:   return 5
    case 7...9:   return 8
    case 10...12: return 10
    case 13...18: return 12
    default:      return 14
    }
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
