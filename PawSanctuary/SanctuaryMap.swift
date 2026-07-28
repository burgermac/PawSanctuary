//
//  SanctuaryMap.swift  —  Phase 4 + Phase 5: Sanctuary area construction & upgrades
//  PawSanctuary
//
//  Players accumulate materials (wood/metal/cement) from Toolboxes and spend
//  them here to build sanctuary areas. Each area unlocks board rows, new species,
//  and currency bonuses. Areas unlock sequentially — complete each before the next
//  becomes available.
//
//  Each area has 4 upgrade tiers. Upgrades cost coins plus higher-tier materials
//  and grant permanent passive bonuses. The next area unlocks only after the previous
//  area is fully built AND all 4 upgrades are purchased.
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

    // Phase 5 — new upgrade bonus types (areas 7–15)
    var subObjectDropRateBonus: Int    = 0  // adds N percentage points to the 20% base sub-object rate
    var pityTimerReduction:     Int    = 0  // reduces rare/epic pity thresholds by N spawns each
    var powerUpDurationBonus:   Double = 0  // extends Speed Burst active time by N seconds

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
            areaEventCoins:           areaEventCoins           + other.areaEventCoins,
            subObjectDropRateBonus:   subObjectDropRateBonus   + other.subObjectDropRateBonus,
            pityTimerReduction:       pityTimerReduction       + other.pityTimerReduction,
            powerUpDurationBonus:     powerUpDurationBonus     + other.powerUpDurationBonus
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
        if subObjectDropRateBonus  > 0 { parts.append("Sub-object rate +\(subObjectDropRateBonus)%") }
        if pityTimerReduction      > 0 { parts.append("Pity timer −\(pityTimerReduction)") }
        if powerUpDurationBonus    > 0 { parts.append("Power-up duration +\(Int(powerUpDurationBonus))s") }
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
            AreaUpgradeTier(
                id: "area.welcome.upgrade.3",
                displayName: "Morning Walk Route",
                description: "A dedicated walking circuit keeps Canine energy channelled and staff efficiency high — every regen tick delivers an extra kibble to the reserves.",
                coinCost: 400,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(kibblePerRegen: 1)
            ),
            AreaUpgradeTier(
                id: "area.welcome.upgrade.4",
                displayName: "Canine Hall of Fame",
                description: "A gallery of framed portraits celebrates every dog's journey from rescue to adoption. Community pride draws enough ongoing support to open an extra adoption slot.",
                coinCost: 1000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(extraAdoptionSlots: 1)
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
            AreaUpgradeTier(
                id: "area.grooming.upgrade.3",
                displayName: "Sunroom Observatory",
                description: "A glass-walled sunroom where Felines lounge in golden light all morning. Charmed volunteers arrive early and stay late, boosting every daily challenge payout.",
                coinCost: 650,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 3)],
                bonus: UpgradeBonus(coinsPerDailyComplete: 3)
            ),
            AreaUpgradeTier(
                id: "area.grooming.upgrade.4",
                displayName: "Catnip Garden",
                description: "A fragrant catnip garden draws press cameras and new supporters throughout the year. The sustained donations ease the weekly Gold fundraising target.",
                coinCost: 1600,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                // Phase 2c: an absolute coin discount, rescaled alongside the Gold
                // threshold it reduces (was 25 against a target of 250).
                bonus: UpgradeBonus(weeklyGoldDiscount: 1_500)
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
            AreaUpgradeTier(
                id: "area.rescue.upgrade.3",
                displayName: "Meadow Foraging Trail",
                description: "Wide foraging trails keep the Lagomorphs content and their keepers busy. The constant activity means kibble stores are topped up more frequently.",
                coinCost: 950,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(kibblePerRegen: 1)
            ),
            AreaUpgradeTier(
                id: "area.rescue.upgrade.4",
                displayName: "Clover Labyrinth",
                description: "A famous clover maze draws visitors year-round. Their sustained engagement eases the monthly milestone — one fewer Gold week is required to claim the prize.",
                coinCost: 2400,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 1),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(monthlyWeeksDiscount: 1)
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
                // Phase 2c: an absolute coin discount, rescaled alongside the Gold
                // threshold it reduces (was 25 against a target of 250).
                bonus: UpgradeBonus(weeklyGoldDiscount: 1_500)
            ),
            AreaUpgradeTier(
                id: "area.foster.upgrade.2",
                displayName: "Migration Network",
                description: "A nationwide bird-banding partnership reduces the effort needed to earn the monthly milestone — just two Gold weeks stand between you and the prize.",
                coinCost: 500,
                materialCosts: [MaterialCost(chainID: ContentRegistry.woodChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(monthlyWeeksDiscount: 1)
            ),
            AreaUpgradeTier(
                id: "area.foster.upgrade.3",
                displayName: "Feather Archive",
                description: "A display cabinet of moulted plumage records every species that has passed through. The rare finds attract naturalist collectors, increasing sub-object activity.",
                coinCost: 1250,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.foster.upgrade.4",
                displayName: "Aerial Observation Post",
                description: "Cameras mounted in the canopy follow migration patterns in real time. The scientific prestige brings quest sponsors who attach an extra Dog Tag to every quest.",
                coinCost: 3100,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(questDogTagBonus: 1)
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
            AreaUpgradeTier(
                id: "area.ambassador.upgrade.3",
                displayName: "Seed Vault",
                description: "An underground seed vault keeps the Rodents well-fed and their pity cycles predictable — guaranteed rare sub-object drops come sooner across the whole sanctuary.",
                coinCost: 1600,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
            AreaUpgradeTier(
                id: "area.ambassador.upgrade.4",
                displayName: "Gnaw & Forage Track",
                description: "A foraging track weaving through the burrow system increases spawner activity across the whole sanctuary — sub-objects fall more frequently from every family.",
                coinCost: 4000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
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
            AreaUpgradeTier(
                id: "area.legends.upgrade.3",
                displayName: "Reptile Nursery",
                description: "A climate-controlled nursery fills with curious adopters waiting for clutches to hatch. The steady demand opens an extra adoption slot for all families.",
                coinCost: 2200,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(extraAdoptionSlots: 1)
            ),
            AreaUpgradeTier(
                id: "area.legends.upgrade.4",
                displayName: "Fossil Gallery",
                description: "Ancient fossils sourced from sanctuary land form a permanent exhibit. Every ambassador animal earns a mention in the newsletter — and extra coins for the sanctuary.",
                coinCost: 5500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 4),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(coinsPerAmbassador: 5)
            ),
        ]
    ),

    // ── Phase 5 — Nine remaining families ───────────────────────────────────

    // 7 — Ursids (Hollow Log)
    SanctuaryArea(
        id: "area.ursids",
        displayName: "Hollow Log",
        sfSymbol: "pawprint.circle.fill",
        color: Color(red: 0.55, green: 0.38, blue: 0.22),
        description: "A cathedral-sized fallen oak with a cavernous hollow — generations of Ursids have called it home, padding the interior with moss and leaves until it smells unmistakably of wild forest.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
        ],
        reward: AreaReward(newFamilySpawner: .owl, bonusKibble: 60, bonusDogTags: 25, bonusXP: 250),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.ursids.upgrade.1",
                displayName: "Honey Cache",
                description: "Rich honeycombs stored deep in the hollow draw extra activity from every spawner nearby — the bees' industry rubs off on all the animals around.",
                coinCost: 600,
                materialCosts: [MaterialCost(chainID: ContentRegistry.woodChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.ursids.upgrade.2",
                displayName: "Bear Statue Overlook",
                description: "A carved cedar sentinel keeps watch over the grove. Every ambassador Ursid earns press coverage — and the donations roll in as coins for the sanctuary.",
                coinCost: 1200,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(coinsPerAmbassador: 5)
            ),
            AreaUpgradeTier(
                id: "area.ursids.upgrade.3",
                displayName: "Foraging Pit",
                description: "Digging pits modelled on natural foraging ground tap into the Ursids' most focused instincts. Their rhythmic activity shortens pity cycles — rare sub-objects arrive sooner.",
                coinCost: 3000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
            AreaUpgradeTier(
                id: "area.ursids.upgrade.4",
                displayName: "Hibernation Vault",
                description: "A deep wintering chamber extends the hive's active season and slows time in a good way — every activated power-up lingers fifteen seconds longer.",
                coinCost: 7500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 4),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(powerUpDurationBonus: 15)
            ),
        ]
    ),

    // 8 — Aquatics (Coral Reef)
    SanctuaryArea(
        id: "area.aquatics",
        displayName: "Coral Reef",
        sfSymbol: "water.waves",
        color: Color(red: 0.20, green: 0.60, blue: 0.80),
        description: "A saltwater lagoon behind the sanctuary's main building, filled with living coral formations and soft light that plays across the sand — Aquatics glide between the branches as visitors press their faces to the glass.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 3),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
        ],
        reward: AreaReward(newFamilySpawner: .fish, bonusKibble: 80, bonusDogTags: 30, bonusXP: 300),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.aquatics.upgrade.1",
                displayName: "Tidal Pool",
                description: "Shallow tidal pools brim with life and keep kibble supplies circulating — each regen tick carries extra kibble on the current.",
                coinCost: 750,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(kibblePerRegen: 1)
            ),
            AreaUpgradeTier(
                id: "area.aquatics.upgrade.2",
                displayName: "Deep Current Channel",
                description: "Underwater channels connect the reef to the open ocean. The steady rhythm of the tides shortens the wait between rare sub-object drops.",
                coinCost: 1500,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
            AreaUpgradeTier(
                id: "area.aquatics.upgrade.3",
                displayName: "Bioluminescent Cave",
                description: "A black-lit cave carved into the reef wall creates a breathtaking after-dark display. The increased foot traffic and media attention draws more sub-object drops across the whole sanctuary.",
                coinCost: 3750,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.aquatics.upgrade.4",
                displayName: "Kelp Forest Expansion",
                description: "A vast kelp forest extension broadens the lagoon's boundary and amplifies every power-up activated nearby — Speed Bursts and all activatable effects linger fifteen seconds longer.",
                coinCost: 9400,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 5),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(powerUpDurationBonus: 15)
            ),
        ]
    ),

    // 9 — Amphibians (Lily Pad)
    SanctuaryArea(
        id: "area.amphibians",
        displayName: "Lily Pad",
        sfSymbol: "leaf.circle.fill",
        color: Color(red: 0.30, green: 0.65, blue: 0.50),
        description: "A still pond ringed with towering reeds and blanketed in giant lily pads — Amphibians lunge, bask, and call from every corner while dragonflies trace arcs above the glassy water.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 3),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
        ],
        reward: AreaReward(newFamilySpawner: .lizard, bonusKibble: 90, bonusDogTags: 35, bonusXP: 350),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.amphibians.upgrade.1",
                displayName: "Frog Choir Stage",
                description: "A natural amphitheatre of lily pads fills the air with evening song. Charmed visitors extend adoption hours — an extra adoption order slot opens.",
                coinCost: 900,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(extraAdoptionSlots: 1)
            ),
            AreaUpgradeTier(
                id: "area.amphibians.upgrade.2",
                displayName: "Wetlands Research Station",
                description: "Scientists monitoring the ecosystem find that the rich wetland chemistry makes spawners unusually productive. Sub-objects appear more often across the whole board.",
                coinCost: 1800,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.amphibians.upgrade.3",
                displayName: "Moonlit Pond",
                description: "Nighttime guided tours showcase the Amphibians' natural glow. Legendary quest sponsors take notice — legendary quests now pay out extra coins.",
                coinCost: 4500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(legendaryQuestCoinBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.amphibians.upgrade.4",
                displayName: "Cascade Stream",
                description: "A cascading stream feeds the pond from higher ground, carrying nutrients that boost the spawn economy. Every adoption order fulfilled earns extra coins for the sanctuary.",
                coinCost: 11200,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 4),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(coinsPerOrderFulfil: 2)
            ),
        ]
    ),

    // 10 — Marsupials (Eucalyptus Branch)
    SanctuaryArea(
        id: "area.marsupials",
        displayName: "Eucalyptus Branch",
        sfSymbol: "tree.fill",
        color: Color(red: 0.75, green: 0.42, blue: 0.62),
        description: "A grove of towering eucalyptus draped with rope bridges and nesting platforms — Marsupials peer down from every height, wide-eyed and curious, as the sharp scent of gum leaves fills the air.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
        ],
        reward: AreaReward(newFamilySpawner: .ferret, bonusKibble: 100, bonusDogTags: 40, bonusXP: 400),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.marsupials.upgrade.1",
                displayName: "Pouch Nursery",
                description: "Wallabies carrying joeys are irresistible to quest sponsors. Every completed quest earns an extra Dog Tag from the admiring crowd.",
                coinCost: 1050,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(questDogTagBonus: 1)
            ),
            AreaUpgradeTier(
                id: "area.marsupials.upgrade.2",
                displayName: "Treetop Canopy Walk",
                description: "An elevated boardwalk through the canopy keeps power-up effects active longer — every Speed Burst gained anywhere in the sanctuary lasts an extra fifteen seconds.",
                coinCost: 2100,
                materialCosts: [MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(powerUpDurationBonus: 15)
            ),
            AreaUpgradeTier(
                id: "area.marsupials.upgrade.3",
                displayName: "Glider Launch Platform",
                description: "Sugar gliders launched from raised platforms trail sub-object fragments in their wake. Their aerobatic displays increase sub-object drop frequency across the whole sanctuary.",
                coinCost: 5200,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.marsupials.upgrade.4",
                displayName: "Wombat Burrow Network",
                description: "A deep underground warren connects the grove's habitats. The reliable burrowing rhythm reduces pity counters — guaranteed rare sub-objects arrive sooner across the sanctuary.",
                coinCost: 13000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 5),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
        ]
    ),

    // 11 — Primates (Tropical Tree)
    SanctuaryArea(
        id: "area.primates",
        displayName: "Tropical Tree",
        sfSymbol: "tree.circle.fill",
        color: Color(red: 0.58, green: 0.32, blue: 0.70),
        description: "A vast strangler fig whose aerial roots form natural ladders and swings — Primates swing, groom, and problem-solve high above the canopy floor while visitors crane their necks to follow every leap.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
        ],
        reward: AreaReward(newFamilySpawner: .parrot, bonusKibble: 110, bonusDogTags: 45, bonusXP: 450),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.primates.upgrade.1",
                displayName: "Research Platform",
                description: "Scientists set up a platform to study the primates' renowned tool use. Their famous ingenuity inspires larger payouts — legendary quests earn extra coins.",
                coinCost: 1250,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(legendaryQuestCoinBonus: 10)
            ),
            AreaUpgradeTier(
                id: "area.primates.upgrade.2",
                displayName: "Forest Intelligence Network",
                description: "A web of observation posts across the canopy accelerates data collection. Pity timers tick down faster — rare sub-objects are guaranteed sooner.",
                coinCost: 2500,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2)],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
            AreaUpgradeTier(
                id: "area.primates.upgrade.3",
                displayName: "Vine Tasting Bar",
                description: "A tasting station offering rare jungle fruit draws foodie visitors who linger for hours. Their generous donations keep staff busy and kibble regen rates elevated.",
                coinCost: 6200,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(kibblePerRegen: 1)
            ),
            AreaUpgradeTier(
                id: "area.primates.upgrade.4",
                displayName: "Primate Enrichment Lab",
                description: "Advanced enrichment programmes recognised by national zoological boards open doors to extended adoption days — one more adoption slot becomes permanently available.",
                coinCost: 15500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 5),
                ],
                bonus: UpgradeBonus(extraAdoptionSlots: 1)
            ),
        ]
    ),

    // 12 — Equines (Stable Gate)
    SanctuaryArea(
        id: "area.equines",
        displayName: "Stable Gate",
        sfSymbol: "door.garage.closed",
        color: Color(red: 0.65, green: 0.48, blue: 0.28),
        description: "A handsome timber stable with iron-hinged doors, a hay loft, and a wide exercise paddock — Equines pace their stalls and poke curious noses over the gate, greeting every morning shift with a whinny.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 5),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 4),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
        ],
        reward: AreaReward(newFamilySpawner: .pony, bonusKibble: 120, bonusDogTags: 50, bonusXP: 500),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.equines.upgrade.1",
                displayName: "Riding Arena",
                description: "Open riding sessions draw morning volunteers in droves. Every daily challenge completed earns extra coins from the popular gate sessions.",
                coinCost: 1500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(coinsPerDailyComplete: 5)
            ),
            AreaUpgradeTier(
                id: "area.equines.upgrade.2",
                displayName: "Paddock Pastures",
                description: "Broad salt-lick pastures create ideal foraging habitat. Spawners near the stable begin dropping sub-objects more reliably across the whole sanctuary.",
                coinCost: 3000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.equines.upgrade.3",
                displayName: "Tack Room & Farrier",
                description: "A professional farrier on-site draws expert visitors who study movement patterns. Their analysis sharpens the sanctuary's spawner rhythms — pity timers shorten and rare sub-objects fall sooner.",
                coinCost: 7500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 4),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
            AreaUpgradeTier(
                id: "area.equines.upgrade.4",
                displayName: "Show-Jump Course",
                description: "A full show-jumping course draws competitors and crowds from across the region. The spectacle and atmosphere extend every power-up activated anywhere in the sanctuary.",
                coinCost: 18700,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 6),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(powerUpDurationBonus: 15)
            ),
        ]
    ),

    // 13 — Pachyderms (Watering Hole)
    SanctuaryArea(
        id: "area.pachyderms",
        displayName: "Watering Hole",
        sfSymbol: "drop.circle.fill",
        color: Color(red: 0.50, green: 0.48, blue: 0.55),
        description: "A wide clay-banked pool fed by a solar pump — Pachyderms wade, spray, and roll in the shallow mud flat while egrets pick their way along the shallows and visitors cluster three-deep at the viewing fence.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 5),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 5),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
        ],
        reward: AreaReward(newFamilySpawner: .hedgehog, bonusKibble: 140, bonusDogTags: 55, bonusXP: 550),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.pachyderms.upgrade.1",
                displayName: "Mud Bath Spa",
                description: "A legendary mud bath draws visitors from far and wide. The steady flow of donations eases every fundraising goal — the weekly Gold coin target dips.",
                coinCost: 1800,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 2),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(weeklyGoldDiscount: 50)
            ),
            AreaUpgradeTier(
                id: "area.pachyderms.upgrade.2",
                displayName: "Savanna Observatory",
                description: "A viewing tower overlooking the waterhole extends every keeper's sight lines. Power-ups linger longer — each Speed Burst gained lasts an extra fifteen seconds.",
                coinCost: 3600,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3)],
                bonus: UpgradeBonus(powerUpDurationBonus: 15)
            ),
            AreaUpgradeTier(
                id: "area.pachyderms.upgrade.3",
                displayName: "Saltmarsh Flats",
                description: "Expansive saltmarsh flats give Pachyderms prime foraging territory. Their steady presence and the habitat's richness increase sub-object drop frequency across the sanctuary.",
                coinCost: 9000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 5),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
            AreaUpgradeTier(
                id: "area.pachyderms.upgrade.4",
                displayName: "Research Station Annexe",
                description: "A satellite research station records the Pachyderms' seasonal patterns. Findings submitted to the foundation reduce the monthly milestone — one fewer Gold week is required.",
                coinCost: 22500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 6),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 5),
                ],
                bonus: UpgradeBonus(monthlyWeeksDiscount: 1)
            ),
        ]
    ),

    // 14 — Bovines (Rustic Milk Pail)
    SanctuaryArea(
        id: "area.bovines",
        displayName: "Rustic Milk Pail",
        sfSymbol: "bucket.fill",
        color: Color(red: 0.70, green: 0.52, blue: 0.18),
        description: "A lovingly restored farmstead with split-rail fencing, hand-painted stall boards, and the warm smell of hay — Bovines graze the wide meadow behind it as bells toll softly with every movement.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 5),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 5),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 5),
        ],
        reward: AreaReward(newFamilySpawner: .guineaPig, bonusKibble: 160, bonusDogTags: 60, bonusXP: 600),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.bovines.upgrade.1",
                displayName: "Grazing Meadow",
                description: "Wide meadows of clover and alfalfa give the herd room to roam. Staff who tend the cattle keep kibble supplies circulating — each regen tick carries extra kibble.",
                coinCost: 2200,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 1),
                ],
                bonus: UpgradeBonus(kibblePerRegen: 1)
            ),
            AreaUpgradeTier(
                id: "area.bovines.upgrade.2",
                displayName: "Heritage Barn",
                description: "A heritage barn houses the sanctuary's rarest breeds. Its peaceful rhythm shortens every spawner's pity timer — guaranteed drops come sooner.",
                coinCost: 4400,
                materialCosts: [MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 3)],
                bonus: UpgradeBonus(pityTimerReduction: 5)
            ),
            AreaUpgradeTier(
                id: "area.bovines.upgrade.3",
                displayName: "Creamery & Market Stall",
                description: "A farm market selling artisan dairy generates a loyal following and extra visibility. Every ambassador animal earns coins from the admiring market crowd.",
                coinCost: 11000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 5),
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(coinsPerAmbassador: 5)
            ),
            AreaUpgradeTier(
                id: "area.bovines.upgrade.4",
                displayName: "Heritage Breed Registry",
                description: "Official heritage breed registry status draws national media attention. The sustained coverage boosts sub-object activity — sub-objects fall more frequently from every family spawner.",
                coinCost: 27500,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 5),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 6),
                ],
                bonus: UpgradeBonus(subObjectDropRateBonus: 5)
            ),
        ]
    ),

    // 15 — Cervids (Forest Thicket)
    SanctuaryArea(
        id: "area.cervids",
        displayName: "Forest Thicket",
        sfSymbol: "tree.fill",
        color: Color(red: 0.35, green: 0.60, blue: 0.30),
        description: "A dense stand of silver birch and fern where dappled light filters through the canopy — Cervids move silently between the trunks, pausing to study visitors with ancient, unhurried eyes.",
        costs: [
            MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 6),
            MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 6),
            MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 6),
        ],
        reward: AreaReward(newFamilySpawner: .fox, bonusKibble: 200, bonusDogTags: 75, bonusXP: 800),
        requiresPrevious: true,
        upgrades: [
            AreaUpgradeTier(
                id: "area.cervids.upgrade.1",
                displayName: "Antler Arch Gallery",
                description: "A gallery of shed antler arches frames the entrance to the Cervids' corner. Awestruck visitors tip generously — every adoption order fulfilled earns extra coins.",
                coinCost: 2800,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID, tier: 5, count: 3),
                    MaterialCost(chainID: ContentRegistry.woodChainID,  tier: 5, count: 2),
                ],
                bonus: UpgradeBonus(coinsPerOrderFulfil: 2)
            ),
            AreaUpgradeTier(
                id: "area.cervids.upgrade.2",
                displayName: "Ancient Grove Shrine",
                description: "Deep in the oldest corner of the sanctuary, a moss-covered shrine draws quiet contemplation. Every new area built and upgraded earns a generous coin bonus.",
                coinCost: 5600,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 4),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 4),
                ],
                bonus: UpgradeBonus(areaEventCoins: 100)
            ),
            AreaUpgradeTier(
                id: "area.cervids.upgrade.3",
                displayName: "Birch Cathedral",
                description: "The innermost ring of silver birch forms a natural cathedral whose solemn beauty draws elite quest sponsors from across the country — pity timers shorten significantly across the whole sanctuary.",
                coinCost: 14000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 6),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 5),
                ],
                bonus: UpgradeBonus(pityTimerReduction: 10)
            ),
            AreaUpgradeTier(
                id: "area.cervids.upgrade.4",
                displayName: "Moonbeam Glade",
                description: "On clear nights, moonbeams filter through the canopy and transform the Glade into a realm of quiet wonder. The sanctuary reaches its full potential — kibble regen peaks and power-up windows lengthen.",
                coinCost: 35000,
                materialCosts: [
                    MaterialCost(chainID: ContentRegistry.woodChainID,   tier: 5, count: 8),
                    MaterialCost(chainID: ContentRegistry.metalChainID,  tier: 5, count: 7),
                    MaterialCost(chainID: ContentRegistry.cementChainID, tier: 5, count: 6),
                ],
                bonus: UpgradeBonus(kibblePerRegen: 1, powerUpDurationBonus: 30)
            ),
        ]
    ),
]
