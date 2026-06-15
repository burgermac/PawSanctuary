//
//  GameStore.swift
//  PawSanctuary
//
//  Single Codable snapshot of the whole game + one save/load path.
//  Replaces the dozen scattered UserDefaults keys that previously held
//  fragments of progress (and left board/inventory/currency unsaved).
//

import Foundation

// ============================================================
// MARK: - GAME STATE SNAPSHOT
// ============================================================

/// A complete, serialisable snapshot of a play session. Everything needed to
/// restore the game exactly as the player left it lives here.
struct GameState: Codable {
    /// Schema version — lets us migrate or discard incompatible saves later.
    var version: Int = 1

    // Board (cells carry their own animals + producers)
    var board: [[BoardCell]]

    // Currencies & counters
    var kibble: Int
    var dogTags: Int
    var score: Int
    var rescueCount: Int    // animals spawned from producers
    var ambassadors: Int    // animal chains completed (reached top tier)
    var mergeCount: Int
    var secondsUntilNextKibble: Int

    // Progression
    var playerLevel: Int
    var playerXP: Int
    var unlockedChainIDs: [ChainID]

    // Inventory
    var inventory: [BoardItem?]
    var inventoryRow1Unlocked: Bool
    var inventoryRow2Unlocked: Bool

    // Quests / challenges / orders
    var activeQuests: [Quest]
    var dailyChallenges: [DailyChallenge]
    var dailyChallengeStreak: Int
    var dailyChallengeBonusClaimed: Bool
    var adoptionOrders: [AdoptionOrder]

    // Spotlight
    var spotlightMergesThisWeek: Int

    // Material storage & producer storage (Phase 3)
    var toolInventory: [BoardItem?]                // .tool and .material items stashed here
    /// Designated storage: one slot per ProducerLevel, keyed by rawValue.
    /// Slots are shown as grayed-out until playerLevel >= level.storageUnlockLevel.
    var producerStorage: [Int: ProducerTile]
    /// Overflow: producers retired before their designated slot unlocked land here temporarily.
    var overflowProducerStorage: [ProducerTile?]

    // Sanctuary map (Phase 4) — stable area IDs for completed builds.
    var completedAreaIDs: [String]
    /// Upgrade tier reached per area, keyed by stable area ID.
    /// 0 (or absent) = built only; 1 = first upgrade; 2 = fully upgraded.
    var areaUpgradeLevels: [String: Int]

    // Spawn multiplier (1 / 2 / 4 / 8) — which tier board spawners produce per tap
    var spawnMultiplier: Int

    // Card pack collection system
    var cardInventory: [String: Int]    // cardID → copies owned (≥1 = collected)
    var starCount: Int                  // stars earned from duplicate cards
    var completedAlbumIDs: [String]     // albums the player has claimed the reward for
    var pendingCardPacks: [CardPackType] // packs waiting to be opened
    var jokerCards: Int                 // common wild cards (fill any missing common)
    var rareJokerCards: Int             // rare wild cards (fill any missing rare)

    // Card trading (Game Center + CloudKit)
    var pendingOutgoingTrades: [CardTrade]   // trades this player has sent
    var pendingIncomingTrades: [CardTrade]   // received trades not yet claimed
    var cardsSentToday: Int
    var lastCardSendDate: Date?

    // Coins & weekly/monthly goal system (Phase 5)
    var coins: Int
    var coinsEarnedThisWeek: Int
    var weeklyGoalBronzeClaimed: Bool
    var weeklyGoalSilverClaimed: Bool
    var weeklyGoalGoldClaimed: Bool
    var lastWeeklyGoalReset: Date?
    var weeklyGoldCompletions: Int   // gold weeks hit this calendar month
    var monthlyGoalClaimed: Bool
    var lastMonthlyGoalReset: Date?

    // Date-based bookkeeping (consolidated from the old scattered keys)
    var lastLoginDate: Date?
    var loginStreak: Int
    var loginDayIndex: Int
    var lastDailyChallengeReset: Date?
    var lastSpotlightWeek: Int

    // Rewarded ads (v12)
    var adsWatchedToday: Int
    var lastAdWatchDate: Date?

    // Board expansion (v13) — kept for Codable backwards-compat; no longer written by new saves.
    var purchasedBoardRows: Int = 0

    // Sanctuary Pass (v14)
    var passLastClaimDate: Date?

    // Loyalty Club (v15)
    var loyaltyClubDayIndex: Int
    var loyaltyClubLastClaimDate: Date?
    var loyaltyClubStreak: Int

    // Events (v16)
    var eventProgress: EventProgress

    // Invite-a-friend (v17)
    var inviteProgress: InviteProgress

    // Ambassador collection quest (v18) — progress toward "collect 3 fully merged animals → 500 coins"
    var ambassadorQuestProgress: Int = 0

    // Material dispensing queue (v20) — one lot per pending toolbox; player taps tile to collect one item at a time
    var pendingMaterialLots: [[BoardItem]] = []

    /// Wall-clock time the snapshot was taken, used to advance timers for the
    /// span the app was closed. Optional so pre-existing saves still decode.
    var lastActiveDate: Date?
}

// ============================================================
// MARK: - GAME STORE
// ============================================================

/// The one place that reads/writes the persisted game.
///
/// Storage layers (in order of authority on load):
///   • **Local file** — `Application Support/PawSanctuary/gameState.json`, written
///     atomically. The primary store; the per-second autosave writes here.
///   • **Backup slot** — `gameState.backup.json`. A last-known-good copy refreshed
///     on each successful launch; used to recover if the main file is unreadable.
///   • **iCloud** — `NSUbiquitousKeyValueStore`, for cross-device sync. Degrades
///     gracefully: with no iCloud entitlement/account these calls are harmless
///     no-ops and the game simply runs on local storage.
///
/// On load, local and iCloud copies are reconciled by `lastActiveDate`
/// (most-recently-active device wins).
enum GameStore {

    /// The schema version this build understands. Bump it whenever a change to
    /// `GameState` makes old saves unreadable — and add migration handling below.
    /// v2: generalized chain model (BoardItem(chainID,tier) replaced MergeItem(species,stage)).
    /// v3: ProducerTile gains chargesRemaining (finite spawner charges, Phase 1).
    /// v4: GameState gains supplyCount; supply chains + producers added (Phase 2).
    /// v5: toolInventory + producerStorage added; tool & material chains added (Phase 3).
    /// v6: three material chains (wood/metal/cement) + toolbox consumable; producerStorage
    ///     changed to [Int:ProducerTile] with one designated slot per ProducerLevel;
    ///     overflowProducerStorage added for producers retired before their slot unlocks.
    /// v7: completedAreaIDs added for Phase 4 sanctuary map construction.
    /// v8: coins, weekly/monthly goal state, areaUpgradeLevels, and AdoptionOrder.rewardCoins (Phase 5).
    /// v9: spawnMultiplier added; animal producers now use kibble-based spawn (no charges/cooldown).
    /// v10: card pack system — cardInventory, starCount, completedAlbumIDs, pendingCardPacks, jokers.
    ///      AdoptionOrder.rewardCardPack added; LevelUpReward.cardPack added.
    /// v11: card trading — pendingOutgoingTrades, pendingIncomingTrades, cardsSentToday, lastCardSendDate.
    /// v12: rewarded ads — adsWatchedToday, lastAdWatchDate.
    /// v13: board expansion — purchasedBoardRows.
    /// v14: sanctuary pass — passLastClaimDate.
    /// v15: loyalty club — loyaltyClubDayIndex, loyaltyClubLastClaimDate, loyaltyClubStreak.
    /// v16: events — eventProgress.
    /// v17: invite-a-friend — inviteProgress.
    /// v18: animal chains reduced 10→9 tiers (stray removed). Shift all animal
    ///      board/inventory item tiers, adoption order wantedTiers, and quest
    ///      reachTier(.animal) goals down by 1 (clamped at 0).
    /// v19: ambassador collection quest — ambassadorQuestProgress.
    /// v20: material dispensing queue — pendingMaterialLots (toolbox tap-to-collect).
    static let currentVersion = 20

    /// Minimal "envelope" used to read just the version before committing to a
    /// full decode. This is the seam where future v1→v2 migrations will branch.
    private struct SaveEnvelope: Codable { var version: Int }

    private static let cloudKey = "pawSanctuary.gameState"

    // MARK: Storage locations

    /// `Application Support/PawSanctuary/` (created on demand).
    private static var folderURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil, create: true))
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("PawSanctuary", isDirectory: true)
    }
    /// Internal (not private) so unit tests can plant/inspect files.
    static var mainFileURL:   URL { folderURL.appendingPathComponent("gameState.json") }
    static var backupFileURL: URL { folderURL.appendingPathComponent("gameState.backup.json") }

    /// True only when the iCloud KVS entitlement is provisioned *and* the user
    /// is signed into iCloud. Accessing NSUbiquitousKeyValueStore.default without
    /// the entitlement logs "BUG IN CLIENT OF KVS" on-device, so we guard every
    /// call site behind this check and never touch .default when it returns false.
    private static var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    // MARK: Public API

    /// Fast local save — used by the per-second autosave. Writes the main file only.
    static func save(_ state: GameState) {
        guard let data = encode(state) else { return }
        writeLocal(data)
    }

    /// Local save **plus** an iCloud push. Call at meaningful moments (e.g. when the
    /// app backgrounds) so another device gets the latest state, without paying for
    /// cloud writes every single second.
    static func saveAndSync(_ state: GameState) {
        guard let data = encode(state) else { return }
        writeLocal(data)
        writeCloud(data)
    }

    /// Loads the best available state: reconciles the local file and the iCloud copy
    /// (most-recently-active wins) and recovers from the backup slot if the main file
    /// is missing or unreadable. Returns `nil` only when no usable save exists.
    static func load() -> GameState? {
        let localState = readValid(try? Data(contentsOf: mainFileURL)) ?? recoverFromBackup()
        let cloudState = isCloudAvailable
            ? readValid(NSUbiquitousKeyValueStore.default.data(forKey: cloudKey))
            : nil

        guard let chosen = mostRecent(localState, cloudState) else { return nil }

        // Make every slot consistent with the winning state, and refresh the
        // last-known-good backup from a state we just validated.
        if let data = encode(chosen) {
            writeLocal(data)
            writeBackup(data)
            writeCloud(data)
        }
        return chosen
    }

    /// Wipes every persisted copy (local file, backup, iCloud).
    static func clear() {
        try? FileManager.default.removeItem(at: mainFileURL)
        try? FileManager.default.removeItem(at: backupFileURL)
        if isCloudAvailable {
            NSUbiquitousKeyValueStore.default.removeObject(forKey: cloudKey)
            NSUbiquitousKeyValueStore.default.synchronize()
        }
    }

    // MARK: Encoding & version checking

    /// Encodes a snapshot, always stamped with the current schema version.
    private static func encode(_ state: GameState) -> Data? {
        var stamped = state
        stamped.version = currentVersion
        do { return try JSONEncoder().encode(stamped) }
        catch { assertionFailure("GameStore: encode failed — \(error)"); return nil }
    }

    /// Decodes + version-checks a blob. Returns `nil` for missing / wrong-version /
    /// corrupt data — the single gate every storage layer passes through on load.
    private static func readValid(_ data: Data?) -> GameState? {
        guard let data else { return nil }
        // Read the version first so we discard intentionally, not by accident.
        let version = (try? JSONDecoder().decode(SaveEnvelope.self, from: data))?.version ?? 0
        if version == 8 { return migrateByInjecting(defaults: ["spawnMultiplier": 1,
                                                                 "cardInventory": [:],
                                                                 "starCount": 0,
                                                                 "completedAlbumIDs": [],
                                                                 "pendingCardPacks": [],
                                                                 "jokerCards": 0,
                                                                 "rareJokerCards": 0], into: data) }
        if version == 9 { return migrateByInjecting(defaults: ["cardInventory": [:],
                                                                "starCount": 0,
                                                                "completedAlbumIDs": [],
                                                                "pendingCardPacks": [],
                                                                "jokerCards": 0,
                                                                "rareJokerCards": 0,
                                                                "pendingOutgoingTrades": [],
                                                                "pendingIncomingTrades": [],
                                                                "cardsSentToday": 0], into: data) }
        if version == 10 { return migrateByInjecting(defaults: ["pendingOutgoingTrades": [],
                                                                 "pendingIncomingTrades": [],
                                                                 "cardsSentToday": 0], into: data) }
        if version == 11 { return migrateByInjecting(defaults: ["adsWatchedToday": 0], into: data) }
        if version == 12 { return migrateByInjecting(defaults: ["purchasedBoardRows": 0], into: data) }
        if version == 13 { return migrateByInjecting(defaults: [:], into: data) }   // passLastClaimDate optional — no default needed
        if version == 14 { return migrateByInjecting(defaults: ["loyaltyClubDayIndex": 0,
                                                                  "loyaltyClubStreak": 0], into: data) }
        if version == 15 { return migrateByInjecting(defaults: ["eventProgress": ["eventId": "", "coinsEarned": 0, "claimedMilestones": []]], into: data) }
        if version == 16 { return migrateByInjecting(defaults: ["inviteProgress": ["invitesSent": 0, "claimedMilestones": []]], into: data) }
        if version == 17 { return migrateV17toV18(data) }
        if version == 18 { return migrateByInjecting(defaults: ["ambassadorQuestProgress": 0], into: data) }
        if version == 19 { return migrateByInjecting(defaults: ["pendingMaterialLots": []], into: data) }
        guard version == currentVersion else { return nil }
        do { return try JSONDecoder().decode(GameState.self, from: data) }
        catch { assertionFailure("GameStore: decode v\(version) failed — \(error)"); return nil }
    }

    /// Injects missing keys with default values, stamps the current version, and re-decodes.
    /// Used for additive schema migrations (new nullable/defaultable fields only).
    private static func migrateByInjecting(defaults: [String: Any], into data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        for (key, value) in defaults where json[key] == nil { json[key] = value }
        // Always ensure the newest non-optional fields are present regardless of source version.
        if json["ambassadorQuestProgress"] == nil { json["ambassadorQuestProgress"] = 0 }
        if json["pendingMaterialLots"]      == nil { json["pendingMaterialLots"]      = [] }
        json["version"] = currentVersion
        guard let patched = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        do { return try JSONDecoder().decode(GameState.self, from: patched) }
        catch { assertionFailure("GameStore: migration decode failed — \(error)"); return nil }
    }

    /// v17 → v18 migration: animal chains shrunk from 10 tiers (0=stray … 9=ambassador)
    /// to 9 tiers (0=rescued … 8=ambassador). Shift every stored animal tier index
    /// down by 1 (clamped at 0) so saved items, orders, and quest goals remain valid.
    private static func migrateV17toV18(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Decrement the tier of a single BoardItem dict if it belongs to an animal chain.
        func shiftAnimalTier(_ item: inout [String: Any]) {
            guard let chainID = item["chainID"] as? String,
                  chainID.hasPrefix("animal."),
                  let tier = item["tier"] as? Int else { return }
            item["tier"] = max(0, tier - 1)
        }

        // ── Board cells ──────────────────────────────────────────
        if var board = json["board"] as? [[[String: Any]]] {
            for row in board.indices {
                for col in board[row].indices {
                    if var item = board[row][col]["item"] as? [String: Any] {
                        shiftAnimalTier(&item)
                        board[row][col]["item"] = item
                    }
                }
            }
            json["board"] = board
        }

        // ── Player inventory ─────────────────────────────────────
        if var inventory = json["inventory"] as? [Any] {
            for i in inventory.indices {
                if var item = inventory[i] as? [String: Any] {
                    shiftAnimalTier(&item)
                    inventory[i] = item
                }
            }
            json["inventory"] = inventory
        }

        // ── Tool inventory (no animal items expected, but guard anyway) ──
        if var toolInventory = json["toolInventory"] as? [Any] {
            for i in toolInventory.indices {
                if var item = toolInventory[i] as? [String: Any] {
                    shiftAnimalTier(&item)
                    toolInventory[i] = item
                }
            }
            json["toolInventory"] = toolInventory
        }

        // ── Adoption orders ──────────────────────────────────────
        // wantedChainID / wantedTier pair: shift if it's an animal chain.
        if var orders = json["adoptionOrders"] as? [[String: Any]] {
            for i in orders.indices {
                if let chainID = orders[i]["wantedChainID"] as? String,
                   chainID.hasPrefix("animal."),
                   let tier = orders[i]["wantedTier"] as? Int {
                    orders[i]["wantedTier"] = max(0, tier - 1)
                }
            }
            json["adoptionOrders"] = orders
        }

        // ── Active quests & daily challenges ────────────────────
        // QuestGoal.reachTier encodes as: {"reachTier": {"_0": "animal", "tier": N, "count": C}}
        // Only shift when the category is "animal"; supply tiers are unchanged.
        func shiftQuestGoals(_ questArray: inout [Any]) {
            for i in questArray.indices {
                guard var quest = questArray[i] as? [String: Any],
                      var goal  = quest["goal"] as? [String: Any],
                      var reach = goal["reachTier"] as? [String: Any],
                      (reach["_0"] as? String) == "animal",
                      let tier  = reach["tier"] as? Int else { continue }
                reach["tier"] = max(0, tier - 1)
                goal["reachTier"] = reach
                quest["goal"] = goal
                questArray[i] = quest
            }
        }

        if var quests = json["activeQuests"] as? [Any] {
            shiftQuestGoals(&quests); json["activeQuests"] = quests
        }
        if var challenges = json["dailyChallenges"] as? [Any] {
            shiftQuestGoals(&challenges); json["dailyChallenges"] = challenges
        }

        // Inject fields added after v17 that this migration path didn't previously include.
        if json["ambassadorQuestProgress"] == nil { json["ambassadorQuestProgress"] = 0 }
        if json["pendingMaterialLots"]      == nil { json["pendingMaterialLots"]      = [] }
        json["version"] = currentVersion
        guard let patched = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        do { return try JSONDecoder().decode(GameState.self, from: patched) }
        catch { assertionFailure("GameStore: migrateV17 decode failed — \(error)"); return nil }
    }

    /// Picks the snapshot with the later `lastActiveDate` (the device that played
    /// most recently). Either argument may be nil.
    private static func mostRecent(_ a: GameState?, _ b: GameState?) -> GameState? {
        switch (a, b) {
        case let (x?, y?):
            return (y.lastActiveDate ?? .distantPast) > (x.lastActiveDate ?? .distantPast) ? y : x
        case let (x?, nil): return x
        case let (nil, y?): return y
        default:            return nil
        }
    }

    // MARK: Local file IO (atomic writes)

    private static func writeLocal(_ data: Data) {
        ensureFolder()
        do { try data.write(to: mainFileURL, options: .atomic) }
        catch { assertionFailure("GameStore: writeLocal failed — \(error)") }
    }
    private static func writeBackup(_ data: Data) {
        ensureFolder()
        try? data.write(to: backupFileURL, options: .atomic)
    }
    private static func recoverFromBackup() -> GameState? {
        guard let data = try? Data(contentsOf: backupFileURL),
              let state = readValid(data) else { return nil }
        writeLocal(data)   // restore the main file from the good backup
        return state
    }
    private static func ensureFolder() {
        try? FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
    }

    // MARK: iCloud (NSUbiquitousKeyValueStore)

    // TODO (pre-launch, iCloud setup): the sync code below is wired and ready, but
    // NSUbiquitousKeyValueStore only actually syncs once the capability is provisioned.
    // To activate cross-device save sync:
    //   1. Xcode → PawSanctuary target → Signing & Capabilities → + Capability →
    //      iCloud → check "Key-value storage". (This provisions the
    //      com.apple.developer.ubiquity-kvstore-identifier entitlement automatically —
    //      do it via the UI, not by hand-editing the project, so signing stays valid.)
    //   2. Ensure the test device/account is signed into iCloud.
    // Until then these calls are harmless no-ops and the game runs on local storage.
    private static func writeCloud(_ data: Data) {
        guard isCloudAvailable else { return }
        NSUbiquitousKeyValueStore.default.set(data, forKey: cloudKey)
        NSUbiquitousKeyValueStore.default.synchronize()
    }
}
