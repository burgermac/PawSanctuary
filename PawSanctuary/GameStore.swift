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
    // Urgent order (v29, Phase 5 Task 5.2) — separate from the persistent slots
    // above. `nil` while `urgentOrderCooldownRemaining` counts down after a miss.
    var urgentOrder: AdoptionOrder? = nil
    var urgentOrderTimeRemaining: Double = 0
    var urgentOrderCooldownRemaining: Double = 0

    // Spotlight
    var spotlightMergesThisWeek: Int

    // Material accumulator & producer storage (Phase 3)
    /// Per-tier counts for each material chain. Keys are ChainIDs; values are [Int] of length 6.
    /// Replaces the old slot-based toolInventory (v20 → v21 migration).
    var materialCounts: [ChainID: [Int]]
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

    // Pity tracking (v22/v23) — per-family spawner pity state (spawnsSinceLastRare/Epic).
    // Keys are ChainIDs; values are PityState structs. Reset to [:] on migration from v22.
    var pityStates: [String: PityState] = [:]

    // Superpower system (v24) — per-family unlock + active-ability runtime state.
    var unlockedSuperpowerSpecies: [String] = []       // AnimalSpecies.rawValue of unlocked families
    var superpowerCooldownEnds: [String: Double] = [:] // species.rawValue → Unix timestamp (when cooldown expires)
    var lagomorphMergeCount: Int = 0                   // Lagomorphs Multiply: every 4th merge spawns 2 Stage-1s
    var lastMergeTimestamp: Double = 0                 // Unix timestamp of last successful merge (Ursids Hibernate)
    var lastMergedSpeciesRaw: String? = nil            // Primates Mimic: family of the last successful merge
    var equineSprintRemaining: Double = 0              // seconds of Sprint (Equines) currently active
    var pouchItems: [BoardItem?] = [nil, nil]          // Marsupials Pouch: 2 off-board storage slots
    var pouchExpiryTimestamp: Double = 0               // Unix timestamp when Pouch expires (0 = inactive)

    // Player commerce state (v26) — offer targeting / difficulty scaling / Phase 3 first-purchase gate.
    var commerce: PlayerCommerceState = PlayerCommerceState()

    // Economy correction (v27, Phase 2)
    /// Deepest animal tier ever reached by merging. Scales every recirculation channel.
    var deepestUnlockedTier: Int = 0
    /// Dog Tag → Kibble exchanges made since `lastExchangeResetDate`; drives the escalating ladder.
    var dogTagExchangesToday: Int = 0
    var lastExchangeResetDate: Date? = nil
    /// Daily-rotating Dog Tag store stock (3 slots, one purchase each).
    var dogTagStoreSlots: [DogTagStoreSlot] = []
    var lastDogTagStoreRotation: Date? = nil
    /// The 6 power-up slots. Persisted as of v27 — before that the array was
    /// rebuilt empty on every launch, silently discarding earned power-ups.
    /// Task 2.2 requires the rolled effect to survive save/load, which is only
    /// meaningful if its container does too.
    var powerUpInventory: [BoardItem?] = Array(repeating: nil, count: 6)

    /// Wall-clock time the snapshot was taken, used to advance timers for the
    /// span the app was closed. Optional so pre-existing saves still decode.
    var lastActiveDate: Date?

    // Live-ops primitives (v30, Phase 6a) — nothing writes to these yet; see
    // LiveOpsEngine.swift's TokenWallet / ProgressTrack.
    /// Named-currency balances, keyed by token ID.
    var eventTokenWallets: [String: Int] = [:]
    /// Per-track claimed-milestone state, keyed by track ID.
    var progressTracks: [String: TrackState] = [:]
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
    /// v21: limitless material accumulator — toolInventory replaced by materialCounts dict.
    /// v22: pity tracking — pityStates dict added (additive; empty default for old saves).
    /// v23: pityStates type changed [String:Int]→[String:PityState]; sub-object chains registered.
    /// v25: AdoptionOrder's rewardDogTags/rewardCoins/rewardCardPack collapse into
    ///      rewards: [OrderReward] (Phase 1, Task 1.1); OrderRewardRegistry rider hook (Task 1.2).
    /// v26: commerce: PlayerCommerceState added (Phase 1, Task 1.4) — purchase history
    ///      and kibble-wall events, for Phase 3 offer targeting/gating. Additive.
    /// v27: economy correction (Phase 2). BoardItem gains an optional `rarity` carrying
    ///      the effect rolled onto a completed sub-object; GameState gains
    ///      deepestUnlockedTier, the Dog Tag ladder's daily counters, and the Dog Tag
    ///      store's stock. Existing top-tier sub-objects are assigned Speed Burst
    ///      rather than re-rolled, so nobody is retroactively handed a rare effect.
    /// v28: animal chains shrink 15 tiers → 12 (Phase 2b). Every stored animal tier
    ///      is remapped: 0–8 unchanged, 9–11 collapse to 8, 12–14 shift to 9–11.
    ///      Applied at the shared migration exit rather than only in the v27 step,
    ///      because the dispatch table is flat — see `finishMigration(_:from:)`.
    /// v29: order roles split (Phase 5, Task 5.2). `AdoptionOrder.timeRemaining` is
    ///      gone — the persistent slots no longer expire. A single separate urgent
    ///      order (urgentOrder / urgentOrderTimeRemaining / urgentOrderCooldownRemaining)
    ///      now carries the short fuse. Structural: the old per-order key is
    ///      removed, not just superseded.
    /// v30: live-ops primitives (Phase 6a). GameState gains eventTokenWallets
    ///      (token ID -> balance) and progressTracks (track ID -> TrackState).
    ///      Purely additive; nothing writes to either yet.
    static let currentVersion = 30

    /// Minimal "envelope" used to read just the version before committing to a
    /// full decode. This is the seam where future v1→v2 migrations will branch.
    private struct SaveEnvelope: Codable { var version: Int }

    private static let cloudKey = "pawSanctuary.gameState"

    /// Set when the most recent `load()` had to discard a save from schema v1–v7 —
    /// versions that predate every migration path below and can't be recovered.
    /// `nil` after a `load()` that found a usable state (local, backup, or cloud) even
    /// if an old-format copy was encountered along the way. Callers check this right
    /// after a `nil` result from `load()` to tell the difference between "no save ever
    /// existed" and "a save existed but couldn't be restored" (QA-08) — surfacing that
    /// distinction to the player is the caller's responsibility.
    /// nonisolated(unsafe): GameStore's static methods are only ever called from the
    /// MainActor-isolated ViewModel, matching the pattern used elsewhere in this codebase
    /// (see MergeBoardViewModel.regenTimer) for state that's single-threaded in practice.
    private(set) nonisolated(unsafe) static var discardedIncompatibleVersion: Int? = nil

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
    /// State is captured on the caller's actor; encoding and disk I/O run on a utility thread.
    static func save(_ state: GameState) {
        Task.detached(priority: .utility) {
            guard let data = encode(state) else { return }
            writeLocal(data)
        }
    }

    /// Local save **plus** an iCloud push. Call at meaningful moments (e.g. when the
    /// app backgrounds) so another device gets the latest state, without paying for
    /// cloud writes every single second.
    static func saveAndSync(_ state: GameState) {
        Task.detached(priority: .utility) {
            guard let data = encode(state) else { return }
            writeLocal(data)
            writeCloud(data)
        }
    }

    /// Synchronous save for moments that cannot tolerate deferral — principally
    /// app backgrounding, where a detached task may never be scheduled before
    /// iOS suspends the process. Routine periodic saves should keep using
    /// `save()` / `saveAndSync()`, which stay off the main thread (PERF-01).
    static func saveNow(_ state: GameState) {
        guard let data = encode(state) else { return }
        writeLocal(data)
        writeBackup(data)
        if isCloudAvailable { writeCloud(data) }
    }

    /// Loads the best available state: reconciles the local file and the iCloud copy
    /// (most-recently-active wins) and recovers from the backup slot if the main file
    /// is missing or unreadable. Returns `nil` only when no usable save exists.
    static func load() -> GameState? {
        discardedIncompatibleVersion = nil
        let localState = readValid(try? Data(contentsOf: mainFileURL)) ?? recoverFromBackup()
        let cloudState = isCloudAvailable
            ? readValid(NSUbiquitousKeyValueStore.default.data(forKey: cloudKey))
            : nil

        guard let chosen = mostRecent(localState, cloudState) else { return nil }

        // A usable state was found (local, backup, or cloud) — any old-format copy
        // encountered along the way was superseded, not lost.
        discardedIncompatibleVersion = nil

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
        if version == 8 { return migrateByInjecting(from: 8, defaults: ["spawnMultiplier": 1,
                                                                 "cardInventory": [:],
                                                                 "starCount": 0,
                                                                 "completedAlbumIDs": [],
                                                                 "pendingCardPacks": [],
                                                                 "jokerCards": 0,
                                                                 "rareJokerCards": 0], into: data) }
        if version == 9 { return migrateByInjecting(from: 9, defaults: ["cardInventory": [:],
                                                                "starCount": 0,
                                                                "completedAlbumIDs": [],
                                                                "pendingCardPacks": [],
                                                                "jokerCards": 0,
                                                                "rareJokerCards": 0,
                                                                "pendingOutgoingTrades": [],
                                                                "pendingIncomingTrades": [],
                                                                "cardsSentToday": 0], into: data) }
        if version == 10 { return migrateByInjecting(from: 10, defaults: ["pendingOutgoingTrades": [],
                                                                 "pendingIncomingTrades": [],
                                                                 "cardsSentToday": 0], into: data) }
        if version == 11 { return migrateByInjecting(from: 11, defaults: ["adsWatchedToday": 0], into: data) }
        if version == 12 { return migrateByInjecting(from: 12, defaults: ["purchasedBoardRows": 0], into: data) }
        if version == 13 { return migrateByInjecting(from: 13, defaults: [:], into: data) }   // passLastClaimDate optional — no default needed
        if version == 14 { return migrateByInjecting(from: 14, defaults: ["loyaltyClubDayIndex": 0,
                                                                  "loyaltyClubStreak": 0], into: data) }
        if version == 15 { return migrateByInjecting(from: 15, defaults: ["eventProgress": ["eventId": "", "coinsEarned": 0, "claimedMilestones": []]], into: data) }
        if version == 16 { return migrateByInjecting(from: 16, defaults: ["inviteProgress": ["invitesSent": 0, "claimedMilestones": []]], into: data) }
        if version == 17 { return migrateV17toV18(data) }
        if version == 18 { return migrateByInjecting(from: 18, defaults: ["ambassadorQuestProgress": 0], into: data) }
        if version == 19 { return migrateByInjecting(from: 19, defaults: ["pendingMaterialLots": []], into: data) }
        if version == 20 { return migrateV20toV21(data) }
        if version == 21 { return migrateV21toV22(data) }
        if version == 22 { return migrateV22toV23(data) }
        if version == 23 { return migrateV23toV24(data) }
        if version == 24 { return migrateV24toV25(data) }
        if version == 25 { return migrateV25toV26(data) }
        if version == 26 { return migrateV26toV27(data) }
        if version == 27 { return migrateV27toV28(data) }
        if version == 28 { return migrateV28toV29(data) }
        if version == 29 { return migrateByInjecting(from: 29, defaults: [:], into: data) }   // eventTokenWallets/progressTracks covered by additiveDefaultsSinceV8
        if version >= 1 && version < 8 {
            // Pre-Phase-0 saves — predate the generalized chain model entirely, so there's
            // no sensible migration path. Record why, rather than discarding silently (QA-08).
            print("[GameStore] discarding save from schema v\(version) — predates all migration paths (earliest supported migration starts at v8)")
            discardedIncompatibleVersion = version
            return nil
        }
        guard version == currentVersion else { return nil }
        do { return try JSONDecoder().decode(GameState.self, from: data) }
        catch { assertionFailure("GameStore: decode v\(version) failed — \(error)"); return nil }
    }

    /// Injects missing keys with default values, stamps the current version, and re-decodes.
    /// Used for additive schema migrations (new nullable/defaultable fields only).
    private static func migrateByInjecting(from sourceVersion: Int,
                                           defaults: [String: Any],
                                           into data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        for (key, value) in defaults where json[key] == nil { json[key] = value }
        return finishMigration(&json, from: sourceVersion)
    }

    /// Every field added since v8 that is **not** Optional, with the value a save
    /// predating it should get.
    ///
    /// This exists because the migration table is flat, not chained: a v19 save
    /// dispatches to exactly one function that jumps straight to `currentVersion`,
    /// so it never passes through the v20…v26 steps that would have added their
    /// fields. Swift's synthesized `Decodable` does **not** fall back to a
    /// property's default value for a missing key — it throws `keyNotFound` — so
    /// any non-Optional field not listed here makes older saves undecodable and
    /// silently discarded. (That is why `commerce` had to be added: a genuine v24
    /// save could not load without it.)
    ///
    /// Optional stored properties need no entry — `decodeIfPresent` already
    /// yields nil for them.
    private static var additiveDefaultsSinceV8: [String: Any] { [
        // v10 — card packs
        "cardInventory": [String: Int](), "starCount": 0, "completedAlbumIDs": [String](),
        "pendingCardPacks": [String](), "jokerCards": 0, "rareJokerCards": 0,
        // v11 — card trading
        "pendingOutgoingTrades": [Any](), "pendingIncomingTrades": [Any](), "cardsSentToday": 0,
        // v12–v13
        "adsWatchedToday": 0, "purchasedBoardRows": 0,
        // v15 — loyalty club
        "loyaltyClubDayIndex": 0, "loyaltyClubStreak": 0,
        // v16–v17
        "eventProgress": ["eventId": "", "coinsEarned": 0, "claimedMilestones": [String]()],
        "inviteProgress": ["invitesSent": 0, "claimedMilestones": [String]()],
        // v19–v22
        "ambassadorQuestProgress": 0, "pendingMaterialLots": [Any](),
        "materialCounts": [String: [Int]](), "pityStates": [String: Any](),
        // v24 — superpowers
        "unlockedSuperpowerSpecies": [String](), "superpowerCooldownEnds": [String: Double](),
        "lagomorphMergeCount": 0, "lastMergeTimestamp": 0.0, "equineSprintRemaining": 0.0,
        "pouchItems": [NSNull(), NSNull()], "pouchExpiryTimestamp": 0.0,
        // v26 — commerce
        "commerce": ["purchaseCount": 0, "totalSpendMicros": 0,
                     "wallEventsTotal": 0, "hasReachedFirstWall": false],
        // v27 — economy correction
        "deepestUnlockedTier": 0, "dogTagExchangesToday": 0,
        "dogTagStoreSlots": [Any](),
        "powerUpInventory": [NSNull(), NSNull(), NSNull(), NSNull(), NSNull(), NSNull()],
        // v29 — urgent order timer/cooldown (Phase 5, Task 5.2). `urgentOrder`
        // itself is Optional and needs no entry here.
        "urgentOrderTimeRemaining": 0.0, "urgentOrderCooldownRemaining": 0.0,
        // v30 — live-ops primitives (Phase 6a): token wallet + progress track state.
        "eventTokenWallets": [String: Int](), "progressTracks": [String: Any](),
    ] }

    /// Fills in every post-v8 default the blob is missing, applies any tier-space
    /// remap the source version predates, stamps the version, decodes.
    /// The single exit point shared by all migration paths.
    ///
    /// `sourceVersion` matters because the dispatch table is flat: a v19 save jumps
    /// straight here without passing through v20…v27. The 15→12 tier remap therefore
    /// cannot live only in `migrateV27toV28` — every path from a pre-v28 save has to
    /// apply it, exactly once, or those saves arrive at v28 still holding 15-tier
    /// indices and silently point at the wrong animals.
    private static func finishMigration(_ json: inout [String: Any],
                                        from sourceVersion: Int) -> GameState? {
        for (key, value) in additiveDefaultsSinceV8 where json[key] == nil { json[key] = value }
        if sourceVersion < 28 { remapAnimalTiersForTwelveTierChains(&json) }
        json["version"] = currentVersion
        guard let patched = try? JSONSerialization.data(withJSONObject: json) else { return nil }
        do { return try JSONDecoder().decode(GameState.self, from: patched) }
        catch { assertionFailure("GameStore: migration decode failed — \(error)"); return nil }
    }

    // MARK: v27 → v28 — 15-tier animal chains become 12-tier

    /// v27 → v28: purely a tier-space remap, and the remap itself runs for every
    /// pre-v28 source version inside `finishMigration`. Nothing else to do here.
    private static func migrateV27toV28(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return finishMigration(&json, from: 27)
    }

    /// v28 → v29: order roles split (Phase 5, Task 5.2). Every persistent order's
    /// `timeRemaining` key is dropped — it's no longer a field on `AdoptionOrder`
    /// (structural, so removed rather than left to linger as unused JSON, matching
    /// the v24→v25 precedent). The new urgent-order fields are purely additive and
    /// come from `additiveDefaultsSinceV8` via `finishMigration`: old saves start
    /// with `urgentOrder == nil` and `urgentOrderCooldownRemaining == 0`, which
    /// `AdoptionBoard.ensureUrgentOrder` reads as "spawn one now."
    private static func migrateV28toV29(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        if var orders = json["adoptionOrders"] as? [[String: Any]] {
            for i in orders.indices { orders[i].removeValue(forKey: "timeRemaining") }
            json["adoptionOrders"] = orders
        }
        return finishMigration(&json, from: 28)
    }

    /// Maps a stored animal tier from the old 15-tier space into the new 12-tier one.
    ///
    ///     old 0–8   → 0–8   (Eras 1–3, unchanged)
    ///     old 9–11  → 8     (the dropped Era 4 collapses onto the last surviving tier)
    ///     old 12–14 → 9–11  (Era 5 shifts down by three)
    ///
    /// Collapsing 9–11 downward is a demotion, chosen because mapping them upward
    /// would collide with the shifted 12–14 range. Pre-launch this only affects
    /// development saves.
    static func remappedAnimalTier(_ old: Int) -> Int {
        if old <= 8  { return max(0, old) }
        if old <= 11 { return 8 }
        return min(11, old - 3)
    }

    /// Rewrites every animal tier stored anywhere in a save. Sub-object, material
    /// and tool chains have their own tier spaces and are deliberately untouched.
    private static func remapAnimalTiersForTwelveTierChains(_ json: inout [String: Any]) {

        /// A BoardItem dict, remapped in place if it belongs to an animal chain.
        func remapItem(_ item: inout [String: Any]) {
            guard let chainID = item["chainID"] as? String,
                  chainID.hasPrefix("animal."),
                  let tier = item["tier"] as? Int else { return }
            item["tier"] = remappedAnimalTier(tier)
        }

        /// A flat `[BoardItem?]`-shaped array (inventory, power-up slots, pouch).
        func remapItemArray(_ key: String) {
            guard var array = json[key] as? [Any] else { return }
            for i in array.indices {
                guard var item = array[i] as? [String: Any] else { continue }
                remapItem(&item)
                array[i] = item
            }
            json[key] = array
        }

        // ── Board ────────────────────────────────────────────────
        if var board = json["board"] as? [[[String: Any]]] {
            for r in board.indices {
                for c in board[r].indices {
                    guard var item = board[r][c]["item"] as? [String: Any] else { continue }
                    remapItem(&item)
                    board[r][c]["item"] = item
                }
            }
            json["board"] = board
        }

        // ── Item-bearing arrays ──────────────────────────────────
        remapItemArray("inventory")
        remapItemArray("powerUpInventory")   // v27
        remapItemArray("pouchItems")         // v24 — Marsupials Pouch can hold animals

        // ── Pending material lots ([[BoardItem]]) ────────────────
        // Materials have their own tier space, but the lots are typed as BoardItem
        // and remapItem is chain-gated, so this is safe and future-proof.
        if var lots = json["pendingMaterialLots"] as? [[[String: Any]]] {
            for l in lots.indices {
                for i in lots[l].indices { remapItem(&lots[l][i]) }
            }
            json["pendingMaterialLots"] = lots
        }

        // ── Adoption orders: what's wanted, and what's paid out ──
        if var orders = json["adoptionOrders"] as? [[String: Any]] {
            for i in orders.indices {
                if let chainID = orders[i]["wantedChainID"] as? String,
                   chainID.hasPrefix("animal."),
                   let tier = orders[i]["wantedTier"] as? Int {
                    orders[i]["wantedTier"] = remappedAnimalTier(tier)
                }
                // Phase 2 board-item rewards carry payloadID/payloadTier.
                if var rewards = orders[i]["rewards"] as? [[String: Any]] {
                    for r in rewards.indices {
                        guard let payloadID = rewards[r]["payloadID"] as? String,
                              payloadID.hasPrefix("animal."),
                              let tier = rewards[r]["payloadTier"] as? Int else { continue }
                        rewards[r]["payloadTier"] = remappedAnimalTier(tier)
                    }
                    orders[i]["rewards"] = rewards
                }
            }
            json["adoptionOrders"] = orders
        }

        // ── Quest / daily-challenge goals ────────────────────────
        // QuestGoal.reachTier encodes as {"reachTier": {"_0": "animal", "tier": N, "count": C}}
        func remapGoals(_ key: String) {
            guard var quests = json[key] as? [Any] else { return }
            for i in quests.indices {
                guard var quest = quests[i] as? [String: Any],
                      var goal  = quest["goal"] as? [String: Any],
                      var reach = goal["reachTier"] as? [String: Any],
                      (reach["_0"] as? String) == "animal",
                      let tier  = reach["tier"] as? Int else { continue }
                reach["tier"] = remappedAnimalTier(tier)
                goal["reachTier"] = reach
                quest["goal"] = goal
                quests[i] = quest
            }
            json[key] = quests
        }
        remapGoals("activeQuests")
        remapGoals("dailyChallenges")

        // ── Dog Tag store stock (v27) ────────────────────────────
        if var slots = json["dogTagStoreSlots"] as? [[String: Any]] {
            for i in slots.indices {
                guard let chainID = slots[i]["chainID"] as? String,
                      chainID.hasPrefix("animal."),
                      let tier = slots[i]["tier"] as? Int else { continue }
                slots[i]["tier"] = remappedAnimalTier(tier)
            }
            json["dogTagStoreSlots"] = slots
        }

        // ── Scalars carrying an animal tier ──────────────────────
        if let deepest = json["deepestUnlockedTier"] as? Int {
            json["deepestUnlockedTier"] = remappedAnimalTier(deepest)
        }
        // commerce.lastWallTier records which tier the player was blocked on (v26).
        if var commerce = json["commerce"] as? [String: Any],
           let tier = commerce["lastWallTier"] as? Int {
            commerce["lastWallTier"] = remappedAnimalTier(tier)
            json["commerce"] = commerce
        }
    }

    /// v26 → v27: economy correction (Phase 2).
    ///
    /// `BoardItem` gains an optional `rarity` naming the effect a completed
    /// sub-object carries. Saved top-tier sub-objects predate the roll, so they are
    /// assigned `.speed` — the most common outcome — rather than re-rolled, which
    /// would retroactively hand some players a rare effect they never earned.
    ///
    /// `deepestUnlockedTier` seeds from the deepest animal tier actually present in
    /// the save, so existing players don't start recirculation from zero.
    private static func migrateV26toV27(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var deepestSeen = 0

        /// Stamps Speed Burst onto a completed sub-object and tracks the deepest animal tier.
        func patch(_ item: inout [String: Any]) {
            guard let chainID = item["chainID"] as? String,
                  let tier = item["tier"] as? Int else { return }
            if chainID.hasPrefix("animal.") {
                deepestSeen = max(deepestSeen, tier)
            } else if chainID.hasPrefix("subobject."),
                      tier >= subObjectTopTier,
                      item["rarity"] == nil {
                item["rarity"] = SubObjectRarity.speed.rawValue
            }
        }

        if var board = json["board"] as? [[[String: Any]]] {
            for r in board.indices {
                for c in board[r].indices {
                    guard var item = board[r][c]["item"] as? [String: Any] else { continue }
                    patch(&item)
                    board[r][c]["item"] = item
                }
            }
            json["board"] = board
        }

        if var inventory = json["inventory"] as? [Any] {
            for i in inventory.indices {
                guard var item = inventory[i] as? [String: Any] else { continue }
                patch(&item)
                inventory[i] = item
            }
            json["inventory"] = inventory
        }

        json["deepestUnlockedTier"] = deepestSeen
        return finishMigration(&json, from: 26)
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

        return finishMigration(&json, from: 17)
    }

    /// v20 → v21: replace slot-based toolInventory with materialCounts accumulator.
    /// Salvages any .material BoardItems from the old toolInventory into per-tier counts.
    /// Board-level material items and pending toolbox lots are cleared.
    private static func migrateV20toV21(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        // Build materialCounts from any .material items in the old toolInventory.
        var wood   = Array(repeating: 0, count: 6)
        var metal  = Array(repeating: 0, count: 6)
        var cement = Array(repeating: 0, count: 6)

        if let old = json["toolInventory"] as? [Any] {
            for entry in old {
                guard let item = entry as? [String: Any],
                      let chainID = item["chainID"] as? String,
                      let tier = item["tier"] as? Int,
                      tier >= 0 && tier <= 5 else { continue }
                switch chainID {
                case ContentRegistry.woodChainID:   wood[tier]   += 1
                case ContentRegistry.metalChainID:  metal[tier]  += 1
                case ContentRegistry.cementChainID: cement[tier] += 1
                default: break
                }
            }
        }

        // Cascade each chain so tier-5 counts reflect completed materials.
        func cascade(_ counts: inout [Int]) {
            for t in 0..<5 { while counts[t] >= 2 { counts[t] -= 2; counts[t+1] += 1 } }
        }
        cascade(&wood); cascade(&metal); cascade(&cement)

        json["materialCounts"] = [
            ContentRegistry.woodChainID:   wood,
            ContentRegistry.metalChainID:  metal,
            ContentRegistry.cementChainID: cement
        ]
        json.removeValue(forKey: "toolInventory")
        json["pendingMaterialLots"] = []          // clear mid-session queued lots

        return finishMigration(&json, from: 20)
    }

    /// v21 → v22: additive migration — injects an empty pityStates dict so the field
    /// decodes cleanly on saves that predate the 15-tier chain expansion.
    private static func migrateV21toV22(_ data: Data) -> GameState? {
        return migrateByInjecting(from: 21, defaults: ["pityStates": [:]], into: data)
    }

    /// v22 → v23: pityStates type changed from [String:Int] to [String:PityState].
    /// Any saved Int-valued pity counters are discarded; the field resets to [:].
    /// (In practice pityStates was always empty in v22 — pity logic was not yet wired.)
    private static func migrateV22toV23(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        // Overwrite (or inject) pityStates with an empty dict safe for [String: PityState].
        json["pityStates"] = [String: Any]()
        return finishMigration(&json, from: 22)
    }

    /// v23 → v24: adds all Superpower System fields (purely additive — all have Swift defaults).
    private static func migrateV23toV24(_ data: Data) -> GameState? {
        return migrateByInjecting(from: 23, defaults: [
            "unlockedSuperpowerSpecies": [String](),
            "superpowerCooldownEnds":    [String: Double](),
            "lagomorphMergeCount":       0,
            "lastMergeTimestamp":        0.0,
            "lastMergedSpeciesRaw":      NSNull(),
            "equineSprintRemaining":     0.0,
            "pouchItems":               [NSNull(), NSNull()],
            "pouchExpiryTimestamp":      0.0,
        ], into: data)
    }

    /// v24 → v25: AdoptionOrder's three fixed reward fields (rewardDogTags,
    /// rewardCoins, rewardCardPack) collapse into a single `rewards: [OrderReward]`
    /// list (Phase 1, Task 1.1). Structural, not additive — the old keys are removed
    /// so the field doesn't linger as unused JSON.
    ///
    /// `commerce` (Phase 1, Task 1.4) is a separate persisted addition landing in a
    /// later v25→v26 migration — not touched here.
    private static func migrateV24toV25(_ data: Data) -> GameState? {
        guard var json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        if var orders = json["adoptionOrders"] as? [[String: Any]] {
            for i in orders.indices {
                var rewards: [[String: Any]] = []
                if let tags = orders[i]["rewardDogTags"] as? Int, tags > 0 {
                    rewards.append(["kind": "dogTags", "amount": tags])
                }
                if let coins = orders[i]["rewardCoins"] as? Int, coins > 0 {
                    rewards.append(["kind": "coins", "amount": coins])
                }
                // CardPackType is a String-rawValue enum with no custom encode(to:),
                // so it encodes as a plain JSON string — verified against a real v24
                // save (rewardCardPack: "star1"), not just the struct definition.
                if let pack = orders[i]["rewardCardPack"] as? String {
                    rewards.append(["kind": "cardPack", "amount": 1, "payloadID": pack])
                }
                orders[i]["rewards"] = rewards
                orders[i].removeValue(forKey: "rewardDogTags")
                orders[i].removeValue(forKey: "rewardCoins")
                orders[i].removeValue(forKey: "rewardCardPack")
            }
            json["adoptionOrders"] = orders
        }

        return finishMigration(&json, from: 24)
    }

    /// v25 → v26: adds `commerce: PlayerCommerceState` (purely additive — every field
    /// has a Swift default; only the four non-Optional fields need explicit JSON values,
    /// since synthesized Decodable already treats Optional stored properties as absent-ok).
    private static func migrateV25toV26(_ data: Data) -> GameState? {
        return migrateByInjecting(from: 25, defaults: [
            "commerce": ["purchaseCount": 0, "totalSpendMicros": 0,
                         "wallEventsTotal": 0, "hasReachedFirstWall": false],
        ], into: data)
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
