//
//  SanctuaryMap.swift  —  Phase 4 + Phase 5: Sanctuary area construction & upgrades
//  PawSanctuary
//
//  Players accumulate materials (wood/metal/cement) from Toolboxes and spend
//  them here to build sanctuary areas. Each area unlocks board rows, new species,
//  and currency bonuses. Areas unlock sequentially — complete each before the next
//  becomes available.
//
//  Phase 5 adds 2 upgrade tiers per area. Upgrades cost coins (the new currency)
//  plus higher-tier materials and grant permanent passive bonuses.
//

import SwiftUI

// ============================================================
// MARK: - MATERIAL COST
// ============================================================

/// One line-item in a build or upgrade recipe.
struct MaterialCost: Codable, Equatable, Identifiable {
    var chainID: ChainID
    var tier: Int
    var count: Int

    var id: String { "\(chainID).\(tier)" }

    var chainName:  String { ContentRegistry.shared.chain(chainID)?.displayName ?? chainID }
    var tierName:   String { ContentRegistry.shared.tier(chainID, tier)?.name   ?? "Tier \(tier)" }
    var tierColor:  Color  { ContentRegistry.shared.tier(chainID, tier)?.color  ?? .gray }
    var tierSymbol: String { ContentRegistry.shared.tier(chainID, tier)?.symbol ?? "square.fill" }
}

// ============================================================
// MARK: - AREA REWARD
// ============================================================

/// What the player receives when an area is completed.
struct AreaReward {
    var newBoardRow:      Bool            = false
    /// When non-nil, building this area auto-places that family's spawner on the board
    /// and unlocks their animal chain. One spawner per area.
    var newFamilySpawner: AnimalSpecies?  = nil
    var bonusKibble:      Int             = 0
    var bonusDogTags:     Int             = 0
    var bonusXP:          Int             = 0

    func primaryMessage() -> String {
        var parts: [String] = []
        if newBoardRow { parts.append("New board row") }
        if let sp = newFamilySpawner { parts.append("\(sp.name) Spawner unlocked!") }
        if bonusKibble  > 0 { parts.append("+\(bonusKibble) Kibble") }
        if bonusDogTags > 0 { parts.append("+\(bonusDogTags) Dog Tags") }
        if bonusXP      > 0 { parts.append("+\(bonusXP) XP") }
        return parts.isEmpty ? "Complete!" : parts.joined(separator: "  ·  ")
    }
}

// ============================================================
// MARK: - UPGRADE BONUS
// ============================================================

/// Passive bonus granted by completing an area upgrade tier.
/// Summed across all active upgrades by the ViewModel's `recalcActiveBonuses()`.
struct UpgradeBonus {
    var coinsPerDailyComplete:   Int  = 0   // Antique Dog House T1
    var coinsPerOrderFulfil:     Int  = 0   // Antique Dog House T2
    var kibblePerRegen:          Int  = 0   // Scratching Post T1 (+1 kibble on each regen tick)
    var coinsPerAmbassador:      Int  = 0   // Scratching Post T2
    var extraAdoptionSlots:      Int  = 0   // Garden Hutch T1 (adds order slots beyond the base 2)
    var questDogTagBonus:        Int  = 0   // Garden Hutch T2 (+N dog tags on any quest claim)
    var weeklyGoldDiscount:      Int  = 0   // Decorative Birdhouse T1 (reduces the Gold coin target)
    var monthlyWeeksDiscount:    Int  = 0   // Decorative Birdhouse T2 (reduces weeks needed for monthly)
    var legendaryQuestCoinBonus: Int  = 0   // Wooden Burrow T1
    var weeklyRewardDoubled:     Bool = false // Wooden Burrow T2 (Silver + Gold kibble ×2)
    var spotlightMultiplierBonus: Int = 0   // Heated Rock T1 (adds to base 2× multiplier)
    var areaEventCoins:          Int  = 0   // Heated Rock T2 (+N coins on any build/upgrade)

    /// Combines two bonus snapshots into one accumulated result.
    func merging(_ other: UpgradeBonus) -> UpgradeBonus {
        UpgradeBonus(
            coinsPerDailyComplete:    coinsPerDailyComplete    + other.coinsPerDailyComplete,
            coinsPerOrderFulfil:      coinsPerOrderFulfil      + other.coinsPerOrderFulfil,
            kibblePerRegen:           kibblePerRegen           + other.kibblePerRegen,
            coinsPerAmbassador:       coinsPerAmbassador       + other.coinsPerAmbassador,
            extraAdoptionSlots:       extraAdoptionSlots       + other.extraAdoptionSlots,
            questDogTagBonus:         questDogTagBonus         + other.questDogTagBonus,
            weeklyGoldDiscount:       weeklyGoldDiscount       + other.weeklyGoldDiscount,
            monthlyWeeksDiscount:     monthlyWeeksDiscount     + other.monthlyWeeksDiscount,
            legendaryQuestCoinBonus:  legendaryQuestCoinBonus  + other.legendaryQuestCoinBonus,
            weeklyRewardDoubled:      weeklyRewardDoubled      || other.weeklyRewardDoubled,
            spotlightMultiplierBonus: spotlightMultiplierBonus + other.spotlightMultiplierBonus,
            areaEventCoins:           areaEventCoins           + other.areaEventCoins
        )
    }

    /// Human-readable summary for the upgrade-built banner.
    var primaryDescription: String {
        var parts: [String] = []
        if coinsPerDailyComplete   > 0 { parts.append("+\(coinsPerDailyComplete) coins/daily") }
        if coinsPerOrderFulfil     > 0 { parts.append("+\(coinsPerOrderFulfil) coin\(coinsPerOrderFulfil == 1 ? "" : "s")/order") }
        if kibblePerRegen          > 0 { parts.append("+\(kibblePerRegen) kibble/regen") }
        if coinsPerAmbassador      > 0 { parts.append("+\(coinsPerAmbassador) coins/ambassador") }
        if extraAdoptionSlots      > 0 { parts.append("+\(extraAdoptionSlots) adoption slot") }
        if questDogTagBonus        > 0 { parts.append("+\(questDogTagBonus) tag/quest") }
        if weeklyGoldDiscount      > 0 { parts.append("Gold target −\(weeklyGoldDiscount)") }
        if monthlyWeeksDiscount    > 0 { parts.append("Monthly: \(monthlyGoalWeeksNeeded - monthlyWeeksDiscount) gold weeks needed") }
        if legendaryQuestCoinBonus > 0 { parts.append("+\(legendaryQuestCoinBonus) coins/legendary") }
        if weeklyRewardDoubled         { parts.append("Weekly rewards ×2") }
        if spotlightMultiplierBonus > 0 { parts.append("Spotlight ×\(2 + spotlightMultiplierBonus)") }
        if areaEventCoins          > 0 { parts.append("+\(areaEventCoins) coins/build") }
        return parts.isEmpty ? "Bonus active" : parts.joined(separator: "  ·  ")
    }
}

// ============================================================
// MARK: - AREA UPGRADE TIER
// ============================================================

/// One rung in an area's upgrade ladder. Costs coins + materials; grants a permanent passive bonus.
struct AreaUpgradeTier: Identifiable {
    let id: String           // stable key, e.g. "area.welcome.upgrade.1"
    let displayName: String
    let description: String
    let coinCost: Int
    let materialCosts: [MaterialCost]
    let bonus: UpgradeBonus
}

// ============================================================
// MARK: - SANCTUARY AREA
// ============================================================

/// A named facility the player constructs by spending materials.
/// Not Codable — only the stable `id` is persisted (in `GameState.completedAreaIDs`
/// and `GameState.areaUpgradeLevels`).
struct SanctuaryArea: Identifiable {
    let id: String
    let displayName: String
    let sfSymbol: String
    let color: Color
    let description: String
    let costs: [MaterialCost]
    let reward: AreaReward
    let requiresPrevious: Bool
    let upgrades: [AreaUpgradeTier]   // index 0 = first upgrade tier, must be sequential
}

// ============================================================
// MARK: - AREA ROSTER (static, in unlock order)
// ============================================================

let sanctuaryAreas: [SanctuaryArea] = [

    // 1 — Tutorial area  (Canines — dog spawner is the day-one starter, so no newFamilySpawner here)
    SanctuaryArea(
        id: "area.welcome",
        displayName: "Antique Dog House",
        sfSymbol: "house.fill",
        color: Color(red: 0.60, green: 0.40, blue: 0.20),
        description: "A weathered wooden dog house — the warm, familiar heart of the Canines corner. Its well-worn scent and cosy straw bedding comfort every new arrival on their very first day.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID, tier: 5, count: 2),
        ],
        reward: AreaReward(bonusKibble: 10, bonusDogTags: 2, bonusXP: 25),
        requiresPrevious: false,
        upgrades: [
            AreaUpgradeTier(
                id: "area.welcome.upgrade.1",
                displayName: "Fetch & Play Yard",
                description: "A wide fenced yard where Canines romp and show off their tricks. Daily challenges run from here — every volunteer who takes part earns extra coins.",
                coinCost: 80,
                materialCosts: [MaterialCost(chainID: ContentRegistry.woodChainID, tier: 5, count: 1)],
                bonus: UpgradeBonus(coinsPerDailyComplete: 2)
            ),
            AreaUpgradeTier(
                id: "area.welcome.upgrade.2",
                displayName: "Puppy Parade Stage",
                description: "Weekly adoption parades bring the whole community together. Every family that takes a pup home leaves a small tip for the sanctuary.",
                coinCost: 160,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 1)],
                bonus: UpgradeBonus(coinsPerOrderFulfil: 1)
            ),
        ]
    ),

    // 2 — Early-game  (Felines — unlocks the Scratching Post spawner)
    SanctuaryArea(
        id: "area.grooming",
        displayName: "Scratching Post",
        sfSymbol: "cat.fill",
        color: Color(red: 0.45, green: 0.45, blue: 0.55),
        description: "A towering sisal-wrapped scratching post ringed with climbing shelves and dangling toys — the ultimate Feline playground where cats stretch, sharpen their claws, and charm every passerby.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 2),
            MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 1),
        ],
        reward: AreaReward(newBoardRow: true, newFamilySpawner: .cat, bonusKibble: 10, bonusXP: 40),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.grooming.upgrade.1",
                displayName: "Cosy Napping Nooks",
                description: "Serene sleeping pods keep the Felines well-rested and content. Staff who check on them keep kibble supplies topped up — regen ticks deliver extra kibble.",
                coinCost: 120,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(kibblePerRegen: 1)
            ),
            AreaUpgradeTier(
                id: "area.grooming.upgrade.2",
                displayName: "Cat Café Corner",
                description: "A charming cat café where adopting families linger over coffee and cuddles. Every ambassador Feline earns press coverage — and extra coins for the sanctuary.",
                coinCost: 260,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(coinsPerAmbassador: 3)
            ),
        ]
    ),

    // 3 — Mid-game  (Lagomorphs — unlocks the Garden Hutch spawner)
    SanctuaryArea(
        id: "area.rescue",
        displayName: "Garden Hutch",
        sfSymbol: "hare.fill",
        color: Color(red: 0.75, green: 0.50, blue: 0.40),
        description: "A sun-drenched garden hutch with vegetable patches, shaded tunnels, and clover-covered runs — a paradise for Lagomorphs who love to binky through the greenery.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 1),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 1),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 1),
        ],
        reward: AreaReward(newBoardRow: true, newFamilySpawner: .rabbit, bonusKibble: 15, bonusDogTags: 5, bonusXP: 60),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.rescue.upgrade.1",
                displayName: "Warren Expansion",
                description: "Extra tunnel runs and underground chambers free up space — more adoption families can bring home a bunny at once.",
                coinCost: 180,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(extraAdoptionSlots: 1)
            ),
            AreaUpgradeTier(
                id: "area.rescue.upgrade.2",
                displayName: "Bunny Hop Trail",
                description: "The famous scenic hop trail makes national news. Quest sponsors take notice — every completed quest now comes with an extra Dog Tag.",
                coinCost: 380,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(questDogTagBonus: 1)
            ),
        ]
    ),

    // 4 — Late mid-game  (Avians — unlocks the Decorative Birdhouse spawner)
    SanctuaryArea(
        id: "area.foster",
        displayName: "Decorative Birdhouse",
        sfSymbol: "bird.fill",
        color: Color(red: 0.25, green: 0.55, blue: 0.90),
        description: "An ornate multi-story birdhouse strung with perches, feeding ledges, and hanging seed bells — the cheerful chorus of the Avians within lifts every visitor's spirits.",
        costs: [
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
        ],
        reward: AreaReward(newBoardRow: true, newFamilySpawner: .bird, bonusKibble: 20, bonusDogTags: 8, bonusXP: 80),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.foster.upgrade.1",
                displayName: "Songbird Roost",
                description: "A cosy indoor roost where birdsong fills the corridors all morning. The uplifting atmosphere draws extra donations — the weekly Gold target drops.",
                coinCost: 250,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(weeklyGoldDiscount: 25)
            ),
            AreaUpgradeTier(
                id: "area.foster.upgrade.2",
                displayName: "Migration Network",
                description: "A nationwide bird-banding partnership reduces the effort needed to earn the monthly milestone — just two Gold weeks stand between you and the prize.",
                coinCost: 500,
                materialCosts: [MaterialCost(chainID: ContentRegistry.woodChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(monthlyWeeksDiscount: 1)
            ),
        ]
    ),

    // 5 — Late-game  (Rodents — unlocks the Wooden Burrow spawner)
    SanctuaryArea(
        id: "area.ambassador",
        displayName: "Wooden Burrow",
        sfSymbol: "tunnel.fill",
        color: Color(red: 0.80, green: 0.55, blue: 0.15),
        description: "A complex of cosy wooden tunnels and nest chambers where Rodents feel right at home — nibbling, burrowing, and charming every volunteer who peers inside.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 2),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
        ],
        reward: AreaReward(newBoardRow: true, newFamilySpawner: .hamster, bonusKibble: 30, bonusDogTags: 12, bonusXP: 120),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.ambassador.upgrade.1",
                displayName: "Explorer's Hoard",
                description: "Deep inside the burrow, the Rodents' legendary hoarding habits inspire quest sponsors — legendary quests now pay out extra coins.",
                coinCost: 320,
                materialCosts: [MaterialCost(chainID: ContentRegistry.woodChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(legendaryQuestCoinBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.ambassador.upgrade.2",
                displayName: "Seed & Store Larder",
                description: "A well-stocked grain larder tucked into the burrow showcases the sanctuary's abundance — weekly Silver and Gold chest kibble rewards are doubled.",
                coinCost: 650,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(weeklyRewardDoubled: true)
            ),
        ]
    ),

    // 6 — Prestige / end-game  (Reptiles — unlocks the Heated Rock spawner)
    SanctuaryArea(
        id: "area.legends",
        displayName: "Heated Rock",
        sfSymbol: "tortoise.fill",
        color: Color(red: 0.70, green: 0.38, blue: 0.15),
        description: "A sun-warmed basking platform studded with smooth river stones and heat lamps — the perfect retreat for Reptiles who thrive in warmth and display their calm confidence to every amazed visitor.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 3),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
        ],
        reward: AreaReward(newFamilySpawner: .turtle, bonusKibble: 50, bonusDogTags: 20, bonusXP: 200),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.legends.upgrade.1",
                displayName: "Basking Terrace",
                description: "With Reptiles at their most vibrant under full sun, spotlight visitors flock to the terrace. All spotlight merges now earn triple score.",
                coinCost: 450,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(spotlightMultiplierBonus: 1)
            ),
            AreaUpgradeTier(
                id: "area.legends.upgrade.2",
                displayName: "Ancient Scale Archive",
                description: "A museum of preserved scales and fossil casts inspires awe in every builder. Every new build and upgrade earns a coin bonus.",
                coinCost: 900,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(areaEventCoins: 50)
            ),
        ]
    ),
]
