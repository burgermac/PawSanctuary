//
//  MergeBoardViewModel.swift
//  PawSanctuary
//
//  The game's central orchestrator. It owns the board grid, coordinates cross-domain
//  operations (rewards, board placement, etc.), and holds references to the five
//  focused sub-coordinators:
//
//    • KibbleEngine       — kibble/dog-tags, regen, rewarded ads
//    • InventoryStore     — animal/tool/producer storage
//    • QuestCoordinator   — quests, daily challenges, spotlight, login
//    • AdoptionBoard      — adoption order generation, timers, fulfillment
//    • PlayerProgression  — level, XP, unlocked chains, spawn multiplier
//
//  Forwarding computed properties preserve every existing view call site so no view
//  code needs to change. SwiftUI's @Observable propagates tracking through computed
//  property getters, so `viewModel.kibble` correctly re-renders when
//  `kibbleEngine.kibble` changes.
//

import SwiftUI
import Observation
import AudioToolbox

// ============================================================
// MARK: - TOAST
// ============================================================

/// A single transient message shown in the toast overlay.
/// All toast-like notifications (board full, inventory full, reward confirmations, etc.)
/// flow through a single queue so none can silently cancel another.
struct Toast: Identifiable, Equatable {
    enum Kind: Equatable {
        case boardFull
        case inventoryFull
        case info(String)   // daily-challenge bonus, spotlight reward, pass/loyalty claim, etc.
    }

    let id: UUID = UUID()
    let kind: Kind

    var message: String {
        switch kind {
        case .boardFull:     return "Board is Full"
        case .inventoryFull: return "Inventory Full"
        case .info(let s):   return s
        }
    }

    /// Colour family that matches the semantic weight of the message.
    var color: Color {
        switch kind {
        case .boardFull:     return Color(red: 0.3, green: 0.4, blue: 0.6)
        case .inventoryFull: return Color(red: 0.7, green: 0.3, blue: 0.2)
        case .info:          return Color(red: 0.2, green: 0.5, blue: 0.7)
        }
    }

    static func == (lhs: Toast, rhs: Toast) -> Bool { lhs.id == rhs.id }
}

// ============================================================
// MARK: - RETIRABLE PRODUCER
// ============================================================

struct RetirableProducer: Identifiable {
    let position: GridPosition
    let producer: ProducerTile
    var id: String { "\(position.row)_\(position.col)" }
}

// ============================================================
// MARK: - AMBASSADOR TRIO EXCHANGE
// ============================================================

/// Represents three Ambassador-tier tiles of the same species on the board
/// that can be exchanged together for a coin bonus.
struct ExchangeableTrio: Identifiable {
    let species: AnimalSpecies
    /// The board positions of the three tiles to be removed on claim.
    let positions: [GridPosition]
    var id: String { species.rawValue }
}

// Board state snapshot for Nine Lives undo (session-only, not persisted).
struct BoardSnapshot {
    let board: [[BoardCell]]
    let inventory: [BoardItem?]
}

// ============================================================
// MARK: - VIEW MODEL
// ============================================================

@Observable
@MainActor
class MergeBoardViewModel {

    // MARK: Sub-coordinators

    let kibbleEngine  = KibbleEngine()
    let inventoryStore = InventoryStore()
    let quests        = QuestCoordinator()
    let adoptionBoardCoordinator = AdoptionBoard()
    let progression   = PlayerProgression()

    // MARK: Board state

    var rows = boardRows   // always 9 — fixed board size
    let cols = 7
    var board: [[BoardCell]] = []
    var score: Int = 0
    var animatingCell: GridPosition? = nil
    var rescueCount: Int = 0
    var ambassadors: Int = 0
    var mergeCount: Int = 0
    /// Progress toward the standing "collect 3 fully merged animals → 500 coins" quest.
    var ambassadorQuestProgress: Int = 0
    /// Queued material lots — each array is the contents of one pending toolbox tile.
    var pendingMaterialLots: [[BoardItem]] = []
    var newlyUnlockedCell: GridPosition? = nil
    var showUnlockBanner = false
    var draggingFrom: GridPosition? = nil
    var selectedCell: GridPosition? = nil
    /// Index into `inventoryStore.powerUpInventory` of the power-up the player has selected
    /// to apply to the next tapped family spawner. Nil when no power-up is selected.
    var selectedPowerUpSlot: Int? = nil

    // Ambassador celebration banner
    var showAmbassadorBanner  = false
    var ambassadorBannerChainID: ChainID = ContentRegistry.animalChainID(.dog)

    // Sanctuary Pass
    var isPassActive: Bool = false
    var passLastClaimDate: Date? = nil

    // Loyalty Club
    var loyaltyClubDayIndex: Int = 0
    var loyaltyClubLastClaimDate: Date? = nil
    var loyaltyClubStreak: Int = 0

    // Events
    var eventProgress: EventProgress = EventProgress()

    var activeEvent: EventDefinition? { EventRegistry.currentEvent }

    // Invite-a-friend
    var inviteProgress: InviteProgress = InviteProgress()

    // Game Center state (not persisted — re-derived each launch)
    var gcIsAuthenticated = false
    var gcLocalPlayerID = ""
    var gcLocalPlayerAlias = ""
    var gcFriends: [GameCenterFriend] = []
    var gcIsLoadingFriends = false

    // Toast queue — single source of truth for all transient messages.
    // Each pending toast is identified by UUID so auto-dismiss Tasks can't
    // accidentally cancel a later toast that was enqueued after them.
    private(set) var toastQueue: [Toast] = []
    var currentToast: Toast? { toastQueue.first }

    // Daily login
    var showLoginReward: Bool = false
    var loginStreakDay: Int = 1

    // Sanctuary map
    var completedAreaIDs: [String] = []
    var showMap: Bool = false
    var showAreaBuiltBanner: Bool = false
    var areaBuiltBannerTitle:  String = ""
    var areaBuiltBannerDetail: String = ""

    // Coins & weekly/monthly goal system
    var coins: Int = 0
    var coinsEarnedThisWeek: Int = 0
    var weeklyGoalBronzeClaimed: Bool = false
    var weeklyGoalSilverClaimed: Bool = false
    var weeklyGoalGoldClaimed: Bool = false
    var lastWeeklyGoalReset: Date? = nil
    var weeklyGoldCompletions: Int = 0
    var monthlyGoalClaimed: Bool = false
    var lastMonthlyGoalReset: Date? = nil
    var areaUpgradeLevels: [String: Int] = [:]

    // Card pack collection system
    var cardInventory: [String: Int] = [:]
    var starCount: Int = 0
    var completedAlbumIDs: [String] = []
    var pendingCardPacks: [CardPackType] = []
    var jokerCards: Int = 0
    var rareJokerCards: Int = 0
    var lastOpenedCards: [OpenedCard] = []
    var showCardPackOpening = false
    var showCardAlbum = false
    var showAlbumCompleteCard: CardAlbumDefinition? = nil

    // Card trading
    var pendingOutgoingTrades: [CardTrade] = []
    var pendingIncomingTrades: [CardTrade] = []
    var cardsSentToday: Int = 0
    var lastCardSendDate: Date? = nil

    // Cached derived state
    private(set) var boardIsFull: Bool = false

    // Pity tracking — keyed by AnimalSpecies.rawValue; persisted via GameState.pityStates.
    var pityStates: [String: PityState] = [:]

    // Superpower system (v24) — persisted fields mirror GameState.
    var unlockedSuperpowerSpecies: [String] = []
    var superpowerCooldownEnds: [String: Double] = [:]
    var lagomorphMergeCount: Int = 0
    var lastMergeTimestamp: Double = 0
    var lastMergedSpeciesRaw: String? = nil
    var equineSprintRemaining: Double = 0
    var pouchItems: [BoardItem?] = [nil, nil]
    var pouchExpiryTimestamp: Double = 0

    // Superpower session-only state (not persisted).
    var preMoveSnapshot: BoardSnapshot? = nil
    var leapMode: Bool = false
    var leapSourceCell: GridPosition? = nil
    var showPouchPanel: Bool = false
    var showSuperpowerUnlockBanner: Bool = false
    var superpowerUnlockBannerSpecies: AnimalSpecies? = nil

    @ObservationIgnored nonisolated(unsafe) private var regenTimer: Timer?
    @ObservationIgnored nonisolated(unsafe) private var saveTickCounter: Int = 0
    @ObservationIgnored nonisolated(unsafe) private var cachedActiveBonuses: UpgradeBonus = UpgradeBonus()
    var activeBonuses: UpgradeBonus { cachedActiveBonuses }

    // ============================================================
    // MARK: - FORWARDING COMPUTED PROPERTIES
    // SwiftUI @Observable propagates tracking through computed getters:
    // accessing `viewModel.kibble` registers a dependency on `kibbleEngine.kibble`.
    // ============================================================

    // KibbleEngine forwards
    var kibble: Int {
        get { kibbleEngine.kibble }
        set { kibbleEngine.kibble = newValue }
    }
    var dogTags: Int {
        get { kibbleEngine.dogTags }
        set { kibbleEngine.dogTags = newValue }
    }
    var secondsUntilNextKibble: Int {
        get { kibbleEngine.secondsUntilNextKibble }
        set { kibbleEngine.secondsUntilNextKibble = newValue }
    }
    var adsWatchedToday: Int {
        get { kibbleEngine.adsWatchedToday }
        set { kibbleEngine.adsWatchedToday = newValue }
    }
    var lastAdWatchDate: Date? {
        get { kibbleEngine.lastAdWatchDate }
        set { kibbleEngine.lastAdWatchDate = newValue }
    }
    var isWatchingAd: Bool {
        get { kibbleEngine.isWatchingAd }
        set { kibbleEngine.isWatchingAd = newValue }
    }
    var showKibbleSheet: Bool {
        get { kibbleEngine.showKibbleSheet }
        set { kibbleEngine.showKibbleSheet = newValue }
    }
    var kibbleStatusText: String { kibbleEngine.kibbleStatusText }
    var kibbleDisplayText: String { kibbleEngine.kibbleDisplayText }
    var remainingAdWatches: Int  { kibbleEngine.remainingAdWatches }

    // InventoryStore forwards
    var inventory: [BoardItem?] {
        get { inventoryStore.inventory }
        set { inventoryStore.inventory = newValue }
    }
    var inventoryRow1Unlocked: Bool {
        get { inventoryStore.inventoryRow1Unlocked }
        set { inventoryStore.inventoryRow1Unlocked = newValue }
    }
    var inventoryRow2Unlocked: Bool {
        get { inventoryStore.inventoryRow2Unlocked }
        set { inventoryStore.inventoryRow2Unlocked = newValue }
    }
    var producerStorage: [Int: ProducerTile] {
        get { inventoryStore.producerStorage }
        set { inventoryStore.producerStorage = newValue }
    }
    var overflowProducerStorage: [ProducerTile?] {
        get { inventoryStore.overflowProducerStorage }
        set { inventoryStore.overflowProducerStorage = newValue }
    }
    var showInventory: Bool {
        get { inventoryStore.showInventory }
        set { inventoryStore.showInventory = newValue }
    }
    var selectedInventorySlot: Int? {
        get { inventoryStore.selectedInventorySlot }
        set { inventoryStore.selectedInventorySlot = newValue }
    }
    var selectedProducerLevel: ProducerLevel? {
        get { inventoryStore.selectedProducerLevel }
        set { inventoryStore.selectedProducerLevel = newValue }
    }
    var selectedOverflowProducerSlot: Int? {
        get { inventoryStore.selectedOverflowProducerSlot }
        set { inventoryStore.selectedOverflowProducerSlot = newValue }
    }
    var inventoryOccupied: Int        { inventoryStore.inventoryOccupied }
    var producerStorageOccupied: Int  { inventoryStore.producerStorageOccupied }
    var inventoryCapacity: Int        { inventoryStore.inventoryCapacity }
    var producerOverflowCapacity: Int { inventoryStore.producerOverflowCapacity }

    // Material accumulator passthroughs
    func completedMaterialCount(chainID: ChainID) -> Int { inventoryStore.completedCount(chainID: chainID) }
    func materialTierCounts(chainID: ChainID) -> [Int]   { inventoryStore.tierCounts(chainID: chainID) }

    // QuestCoordinator forwards
    var activeQuests: [Quest] {
        get { quests.activeQuests }
        set { quests.activeQuests = newValue }
    }
    var dailyChallenges: [DailyChallenge] {
        get { quests.dailyChallenges }
        set { quests.dailyChallenges = newValue }
    }
    var dailyChallengeStreak: Int {
        get { quests.dailyChallengeStreak }
        set { quests.dailyChallengeStreak = newValue }
    }
    var dailyChallengeBonusClaimed: Bool {
        get { quests.dailyChallengeBonusClaimed }
        set { quests.dailyChallengeBonusClaimed = newValue }
    }
    var spotlightChainID: ChainID {
        get { quests.spotlightChainID }
        set { quests.spotlightChainID = newValue }
    }
    var spotlightMergesThisWeek: Int {
        get { quests.spotlightMergesThisWeek }
        set { quests.spotlightMergesThisWeek = newValue }
    }
    var lastSpotlightWeek: Int {
        get { quests.lastSpotlightWeek }
        set { quests.lastSpotlightWeek = newValue }
    }
    var lastDailyChallengeReset: Date? {
        get { quests.lastDailyChallengeReset }
        set { quests.lastDailyChallengeReset = newValue }
    }
    var lastLoginDate: Date? {
        get { quests.lastLoginDate }
        set { quests.lastLoginDate = newValue }
    }
    var loginStreak: Int {
        get { quests.loginStreak }
        set { quests.loginStreak = newValue }
    }
    var loginDayIndex: Int {
        get { quests.loginDayIndex }
        set { quests.loginDayIndex = newValue }
    }
    var spotlightProgressFraction: Double { quests.spotlightProgressFraction }
    var dailyChallengeResetText: String   { quests.dailyChallengeResetText }

    // AdoptionBoard forwards
    var adoptionOrders: [AdoptionOrder] {
        get { adoptionBoardCoordinator.adoptionOrders }
        set { adoptionBoardCoordinator.adoptionOrders = newValue }
    }

    // PlayerProgression forwards
    var playerLevel: Int {
        get { progression.playerLevel }
        set { progression.playerLevel = newValue }
    }
    var playerXP: Int {
        get { progression.playerXP }
        set { progression.playerXP = newValue }
    }
    var unlockedChainIDs: [ChainID] {
        get { progression.unlockedChainIDs }
        set { progression.unlockedChainIDs = newValue }
    }
    var unlockedProducerShopTiers: Set<ProducerLevel> {
        get { progression.unlockedProducerShopTiers }
        set { progression.unlockedProducerShopTiers = newValue }
    }
    var spawnMultiplier: Int {
        get { progression.spawnMultiplier }
        set { progression.spawnMultiplier = newValue }
    }
    var showLevelUpBanner: Bool {
        get { progression.showLevelUpBanner }
        set { progression.showLevelUpBanner = newValue }
    }
    var levelUpBannerTitle: String {
        get { progression.levelUpBannerTitle }
        set { progression.levelUpBannerTitle = newValue }
    }
    var levelUpBannerDetail: String {
        get { progression.levelUpBannerDetail }
        set { progression.levelUpBannerDetail = newValue }
    }
    var unlockedAnimalChainIDs: [ChainID]    { progression.unlockedAnimalChainIDs }
    var unlockedSupplyChainIDs: [ChainID]    { progression.unlockedSupplyChainIDs }
    var unlockedMergeableChainIDs: [ChainID] { progression.unlockedMergeableChainIDs }
    var unlockedMultipliers: [Int]           { progression.unlockedMultipliers }
    var xpToNextLevel: Int                   { progression.xpToNextLevel }
    var xpProgressFraction: Double           { progression.xpProgressFraction }
    var isInviteUnlocked: Bool               { progression.isInviteUnlocked }
    var isLoyaltyClubUnlocked: Bool          { progression.isLoyaltyClubUnlocked }

    // MARK: Board-derived computed

    var selectedCellHasProducer: Bool {
        guard let pos = selectedCell,
              pos.row < board.count,
              pos.col < (board.first?.count ?? 0) else { return false }
        return board[pos.row][pos.col].producer != nil
    }

    /// True when the selected cell holds a mergeable animal item (not a producer, not a toolbox).
    var selectedCellHasAnimalItem: Bool {
        guard let pos = selectedCell,
              pos.row < board.count,
              pos.col < (board.first?.count ?? 0) else { return false }
        let cell = board[pos.row][pos.col]
        guard cell.producer == nil, let item = cell.item else { return false }
        return item.chain?.category == .animal
    }

    /// Coin reward for selling an animal at the given tier index (0 = base, 14 = top tier).
    func sellValue(forTier tier: Int) -> Int {
        let scale = [1, 2, 5, 10, 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 25000, 100000]
        guard tier >= 0 && tier < scale.count else { return tier < 0 ? 1 : scale.last! }
        return scale[tier]
    }

    var selectedItemInfo: (text: String, chainID: ChainID?)? {
        if draggingFrom != nil {
            return ("Drag off-board to move to storage", nil)
        }
        guard let pos = selectedCell,
              pos.row < board.count,
              pos.col < (board.first?.count ?? 0) else { return nil }
        let cell = board[pos.row][pos.col]
        if let producer = cell.producer {
            if producer.level == .familySpawner, let sp = producer.species {
                return ("\(sp.spawnerName) · Tap to rescue \(sp.name) · costs \(spawnMultiplier) kibble · 20% sub-object drop chance", nil)
            }
            return ("\(producer.level.displayName) · Tap to spawn · costs \(spawnMultiplier) kibble", nil)
        }
        if let item = cell.item, let def = item.def, let chain = item.chain {
            let levelPrefix = chain.category == .animal ? "Level \(item.tier + 1) · " : ""
            let label = levelPrefix + def.name + " " + chain.displayName
            if item.isTopTier {
                return (label + " · Ambassador — top tier", item.chainID)
            }
            let nextName = item.tier + 1 < chain.tiers.count ? chain.tiers[item.tier + 1].name : nil
            if let next = nextName {
                return (label + " · Merge two to reach " + next, item.chainID)
            }
            return (label, item.chainID)
        }
        if !cell.isUnlocked {
            let unlockLevel = boardRowUnlockLevels[cell.position.row] ?? 99
            return ("Locked · Reach level \(unlockLevel) to unlock this row", nil)
        }
        return nil
    }

    var retirableProducers: [RetirableProducer] {
        let incompleteGoals = quests.activeQuests.filter { !$0.isComplete }.map(\.goal)
                            + quests.dailyChallenges.filter { !$0.isComplete }.map(\.goal)
        var result: [RetirableProducer] = []
        for r in 0..<rows {
            for c in 0..<cols {
                guard let producer = board[r][c].producer else { continue }
                if !producerIsNeeded(producer, by: incompleteGoals) {
                    result.append(RetirableProducer(position: GridPosition(row: r, col: c),
                                                    producer: producer))
                }
            }
        }
        return result
    }

    /// One entry per species that has ≥ 3 Ambassador-tier tiles on the unlocked board.
    /// Each entry carries the first three matching cell positions (row-major order).
    var exchangeableTrios: [ExchangeableTrio] {
        AnimalSpecies.allCases.compactMap { species in
            let chainID = ContentRegistry.animalChainID(species)
            let positions = board.flatMap { $0 }
                .filter { cell in
                    guard cell.isUnlocked, let item = cell.item else { return false }
                    return item.chainID == chainID && item.isTopTier
                }
                .map(\.position)
            guard positions.count >= 3 else { return nil }
            return ExchangeableTrio(species: species, positions: Array(positions.prefix(3)))
        }
    }

    /// Removes three Ambassador tiles of the species from the board and awards the trio bonus.
    func exchangeAmbassadorTrio(_ trio: ExchangeableTrio) {
        for pos in trio.positions {
            board[pos.row][pos.col].item = nil
        }
        earnCoins(ambassadorTrioExchangeCoins)
        recalcBoardIsFull()
        enqueueToast(Toast(kind: .info(
            "\(trio.species.name) Trio exchanged for \(ambassadorTrioExchangeCoins) coins!"
        )))
    }

    private func producerIsNeeded(_ producer: ProducerTile, by goals: [QuestGoal]) -> Bool {
        for goal in goals {
            switch goal {
            case .spawnBase:
                if producer.level.targetCategory == .animal { return true }
            case .mergeInChain(let chainID, _):
                if producer.level.targetCategory == .animal {
                    if ContentRegistry.shared.chain(chainID)?.category == .animal { return true }
                } else if producer.level.targetChainID == chainID {
                    return true
                }
            case .mergeAny, .reachTier:
                break
            }
        }
        return false
    }

    var lockedCells: [GridPosition] {
        boardRowUnlockLevels.keys
            .flatMap { row in (0..<cols).map { GridPosition(row: row, col: $0) } }
            .filter { pos in board.indices.contains(pos.row) && !board[pos.row][pos.col].isUnlocked }
    }
    /// Fraction (0–1) of progress toward unlocking the next locked row by level.
    var unlockProgress: Double {
        guard let nextRow = boardRowUnlockLevels.keys.sorted().first(where: { row in
            board.indices.contains(row) &&
            !(board[row].first?.isUnlocked ?? true)
        }),
              let targetLevel = boardRowUnlockLevels[nextRow] else { return 1.0 }
        let prevLevel = targetLevel == 3 ? 1 : 3   // level 1 → level 3, level 3 → level 8
        let span = Double(targetLevel - prevLevel)
        let progress = Double(progression.playerLevel - prevLevel)
        return min(1.0, max(0.0, span > 0 ? progress / span : 1.0))
    }
    var unlockHintText: String {
        guard let nextRow = boardRowUnlockLevels.keys.sorted().first(where: { row in
            board.indices.contains(row) &&
            !(board[row].first?.isUnlocked ?? true)
        }),
              let targetLevel = boardRowUnlockLevels[nextRow] else { return "All rows unlocked!" }
        if progression.playerLevel >= targetLevel { return "Row ready to unlock!" }
        let needed = targetLevel - progression.playerLevel
        return "Reach level \(targetLevel) to unlock the next row (\(needed) level\(needed == 1 ? "" : "s") away)"
    }

    var effectiveWeeklyGoldTarget: Int {
        max(weeklyGoalSilverCoins + 1, weeklyGoalGoldCoins - cachedActiveBonuses.weeklyGoldDiscount)
    }
    var weeklyGoalReached: (bronze: Bool, silver: Bool, gold: Bool) {
        (coinsEarnedThisWeek >= weeklyGoalBronzeCoins,
         coinsEarnedThisWeek >= weeklyGoalSilverCoins,
         coinsEarnedThisWeek >= effectiveWeeklyGoldTarget)
    }
    var monthlyGoalWeeksRequired: Int {
        max(1, monthlyGoalWeeksNeeded - cachedActiveBonuses.monthlyWeeksDiscount)
    }
    var monthlyGoalReached: Bool { weeklyGoldCompletions >= monthlyGoalWeeksRequired }
    var adoptionOrderCount: Int  { 2 + cachedActiveBonuses.extraAdoptionSlots }

    var passMultiplier: Double { isPassActive ? passKibbleMultiplier : 1.0 }
    func withPassBonus(_ base: Int) -> Int { Int(Double(base) * passMultiplier) }
    var effectiveAdKibble: Int { isPassActive ? adKibbleReward * 2 : adKibbleReward }

    var canClaimPassDaily: Bool {
        guard isPassActive else { return false }
        guard let last = passLastClaimDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    var canClaimLoyaltyClub: Bool {
        guard isLoyaltyClubUnlocked else { return false }
        guard let last = loyaltyClubLastClaimDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }
    var currentLoyaltyReward: LoyaltyReward {
        loyaltyClubCycle[loyaltyClubDayIndex % loyaltyClubCycle.count]
    }

    let maxDailyCardSends = 5

    var remainingDailyTrades: Int {
        if let last = lastCardSendDate, !Calendar.current.isDateInToday(last) {
            return maxDailyCardSends
        }
        return max(0, maxDailyCardSends - cardsSentToday)
    }

    var allDuplicateCards: [(definition: CardDefinition, extraCount: Int)] {
        CardRegistry.allCards.compactMap { def in
            let count = cardInventory[def.id, default: 0]
            guard count > 1 else { return nil }
            return (def, count - 1)
        }
    }

    // MARK: Init

    init() {
        if let saved = GameStore.load() {
            apply(saved)
            if let last = saved.lastActiveDate { applyOfflineProgress(since: last) }
        } else {
            freshStart()
        }
        checkDailyLogin()
        checkDailyChallengeReset()
        updateWeeklySpotlight()
        if quests.activeQuests.isEmpty   { setupQuests() }
        if adoptionBoardCoordinator.adoptionOrders.isEmpty { setupAdoptionOrders() }
        checkWeeklyGoalReset()
        checkMonthlyGoalReset()
        startTimer()
        authenticateGameCenter { [weak self] playerID, alias in
            self?.gcIsAuthenticated  = true
            self?.gcLocalPlayerID    = playerID
            self?.gcLocalPlayerAlias = alias
        }
    }

    deinit { regenTimer?.invalidate() }

    // MARK: Fresh game

    private func freshStart() {
        buildEmptyBoard()
        spawnAnimal(); spawnAnimal(); spawnAnimal()
        let lastUnlockedRow = (0..<boardRows).filter { boardRowUnlockLevels[$0] == nil }.max() ?? 0
        board[lastUnlockedRow][0].producer = ProducerTile(level: .familySpawner, species: .dog)
        kibbleEngine.secondsUntilNextKibble = kibbleRegenSecs
        // Give the player a starter toolbox so they can afford their first map area
        // from day one without waiting on quests.
        placeToolbox()
        recalcBoardIsFull()
        setupQuests()
        setupAdoptionOrders()
    }

    /// Ensures at least one Canines family spawner exists on an unlocked cell.
    /// Called after restoring a save to recover boards that lost all producers.
    private func ensureStartingProducer() {
        let hasProducer = board.flatMap { $0 }.contains { $0.producer != nil }
        guard !hasProducer else { return }
        let lastUnlockedRow = (0..<boardRows).filter { boardRowUnlockLevels[$0] == nil }.max() ?? 0
        if let col = (0..<cols).first(where: { board[lastUnlockedRow][$0].isEmpty }) {
            board[lastUnlockedRow][col].producer = ProducerTile(level: .familySpawner, species: .dog)
        }
    }

    private func buildEmptyBoard() {
        board = (0..<boardRows).map { row in
            (0..<cols).map { col in
                // Rows listed in boardRowUnlockLevels start locked; all others start unlocked.
                let isLocked = boardRowUnlockLevels[row] != nil
                return BoardCell(position: GridPosition(row: row, col: col),
                                 item: nil, isUnlocked: !isLocked)
            }
        }
        rows = boardRows
    }

    func setupQuests() {
        quests.setupQuests(unlockedChainIDs: progression.unlockedChainIDs,
                           playerLevel: playerLevel)
    }

    func setupAdoptionOrders() {
        adoptionBoardCoordinator.setupOrders(count: adoptionOrderCount,
                                             unlockedChainIDs: progression.unlockedAnimalChainIDs,
                                             playerLevel: progression.playerLevel)
        rescheduleRescueExpiring()
    }

    func startTimer() {
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.timerTick() }
        }
        RunLoop.main.add(t, forMode: .common)
        regenTimer = t
    }

    @MainActor
    private func timerTick() {
        kibbleEngine.tick(bonusPerRegen: cachedActiveBonuses.kibblePerRegen)
        // Equines Sprint: second kibble tick and countdown.
        if equineSprintRemaining > 0 {
            kibbleEngine.tick(bonusPerRegen: cachedActiveBonuses.kibblePerRegen)
            equineSprintRemaining = max(0, equineSprintRemaining - 1)
        }
        // Marsupials Pouch: return stored items when timer fires.
        if pouchExpiryTimestamp > 0 && Date().timeIntervalSince1970 >= pouchExpiryTimestamp {
            returnPouchItems()
        }
        adoptionBoardCoordinator.tick(unlockedChainIDs: progression.unlockedAnimalChainIDs,
                                      playerLevel: progression.playerLevel)
        tickProducers()
        saveTickCounter = (saveTickCounter + 1) % 5
        if saveTickCounter == 0 { save() }
    }

    // MARK: Persistence

    private func captureState() -> GameState {
        var s = GameState(
            board: board,
            kibble: 0, dogTags: 0, score: score,
            rescueCount: rescueCount,
            ambassadors: ambassadors, mergeCount: mergeCount,
            secondsUntilNextKibble: 0,
            playerLevel: 0, playerXP: 0, unlockedChainIDs: [],
            inventory: [], inventoryRow1Unlocked: false, inventoryRow2Unlocked: false,
            activeQuests: [], dailyChallenges: [], dailyChallengeStreak: 0,
            dailyChallengeBonusClaimed: false, adoptionOrders: [],
            spotlightMergesThisWeek: 0,
            materialCounts: InventoryStore.emptyMaterialCounts(), producerStorage: [:], overflowProducerStorage: [],
            completedAreaIDs: completedAreaIDs, areaUpgradeLevels: areaUpgradeLevels,
            spawnMultiplier: 0,
            cardInventory: cardInventory, starCount: starCount,
            completedAlbumIDs: completedAlbumIDs, pendingCardPacks: pendingCardPacks,
            jokerCards: jokerCards, rareJokerCards: rareJokerCards,
            pendingOutgoingTrades: pendingOutgoingTrades,
            pendingIncomingTrades: pendingIncomingTrades,
            cardsSentToday: cardsSentToday, lastCardSendDate: lastCardSendDate,
            coins: coins, coinsEarnedThisWeek: coinsEarnedThisWeek,
            weeklyGoalBronzeClaimed: weeklyGoalBronzeClaimed,
            weeklyGoalSilverClaimed: weeklyGoalSilverClaimed,
            weeklyGoalGoldClaimed: weeklyGoalGoldClaimed,
            lastWeeklyGoalReset: lastWeeklyGoalReset,
            weeklyGoldCompletions: weeklyGoldCompletions,
            monthlyGoalClaimed: monthlyGoalClaimed,
            lastMonthlyGoalReset: lastMonthlyGoalReset,
            lastLoginDate: nil, loginStreak: 0, loginDayIndex: 0,
            lastDailyChallengeReset: nil, lastSpotlightWeek: 0,
            adsWatchedToday: 0, lastAdWatchDate: nil,
            purchasedBoardRows: 0,
            passLastClaimDate: passLastClaimDate,
            loyaltyClubDayIndex: loyaltyClubDayIndex,
            loyaltyClubLastClaimDate: loyaltyClubLastClaimDate,
            loyaltyClubStreak: loyaltyClubStreak,
            eventProgress: eventProgress,
            inviteProgress: inviteProgress,
            ambassadorQuestProgress: ambassadorQuestProgress,
            pendingMaterialLots: pendingMaterialLots,
            lastActiveDate: Date()
        )
        s.pityStates = pityStates
        s.unlockedSuperpowerSpecies = unlockedSuperpowerSpecies
        s.superpowerCooldownEnds    = superpowerCooldownEnds
        s.lagomorphMergeCount       = lagomorphMergeCount
        s.lastMergeTimestamp        = lastMergeTimestamp
        s.lastMergedSpeciesRaw      = lastMergedSpeciesRaw
        s.equineSprintRemaining     = equineSprintRemaining
        s.pouchItems                = pouchItems
        s.pouchExpiryTimestamp      = pouchExpiryTimestamp
        kibbleEngine.capture(into: &s)
        inventoryStore.capture(into: &s)
        quests.capture(into: &s)
        adoptionBoardCoordinator.capture(into: &s)
        progression.capture(into: &s)
        return s
    }

    private func apply(_ s: GameState) {
        board = s.board
        rows  = board.count
        let savedCols = board.first.map(\.count) ?? cols
        if savedCols < cols {
            for r in 0..<rows {
                let extras = (savedCols..<cols).map { c in
                    BoardCell(position: GridPosition(row: r, col: c), item: nil,
                              isUnlocked: boardRowUnlockLevels[r] == nil)
                }
                board[r].append(contentsOf: extras)
            }
        }
        // Migration: if saved board has fewer than 9 rows, pad to full size.
        if board.count < boardRows {
            for r in board.count..<boardRows {
                let isLocked = boardRowUnlockLevels[r] != nil
                board.append((0..<cols).map { c in
                    BoardCell(position: GridPosition(row: r, col: c),
                              item: nil, isUnlocked: !isLocked)
                })
            }
        }
        rows = boardRows
        score = s.score
        rescueCount = s.rescueCount
        ambassadors = s.ambassadors; mergeCount = s.mergeCount
        ambassadorQuestProgress = s.ambassadorQuestProgress
        pendingMaterialLots     = s.pendingMaterialLots
        completedAreaIDs    = s.completedAreaIDs
        areaUpgradeLevels   = s.areaUpgradeLevels
        cardInventory       = s.cardInventory
        starCount           = s.starCount
        completedAlbumIDs   = s.completedAlbumIDs
        pendingCardPacks    = s.pendingCardPacks
        jokerCards          = s.jokerCards
        rareJokerCards      = s.rareJokerCards
        pendingOutgoingTrades = s.pendingOutgoingTrades
        pendingIncomingTrades = s.pendingIncomingTrades
        cardsSentToday      = s.cardsSentToday
        lastCardSendDate    = s.lastCardSendDate
        passLastClaimDate        = s.passLastClaimDate
        loyaltyClubDayIndex      = s.loyaltyClubDayIndex
        loyaltyClubLastClaimDate = s.loyaltyClubLastClaimDate
        loyaltyClubStreak        = s.loyaltyClubStreak
        eventProgress            = s.eventProgress
        inviteProgress           = s.inviteProgress
        coins                    = s.coins
        coinsEarnedThisWeek      = s.coinsEarnedThisWeek
        weeklyGoalBronzeClaimed  = s.weeklyGoalBronzeClaimed
        weeklyGoalSilverClaimed  = s.weeklyGoalSilverClaimed
        weeklyGoalGoldClaimed    = s.weeklyGoalGoldClaimed
        lastWeeklyGoalReset      = s.lastWeeklyGoalReset
        weeklyGoldCompletions    = s.weeklyGoldCompletions
        monthlyGoalClaimed       = s.monthlyGoalClaimed
        lastMonthlyGoalReset     = s.lastMonthlyGoalReset
        pityStates                = s.pityStates
        unlockedSuperpowerSpecies = s.unlockedSuperpowerSpecies
        superpowerCooldownEnds    = s.superpowerCooldownEnds
        lagomorphMergeCount       = s.lagomorphMergeCount
        lastMergeTimestamp        = s.lastMergeTimestamp
        lastMergedSpeciesRaw      = s.lastMergedSpeciesRaw
        equineSprintRemaining     = s.equineSprintRemaining
        pouchItems                = s.pouchItems
        pouchExpiryTimestamp      = s.pouchExpiryTimestamp
        kibbleEngine.restore(from: s)
        inventoryStore.restore(from: s)
        quests.restore(from: s)
        adoptionBoardCoordinator.restore(from: s)
        progression.restore(from: s)

        recalcBoardIsFull()
        recalcActiveBonuses()
        ensureStartingProducer()
    }

    private func save() { GameStore.save(captureState()) }
    func persist() { GameStore.saveAndSync(captureState()) }

    private func applyOfflineProgress(since lastActive: Date) {
        let elapsed = Date().timeIntervalSince(lastActive)
        guard elapsed >= 1 else { return }
        let secs = Int(elapsed)

        kibbleEngine.applyOfflineProgress(secs: secs)

        // Producer cooldowns
        for r in 0..<rows {
            for c in 0..<cols {
                if var p = board[r][c].producer, !p.isReady {
                    p.cooldownRemaining = max(0, p.cooldownRemaining - elapsed)
                    board[r][c].producer = p
                }
            }
        }

        adoptionBoardCoordinator.applyOfflineProgress(
            elapsed: elapsed,
            unlockedChainIDs: progression.unlockedAnimalChainIDs,
            playerLevel: progression.playerLevel
        )
    }

    #if DEBUG
    func resetToFreshGame() {
        GameStore.clear()
        score = 0; rescueCount = 0; ambassadors = 0; mergeCount = 0; ambassadorQuestProgress = 0; pendingMaterialLots = []
        kibbleEngine.kibble = startingKibble
        kibbleEngine.dogTags = 0
        kibbleEngine.secondsUntilNextKibble = kibbleRegenSecs
        kibbleEngine.adsWatchedToday = 0; kibbleEngine.lastAdWatchDate = nil
        progression.playerLevel = 1; progression.playerXP = 0
        progression.unlockedChainIDs = startingChainIDs
        progression.unlockedProducerShopTiers = []   // family spawners earned via map, not shop
        rows = boardRows
        inventoryStore.inventory = Array(repeating: nil, count: totalInventorySlots)
        inventoryStore.inventoryRow1Unlocked = false
        inventoryStore.inventoryRow2Unlocked = false
        inventoryStore.materialCounts = InventoryStore.emptyMaterialCounts()
        inventoryStore.producerStorage = [:]
        inventoryStore.overflowProducerStorage = Array(repeating: nil, count: totalProducerOverflowSlots)
        completedAreaIDs = []; areaUpgradeLevels = [:]
        coins = 0; coinsEarnedThisWeek = 0
        weeklyGoalBronzeClaimed = false; weeklyGoalSilverClaimed = false; weeklyGoalGoldClaimed = false
        lastWeeklyGoalReset = nil; weeklyGoldCompletions = 0
        monthlyGoalClaimed = false; lastMonthlyGoalReset = nil
        cachedActiveBonuses = UpgradeBonus()
        selectedCell = nil; draggingFrom = nil
        quests.dailyChallengeStreak = 0; quests.dailyChallengeBonusClaimed = false
        quests.spotlightMergesThisWeek = 0
        quests.lastLoginDate = nil; quests.loginStreak = 0; quests.loginDayIndex = 0
        quests.lastDailyChallengeReset = nil; quests.lastSpotlightWeek = 0
        passLastClaimDate = nil
        loyaltyClubDayIndex = 0; loyaltyClubLastClaimDate = nil; loyaltyClubStreak = 0
        eventProgress = EventProgress(); inviteProgress = InviteProgress()
        unlockedSuperpowerSpecies = []; superpowerCooldownEnds = [:]
        lagomorphMergeCount = 0; lastMergeTimestamp = 0; lastMergedSpeciesRaw = nil
        equineSprintRemaining = 0; pouchItems = [nil, nil]; pouchExpiryTimestamp = 0
        preMoveSnapshot = nil; leapMode = false; leapSourceCell = nil
        showSuperpowerUnlockBanner = false; superpowerUnlockBannerSpecies = nil; showPouchPanel = false
        inventoryStore.showInventory = false
        showLoginReward = false
        progression.showLevelUpBanner = false
        showAmbassadorBanner = false

        freshStart()
        checkDailyLogin()
        checkDailyChallengeReset()
        updateWeeklySpotlight()
        save()
    }
    #endif

    // MARK: Cached state helpers

    private func recalcBoardIsFull() {
        boardIsFull = board.flatMap { $0 }.filter { $0.isUnlocked }.allSatisfy { !$0.isEmpty }
    }

    // MARK: Spawning

    // MARK: Producer tiles

    func activateProducer(at pos: GridPosition) {
        guard var producer = board[pos.row][pos.col].producer else { return }

        if producer.level == .familySpawner, let species = producer.species {
            // Family spawner — kibble-based, unlimited, species-specific animal chain
            // Bask (Reptiles .turtle): half kibble cost.
            let baseCost = progression.spawnMultiplier
            let baskActive = species == .turtle && unlockedSuperpowerSpecies.contains(AnimalSpecies.turtle.rawValue)
            let cost = baskActive ? max(1, baseCost / 2) : baseCost
            guard kibbleEngine.kibble >= cost else {
                triggerToast(.noKibble); selectedCell = pos; return
            }
            let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
            guard let target = empty.randomElement() else {
                triggerToast(.boardFull); selectedCell = pos; return
            }
            let chainID = ContentRegistry.animalChainID(species)
            let maxTier = ContentRegistry.shared.chain(chainID)?.maxTier ?? 0
            var spawnTier = min(progression.spawnMultiplier - 1, maxTier)

            // High-Tier Drop guarantee: force tier ≥ 2 and consume the buff.
            if producer.nextDropGuaranteedHighTier {
                spawnTier = min(2, maxTier)
                producer.nextDropGuaranteedHighTier = false
                board[pos.row][pos.col].producer = producer
            }
            // Hibernate Bonus (Ursids .owl): after 5 idle minutes, force Stage 3 (tier 2).
            let hibernateActive = unlockedSuperpowerSpecies.contains(AnimalSpecies.owl.rawValue)
            if hibernateActive && lastMergeTimestamp > 0
                && Date().timeIntervalSince1970 - lastMergeTimestamp >= 300 {
                spawnTier = min(2, maxTier)
                lastMergeTimestamp = Date().timeIntervalSince1970  // reset idle clock
            }

            var pityState = pityStates[species.rawValue] ?? PityState()
            let dropResult = SubObjectSystem.resolveSpawnerDrop(
                species: species,
                pityState: &pityState,
                spawnTier: spawnTier,
                dropRateBonus: cachedActiveBonuses.subObjectDropRateBonus,
                pityTimerReduction: cachedActiveBonuses.pityTimerReduction
            )
            pityStates[species.rawValue] = pityState
            let spawnedItem: BoardItem
            switch dropResult {
            case .animal(let tier):
                spawnedItem = BoardItem(chainID: chainID, tier: tier)
            case .subObject(let subChainID, _):
                // Hoard (Rodents .hamster): sub-objects spawn at tier 1 (Stage 2) instead of tier 0.
                let hoardActive = species == .hamster && unlockedSuperpowerSpecies.contains(AnimalSpecies.hamster.rawValue)
                let subTier = hoardActive ? min(1, ContentRegistry.shared.chain(subChainID)?.maxTier ?? 0) : 0
                spawnedItem = BoardItem(chainID: subChainID, tier: subTier)
            }
            board[target.position.row][target.position.col].item = spawnedItem
            // Scout (Avians .bird): after spawning, pre-roll next drop and cache it.
            if unlockedSuperpowerSpecies.contains(AnimalSpecies.bird.rawValue) {
                var pityForPreview = pityStates[species.rawValue] ?? PityState()
                let preview = SubObjectSystem.resolveSpawnerDrop(
                    species: species,
                    pityState: &pityForPreview,
                    spawnTier: spawnTier,
                    dropRateBonus: cachedActiveBonuses.subObjectDropRateBonus,
                    pityTimerReduction: cachedActiveBonuses.pityTimerReduction
                )
                if var p = board[pos.row][pos.col].producer {
                    if case .subObject = preview { p.scoutPreviewIsSubObject = true }
                    else { p.scoutPreviewIsSubObject = false }
                    board[pos.row][pos.col].producer = p
                }
            }
            kibbleEngine.kibble -= cost
            if let secs = kibbleEngine.secondsUntilKibbleFull(bonusPerRegen: cachedActiveBonuses.kibblePerRegen) {
                NotificationManager.shared.scheduleKibbleFull(secondsUntilFull: secs)
            }
            rescueCount += 1
            recalcBoardIsFull()
            grantXP(xpPerRescue)
            updateAllAfterRescue()
            updateOrdersAfterMerge(chainID: chainID, tier: spawnTier)
            animatingCell = target.position
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                self.animatingCell = nil
            }
        } else if producer.level.targetCategory == .animal {
            // Legacy rescue-tier producers (rescueCrate/shelterPod/fosterHome) — random family
            let cost = progression.spawnMultiplier
            guard kibbleEngine.kibble >= cost else {
                triggerToast(.noKibble); selectedCell = pos; return
            }
            let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
            guard let target = empty.randomElement() else {
                triggerToast(.boardFull); selectedCell = pos; return
            }
            let chainID = ContentRegistry.randomChainID(in: .animal, from: progression.unlockedChainIDs)
                ?? progression.unlockedAnimalChainIDs.first
                ?? ContentRegistry.animalChainID(.dog)
            let maxTier = ContentRegistry.shared.chain(chainID)?.maxTier ?? 0
            let spawnTier = min(progression.spawnMultiplier - 1, maxTier)
            board[target.position.row][target.position.col].item =
                BoardItem(chainID: chainID, tier: spawnTier)
            kibbleEngine.kibble -= cost
            if let secs = kibbleEngine.secondsUntilKibbleFull(bonusPerRegen: cachedActiveBonuses.kibblePerRegen) {
                NotificationManager.shared.scheduleKibbleFull(secondsUntilFull: secs)
            }
            rescueCount += 1
            recalcBoardIsFull()
            grantXP(xpPerRescue)
            updateAllAfterRescue()
            updateOrdersAfterMerge(chainID: chainID, tier: spawnTier)
            animatingCell = target.position
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(600))
                self.animatingCell = nil
            }
        } else {
            if producer.isReady {
                let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty && $0.position != pos }
                if let target = empty.randomElement() {
                    let chainID = producer.level.targetChainID ?? ContentRegistry.animalChainID(.dog)
                    board[target.position.row][target.position.col].item =
                        BoardItem(chainID: chainID, tier: producer.level.startTier)
                    producer.cooldownRemaining = producer.level.cooldown
                    producer.chargesRemaining -= 1
                    board[pos.row][pos.col].producer = producer.chargesRemaining > 0 ? producer : nil
                    recalcBoardIsFull()
                    animatingCell = target.position
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(600))
                        self.animatingCell = nil
                    }
                } else {
                    triggerToast(.boardFull)
                }
            }
        }
        selectedCell = pos
    }

    private func tickProducers() {
        for row in 0..<rows {
            for col in 0..<cols {
                guard var p = board[row][col].producer else { continue }

                let snapshot = p

                // Tick down speed-burst timer (applies to all producer types).
                if p.speedBurstActive {
                    p.speedBurstRemaining -= 1
                    if p.speedBurstRemaining <= 0 {
                        p.speedBurstActive = false
                        p.speedBurstRemaining = 0
                    }
                }

                // Advance cooldown for supply producers.
                // Family spawners are always ready — skip the cooldown math entirely.
                if p.level != .familySpawner && !p.isReady {
                    let increment: Double = p.speedBurstActive ? 2.0 : 1.0
                    p.cooldownRemaining = max(0, p.cooldownRemaining - increment)
                }

                // Only write back when something actually changed.
                if p != snapshot { board[row][col].producer = p }
            }
        }
    }

    // MARK: Producer shop

    func buyProducer(_ level: ProducerLevel) {
        guard kibbleEngine.dogTags >= level.dogTagCost else { return }
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        guard let target = empty.randomElement() else { triggerToast(.boardFull); return }
        kibbleEngine.dogTags -= level.dogTagCost
        board[target.position.row][target.position.col].producer = ProducerTile(level: level)
        recalcBoardIsFull()
    }

    func exchangeTagsForKibble(_ exchange: DogTagKibbleExchange) {
        kibbleEngine.exchangeTagsForKibble(exchange)
    }

    private func placeProducerReward(_ level: ProducerLevel) {
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        if let target = empty.randomElement() {
            board[target.position.row][target.position.col].producer = ProducerTile(level: level)
            recalcBoardIsFull()
        } else {
            kibbleEngine.kibble += 10
        }
    }

    @discardableResult
    private func spawnAnimal() -> Bool {
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        guard let target = empty.randomElement() else { return false }
        let chainID = progression.unlockedAnimalChainIDs.randomElement()
                      ?? ContentRegistry.animalChainID(.dog)
        board[target.position.row][target.position.col].item =
            BoardItem(chainID: chainID, tier: 0)
        rescueCount += 1
        recalcBoardIsFull()
        updateAllAfterRescue()
        return true
    }

    // MARK: Board interaction

    func boardCellTapped(at pos: GridPosition) {
        HapticManager.shared.lightTap()

        // Leap mode: two-step teleport interaction takes priority over everything else.
        if leapMode { handleLeapTap(at: pos); return }

        // Pouch mode: tap an animal to store it in the Pouch.
        if showPouchPanel {
            if !pouchStore(from: pos) {
                if pouchItems[0] != nil && pouchItems[1] != nil {
                    enqueueToast(Toast(kind: .info("Pouch is full (2 slots).")))
                }
            }
            return
        }

        // Power-up apply: if a power-up is selected, try to apply it to a family spawner.
        if selectedPowerUpSlot != nil {
            if board[pos.row][pos.col].producer?.level == .familySpawner {
                applyPowerUpToSpawner(at: pos)
                return
            } else {
                // Tapped elsewhere — deselect power-up without applying.
                selectedPowerUpSlot = nil
            }
        }

        if board[pos.row][pos.col].item?.chainID == ContentRegistry.toolboxChainID {
            absorbToolbox(at: pos)
            return
        }
        if board[pos.row][pos.col].producer != nil {
            if let sel = selectedCell, sel != pos, board[sel.row][sel.col].producer == nil {
                attemptMergeOrMove(from: sel, to: pos)
                selectedCell = nil
            } else {
                activateProducer(at: pos)
            }
            return
        }
        if let sel = selectedCell {
            if sel == pos { selectedCell = nil }
            else { attemptMergeOrMove(from: sel, to: pos); selectedCell = nil }
        } else if board[pos.row][pos.col].item != nil {
            inventoryStore.selectedInventorySlot = nil
            selectedCell = pos
        }
    }

    // MARK: Power-up selection and application

    /// Selects or deselects a power-up slot in `powerUpInventory`.
    /// Also clears `selectedCell` so the board selection and power-up selection don't fight.
    func powerUpSlotTapped(_ slot: Int) {
        guard slot < inventoryStore.powerUpInventory.count,
              inventoryStore.powerUpInventory[slot] != nil else {
            selectedPowerUpSlot = nil
            return
        }
        if selectedPowerUpSlot == slot {
            selectedPowerUpSlot = nil
        } else {
            selectedPowerUpSlot = slot
            selectedCell = nil
        }
    }

    /// Applies the currently selected power-up to the family spawner at `pos`.
    /// Consumes the power-up from inventory and shows a toast.
    func applyPowerUpToSpawner(at pos: GridPosition) {
        guard let slot = selectedPowerUpSlot,
              let powerUpItem = inventoryStore.powerUpInventory[slot],
              var producer = board[pos.row][pos.col].producer,
              producer.level == .familySpawner else {
            selectedPowerUpSlot = nil
            return
        }
        guard let effect = SubObjectSystem.powerUpEffect(for: powerUpItem) else {
            selectedPowerUpSlot = nil
            return
        }

        SubObjectSystem.applyPowerUp(effect: effect, to: &producer, viewModel: self,
                                     powerUpDurationBonus: cachedActiveBonuses.powerUpDurationBonus)
        board[pos.row][pos.col].producer = producer

        inventoryStore.powerUpInventory[slot] = nil
        selectedPowerUpSlot = nil

        SoundManager.shared.playQuestClaim()
        HapticManager.shared.successPattern()

        let message: String
        switch effect {
        case .speedBurst:     message = "⚡ Speed Burst activated!"
        case .spawnerRefill:  message = "🐾 Bonus kibble added!"
        case .highTierDrop:   message = "⭐ High-Tier Drop guaranteed!"
        case .mapSupplies:    message = "🪵 Map Supplies added!"
        }
        enqueueToast(Toast(kind: .info(message)))
    }

    func attemptMergeOrMove(from: GridPosition, to: GridPosition) {
        guard from != to,
              to.row >= 0, to.row < rows, to.col >= 0, to.col < cols,
              board[to.row][to.col].isUnlocked else { return }

        if let srcProducer = board[from.row][from.col].producer {
            let dstProducer = board[to.row][to.col].producer
            let dstItem     = board[to.row][to.col].item
            if let dst = dstProducer {
                if srcProducer.level == dst.level, let nextLevel = srcProducer.level.next {
                    board[to.row][to.col].producer   = ProducerTile(level: nextLevel)
                    board[from.row][from.col].producer = nil
                    animatingCell = to
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(600))
                        self.animatingCell = nil
                    }
                } else {
                    board[to.row][to.col].producer   = srcProducer
                    board[from.row][from.col].producer = dst
                }
            } else if dstItem == nil {
                board[to.row][to.col].producer   = srcProducer
                board[from.row][from.col].producer = nil
            }
            selectedCell = nil
            return
        }

        guard let srcItem = board[from.row][from.col].item else { return }
        guard board[to.row][to.col].producer == nil else { return }

        if let dstItem = board[to.row][to.col].item {
            if srcItem.chainID == dstItem.chainID,
               srcItem.tier == dstItem.tier,
               let next = ContentRegistry.shared.nextTier(srcItem.chainID, after: srcItem.tier) {
                // Nine Lives snapshot — taken before the board state changes.
                preMoveSnapshot = BoardSnapshot(board: board, inventory: inventoryStore.inventory)
                board[to.row][to.col].item   = BoardItem(chainID: srcItem.chainID, tier: next)
                board[from.row][from.col].item = nil
                SoundManager.shared.playMerge()
                HapticManager.shared.mediumImpact()
                let srcDef = ContentRegistry.shared.tier(srcItem.chainID, srcItem.tier)
                let multiplier = srcItem.chainID == quests.spotlightChainID
                    ? (2 + cachedActiveBonuses.spotlightMultiplierBonus) : 1
                score += (srcDef?.scoreValue ?? 0) * multiplier
                grantXP(srcDef?.xpValue ?? 0)
                if next == (srcItem.chain?.maxTier ?? Int.max) {
                    triggerTopTierCelebration(chainID: srcItem.chainID)
                }
                mergeCount += 1
                lastMergeTimestamp = Date().timeIntervalSince1970
                let mergedSpecies = AnimalSpecies(rawValue: srcItem.chainID.replacingOccurrences(of: "animal.", with: ""))
                if let sp = mergedSpecies { lastMergedSpeciesRaw = sp.rawValue }
                recalcBoardIsFull()
                updateAllAfterMerge(chainID: srcItem.chainID, tier: next)
                if let sp = mergedSpecies { checkSuperpowerUnlock(species: sp, tier: next) }
                applyPassivePowers(mergedSpecies: mergedSpecies, mergePos: to, emptyPos: from)
                // Power-up routing: power-up chain items and completed sub-objects (tier 3)
                // are auto-moved to power-up inventory rather than left on the board.
                let mergedChain = ContentRegistry.shared.chain(srcItem.chainID)
                let isCompletedSubObject = mergedChain?.category == .subObject
                    && next == mergedChain?.maxTier
                if mergedChain?.category == .powerUp || isCompletedSubObject {
                    if let powerUpItem = board[to.row][to.col].item {
                        board[to.row][to.col].item = nil
                        inventoryStore.addItem(powerUpItem)
                        recalcBoardIsFull()
                        SoundManager.shared.playQuestClaim()
                        HapticManager.shared.successPattern()
                        let msg = isCompletedSubObject
                            ? "Consumable ready! Check your Supplies."
                            : "Power-up earned! Check your Supplies."
                        enqueueToast(Toast(kind: .info(msg)))
                    }
                }
                animatingCell = to
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    self.animatingCell = nil
                }
            } else {
                board[to.row][to.col].item    = srcItem
                board[from.row][from.col].item = dstItem
            }
        } else {
            board[to.row][to.col].item    = srcItem
            board[from.row][from.col].item = nil
            recalcBoardIsFull()
        }
    }

    func sendBoardItemToInventory(from pos: GridPosition) {
        guard board[pos.row][pos.col].producer == nil else { return }
        guard let item = board[pos.row][pos.col].item else { return }
        if inventoryStore.addItem(item) {
            board[pos.row][pos.col].item = nil
            recalcBoardIsFull()
        } else {
            triggerToast(.inventoryFull)
        }
    }

    func storeSelectedItemToInventory() {
        guard let pos = selectedCell, let item = board[pos.row][pos.col].item else { return }
        if inventoryStore.addItem(item) {
            board[pos.row][pos.col].item = nil
            selectedCell = nil
            recalcBoardIsFull()
        } else {
            triggerToast(.inventoryFull)
        }
    }

    /// Sells the animal on the currently selected cell for coins.
    func sellSelectedAnimal() {
        guard let pos = selectedCell,
              pos.row < board.count,
              pos.col < (board.first?.count ?? 0),
              board[pos.row][pos.col].producer == nil,
              let item = board[pos.row][pos.col].item,
              item.chain?.category == .animal else { return }
        let value = sellValue(forTier: item.tier)
        board[pos.row][pos.col].item = nil
        earnCoins(value)
        selectedCell = nil
        recalcBoardIsFull()
        SoundManager.shared.playButtonTap()
        HapticManager.shared.lightTap()
        enqueueToast(Toast(kind: .info("+\(value) Coins")))
    }

    /// Called after every level-up. Unlocks any rows whose required level has been reached.
    func checkLevelUnlock() {
        let currentLevel = progression.playerLevel
        for (row, requiredLevel) in boardRowUnlockLevels {
            guard currentLevel >= requiredLevel else { continue }
            guard board.indices.contains(row) else { continue }
            let alreadyUnlocked = board[row].allSatisfy { $0.isUnlocked }
            guard !alreadyUnlocked else { continue }
            for col in 0..<cols {
                board[row][col].isUnlocked = true
            }
            newlyUnlockedCell = GridPosition(row: row, col: 0)
            recalcBoardIsFull()
            SoundManager.shared.playCellUnlock()
            HapticManager.shared.successPattern()
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { showUnlockBanner = true }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.easeOut(duration: 0.4)) { self.showUnlockBanner = false }
            }
        }
    }

    // MARK: Top-tier celebration

    func triggerTopTierCelebration(chainID: ChainID) {
        if ContentRegistry.shared.chain(chainID)?.category == .animal {
            ambassadors += 1
            ambassadorQuestProgress += 1
            earnCoins(coinsPerAmbassadorMerge + cachedActiveBonuses.coinsPerAmbassador)
            // Drop a toolbox so reaching ambassador tier feeds building materials —
            // kibble is earned via the regen timer, dog tags, quests, and IAP only.
            placeToolbox()
            // Check whether the new ambassador count triggers a Sanctuary Star milestone.
            MilestoneManager.shared.checkMilestones(stars: ambassadors)
        }
        kibbleEngine.dogTags += 5
        grantXP(100)
        ambassadorBannerChainID = chainID
        withAnimation(.spring(response: 0.5, dampingFraction: 0.65)) {
            showAmbassadorBanner = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            withAnimation(.easeOut(duration: 0.4)) { self.showAmbassadorBanner = false }
        }
    }

    func dismissAmbassadorBanner() {
        withAnimation(.easeOut(duration: 0.3)) { showAmbassadorBanner = false }
    }

    // MARK: Ambassador Collection Quest

    let ambassadorQuestGoal      = 3
    let ambassadorQuestCoinReward = 500

    var ambassadorQuestReady: Bool { ambassadorQuestProgress >= ambassadorQuestGoal }

    func claimAmbassadorQuest() {
        guard ambassadorQuestReady else { return }
        // Remove the 3 ambassador-tier animal tiles from the board
        var removed = 0
        outer: for r in 0..<rows {
            for c in 0..<cols {
                guard let item = board[r][c].item,
                      item.isTopTier,
                      item.chain?.category == .animal else { continue }
                board[r][c].item = nil
                removed += 1
                if removed >= ambassadorQuestGoal { break outer }
            }
        }
        ambassadorQuestProgress -= ambassadorQuestGoal   // carry overflow into next cycle
        earnCoins(ambassadorQuestCoinReward)
        SoundManager.shared.playQuestClaim()
        HapticManager.shared.successPattern()
        if removed > 0 { recalcBoardIsFull() }
        enqueueToast(Toast(kind: .info("Ambassador trio claimed! +\(ambassadorQuestCoinReward) Coins")))
        persist()
    }

    // MARK: XP & Levelling

    func grantXP(_ amount: Int) {
        let rewards = progression.grantXP(amount)
        for reward in rewards {
            if let p = reward.newSupplyProducer { placeProducerReward(p) }
            if reward.bonusKibble > 0 { kibbleEngine.kibble += reward.bonusKibble }
            if let pack = reward.cardPack { earnCardPack(pack) }
        }
        if !rewards.isEmpty { checkLevelUnlock() }
    }

    // MARK: Inventory wrappers (board-side of cross-boundary operations)

    @discardableResult
    func addToInventory(_ item: BoardItem) -> Bool {
        inventoryStore.addItem(item)
    }

    func inventorySlotTapped(_ slot: Int) {
        inventoryStore.inventorySlotTapped(slot)
    }

    func placeSelectedInventoryItemOnBoard() {
        guard inventoryStore.selectedInventorySlot != nil else { return }
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        guard let target = empty.first else { triggerToast(.boardFull); return }
        guard let item = inventoryStore.consumeSelectedInventoryItem() else { return }
        board[target.position.row][target.position.col].item = item
        recalcBoardIsFull()
    }

    func unlockInventoryRow1() {
        inventoryStore.unlockRow1(deductingFrom: &kibbleEngine.dogTags)
    }

    func unlockInventoryRow2() {
        inventoryStore.unlockRow2(deductingFrom: &kibbleEngine.dogTags)
    }

    @discardableResult
    func consumeFromToolInventory(chainID: ChainID, tier: Int) -> Bool {
        inventoryStore.consumeFromToolInventory(chainID: chainID, tier: tier)
    }

    func retireProducer(at pos: GridPosition) {
        guard let producer = board[pos.row][pos.col].producer else { return }
        if inventoryStore.retireProducer(producer, playerLevel: progression.playerLevel) {
            board[pos.row][pos.col].producer = nil
            selectedCell = nil
            recalcBoardIsFull()
        } else {
            triggerToast(.inventoryFull)
        }
    }

    func designatedSlotTapped(level: ProducerLevel) {
        inventoryStore.designatedSlotTapped(level: level, playerLevel: progression.playerLevel)
    }

    func overflowSlotTapped(_ slot: Int) {
        inventoryStore.overflowSlotTapped(slot)
    }

    func placeDesignatedProducerOnBoard() {
        guard inventoryStore.selectedProducerLevel != nil else { return }
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        guard let target = empty.first else { triggerToast(.boardFull); return }
        guard let producer = inventoryStore.consumeSelectedDesignatedProducer() else { return }
        board[target.position.row][target.position.col].producer = producer
        recalcBoardIsFull()
    }

    func placeOverflowProducerOnBoard() {
        guard inventoryStore.selectedOverflowProducerSlot != nil else { return }
        guard let (producer, migrated) = inventoryStore.consumeSelectedOverflowProducer(
            playerLevel: progression.playerLevel
        ) else { return }
        if migrated {
            // Migrated to the designated slot — no board placement needed.
            return
        }
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        guard let target = empty.first else {
            // Board is full — put the producer back in overflow.
            let slot = inventoryStore.overflowProducerStorage.indices
                .first(where: { inventoryStore.overflowProducerStorage[$0] == nil })
            if let s = slot { inventoryStore.overflowProducerStorage[s] = producer }
            triggerToast(.boardFull); return
        }
        board[target.position.row][target.position.col].producer = producer
        recalcBoardIsFull()
    }

    func countMaterial(chainID: ChainID, tier: Int) -> Int {
        inventoryStore.countMaterial(chainID: chainID, tier: tier)
    }

    // MARK: Toast queue

    /// Adds a toast to the back of the queue. If the queue was empty the
    /// auto-dismiss timer is started immediately for the new front item.
    func enqueueToast(_ toast: Toast) {
        toastQueue.append(toast)
        if toastQueue.count == 1 { scheduleAutoDismiss(id: toast.id) }
    }

    /// Removes the front toast (e.g. on tap-to-dismiss) and chains the
    /// dismiss timer for the next item if one is waiting.
    func dismissCurrentToast() {
        guard !toastQueue.isEmpty else { return }
        withAnimation(.easeOut(duration: 0.2)) { _ = toastQueue.removeFirst() }
        if let next = toastQueue.first { scheduleAutoDismiss(id: next.id) }
    }

    /// Schedules auto-removal of the toast with the given id.
    /// The id check prevents a stale Task from removing a *later* toast
    /// that happened to fill the front slot before the timer fired.
    private func scheduleAutoDismiss(id: UUID) {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard self.toastQueue.first?.id == id else { return }
            withAnimation(.easeOut(duration: 0.2)) { _ = self.toastQueue.removeFirst() }
            if let next = self.toastQueue.first { self.scheduleAutoDismiss(id: next.id) }
        }
    }

    enum ToastType { case inventoryFull, boardFull, noKibble }
    func triggerToast(_ type: ToastType) {
        switch type {
        case .inventoryFull: enqueueToast(Toast(kind: .inventoryFull))
        case .boardFull:     enqueueToast(Toast(kind: .boardFull))
        case .noKibble:      kibbleEngine.showKibbleSheet = true
        }
    }

    // MARK: Card Pack System

    func earnCardPack(_ type: CardPackType) {
        pendingCardPacks.append(type)
    }

    @discardableResult
    func openNextCardPack() -> [OpenedCard] {
        guard !pendingCardPacks.isEmpty else { return [] }
        let packType = pendingCardPacks.removeFirst()
        let drawn = CardRegistry.drawCards(from: packType)
        var opened: [OpenedCard] = []
        for card in drawn {
            let owned = cardInventory[card.id, default: 0]
            if owned > 0 {
                let stars = card.rarity.duplicateStars
                starCount += stars
                opened.append(OpenedCard(definition: card, wasDuplicate: true, starsEarned: stars))
            } else {
                cardInventory[card.id] = 1
                opened.append(OpenedCard(definition: card, wasDuplicate: false, starsEarned: 0))
            }
        }
        lastOpenedCards = opened
        checkAlbumCompletions()
        return opened
    }

    func useJoker(for cardID: String) {
        guard let def = CardRegistry.cardsByID[cardID] else { return }
        let owned = cardInventory[cardID, default: 0]
        guard owned == 0 else { return }
        if def.rarity == .rare {
            guard rareJokerCards > 0 else { return }
            rareJokerCards -= 1
        } else {
            guard jokerCards > 0 else { return }
            jokerCards -= 1
        }
        cardInventory[cardID] = 1
        checkAlbumCompletions()
    }

    private func checkAlbumCompletions() {
        for album in CardRegistry.albums {
            guard !completedAlbumIDs.contains(album.id) else { continue }
            let complete = album.cardIDs.allSatisfy { cardInventory[$0, default: 0] > 0 }
            guard complete else { continue }
            completedAlbumIDs.append(album.id)
            kibbleEngine.kibble  += withPassBonus(album.rewardKibble)
            kibbleEngine.dogTags += album.rewardDogTags
            earnCoins(album.rewardCoins)
            showAlbumCompleteCard = album
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                self.showAlbumCompleteCard = nil
            }
        }
    }

    func buyFromStarShop(_ item: StarShopItem) {
        guard starCount >= item.starCost else { return }
        starCount -= item.starCost
        if let pack = item.grantsPack {
            earnCardPack(pack)
        } else {
            switch item {
            case .jokerCard:     jokerCards += 1
            case .rareJokerCard: rareJokerCards += 1
            default: break
            }
        }
        persist()
    }

    func ownedCount(in album: CardAlbumDefinition) -> Int {
        album.cardIDs.filter { cardInventory[$0, default: 0] > 0 }.count
    }

    // MARK: Card Trading

    func sendDuplicateCard(_ cardID: String, to friend: GameCenterFriend) {
        guard cardInventory[cardID, default: 0] > 1 else { return }
        guard remainingDailyTrades > 0, gcIsAuthenticated else { return }
        cardInventory[cardID]! -= 1
        let trade = CardTrade(
            cardID: cardID,
            fromPlayerID: gcLocalPlayerID,
            fromDisplayName: gcLocalPlayerAlias,
            toPlayerID: friend.id,
            toDisplayName: friend.displayName,
            sentAt: Date(),
            status: .pending
        )
        pendingOutgoingTrades.append(trade)
        cardsSentToday  += 1
        lastCardSendDate = Date()
        persist()
        Task { await CardTradeBackend.upload(trade) }
    }

    func claimIncomingTrade(_ trade: CardTrade) {
        guard let idx = pendingIncomingTrades.firstIndex(where: { $0.id == trade.id }) else { return }
        pendingIncomingTrades.remove(at: idx)
        cardInventory[trade.cardID, default: 0] += 1
        checkAlbumCompletions()
        persist()
        Task { await CardTradeBackend.markClaimed(tradeID: trade.id) }
    }

    @discardableResult
    func convertAllDuplicatesToStars() -> Int {
        var total = 0
        for def in CardRegistry.allCards {
            let count = cardInventory[def.id, default: 0]
            guard count > 1 else { continue }
            let extras = count - 1
            cardInventory[def.id] = 1
            total += extras * def.rarity.duplicateStars
        }
        starCount += total
        if total > 0 { persist() }
        return total
    }

    func refreshIncomingTrades() async {
        guard gcIsAuthenticated else { return }
        let fetched = await CardTradeBackend.fetchIncoming(for: gcLocalPlayerID)
        let existingIDs = Set(pendingIncomingTrades.map(\.id))
        let newTrades = fetched.filter { !existingIDs.contains($0.id) }
        if !newTrades.isEmpty {
            pendingIncomingTrades.append(contentsOf: newTrades)
            persist()
        }
    }

    func loadGCFriends() async {
        gcIsLoadingFriends = true
        gcFriends = await loadGameCenterFriends()
        gcIsLoadingFriends = false
    }

    // MARK: Update systems after merge / rescue

    func updateAllAfterMerge(chainID: ChainID, tier: Int) {
        quests.updateQuestsAfterMerge(chainID: chainID, tier: tier)
        quests.updateDailyChallengesAfterMerge(chainID: chainID, tier: tier)
        // Memory (Pachyderms .hedgehog): quest/challenge progress counts double.
        let hedgehogChain = ContentRegistry.animalChainID(.hedgehog)
        if chainID == hedgehogChain && unlockedSuperpowerSpecies.contains(AnimalSpecies.hedgehog.rawValue) {
            quests.updateQuestsAfterMerge(chainID: chainID, tier: tier)
            quests.updateDailyChallengesAfterMerge(chainID: chainID, tier: tier)
        }
        if let rewards = quests.checkAllDailyChallengesComplete(
            coinsPerDailyComplete: cachedActiveBonuses.coinsPerDailyComplete) {
            applyQuestRewards(rewards)
        }
        updateOrdersAfterMerge(chainID: chainID, tier: tier)
        if let rewards = quests.recordSpotlightMerge(chainID: chainID) {
            kibbleEngine.kibble  += rewards.kibble
            kibbleEngine.dogTags += rewards.dogTags
        }
    }

    func updateAllAfterRescue() {
        quests.updateQuestsAfterRescue()
        quests.updateDailyChallengesAfterRescue()
        if let rewards = quests.checkAllDailyChallengesComplete(
            coinsPerDailyComplete: cachedActiveBonuses.coinsPerDailyComplete) {
            applyQuestRewards(rewards)
        }
    }

    // MARK: Superpower System

    /// Check whether the just-merged family should unlock its superpower now.
    private func checkSuperpowerUnlock(species: AnimalSpecies, tier: Int) {
        guard tier == Superpower.unlockTier else { return }
        guard !unlockedSuperpowerSpecies.contains(species.rawValue) else { return }
        unlockedSuperpowerSpecies.append(species.rawValue)
        SoundManager.shared.playQuestClaim()
        HapticManager.shared.successPattern()
        showSuperpowerUnlockBanner = true
        superpowerUnlockBannerSpecies = species
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            self.showSuperpowerUnlockBanner = false
        }
    }

    /// Place a free tile at a random empty cell. Returns false if the board is full.
    @discardableResult
    private func placeFreeTile(chainID: ChainID, tier: Int) -> Bool {
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        guard let target = empty.randomElement() else { return false }
        board[target.position.row][target.position.col].item = BoardItem(chainID: chainID, tier: tier)
        recalcBoardIsFull()
        animatingCell = target.position
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            self.animatingCell = nil
        }
        return true
    }

    /// Fire all passive superpowers that trigger on a successful merge.
    private func applyPassivePowers(mergedSpecies: AnimalSpecies?, mergePos: GridPosition, emptyPos: GridPosition) {
        guard let species = mergedSpecies else { return }
        let unlocked = unlockedSuperpowerSpecies

        // Fetch! (Canines .dog): every 5th merge spawns a free Stage-1 Canine.
        if unlocked.contains(AnimalSpecies.dog.rawValue) && mergeCount % 5 == 0 {
            placeFreeTile(chainID: ContentRegistry.animalChainID(.dog), tier: 0)
        }

        // Multiply (Lagomorphs .rabbit): every 4th Lagomorph merge spawns 2 Stage-1 Lagomorphs.
        if species == .rabbit && unlocked.contains(AnimalSpecies.rabbit.rawValue) {
            lagomorphMergeCount += 1
            if lagomorphMergeCount % 4 == 0 {
                let rabbitChain = ContentRegistry.animalChainID(.rabbit)
                placeFreeTile(chainID: rabbitChain, tier: 0)
                placeFreeTile(chainID: rabbitChain, tier: 0)
            }
        }

        // Antler Drop (Cervids .fox): 25% chance to drop a bonus Stage-2 sub-object.
        if species == .fox && unlocked.contains(AnimalSpecies.fox.rawValue) {
            if Int.random(in: 0..<4) == 0 {
                let subChain = "subobject.\(AnimalSpecies.fox.rawValue)"
                let maxSub = ContentRegistry.shared.chain(subChain)?.maxTier ?? 3
                placeFreeTile(chainID: subChain, tier: min(1, maxSub))
            }
        }

        // Current (Aquatics .fish): adjacent sub-objects slide toward the newly empty cell.
        if unlocked.contains(AnimalSpecies.fish.rawValue) {
            applyAquaticsCurrent(emptyPos: emptyPos)
        }
    }

    /// Slide any adjacent sub-object items into `emptyPos` (first one found wins).
    private func applyAquaticsCurrent(emptyPos: GridPosition) {
        let neighbors = [
            GridPosition(row: emptyPos.row - 1, col: emptyPos.col),
            GridPosition(row: emptyPos.row + 1, col: emptyPos.col),
            GridPosition(row: emptyPos.row,     col: emptyPos.col - 1),
            GridPosition(row: emptyPos.row,     col: emptyPos.col + 1),
        ]
        for neighbor in neighbors {
            guard neighbor.row >= 0, neighbor.row < rows,
                  neighbor.col >= 0, neighbor.col < cols else { continue }
            guard let item = board[neighbor.row][neighbor.col].item else { continue }
            guard ContentRegistry.shared.chain(item.chainID)?.category == .subObject else { continue }
            board[emptyPos.row][emptyPos.col].item = item
            board[neighbor.row][neighbor.col].item = nil
            return
        }
    }

    // MARK: Active superpower dispatch

    /// Called by the UI button strip. Checks cooldown and dispatches to the specific handler.
    func activateSuperpower(for species: AnimalSpecies) {
        guard case .active(let cooldown) = species.superpower.kind else { return }
        guard unlockedSuperpowerSpecies.contains(species.rawValue) else { return }
        let now = Date().timeIntervalSince1970
        if let expiry = superpowerCooldownEnds[species.rawValue], now < expiry { return }
        switch species {
        case .cat:       activateNineLives()
        case .guineaPig: activateStampede()
        case .pony:      activateSprint()
        case .lizard:    initiateLeap()
        case .parrot:    activateMimic()
        case .ferret:    activatePouch()
        default: return
        }
        superpowerCooldownEnds[species.rawValue] = now + cooldown
        HapticManager.shared.mediumImpact()
    }

    // Nine Lives (Felines .cat): undo last merge.
    private func activateNineLives() {
        guard let snap = preMoveSnapshot else {
            enqueueToast(Toast(kind: .info("No merge to undo yet."))); return
        }
        board = snap.board
        inventoryStore.inventory = snap.inventory
        rows = board.count
        recalcBoardIsFull()
        preMoveSnapshot = nil
        SoundManager.shared.playQuestClaim()
    }

    // Stampede (Ungulates .guineaPig): merge all same-family same-stage pairs.
    private func activateStampede() {
        var changed = true
        while changed {
            changed = false
            let cells = board.flatMap { $0 }.filter { $0.item != nil }
            // Build a frequency map: chainID+tier → [positions]
            var groups: [String: [GridPosition]] = [:]
            for cell in cells {
                guard let item = cell.item else { continue }
                let key = "\(item.chainID)|\(item.tier)"
                groups[key, default: []].append(cell.position)
            }
            for (_, positions) in groups where positions.count >= 2 {
                let a = positions[0]; let b = positions[1]
                guard let itemA = board[a.row][a.col].item else { continue }
                guard let next = ContentRegistry.shared.nextTier(itemA.chainID, after: itemA.tier) else { continue }
                board[b.row][b.col].item = BoardItem(chainID: itemA.chainID, tier: next)
                board[a.row][a.col].item = nil
                mergeCount += 1
                lastMergeTimestamp = Date().timeIntervalSince1970
                updateAllAfterMerge(chainID: itemA.chainID, tier: next)
                changed = true
            }
        }
        recalcBoardIsFull()
        SoundManager.shared.playMerge()
    }

    // Sprint (Equines .pony): double kibble regen for 60 seconds.
    private func activateSprint() {
        equineSprintRemaining = 60.0
        enqueueToast(Toast(kind: .info("Kibble regen doubled for 60 s!")))
    }

    // Leap (Amphibians .lizard): enter two-step teleport mode.
    private func initiateLeap() {
        leapMode = true
        leapSourceCell = nil
        enqueueToast(Toast(kind: .info("Leap: tap an Amphibian, then an empty cell.")))
    }

    /// Call from the UI when Leap mode is active and the player taps a cell.
    func handleLeapTap(at pos: GridPosition) {
        guard leapMode else { return }
        if leapSourceCell == nil {
            // First tap — select the animal to teleport.
            guard let item = board[pos.row][pos.col].item else { return }
            guard let species = AnimalSpecies(rawValue: item.chainID.replacingOccurrences(of: "animal.", with: "")),
                  species == .lizard else {
                enqueueToast(Toast(kind: .info("Tap an Amphibian tile."))); return
            }
            leapSourceCell = pos
        } else {
            // Second tap — move to empty destination.
            guard let src = leapSourceCell else { return }
            guard board[pos.row][pos.col].isEmpty, board[pos.row][pos.col].isUnlocked else {
                enqueueToast(Toast(kind: .info("Tap an empty cell for the destination."))); return
            }
            board[pos.row][pos.col].item = board[src.row][src.col].item
            board[src.row][src.col].item = nil
            leapMode = false; leapSourceCell = nil
            recalcBoardIsFull()
            SoundManager.shared.playMerge()
        }
    }

    // Mimic (Primates .parrot): spawn a Stage-1 of the last merged family.
    private func activateMimic() {
        guard let rawValue = lastMergedSpeciesRaw,
              let species = AnimalSpecies(rawValue: rawValue) else {
            enqueueToast(Toast(kind: .info("Merge something first!"))); return
        }
        let chainID = ContentRegistry.animalChainID(species)
        if !placeFreeTile(chainID: chainID, tier: 0) {
            enqueueToast(Toast(kind: .info("Board is full!")))
        }
    }

    // Pouch (Marsupials .ferret): store up to 2 animals off-board for 30 s.
    private func activatePouch() {
        pouchItems = [nil, nil]
        pouchExpiryTimestamp = Date().timeIntervalSince1970 + 30
        showPouchPanel = true
    }

    /// Move an item from the board into the Pouch. Returns true on success.
    func pouchStore(from pos: GridPosition) -> Bool {
        guard let item = board[pos.row][pos.col].item else { return false }
        if pouchItems[0] == nil { pouchItems[0] = item }
        else if pouchItems[1] == nil { pouchItems[1] = item }
        else { return false }
        board[pos.row][pos.col].item = nil
        recalcBoardIsFull()
        return true
    }

    /// Auto-return Pouch items to the board (or inventory) when the timer expires.
    func returnPouchItems() {
        pouchExpiryTimestamp = 0
        showPouchPanel = false
        for item in pouchItems.compactMap({ $0 }) {
            if !placeFreeTile(chainID: item.chainID, tier: item.tier) {
                inventoryStore.addItem(item)
            }
        }
        pouchItems = [nil, nil]
    }

    private func applyQuestRewards(_ r: QuestRewards) {
        kibbleEngine.kibble  += withPassBonus(r.kibble)
        kibbleEngine.dogTags += r.dogTags
        grantXP(r.xp)
        earnCoins(r.coins)
        if r.showBonus, !r.bannerText.isEmpty {
            SoundManager.shared.playDailyChallenge()
            HapticManager.shared.successPattern()
            enqueueToast(Toast(kind: .info(r.bannerText)))
        }
    }

    // MARK: Quest logic

    func generateQuest() -> Quest {
        quests.generateQuest(unlockedChainIDs: progression.unlockedChainIDs,
                             playerLevel: playerLevel)
    }

    func setupQuestsPublic() { setupQuests() }

    func claimQuest(id: UUID) {
        guard let quest = quests.claimAndReplace(questID: id,
                                                 unlockedChainIDs: progression.unlockedChainIDs,
                                                 playerLevel: playerLevel)
        else { return }
        kibbleEngine.kibble  += withPassBonus(quest.kibbleReward)
        kibbleEngine.dogTags += quest.dogTagReward + cachedActiveBonuses.questDogTagBonus
        grantXP(quest.difficulty.xpReward)

        var coinEarned = quest.difficulty.coinReward
        if quest.difficulty == .legendary { coinEarned += cachedActiveBonuses.legendaryQuestCoinBonus }
        earnCoins(coinEarned)

        // Rescue-tier producers replaced by family spawners (earned via map).
        // Award bonus Dog Tags instead for hard/legendary quests.
        switch quest.difficulty {
        case .hard      where Int.random(in: 1...4) == 1: kibbleEngine.dogTags += 3
        case .legendary where Int.random(in: 1...2) == 1: kibbleEngine.dogTags += 5
        default: break
        }
        switch quest.difficulty {
        case .easy      where Int.random(in: 1...4) == 1: placeToolbox()
        case .medium:    placeToolbox()
        case .hard:      placeToolbox(); placeToolbox()
        case .legendary: placeToolbox(); placeToolbox(); placeToolbox()
        default: break
        }
    }

    private func placeToolbox() {
        let lot = buildToolboxLot()
        let empty = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
        if let target = empty.randomElement() {
            pendingMaterialLots.append(lot)
            board[target.position.row][target.position.col].item =
                BoardItem(chainID: ContentRegistry.toolboxChainID, tier: 0)
            recalcBoardIsFull()
        } else {
            // Board full — absorb materials immediately; no tile placed.
            inventoryStore.absorbMaterialItems(lot)
            enqueueToast(Toast(kind: .info("Materials collected! (\(lot.count) items)")))
        }
    }

    /// Tap a toolbox tile to instantly absorb all materials from its lot into the accumulator.
    func absorbToolbox(at pos: GridPosition) {
        guard board[pos.row][pos.col].item?.chainID == ContentRegistry.toolboxChainID else { return }
        let lot = pendingMaterialLots.isEmpty ? [] : pendingMaterialLots.removeFirst()
        inventoryStore.absorbMaterialItems(lot)
        board[pos.row][pos.col].item = nil
        selectedCell = nil
        if !lot.isEmpty {
            let woodCount   = lot.filter { $0.chainID == ContentRegistry.woodChainID }.count
            let metalCount  = lot.filter { $0.chainID == ContentRegistry.metalChainID }.count
            let cementCount = lot.filter { $0.chainID == ContentRegistry.cementChainID }.count
            var parts: [String] = []
            if woodCount   > 0 { parts.append("Wood ×\(woodCount)") }
            if metalCount  > 0 { parts.append("Metal ×\(metalCount)") }
            if cementCount > 0 { parts.append("Cement ×\(cementCount)") }
            enqueueToast(Toast(kind: .info("Toolbox collected! \(parts.joined(separator: ", "))")))
        }
        SoundManager.shared.playButtonTap()
        recalcBoardIsFull()
        persist()
    }

    private func buildToolboxLot() -> [BoardItem] {
        let materialChainIDs = [ContentRegistry.woodChainID,
                                ContentRegistry.metalChainID,
                                ContentRegistry.cementChainID]
        let maxTier = toolboxMaxTier(forPlayerLevel: progression.playerLevel)
        var items: [BoardItem] = []
        for chainID in materialChainIDs {
            let count = Int.random(in: 1...3)
            for _ in 0..<count {
                items.append(BoardItem(chainID: chainID, tier: weightedToolboxTier(max: maxTier)))
            }
        }
        return items
    }

    private var boardToolboxCount: Int {
        board.flatMap { $0 }.filter { $0.item?.chainID == ContentRegistry.toolboxChainID }.count
    }

    private func weightedToolboxTier(max maxTier: Int) -> Int {
        let weights = (0...maxTier).map { maxTier + 1 - $0 }
        let total   = weights.reduce(0, +)
        var roll    = Int.random(in: 0..<total)
        for (tier, weight) in zip(0...maxTier, weights) {
            if roll < weight { return tier }
            roll -= weight
        }
        return 0
    }

    // MARK: Daily challenges wrappers

    func checkDailyChallengeReset() {
        quests.checkDailyChallengeReset(unlockedChainIDs: progression.unlockedChainIDs)
    }

    func generateDailyChallenges() {
        quests.generateDailyChallenges(unlockedChainIDs: progression.unlockedChainIDs)
    }

    func updateQuestsAfterMerge(chainID: ChainID, tier: Int) {
        quests.updateQuestsAfterMerge(chainID: chainID, tier: tier)
    }

    func updateDailyChallengesAfterMerge(chainID: ChainID, tier: Int) {
        quests.updateDailyChallengesAfterMerge(chainID: chainID, tier: tier)
    }

    // MARK: Daily login

    func checkDailyLogin() {
        let isNew = quests.checkDailyLogin()
        showLoginReward = isNew
        loginStreakDay = quests.loginStreakDay
    }

    func claimLoginReward() {
        let idx    = max(0, min(loginStreakDay - 1, loginDailyRewards.count - 1))
        let reward = loginDailyRewards[idx]
        kibbleEngine.kibble  += reward.kibble
        kibbleEngine.dogTags += reward.dogTags
        showLoginReward = false
        persist()
    }

    // MARK: Adoption Order Board

    func updateOrdersAfterMerge(chainID: ChainID, tier: Int) {
        let completedIndices = adoptionBoardCoordinator.updateAfterMerge(chainID: chainID, tier: tier)
        for idx in completedIndices { autoClaimOrder(at: idx) }
    }

    func autoClaimOrder(at index: Int) {
        guard adoptionBoardCoordinator.adoptionOrders.indices.contains(index),
              adoptionBoardCoordinator.adoptionOrders[index].isComplete,
              !adoptionBoardCoordinator.adoptionOrders[index].isClaimed else { return }
        let order = adoptionBoardCoordinator.adoptionOrders[index]
        // Adoption orders are fulfilled by merging animals on the board; kibble is
        // intentionally NOT a merge reward (regen timer, dog tags, quests, IAP only).
        SoundManager.shared.playRescueClaim()
        kibbleEngine.dogTags += order.rewardDogTags
        grantXP(xpPerOrderFulfil)
        earnCoins(order.rewardCoins + cachedActiveBonuses.coinsPerOrderFulfil)
        if let pack = order.rewardCardPack { earnCardPack(pack) }
        adoptionBoardCoordinator.markClaimed(at: index)
        NotificationManager.shared.cancelRescueExpiring()
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.adoptionBoardCoordinator.replaceOrder(
                at: index,
                unlockedChainIDs: self.progression.unlockedAnimalChainIDs,
                playerLevel: self.progression.playerLevel
            )
            self.rescheduleRescueExpiring()
        }
    }

    /// Schedules (or cancels) the rescue-expiring notification based on the
    /// soonest-expiring active order that still has > 2 minutes remaining.
    private func rescheduleRescueExpiring() {
        let now = Date()
        let earliest = adoptionBoardCoordinator.adoptionOrders
            .filter { !$0.isClaimed && !$0.isComplete && $0.timeRemaining > 120 }
            .map { now.addingTimeInterval($0.timeRemaining) }
            .min()
        if let expiresAt = earliest {
            NotificationManager.shared.scheduleRescueExpiring(expiresAt: expiresAt)
        } else {
            NotificationManager.shared.cancelRescueExpiring()
        }
    }

    func generateAdoptionOrder() -> AdoptionOrder {
        adoptionBoardCoordinator.generateOrder(
            unlockedChainIDs: progression.unlockedAnimalChainIDs,
            playerLevel: progression.playerLevel
        )
    }

    func skipOrder(at index: Int) {
        guard adoptionBoardCoordinator.canSkip(at: index,
                                               kibbleCost: adoptionSkipCost,
                                               currentKibble: kibbleEngine.kibble) else { return }
        kibbleEngine.kibble -= adoptionSkipCost
        adoptionBoardCoordinator.skipOrder(at: index,
                                           unlockedChainIDs: progression.unlockedAnimalChainIDs,
                                           playerLevel: progression.playerLevel)
        rescheduleRescueExpiring()
    }

    // MARK: Weekly spotlight

    func updateWeeklySpotlight() {
        quests.updateWeeklySpotlight(unlockedChainIDs: progression.unlockedChainIDs)
    }

    func recordSpotlightMerge(chainID: ChainID) {
        if let rewards = quests.recordSpotlightMerge(chainID: chainID) {
            kibbleEngine.kibble  += rewards.kibble
            kibbleEngine.dogTags += rewards.dogTags
        }
    }

    // MARK: Spawn multiplier

    func cycleSpawnMultiplier() {
        progression.cycleSpawnMultiplier()
        persist()
    }

    // MARK: Invite

    func recordInviteSent() {
        inviteProgress.invitesSent += 1
        persist()
    }

    func claimInviteMilestone(tier: Int) {
        guard let milestone = inviteMilestones.first(where: { $0.id == tier }),
              inviteProgress.canClaim(milestone) else { return }
        inviteProgress.claimedMilestones.append(tier)
        let kibble = withPassBonus(milestone.kibbleReward)
        if kibble > 0 { kibbleEngine.kibble = min(kibbleRegenCap, kibbleEngine.kibble + kibble) }
        if milestone.dogTagsReward > 0 { kibbleEngine.dogTags += milestone.dogTagsReward }
        persist()
    }

    // MARK: Sanctuary Pass

    func claimPassDaily() {
        guard canClaimPassDaily else { return }
        passLastClaimDate = Date()
        kibbleEngine.kibble += passDailyKibble
        enqueueToast(Toast(kind: .info("Sanctuary Pass: +\(passDailyKibble) Kibble")))
        persist()
    }

    // MARK: Loyalty Club

    func claimLoyaltyClub() {
        guard canClaimLoyaltyClub else { return }
        let reward = currentLoyaltyReward
        loyaltyClubLastClaimDate = Date()
        loyaltyClubStreak += 1
        loyaltyClubDayIndex = (loyaltyClubDayIndex + 1) % loyaltyClubCycle.count
        kibbleEngine.kibble  += withPassBonus(reward.kibble)
        kibbleEngine.dogTags += reward.dogTags
        if let pack = reward.cardPack { earnCardPack(pack) }
        var text = "Loyalty Club: +\(withPassBonus(reward.kibble)) Kibble"
        if reward.dogTags > 0   { text += "  +\(reward.dogTags) Tags" }
        if reward.cardPack != nil { text += "  + Card Pack" }
        enqueueToast(Toast(kind: .info(text)))
    }

    // MARK: Rewarded ads

    func watchRewardedAd(provider: RewardedAdProvider = StubAdProvider()) {
        kibbleEngine.watchRewardedAd(effectiveKibble: effectiveAdKibble, provider: provider)
    }

    // MARK: Sanctuary map

    func isAreaAvailable(_ area: SanctuaryArea) -> Bool {
        guard !completedAreaIDs.contains(area.id) else { return false }
        guard area.requiresPrevious else { return true }
        guard let idx = sanctuaryAreas.firstIndex(where: { $0.id == area.id }), idx > 0 else {
            return false
        }
        let prev = sanctuaryAreas[idx - 1]
        guard completedAreaIDs.contains(prev.id) else { return false }
        return (areaUpgradeLevels[prev.id] ?? 0) >= prev.upgrades.count
    }

    func isAreaPreviousBuilt(_ area: SanctuaryArea) -> Bool {
        guard area.requiresPrevious else { return true }
        guard let idx = sanctuaryAreas.firstIndex(where: { $0.id == area.id }), idx > 0 else { return false }
        return completedAreaIDs.contains(sanctuaryAreas[idx - 1].id)
    }

    func isPreviousFullyUpgraded(_ area: SanctuaryArea) -> Bool {
        guard area.requiresPrevious else { return true }
        guard let idx = sanctuaryAreas.firstIndex(where: { $0.id == area.id }), idx > 0 else { return false }
        let prev = sanctuaryAreas[idx - 1]
        return (areaUpgradeLevels[prev.id] ?? 0) >= prev.upgrades.count
    }

    func canAffordArea(_ area: SanctuaryArea) -> Bool {
        area.costs.allSatisfy { cost in
            inventoryStore.countMaterial(chainID: cost.chainID, tier: cost.tier) >= cost.count
        }
    }

    func buildArea(_ area: SanctuaryArea) {
        guard isAreaAvailable(area), canAffordArea(area) else { return }
        for cost in area.costs {
            for _ in 0..<cost.count {
                inventoryStore.consumeFromToolInventory(chainID: cost.chainID, tier: cost.tier)
            }
        }
        completedAreaIDs.append(area.id)
        let r = area.reward
        if let species = r.newFamilySpawner {
            // Unlock the family's animal chain
            let chainID = ContentRegistry.animalChainID(species)
            if !progression.unlockedChainIDs.contains(chainID) { progression.unlockedChainIDs.append(chainID) }
            // Auto-place the spawner; overflow to storage if board is full
            let spawnerTile = ProducerTile(level: .familySpawner, species: species)
            let emptyUnlocked = board.flatMap { $0 }.filter { $0.isUnlocked && $0.isEmpty }
            if let target = emptyUnlocked.randomElement() {
                board[target.position.row][target.position.col].producer = spawnerTile
                recalcBoardIsFull()
                animatingCell = target.position
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    self.animatingCell = nil
                }
            } else {
                // Board full — store in overflow so player can retrieve from inventory
                inventoryStore.overflowProducerStorage.append(spawnerTile)
            }
        }
        if r.bonusKibble  > 0 { kibbleEngine.kibble  += r.bonusKibble }
        if r.bonusDogTags > 0 { kibbleEngine.dogTags += r.bonusDogTags }
        if r.bonusXP      > 0 { grantXP(r.bonusXP) }
        if cachedActiveBonuses.areaEventCoins > 0 { earnCoins(cachedActiveBonuses.areaEventCoins) }
        areaBuiltBannerTitle  = "\(area.displayName) Built!"
        areaBuiltBannerDetail = r.primaryMessage()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { showAreaBuiltBanner = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.4)) { self.showAreaBuiltBanner = false }
        }
    }

    // MARK: Coins & weekly/monthly goals

    func earnCoins(_ amount: Int) {
        guard amount > 0 else { return }
        coins += amount
        coinsEarnedThisWeek += amount
        trackEventCoins(amount)
    }

    private func trackEventCoins(_ amount: Int) {
        guard let event = EventRegistry.currentEvent else { return }
        if eventProgress.eventId != event.id {
            eventProgress = EventProgress(eventId: event.id, coinsEarned: 0, claimedMilestones: [])
        }
        eventProgress.coinsEarned += amount
    }

    func claimEventMilestone(tier: Int) {
        guard let event = activeEvent,
              let milestone = event.milestones.first(where: { $0.id == tier }),
              eventProgress.canClaim(milestone) else { return }
        eventProgress.claimedMilestones.append(tier)
        let kibble = withPassBonus(milestone.kibbleReward)
        kibbleEngine.kibble = min(kibbleRegenCap, kibbleEngine.kibble + kibble)
        if milestone.dogTagsReward > 0 { kibbleEngine.dogTags += milestone.dogTagsReward }
        persist()
    }

    func checkWeeklyGoalReset() {
        let cal = Calendar.current
        let now = Date()
        guard let thisWeekStart = cal.dateInterval(of: .weekOfYear, for: now)?.start else { return }
        guard let lastReset = lastWeeklyGoalReset else { lastWeeklyGoalReset = thisWeekStart; return }
        guard lastReset < thisWeekStart else { return }
        if weeklyGoalGoldClaimed { weeklyGoldCompletions += 1 }
        coinsEarnedThisWeek     = 0
        weeklyGoalBronzeClaimed = false
        weeklyGoalSilverClaimed = false
        weeklyGoalGoldClaimed   = false
        lastWeeklyGoalReset     = thisWeekStart
    }

    func checkMonthlyGoalReset() {
        let cal = Calendar.current
        let now = Date()
        guard let thisMonthStart = cal.dateInterval(of: .month, for: now)?.start else { return }
        guard let lastReset = lastMonthlyGoalReset else { lastMonthlyGoalReset = thisMonthStart; return }
        guard lastReset < thisMonthStart else { return }
        weeklyGoldCompletions = 0
        monthlyGoalClaimed    = false
        lastMonthlyGoalReset  = thisMonthStart
    }

    func claimWeeklyGoal(tier: WeeklyGoalTier) {
        let reached = weeklyGoalReached
        switch tier {
        case .bronze:
            guard reached.bronze && !weeklyGoalBronzeClaimed else { return }
            weeklyGoalBronzeClaimed = true
        case .silver:
            guard reached.silver && !weeklyGoalSilverClaimed else { return }
            weeklyGoalSilverClaimed = true
        case .gold:
            guard reached.gold && !weeklyGoalGoldClaimed else { return }
            weeklyGoalGoldClaimed = true
            weeklyGoldCompletions += 1
        }
        let multiplier = cachedActiveBonuses.weeklyRewardDoubled && tier != .bronze ? 2 : 1
        kibbleEngine.kibble  += tier.baseKibbleReward * multiplier
        kibbleEngine.dogTags += tier.dogTagReward
        grantXP(tier.xpReward)
        for _ in 0..<tier.toolboxCount { placeToolbox() }
    }

    func claimMonthlyGoal() {
        guard monthlyGoalReached && !monthlyGoalClaimed else { return }
        monthlyGoalClaimed = true
        kibbleEngine.kibble  += 50
        kibbleEngine.dogTags += 20
        grantXP(200)
        for _ in 0..<3 { placeToolbox() }
    }

    // MARK: Active bonuses

    private func recalcActiveBonuses() {
        var result = UpgradeBonus()
        for area in sanctuaryAreas {
            let level = areaUpgradeLevels[area.id] ?? 0
            for (i, upgrade) in area.upgrades.enumerated() where i < level {
                result = result.merging(upgrade.bonus)
            }
        }
        cachedActiveBonuses = result
    }

    // MARK: Area upgrades

    func isUpgradeAvailable(_ area: SanctuaryArea, tier: Int) -> Bool {
        guard completedAreaIDs.contains(area.id) else { return false }
        guard tier < area.upgrades.count else { return false }
        let currentLevel = areaUpgradeLevels[area.id] ?? 0
        return tier == currentLevel
    }

    func canAffordUpgrade(_ area: SanctuaryArea, tier: Int) -> Bool {
        guard tier < area.upgrades.count else { return false }
        let upgrade = area.upgrades[tier]
        guard coins >= upgrade.coinCost else { return false }
        return upgrade.materialCosts.allSatisfy { cost in
            inventoryStore.countMaterial(chainID: cost.chainID, tier: cost.tier) >= cost.count
        }
    }

    func upgradeArea(_ area: SanctuaryArea) {
        let tier = areaUpgradeLevels[area.id] ?? 0
        guard isUpgradeAvailable(area, tier: tier), canAffordUpgrade(area, tier: tier) else { return }
        let upgrade = area.upgrades[tier]
        coins -= upgrade.coinCost
        for cost in upgrade.materialCosts {
            for _ in 0..<cost.count {
                inventoryStore.consumeFromToolInventory(chainID: cost.chainID, tier: cost.tier)
            }
        }
        areaUpgradeLevels[area.id] = tier + 1
        recalcActiveBonuses()
        adoptionBoardCoordinator.syncOrderSlots(count: adoptionOrderCount,
                                                unlockedChainIDs: progression.unlockedAnimalChainIDs,
                                                playerLevel: progression.playerLevel)
        if cachedActiveBonuses.areaEventCoins > 0 { earnCoins(cachedActiveBonuses.areaEventCoins) }
        areaBuiltBannerTitle  = "\(area.displayName) Upgraded!"
        areaBuiltBannerDetail = upgrade.bonus.primaryDescription
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) { showAreaBuiltBanner = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            withAnimation(.easeOut(duration: 0.4)) { self.showAreaBuiltBanner = false }
        }
    }

    // MARK: IAP

    func applyPurchase(_ product: IAPProduct) {
        if let k = product.kibbleAmount { kibbleEngine.kibble  += k }
        if let t = product.dogTagAmount { kibbleEngine.dogTags += t }
        if let ep = product.energyPackContents {
            kibbleEngine.kibble  += ep.kibble
            kibbleEngine.dogTags += ep.dogTags
            for _ in 0..<ep.spawnerCount { placeProducerReward(ep.spawnerLevel) }
            earnCardPack(ep.cardPack)
        }
        if product == .sanctuaryPass {
            isPassActive = true
            claimPassDaily()
        }
    }
}
