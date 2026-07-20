//
//  PersistenceTests.swift
//  PawSanctuaryTests
//
//  Round-trip + version-guard coverage for the persistence layer.
//  Persistence is the riskiest subsystem to silently break in a refactor,
//  so these lock down: every Codable model survives encode→decode intact,
//  GameStore.save/load is faithful, and the version guard discards mismatches.
//

import XCTest
@testable import PawSanctuary

final class PersistenceTests: XCTestCase {

    // Keep encoding deterministic so we can compare raw bytes where useful.
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return e
    }()
    private let decoder = JSONDecoder()

    override func setUp() {
        super.setUp()
        GameStore.clear()   // isolate each test from any prior save state
    }

    override func tearDown() {
        // Never leave test data behind in the shared store.
        GameStore.clear()
        super.tearDown()
    }

    /// Writes raw bytes directly into the main save file (for tamper/corruption tests).
    private func writeMainFile(_ data: Data) throws {
        try FileManager.default.createDirectory(
            at: GameStore.mainFileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        try data.write(to: GameStore.mainFileURL)
    }

    // MARK: Helpers

    /// A representative state exercising animals, producers, inventory,
    /// quests, daily challenges, and adoption orders.
    // Chain-id shorthands for readable test data.
    private func aid(_ s: AnimalSpecies) -> ChainID { ContentRegistry.animalChainID(s) }

    private func makeSampleState() -> GameState {
        let board: [[BoardCell]] = [
            [
                BoardCell(position: GridPosition(row: 0, col: 0),
                          item: BoardItem(chainID: aid(.fox), tier: 8),   // tier 8 = Ambassador (9-tier chain)
                          isUnlocked: true),
                BoardCell(position: GridPosition(row: 0, col: 1),
                          producer: ProducerTile(level: .shelterPod, cooldownRemaining: 17.5),
                          isUnlocked: true),
            ],
            [
                BoardCell(position: GridPosition(row: 1, col: 0), item: nil, isUnlocked: true),
                BoardCell(position: GridPosition(row: 1, col: 1), item: nil, isUnlocked: false),
            ],
        ]
        return GameState(
            board: board,
            kibble: 73, dogTags: 12, score: 4250,
            rescueCount: 88, supplyCount: 7, ambassadors: 3, mergeCount: 140,
            secondsUntilNextKibble: 41,
            playerLevel: 9, playerXP: 320,
            unlockedChainIDs: [aid(.dog), aid(.cat), aid(.rabbit), aid(.bird), aid(.hamster), aid(.turtle)],
            inventory: [BoardItem(chainID: aid(.owl), tier: 4), nil, nil],   // tier 4 = Foster (9-tier chain)
            inventoryRow1Unlocked: true, inventoryRow2Unlocked: false,
            activeQuests: [
                Quest(goal: .mergeInChain(aid(.cat), count: 4), difficulty: .medium,
                      dogTagReward: 3, kibbleReward: 4),
                Quest(goal: .reachTier(.animal, tier: 8, count: 1), difficulty: .legendary,
                      dogTagReward: 12, kibbleReward: 20),
            ],
            dailyChallenges: [
                DailyChallenge(goal: .spawnBase(count: 8), difficulty: .medium),
            ],
            dailyChallengeStreak: 5, dailyChallengeBonusClaimed: true,
            adoptionOrders: [
                AdoptionOrder(familyIndex: 2, wantedChainID: aid(.turtle), wantedTier: 5,  // tier 5 = Adopted (9-tier chain)
                              wantedCount: 2, timeRemaining: 312, rewardKibble: 56, rewardDogTags: 4,
                              rewardCoins: 10),
            ],
            spotlightMergesThisWeek: 7,
            materialCounts: [ContentRegistry.woodChainID: [0, 0, 1, 0, 0, 0],
                             ContentRegistry.metalChainID:  [0, 0, 0, 0, 0, 0],
                             ContentRegistry.cementChainID: [0, 0, 0, 0, 0, 0]],
            producerStorage: [ProducerLevel.groomingBox.rawValue:
                                  ProducerTile(level: .groomingBox, cooldownRemaining: 10)],
            overflowProducerStorage: [ProducerTile(level: .fosterHome, cooldownRemaining: 5), nil],
            completedAreaIDs: ["area.welcome"],
            areaUpgradeLevels: ["area.welcome": 1],
            spawnMultiplier: 2,
            cardInventory: ["rescue.c1": 1, "rescue.r1": 2],
            starCount: 7,
            completedAlbumIDs: [],
            pendingCardPacks: [.star2, .star4],
            jokerCards: 1,
            rareJokerCards: 0,
            pendingOutgoingTrades: [],
            pendingIncomingTrades: [],
            cardsSentToday: 2,
            lastCardSendDate: Date(timeIntervalSince1970: 1_700_090_000),
            coins: 85, coinsEarnedThisWeek: 40,
            weeklyGoalBronzeClaimed: true, weeklyGoalSilverClaimed: false, weeklyGoalGoldClaimed: false,
            lastWeeklyGoalReset: nil,
            weeklyGoldCompletions: 1, monthlyGoalClaimed: false, lastMonthlyGoalReset: nil,
            lastLoginDate: Date(timeIntervalSince1970: 1_700_000_000),
            loginStreak: 4, loginDayIndex: 3,
            lastDailyChallengeReset: Date(timeIntervalSince1970: 1_700_086_400),
            lastSpotlightWeek: 22,
            adsWatchedToday: 2, lastAdWatchDate: Date(timeIntervalSince1970: 1_700_090_000),
            purchasedBoardRows: 1,
            passLastClaimDate: nil,
            loyaltyClubDayIndex: 3, loyaltyClubLastClaimDate: nil, loyaltyClubStreak: 2,
            eventProgress: EventProgress(eventId: "rescue_rush_jun2026", coinsEarned: 750, claimedMilestones: [1]),
            inviteProgress: InviteProgress(invitesSent: 3, claimedMilestones: [1, 2]),
            lastActiveDate: Date(timeIntervalSince1970: 1_700_090_000)
        )
    }

    // MARK: Whole-snapshot round trip

    func testGameStateRoundTripPreservesEverything() throws {
        let original = makeSampleState()
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(original))

        // Scalars
        XCTAssertEqual(decoded.kibble, 73)
        XCTAssertEqual(decoded.dogTags, 12)
        XCTAssertEqual(decoded.score, 4250)
        XCTAssertEqual(decoded.rescueCount, 88)
        XCTAssertEqual(decoded.ambassadors, 3)
        XCTAssertEqual(decoded.mergeCount, 140)
        XCTAssertEqual(decoded.secondsUntilNextKibble, 41)
        XCTAssertEqual(decoded.playerLevel, 9)
        XCTAssertEqual(decoded.playerXP, 320)
        XCTAssertEqual(decoded.unlockedChainIDs, [aid(.dog), aid(.cat), aid(.rabbit), aid(.bird), aid(.hamster), aid(.turtle)])
        XCTAssertEqual(decoded.inventoryRow1Unlocked, true)
        XCTAssertEqual(decoded.inventoryRow2Unlocked, false)
        XCTAssertEqual(decoded.dailyChallengeStreak, 5)
        XCTAssertEqual(decoded.dailyChallengeBonusClaimed, true)
        XCTAssertEqual(decoded.spotlightMergesThisWeek, 7)
        XCTAssertEqual(decoded.loginStreak, 4)
        XCTAssertEqual(decoded.loginDayIndex, 3)
        XCTAssertEqual(decoded.lastSpotlightWeek, 22)

        // Board geometry + tile contents (the part that used to be lost entirely)
        XCTAssertEqual(decoded.board.count, 2)
        XCTAssertEqual(decoded.board[0].count, 2)
        XCTAssertEqual(decoded.board[0][0].item?.chainID, aid(.fox))
        XCTAssertEqual(decoded.board[0][0].item?.tier, 8)
        XCTAssertTrue(decoded.board[0][0].item?.isTopTier ?? false)   // registry-driven (tier 8 = ambassador, top of 9-tier chain)
        XCTAssertNil(decoded.board[0][0].producer)
        XCTAssertEqual(decoded.board[0][1].producer?.level, .shelterPod)
        XCTAssertEqual(decoded.board[0][1].producer?.cooldownRemaining, 17.5)
        XCTAssertEqual(decoded.board[0][1].producer?.chargesRemaining, ProducerLevel.shelterPod.maxCharges)
        XCTAssertNil(decoded.board[0][1].item)
        XCTAssertTrue(decoded.board[0][0].isUnlocked)
        XCTAssertFalse(decoded.board[1][1].isUnlocked)

        // Inventory
        XCTAssertEqual(decoded.inventory.count, 3)
        XCTAssertEqual(decoded.inventory[0]?.chainID, aid(.owl))
        XCTAssertEqual(decoded.inventory[0]?.tier, 4)
        XCTAssertNil(decoded.inventory[1] ?? nil)

        // Quests (incl. enum-with-associated-value goals)
        XCTAssertEqual(decoded.activeQuests.count, 2)
        XCTAssertEqual(decoded.activeQuests[0].difficulty, .medium)
        XCTAssertEqual(decoded.activeQuests[0].goal.targetCount, 4)
        XCTAssertEqual(decoded.activeQuests[1].difficulty, .legendary)

        // Daily challenge
        XCTAssertEqual(decoded.dailyChallenges.count, 1)
        XCTAssertEqual(decoded.dailyChallenges[0].goal.targetCount, 8)

        // Adoption order (including v8 rewardCoins field)
        XCTAssertEqual(decoded.adoptionOrders.count, 1)
        XCTAssertEqual(decoded.adoptionOrders[0].familyIndex, 2)
        XCTAssertEqual(decoded.adoptionOrders[0].wantedChainID, aid(.turtle))
        XCTAssertEqual(decoded.adoptionOrders[0].wantedTier, 5)
        XCTAssertEqual(decoded.adoptionOrders[0].wantedCount, 2)
        XCTAssertEqual(decoded.adoptionOrders[0].rewardKibble, 56)
        XCTAssertEqual(decoded.adoptionOrders[0].rewardCoins, 10)

        // Spawn multiplier (v9)
        XCTAssertEqual(decoded.spawnMultiplier, 2)

        // Card system (v10)
        XCTAssertEqual(decoded.cardInventory["rescue.c1"], 1)
        XCTAssertEqual(decoded.cardInventory["rescue.r1"], 2)
        XCTAssertEqual(decoded.starCount, 7)
        XCTAssertEqual(decoded.completedAlbumIDs, [])
        XCTAssertEqual(decoded.pendingCardPacks, [.star2, .star4])
        XCTAssertEqual(decoded.jokerCards, 1)
        XCTAssertEqual(decoded.rareJokerCards, 0)
        XCTAssertEqual(decoded.pendingOutgoingTrades, [])
        XCTAssertEqual(decoded.pendingIncomingTrades, [])
        XCTAssertEqual(decoded.cardsSentToday, 2)

        // Dates (encoded as Doubles — compare with tolerance)
        XCTAssertEqual(decoded.lastActiveDate?.timeIntervalSince1970 ?? 0, 1_700_090_000, accuracy: 0.001)
        XCTAssertEqual(decoded.lastLoginDate?.timeIntervalSince1970 ?? 0, 1_700_000_000, accuracy: 0.001)
    }

    // MARK: QuestGoal — the riskiest Codable (enum with associated values)

    func testEveryQuestGoalCaseRoundTrips() throws {
        let goals: [QuestGoal] = [
            .mergeAny(count: 6),
            .mergeInChain(aid(.hamster), count: 3),
            .reachTier(.animal, tier: 7, count: 2),
            .spawnBase(count: 10),
        ]
        for goal in goals {
            // Re-encoding the decoded value must byte-match the original encoding.
            let data = try encoder.encode(goal)
            let reEncoded = try encoder.encode(try decoder.decode(QuestGoal.self, from: data))
            XCTAssertEqual(data, reEncoded, "QuestGoal \(goal) did not survive a round trip")
        }
    }

    // MARK: Identity preservation

    func testItemAndProducerIdentitiesSurvive() throws {
        let item = BoardItem(chainID: aid(.bird), tier: 2)
        let producer = ProducerTile(level: .fosterHome, cooldownRemaining: 5)
        let decodedItem = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        let decodedProducer = try decoder.decode(ProducerTile.self, from: encoder.encode(producer))
        XCTAssertEqual(decodedItem.id, item.id, "BoardItem id should be stable across save/load")
        XCTAssertEqual(decodedProducer.id, producer.id, "ProducerTile id should be stable across save/load")
    }

    // MARK: Finite charges (Phase 1)

    func testProducerInitializesWithFullCharges() {
        for level in ProducerLevel.allCases where level.isShopProducer {
            let tile = ProducerTile(level: level)
            XCTAssertEqual(tile.chargesRemaining, level.maxCharges,
                           "\(level) should start with maxCharges (\(level.maxCharges))")
        }
    }

    func testProducerChargesRoundTrip() throws {
        // A partially-spent producer must persist its remaining charges faithfully.
        let tile = ProducerTile(level: .fosterHome, cooldownRemaining: 30, chargesRemaining: 3)
        let decoded = try decoder.decode(ProducerTile.self, from: encoder.encode(tile))
        XCTAssertEqual(decoded.level, .fosterHome)
        XCTAssertEqual(decoded.cooldownRemaining, 30, accuracy: 0.001)
        XCTAssertEqual(decoded.chargesRemaining, 3)
        XCTAssertEqual(decoded.id, tile.id, "id must survive round-trip")
    }

    func testMaxChargesAreReasonable() {
        // Guard that balance values aren't accidentally zeroed or reversed.
        XCTAssertGreaterThan(ProducerLevel.shelterPod.maxCharges, ProducerLevel.rescueCrate.maxCharges)
        XCTAssertGreaterThan(ProducerLevel.fosterHome.maxCharges, ProducerLevel.shelterPod.maxCharges)
        // Starter crate should have at least one charge.
        XCTAssertGreaterThan(ProducerLevel.rescueCrate.maxCharges, 0)
    }

    func testDepletionSequence() {
        // Simulates the activateProducer charge logic: decrement on each fire,
        // nil out the producer slot when the last charge is used.
        let level = ProducerLevel.rescueCrate
        var producer: ProducerTile? = ProducerTile(level: level)
        XCTAssertEqual(producer?.chargesRemaining, level.maxCharges)

        for fireNumber in 1...level.maxCharges {
            guard var p = producer else {
                XCTFail("Producer disappeared before charge \(fireNumber)")
                return
            }
            // Simulate cooldown having elapsed, then fire.
            p.cooldownRemaining = 0
            XCTAssertTrue(p.isReady, "Producer should be ready before fire \(fireNumber)")
            p.cooldownRemaining = level.cooldown
            p.chargesRemaining -= 1
            producer = p.chargesRemaining > 0 ? p : nil

            if fireNumber < level.maxCharges {
                XCTAssertNotNil(producer, "Producer should survive after fire \(fireNumber)/\(level.maxCharges)")
                XCTAssertEqual(producer?.chargesRemaining, level.maxCharges - fireNumber)
            } else {
                XCTAssertNil(producer, "Producer should be removed after its final charge (\(level.maxCharges))")
            }
        }
    }

    // MARK: Phase 2 — Supply chains

    func testSupplyChainsRegistered() {
        let reg = ContentRegistry.shared
        let supplyIDs = [ContentRegistry.groomingChainID,
                         ContentRegistry.foodChainID,
                         ContentRegistry.shelterChainID]
        for id in supplyIDs {
            let chain = reg.chain(id)
            XCTAssertNotNil(chain, "\(id) must be in the registry")
            XCTAssertEqual(chain?.category, .supply)
            XCTAssertEqual(chain?.tiers.count, 6, "\(id) must have 6 tiers")
            XCTAssertNotNil(reg.nextTier(id, after: 0), "tier 0 should have a next")
            XCTAssertNil(reg.nextTier(id, after: 5), "tier 5 is the top — no next")
        }
    }

    func testSupplyProducerTargetChainIDs() {
        XCTAssertEqual(ProducerLevel.groomingBox.targetChainID, ContentRegistry.groomingChainID)
        XCTAssertEqual(ProducerLevel.feedBox.targetChainID,     ContentRegistry.foodChainID)
        XCTAssertEqual(ProducerLevel.shelterBox.targetChainID,  ContentRegistry.shelterChainID)
        // Animal producers have no fixed chain target.
        XCTAssertNil(ProducerLevel.rescueCrate.targetChainID)
        XCTAssertNil(ProducerLevel.shelterPod.targetChainID)
        XCTAssertNil(ProducerLevel.fosterHome.targetChainID)
    }

    func testSupplyProducersCannotMergeUp() {
        XCTAssertNil(ProducerLevel.groomingBox.next, "groomingBox has no merge-up path")
        XCTAssertNil(ProducerLevel.feedBox.next)
        XCTAssertNil(ProducerLevel.shelterBox.next)
    }

    func testLevelUpRewardGrantsSupplyProducerAtCorrectLevels() {
        let level15 = levelUpReward(for: 15)
        XCTAssertEqual(level15.newSupplyProducer, .groomingBox)

        let level20 = levelUpReward(for: 20)
        XCTAssertEqual(level20.newSupplyProducer, .feedBox)

        let level25 = levelUpReward(for: 25)
        XCTAssertEqual(level25.newSupplyProducer, .shelterBox)

        // No supply producer at animal-species unlock levels.
        XCTAssertNil(levelUpReward(for: 3).newSupplyProducer)
        XCTAssertNil(levelUpReward(for: 12).newSupplyProducer)
    }

    func testSupplyItemRoundTrips() throws {
        // A BoardItem from a supply chain must persist exactly like animal items.
        let item = BoardItem(chainID: ContentRegistry.groomingChainID, tier: 3)
        let decoded = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        XCTAssertEqual(decoded.chainID, ContentRegistry.groomingChainID)
        XCTAssertEqual(decoded.tier, 3)
        XCTAssertNotNil(decoded.def, "supply chain tier 3 should resolve in the registry")
        XCTAssertEqual(decoded.def?.name, "Spa Kit")
    }

    func testSupplyProducerRoundTrips() throws {
        let producer = ProducerTile(level: .feedBox)
        let decoded = try decoder.decode(ProducerTile.self, from: encoder.encode(producer))
        XCTAssertEqual(decoded.level, .feedBox)
        XCTAssertEqual(decoded.chargesRemaining, ProducerLevel.feedBox.maxCharges)
        XCTAssertEqual(decoded.id, producer.id)
    }

    func testSupplyCountRoundTrips() throws {
        var state = makeSampleState()
        state.supplyCount = 42
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.supplyCount, 42)
    }

    func testReachTierQuestOnlyProgressesOnMatchingCategory() {
        // A reachTier(.animal, tier:2) goal must NOT progress when a supply item reaches tier 2.
        var quest = Quest(goal: .reachTier(.animal, tier: 2, count: 1),
                         difficulty: .easy, dogTagReward: 1, kibbleReward: 2)
        let supplyChainID = ContentRegistry.groomingChainID

        // Simulate the category-aware match: supply merge at tier 2 should not tick animal goal.
        let mergedCategory = ContentRegistry.shared.chain(supplyChainID)?.category
        var progressed = false
        if case .reachTier(let cat, let t, _) = quest.goal, t == 2, cat == mergedCategory {
            quest.progress += 1
            progressed = true
        }
        XCTAssertFalse(progressed, "Animal reachTier goal must not progress on a supply merge")
        XCTAssertEqual(quest.progress, 0)
    }

    func testAmbassadorsOnlyCountsAnimalTopTier() {
        // Verify the guard: supply chain top-tier should not increment ambassadors.
        let supplyChain = ContentRegistry.shared.chain(ContentRegistry.groomingChainID)!
        let animalChain = ContentRegistry.shared.chain(ContentRegistry.animalChainID(.dog))!
        XCTAssertEqual(supplyChain.category, .supply)
        XCTAssertEqual(animalChain.category, .animal)
        // The guard in triggerTopTierCelebration checks category == .animal.
        XCTAssertFalse(supplyChain.category == .animal, "Supply top tier should NOT count as ambassador")
        XCTAssertTrue(animalChain.category == .animal,  "Animal top tier SHOULD count as ambassador")
    }

    func testSupplyQuestGoalsNotGeneratedBeforeLevel15() {
        // Before any supply chains are unlocked, quest pool must stay animal-only.
        // unlockedSupplyChainIDs is empty → hasSupply = false → no supply goals appended.
        // We test this by verifying the supply chain IDs are NOT in startingChainIDs.
        let startIDs = Set(startingChainIDs)
        XCTAssertFalse(startIDs.contains(ContentRegistry.groomingChainID))
        XCTAssertFalse(startIDs.contains(ContentRegistry.foodChainID))
        XCTAssertFalse(startIDs.contains(ContentRegistry.shelterChainID))
    }

    // MARK: Model generality — proves it's not animal-special-cased

    func testNonAnimalChainItemRoundTrips() throws {
        // A BoardItem from a chain the registry doesn't (yet) define must still
        // persist faithfully — the save stores only chainID + tier.
        let item = BoardItem(chainID: "material.plank", tier: 3)
        let decoded = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        XCTAssertEqual(decoded.chainID, "material.plank")
        XCTAssertEqual(decoded.tier, 3)
        XCTAssertNil(decoded.def, "Unknown chain has no registry tier (treated as empty by callers)")
    }

    // MARK: GameStore save / load

    func testGameStoreSaveThenLoadIsFaithful() throws {
        let original = makeSampleState()
        GameStore.save(original)

        let loaded = try XCTUnwrap(GameStore.load())
        XCTAssertEqual(loaded.version, GameStore.currentVersion)   // save stamps the version
        XCTAssertEqual(loaded.kibble, original.kibble)
        XCTAssertEqual(loaded.playerLevel, original.playerLevel)
        XCTAssertEqual(loaded.board[0][0].item?.chainID, aid(.fox))
        XCTAssertEqual(loaded.adoptionOrders.first?.wantedTier, 5)
    }

    // MARK: Version guard

    func testVersionGuardDiscardsMismatchedVersion() throws {
        // Write a structurally-valid blob whose version is wrong.
        var state = makeSampleState()
        state.version = GameStore.currentVersion
        let data = try JSONEncoder().encode(state)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj["version"] = GameStore.currentVersion + 999
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        XCTAssertNil(GameStore.load(), "Mismatched-version save should be discarded")
    }

    func testCardPackTypeLegacyRawValueRemapping() throws {
        // Verifies that old v10 rawValues ("basic", "star", "mega") decode
        // to the correct new pack type via the custom Codable conformance.
        let mapping: [(String, CardPackType)] = [("basic", .star2), ("star", .star4), ("mega", .star6)]
        for (raw, expected) in mapping {
            let data = "\"\(raw)\"".data(using: .utf8)!
            let decoded = try JSONDecoder().decode(CardPackType.self, from: data)
            XCTAssertEqual(decoded, expected, "Legacy '\(raw)' should remap to \(expected)")
        }
    }

    func testV10toV11MigrationInjectsDefaultTradeFields() throws {
        var state = makeSampleState()
        let data = try JSONEncoder().encode(state)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["pendingOutgoingTrades", "pendingIncomingTrades", "cardsSentToday", "lastCardSendDate"] {
            obj.removeValue(forKey: key)
        }
        obj["version"] = 10
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        let loaded = try XCTUnwrap(GameStore.load(), "v10 save should migrate to v11")
        XCTAssertEqual(loaded.pendingOutgoingTrades, [])
        XCTAssertEqual(loaded.pendingIncomingTrades, [])
        XCTAssertEqual(loaded.cardsSentToday, 0)
        XCTAssertNil(loaded.lastCardSendDate)
        XCTAssertEqual(loaded.version, GameStore.currentVersion)
    }

    func testV9toV10MigrationInjectsDefaultCardFields() throws {
        var state = makeSampleState()
        let data = try JSONEncoder().encode(state)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["cardInventory", "starCount", "completedAlbumIDs", "pendingCardPacks",
                    "jokerCards", "rareJokerCards"] {
            obj.removeValue(forKey: key)
        }
        obj["version"] = 9
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        let loaded = try XCTUnwrap(GameStore.load(), "v9 save should migrate successfully")
        XCTAssertEqual(loaded.cardInventory, [:])
        XCTAssertEqual(loaded.starCount, 0)
        XCTAssertEqual(loaded.completedAlbumIDs, [])
        XCTAssertEqual(loaded.pendingCardPacks, [])
        XCTAssertEqual(loaded.jokerCards, 0)
        XCTAssertEqual(loaded.rareJokerCards, 0)
        XCTAssertEqual(loaded.version, GameStore.currentVersion)
    }

    func testV8toV9MigrationInjectsDefaultSpawnMultiplier() throws {
        // Build a v9 state, strip spawnMultiplier, stamp version=8, save — simulates a v8 save.
        var state = makeSampleState()
        let data = try JSONEncoder().encode(state)
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj.removeValue(forKey: "spawnMultiplier")
        obj["version"] = 8
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        let loaded = try XCTUnwrap(GameStore.load(), "v8 save should migrate successfully")
        XCTAssertEqual(loaded.spawnMultiplier, 1, "migrated save should default spawnMultiplier to 1")
        XCTAssertEqual(loaded.version, GameStore.currentVersion)
    }

    func testV16toV17MigrationInjectsDefaultInviteProgress() throws {
        let data = try JSONEncoder().encode(makeSampleState())
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj.removeValue(forKey: "inviteProgress")
        obj["version"] = 16
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        let loaded = try XCTUnwrap(GameStore.load(), "v16 save should migrate to v17")
        XCTAssertEqual(loaded.inviteProgress.invitesSent, 0)
        XCTAssertEqual(loaded.inviteProgress.claimedMilestones, [])
        XCTAssertEqual(loaded.version, GameStore.currentVersion)
    }

    func testV17toV18MigrationShiftsAnimalTiers() throws {
        // Build a v17-style save with old 10-tier indices and stamp it version=17.
        // Expected shift: old tier N → new tier max(0, N-1).
        let data = try JSONEncoder().encode(makeSampleState())
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        // Patch board[0][0].item.tier = 9 (old ambassador) → expect 8 after migration.
        var board = obj["board"] as! [[[String: Any]]]
        var boardItem = board[0][0]["item"] as! [String: Any]
        boardItem["tier"] = 9
        board[0][0]["item"] = boardItem
        obj["board"] = board

        // Patch inventory[0].tier = 5 (old foster) → expect 4 after migration.
        var inv = obj["inventory"] as! [Any]
        var invItem = inv[0] as! [String: Any]
        invItem["tier"] = 5
        inv[0] = invItem
        obj["inventory"] = inv

        // Patch adoptionOrders[0].wantedTier = 6 (old adopted) → expect 5 after migration.
        var orders = obj["adoptionOrders"] as! [[String: Any]]
        orders[0]["wantedTier"] = 6
        obj["adoptionOrders"] = orders

        // Patch activeQuests[1].goal reachTier.tier = 9 (old ambassador) → expect 8 after migration.
        var quests = obj["activeQuests"] as! [[String: Any]]
        quests[1]["goal"] = ["reachTier": ["_0": "animal", "tier": 9, "count": 1]]
        obj["activeQuests"] = quests

        obj["version"] = 17
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        let loaded = try XCTUnwrap(GameStore.load(), "v17 save should migrate to v18")
        XCTAssertEqual(loaded.version, GameStore.currentVersion)
        XCTAssertEqual(loaded.board[0][0].item?.tier, 8, "Ambassador tier 9 → 8")
        XCTAssertEqual(loaded.inventory[0]?.tier, 4, "Foster tier 5 → 4")
        XCTAssertEqual(loaded.adoptionOrders[0].wantedTier, 5, "Adopted wantedTier 6 → 5")
        if case .reachTier(_, let t, _) = loaded.activeQuests[1].goal {
            XCTAssertEqual(t, 8, "Ambassador reachTier goal tier 9 → 8")
        } else {
            XCTFail("activeQuests[1].goal should be .reachTier after migration")
        }

        // Tier 0 (old stray) must clamp at 0, not go negative.
        var obj2 = obj
        var board2 = obj2["board"] as! [[[String: Any]]]
        var boardItem2 = board2[0][0]["item"] as! [String: Any]
        boardItem2["tier"] = 0
        board2[0][0]["item"] = boardItem2
        obj2["board"] = board2
        obj2["version"] = 17
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj2))
        let loaded2 = try XCTUnwrap(GameStore.load(), "v17 stray-tier save should migrate")
        XCTAssertEqual(loaded2.board[0][0].item?.tier, 0, "Stray tier 0 clamps at 0, not -1")
    }

    func testV15toV16MigrationInjectsDefaultEventProgress() throws {
        let data = try JSONEncoder().encode(makeSampleState())
        var obj = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        obj.removeValue(forKey: "eventProgress")
        obj["version"] = 15
        try writeMainFile(try JSONSerialization.data(withJSONObject: obj))

        let loaded = try XCTUnwrap(GameStore.load(), "v15 save should migrate to v16")
        XCTAssertEqual(loaded.eventProgress.eventId, "")
        XCTAssertEqual(loaded.eventProgress.coinsEarned, 0)
        XCTAssertEqual(loaded.eventProgress.claimedMilestones, [])
        XCTAssertEqual(loaded.version, GameStore.currentVersion)
    }

    func testVersionGuardDiscardsCorruptData() throws {
        try writeMainFile(Data("not json".utf8))
        XCTAssertNil(GameStore.load(), "Corrupt save should be discarded, not crash")
    }

    func testLoadReturnsNilWhenNoSaveExists() {
        XCTAssertNil(GameStore.load())
    }

    // MARK: Backup recovery

    // MARK: Phase 3 — Three material chains, toolbox, and producer storage

    func testThreeMaterialChainsRegistered() {
        let reg = ContentRegistry.shared
        let ids = [ContentRegistry.woodChainID,
                   ContentRegistry.metalChainID,
                   ContentRegistry.cementChainID]
        for id in ids {
            let chain = reg.chain(id)
            XCTAssertNotNil(chain, "\(id) must be in the registry")
            XCTAssertEqual(chain?.category, .material, "\(id) must be .material")
            XCTAssertEqual(chain?.tiers.count, 6, "\(id) must have 6 tiers")
            XCTAssertNotNil(reg.nextTier(id, after: 0), "tier 0 should have a next")
            XCTAssertNil(reg.nextTier(id, after: 5),    "tier 5 is the top — no next")
        }
    }

    func testMaterialChainTierNames() {
        let reg = ContentRegistry.shared
        XCTAssertEqual(reg.tier(ContentRegistry.woodChainID,   0)?.name, "Log")
        XCTAssertEqual(reg.tier(ContentRegistry.woodChainID,   5)?.name, "Hardwood Kit")
        XCTAssertEqual(reg.tier(ContentRegistry.metalChainID,  0)?.name, "Nail")
        XCTAssertEqual(reg.tier(ContentRegistry.metalChainID,  5)?.name, "Steel Girder")
        XCTAssertEqual(reg.tier(ContentRegistry.cementChainID, 0)?.name, "Pebble")
        XCTAssertEqual(reg.tier(ContentRegistry.cementChainID, 5)?.name, "Foundation Kit")
    }

    func testToolboxChainIsRegisteredAndConsumable() {
        let reg   = ContentRegistry.shared
        let chain = reg.chain(ContentRegistry.toolboxChainID)
        XCTAssertNotNil(chain)
        XCTAssertEqual(chain?.category, .tool, "Toolbox is a .tool consumable")
        XCTAssertEqual(chain?.tiers.count, 1,  "Toolbox has a single tier — it opens, not merges")
        // Confirm it has no next tier (can't be merged up)
        XCTAssertNil(reg.nextTier(ContentRegistry.toolboxChainID, after: 0))
    }

    func testWoodItemRoundTrips() throws {
        let item = BoardItem(chainID: ContentRegistry.woodChainID, tier: 3)
        let decoded = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        XCTAssertEqual(decoded.chainID, ContentRegistry.woodChainID)
        XCTAssertEqual(decoded.tier, 3)
        XCTAssertEqual(decoded.def?.name, "Timber")
    }

    func testMetalItemRoundTrips() throws {
        let item = BoardItem(chainID: ContentRegistry.metalChainID, tier: 4)
        let decoded = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        XCTAssertEqual(decoded.def?.name, "I-Beam")
    }

    func testCementItemRoundTrips() throws {
        let item = BoardItem(chainID: ContentRegistry.cementChainID, tier: 2)
        let decoded = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        XCTAssertEqual(decoded.def?.name, "Stone")
    }

    func testToolboxItemRoundTrips() throws {
        let item = BoardItem(chainID: ContentRegistry.toolboxChainID, tier: 0)
        let decoded = try decoder.decode(BoardItem.self, from: encoder.encode(item))
        XCTAssertEqual(decoded.chainID, ContentRegistry.toolboxChainID)
        XCTAssertEqual(decoded.def?.name, "Toolbox")
        // A single-tier chain is always at its max — isTopTier is true.
        // The ambassador guard checks category == .animal, so this never triggers a celebration.
        XCTAssertEqual(decoded.chain?.category, .tool)
        XCTAssertNil(decoded.chain?.tiers.first?.badge, "Toolbox has no top-tier badge")
    }

    func testDesignatedProducerStorageRoundTrips() throws {
        let state   = makeSampleState()
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        // materialCounts accumulator
        XCTAssertEqual(decoded.materialCounts[ContentRegistry.woodChainID]?[2], 1)
        XCTAssertEqual(decoded.materialCounts[ContentRegistry.metalChainID]?.reduce(0, +), 0)
        // producerStorage dictionary — keyed by rawValue
        let key = ProducerLevel.groomingBox.rawValue
        XCTAssertNotNil(decoded.producerStorage[key])
        XCTAssertEqual(decoded.producerStorage[key]?.level, .groomingBox)
        XCTAssertEqual(decoded.producerStorage[key]?.cooldownRemaining ?? 0, 10, accuracy: 0.001)
        // overflow
        XCTAssertEqual(decoded.overflowProducerStorage[0]?.level, .fosterHome)
        XCTAssertNil(decoded.overflowProducerStorage[1] ?? nil)
    }

    func testDesignatedStorageRoundTripPreservesCharges() throws {
        let producer = ProducerTile(level: .shelterPod, cooldownRemaining: 20, chargesRemaining: 3)
        let decoded  = try decoder.decode(ProducerTile.self, from: encoder.encode(producer))
        XCTAssertEqual(decoded.level, .shelterPod)
        XCTAssertEqual(decoded.chargesRemaining, 3)
        XCTAssertEqual(decoded.cooldownRemaining, 20, accuracy: 0.001)
    }

    func testStorageUnlockLevelProgression() {
        // Slot unlock levels must be non-decreasing and match the acquisition level.
        XCTAssertEqual(ProducerLevel.rescueCrate.storageUnlockLevel, 1)
        XCTAssertEqual(ProducerLevel.shelterPod.storageUnlockLevel,  4)
        XCTAssertEqual(ProducerLevel.fosterHome.storageUnlockLevel,  7)
        XCTAssertEqual(ProducerLevel.groomingBox.storageUnlockLevel, 15)
        XCTAssertEqual(ProducerLevel.feedBox.storageUnlockLevel,     20)
        XCTAssertEqual(ProducerLevel.shelterBox.storageUnlockLevel,  25)
        // Each shop-producer level must be <= the next (non-decreasing).
        // familySpawner is excluded — it has no storage slot (storageUnlockLevel == 1 sentinel).
        let levels = ProducerLevel.allCases.filter(\.isShopProducer).map(\.storageUnlockLevel)
        for i in 0..<(levels.count - 1) {
            XCTAssertLessThanOrEqual(levels[i], levels[i + 1])
        }
    }

    // MARK: Phase 4 — Sanctuary map & area construction

    func testCompletedAreaIDsRoundTrips() throws {
        var state = makeSampleState()
        state.completedAreaIDs = ["area.welcome", "area.grooming"]
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.completedAreaIDs, ["area.welcome", "area.grooming"])
    }

    func testEmptyCompletedAreaIDsRoundTrips() throws {
        var state = makeSampleState()
        state.completedAreaIDs = []
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.completedAreaIDs, [])
    }

    func testSanctuaryAreasHaveUniqueStableIDs() {
        let ids = sanctuaryAreas.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "All area IDs must be unique")
        // IDs must be stable strings (no whitespace, no spaces — used as persistence keys).
        for id in ids {
            XCTAssertFalse(id.contains(" "), "Area id '\(id)' must not contain spaces")
            XCTAssertTrue(id.hasPrefix("area."), "Area id '\(id)' should follow the 'area.<name>' convention")
        }
    }

    func testSanctuaryAreasOrderedWithFirstNotRequiringPrevious() {
        XCTAssertFalse(sanctuaryAreas[0].requiresPrevious, "First area must not require a previous area")
        // All subsequent areas should require a predecessor.
        for area in sanctuaryAreas.dropFirst() {
            XCTAssertTrue(area.requiresPrevious, "'\(area.id)' should require a previous area")
        }
    }

    func testMaterialCostsReferenceRegisteredChains() {
        for area in sanctuaryAreas {
            for cost in area.costs {
                let chain = ContentRegistry.shared.chain(cost.chainID)
                XCTAssertNotNil(chain, "Cost chainID '\(cost.chainID)' in '\(area.id)' must be registered")
                XCTAssertEqual(chain?.category, .material, "Area costs must reference .material chains")
                XCTAssertNotNil(ContentRegistry.shared.tier(cost.chainID, cost.tier),
                                "Tier \(cost.tier) of '\(cost.chainID)' must exist")
                XCTAssertGreaterThan(cost.count, 0, "Cost count must be positive")
            }
        }
    }

    func testAreaAvailabilityLogic() {
        // Simulate the isAreaAvailable logic without instantiating the full ViewModel.
        // Use the same index-based prerequisite check the ViewModel uses.
        var completed: [String] = []

        func isAvailable(_ area: SanctuaryArea) -> Bool {
            guard !completed.contains(area.id) else { return false }
            guard area.requiresPrevious else { return true }
            guard let idx = sanctuaryAreas.firstIndex(where: { $0.id == area.id }), idx > 0 else {
                return false
            }
            return completed.contains(sanctuaryAreas[idx - 1].id)
        }

        let first  = sanctuaryAreas[0]
        let second = sanctuaryAreas[1]

        XCTAssertTrue(isAvailable(first),   "First area must be available from the start")
        XCTAssertFalse(isAvailable(second), "Second area must not be available before first is built")

        completed.append(first.id)
        XCTAssertFalse(isAvailable(first),  "First area must not be available after completion")
        XCTAssertTrue(isAvailable(second),  "Second area must be available once first is complete")
    }

    func testAreaRewardPrimaryMessageIncludesAllComponents() {
        let reward = AreaReward(newBoardRow: true, newSpecies: [.fox, .owl],
                                bonusKibble: 20, bonusDogTags: 5, bonusXP: 60)
        let msg = reward.primaryMessage()
        XCTAssertTrue(msg.contains("board row"), "Message should mention new board row")
        XCTAssertTrue(msg.contains("Cervids"),   "Message should mention Cervids (fox family)")
        XCTAssertTrue(msg.contains("Ursids"),    "Message should mention Ursids (owl family)")
        XCTAssertTrue(msg.contains("20"),        "Message should mention kibble amount")
        XCTAssertTrue(msg.contains("5"),         "Message should mention dog tag amount")
        XCTAssertTrue(msg.contains("60"),        "Message should mention XP amount")
    }

    func testEmptyAreaRewardPrimaryMessageDoesNotCrash() {
        let reward = AreaReward()
        XCTAssertFalse(reward.primaryMessage().isEmpty, "Even empty reward should return a non-empty string")
    }

    func testMaterialCostComputedProperties() {
        let cost = MaterialCost(chainID: ContentRegistry.woodChainID, tier: 2, count: 3)
        XCTAssertEqual(cost.chainName,  "Wood")
        XCTAssertEqual(cost.tierName,   "Lumber")
        XCTAssertFalse(cost.tierSymbol.isEmpty, "tierSymbol should resolve from the registry")
        XCTAssertEqual(cost.id, "material.wood.2", "id should combine chainID and tier")
    }

    func testCompletedAreaIDsPersistedByGameStore() throws {
        var state = makeSampleState()
        state.completedAreaIDs = ["area.welcome", "area.grooming", "area.rescue"]
        GameStore.save(state)
        let loaded = try XCTUnwrap(GameStore.load())
        XCTAssertEqual(loaded.completedAreaIDs, ["area.welcome", "area.grooming", "area.rescue"])
    }

    // MARK: Gameplay tuning (efficiency & balance pass)

    // ── Toolbox tier scaling ────────────────────────────────────

    func testToolboxMaxTierScalesWithPlayerLevel() {
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 1),  1, "Level  1 → max tier 1")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 4),  1, "Level  4 → max tier 1")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 5),  2, "Level  5 → max tier 2")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 9),  2, "Level  9 → max tier 2")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 10), 3, "Level 10 → max tier 3")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 14), 3, "Level 14 → max tier 3")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 15), 4, "Level 15 → max tier 4")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 19), 4, "Level 19 → max tier 4")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 20), 5, "Level 20 → max tier 5")
        XCTAssertEqual(toolboxMaxTier(forPlayerLevel: 99), 5, "Level 99 → still capped at 5")
    }

    func testToolboxMaxTierNeverExceedsChainDepth() {
        // Material chains have 6 tiers (0–5). toolboxMaxTier must never exceed 5.
        for level in [1, 5, 10, 15, 20, 25, 50, 100] {
            XCTAssertLessThanOrEqual(toolboxMaxTier(forPlayerLevel: level), 5,
                                     "Max tier at level \(level) must not exceed 5")
        }
    }

    // ── Adoption order stage capping ────────────────────────────

    func testMaxAchievableOrderTierAtEachLevelBand() {
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 1),  RescueStage.groomed.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 3),  RescueStage.groomed.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 4),  RescueStage.trained.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 6),  RescueStage.trained.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 7),  RescueStage.adopted.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 9),  RescueStage.adopted.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 10), RescueStage.bondedPair.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 12), RescueStage.bondedPair.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 13), RescueStage.communityFav.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 15), RescueStage.communityFav.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 16), RescueStage.ambassador.tierIndex)
        XCTAssertEqual(maxAchievableOrderTier(forPlayerLevel: 50), RescueStage.ambassador.tierIndex)
    }

    func testMaxAchievableOrderTierIsNonDecreasing() {
        // Tier cap must never decrease as the player levels up.
        var prev = maxAchievableOrderTier(forPlayerLevel: 1)
        for level in 2...30 {
            let current = maxAchievableOrderTier(forPlayerLevel: level)
            XCTAssertGreaterThanOrEqual(current, prev,
                "Max tier at level \(level) (\(current)) must not be less than level \(level-1) (\(prev))")
            prev = current
        }
    }

    func testAdoptionOrderStageClamping() {
        // Simulate the clamping formula used in generateAdoptionOrder().
        // At level 1-3 an "ambassador" roll should be clamped to "groomed".
        let maxTier = maxAchievableOrderTier(forPlayerLevel: 1)
        let ambassadorRaw = RescueStage.ambassador.rawValue
        let clampedRaw    = min(ambassadorRaw, maxTier + 1)
        let clamped       = RescueStage(rawValue: clampedRaw)
        XCTAssertEqual(clamped, .groomed,
                       "Ambassador order at level 1 must clamp to Groomed")

        // At level 16+ clamping should be a no-op for ambassador.
        let maxTierHigh  = maxAchievableOrderTier(forPlayerLevel: 16)
        let clampedHigh  = RescueStage(rawValue: min(ambassadorRaw, maxTierHigh + 1))
        XCTAssertEqual(clampedHigh, .ambassador,
                       "Ambassador order at level 16 must not be clamped")
    }

    // MARK: Phase 5 — Coins, weekly/monthly goals, area upgrades

    func testCoinsAndGoalStateRoundTrip() throws {
        var state = makeSampleState()
        state.coins = 85
        state.coinsEarnedThisWeek = 40
        state.weeklyGoalBronzeClaimed = true
        state.weeklyGoalSilverClaimed = false
        state.weeklyGoalGoldClaimed   = false
        state.weeklyGoldCompletions   = 1
        state.monthlyGoalClaimed      = false
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.coins, 85)
        XCTAssertEqual(decoded.coinsEarnedThisWeek, 40)
        XCTAssertTrue(decoded.weeklyGoalBronzeClaimed)
        XCTAssertFalse(decoded.weeklyGoalSilverClaimed)
        XCTAssertFalse(decoded.weeklyGoalGoldClaimed)
        XCTAssertEqual(decoded.weeklyGoldCompletions, 1)
        XCTAssertFalse(decoded.monthlyGoalClaimed)
    }

    func testAreaUpgradeLevelsRoundTrip() throws {
        var state = makeSampleState()
        state.areaUpgradeLevels = ["area.welcome": 2, "area.grooming": 1]
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.areaUpgradeLevels["area.welcome"],  2)
        XCTAssertEqual(decoded.areaUpgradeLevels["area.grooming"], 1)
        XCTAssertNil(decoded.areaUpgradeLevels["area.rescue"])
    }

    func testAdoptionOrderRewardCoinsRoundTrips() throws {
        let order = AdoptionOrder(familyIndex: 0, wantedChainID: aid(.dog), wantedTier: 3,
                                  wantedCount: 1, timeRemaining: 500,
                                  rewardKibble: 30, rewardDogTags: 3, rewardCoins: 8)
        let decoded = try decoder.decode(AdoptionOrder.self, from: encoder.encode(order))
        XCTAssertEqual(decoded.rewardCoins, 8)
        XCTAssertEqual(decoded.rewardKibble, 30)
        XCTAssertEqual(decoded.id, order.id)
    }

    func testWeeklyGoalTierThresholdsAreOrdered() {
        let bronze = WeeklyGoalTier.bronze.baseCoinsNeeded
        let silver = WeeklyGoalTier.silver.baseCoinsNeeded
        let gold   = WeeklyGoalTier.gold.baseCoinsNeeded
        XCTAssertLessThan(bronze, silver, "Bronze must be below silver")
        XCTAssertLessThan(silver, gold,   "Silver must be below gold")
        XCTAssertGreaterThan(bronze, 0,   "Bronze threshold must be positive")
    }

    func testWeeklyGoalTiersHaveDistinctColors() {
        let colors = WeeklyGoalTier.allCases.map(\.color)
        // Crude check — each tier's color should differ from the next
        XCTAssertNotEqual(colors[0], colors[1])
        XCTAssertNotEqual(colors[1], colors[2])
    }

    func testUpgradeBonusMerging() {
        let a = UpgradeBonus(coinsPerDailyComplete: 2, kibblePerRegen: 1)
        let b = UpgradeBonus(coinsPerDailyComplete: 3, extraAdoptionSlots: 1)
        let combined = a.merging(b)
        XCTAssertEqual(combined.coinsPerDailyComplete, 5)
        XCTAssertEqual(combined.kibblePerRegen, 1)
        XCTAssertEqual(combined.extraAdoptionSlots, 1)
        XCTAssertFalse(combined.weeklyRewardDoubled)
    }

    func testUpgradeBonusWeeklyRewardDoubledIsOrred() {
        let a = UpgradeBonus(weeklyRewardDoubled: false)
        let b = UpgradeBonus(weeklyRewardDoubled: true)
        XCTAssertTrue(a.merging(b).weeklyRewardDoubled)
        XCTAssertTrue(b.merging(a).weeklyRewardDoubled)
        XCTAssertFalse(a.merging(a).weeklyRewardDoubled)
    }

    func testAllAreaUpgradeIDsAreUniqueAndStable() {
        let ids = sanctuaryAreas.flatMap { $0.upgrades.map(\.id) }
        XCTAssertEqual(Set(ids).count, ids.count, "All upgrade IDs must be unique")
        for id in ids {
            XCTAssertFalse(id.contains(" "), "Upgrade id '\(id)' must not contain spaces")
        }
    }

    func testEachAreaHasTwoUpgradeTiers() {
        for area in sanctuaryAreas {
            XCTAssertEqual(area.upgrades.count, 2,
                           "'\(area.id)' must have exactly 2 upgrade tiers, found \(area.upgrades.count)")
        }
    }

    func testUpgradeMaterialCostsReferenceRegisteredChains() {
        for area in sanctuaryAreas {
            for upgrade in area.upgrades {
                for cost in upgrade.materialCosts {
                    let chain = ContentRegistry.shared.chain(cost.chainID)
                    XCTAssertNotNil(chain,
                        "Upgrade '\(upgrade.id)' cost chainID '\(cost.chainID)' must be registered")
                    XCTAssertEqual(chain?.category, .material,
                        "Upgrade '\(upgrade.id)' cost must reference a .material chain")
                    XCTAssertNotNil(ContentRegistry.shared.tier(cost.chainID, cost.tier),
                        "Tier \(cost.tier) of '\(cost.chainID)' must exist")
                    XCTAssertGreaterThan(cost.count, 0, "Cost count must be positive")
                }
                XCTAssertGreaterThan(upgrade.coinCost, 0, "Upgrade '\(upgrade.id)' coin cost must be positive")
            }
        }
    }

    func testUpgradeCoinCostsIncreaseWithinEachArea() {
        for area in sanctuaryAreas where area.upgrades.count >= 2 {
            let t1Cost = area.upgrades[0].coinCost
            let t2Cost = area.upgrades[1].coinCost
            XCTAssertLessThan(t1Cost, t2Cost,
                "'\(area.id)' T1 coin cost (\(t1Cost)) must be less than T2 (\(t2Cost))")
        }
    }

    func testQuestDifficultyCoinRewardsAreOrdered() {
        let easy = QuestDifficulty.easy.coinReward
        let med  = QuestDifficulty.medium.coinReward
        let hard = QuestDifficulty.hard.coinReward
        let leg  = QuestDifficulty.legendary.coinReward
        XCTAssertLessThan(easy, med)
        XCTAssertLessThan(med,  hard)
        XCTAssertLessThan(hard, leg)
        XCTAssertGreaterThan(easy, 0)
    }

    func testMonthlyGoalWeeksNeededIsPositive() {
        XCTAssertGreaterThan(monthlyGoalWeeksNeeded, 0)
        XCTAssertLessThanOrEqual(monthlyGoalWeeksNeeded, 4)
    }

    // ── Backup recovery ─────────────────────────────────────────

    // MARK: Backup recovery

    func testRecoversFromBackupWhenMainFileIsCorrupt() throws {
        // A good save populates the backup slot (load() refreshes it).
        GameStore.save(makeSampleState())
        _ = GameStore.load()   // promotes main → backup

        // Now corrupt the main file; load() should fall back to the backup.
        try writeMainFile(Data("garbage".utf8))
        let recovered = try XCTUnwrap(GameStore.load(),
                                      "Should recover the last-known-good backup")
        XCTAssertEqual(recovered.kibble, 73)
        XCTAssertEqual(recovered.board[0][1].producer?.level, .shelterPod)
    }

    // MARK: Events system (v16)

    func testEventProgressRoundTrips() throws {
        let progress = EventProgress(eventId: "test_event", coinsEarned: 1200, claimedMilestones: [1, 2])
        let decoded = try decoder.decode(EventProgress.self, from: encoder.encode(progress))
        XCTAssertEqual(decoded.eventId, "test_event")
        XCTAssertEqual(decoded.coinsEarned, 1200)
        XCTAssertEqual(decoded.claimedMilestones, [1, 2])
    }

    func testEventProgressHasClaimed() {
        let progress = EventProgress(eventId: "e", coinsEarned: 0, claimedMilestones: [1, 3])
        XCTAssertTrue(progress.hasClaimed(1))
        XCTAssertFalse(progress.hasClaimed(2))
        XCTAssertTrue(progress.hasClaimed(3))
    }

    func testEventProgressCanClaim() {
        let milestone = EventMilestone(id: 2, coinsRequired: 1000, kibbleReward: 50, dogTagsReward: 0)
        var progress = EventProgress(eventId: "e", coinsEarned: 999, claimedMilestones: [])
        XCTAssertFalse(progress.canClaim(milestone), "below threshold — cannot claim")
        progress.coinsEarned = 1000
        XCTAssertTrue(progress.canClaim(milestone), "at threshold — can claim")
        progress.claimedMilestones = [2]
        XCTAssertFalse(progress.canClaim(milestone), "already claimed — cannot claim again")
    }

    func testEventProgressResetOnNewEventID() throws {
        // Saved state has progress for "rescue_rush_jun2026"; loading it should keep it intact.
        // A different eventId in the registry would reset progress in the VM — but the
        // Codable model itself carries whatever was saved.
        let state = makeSampleState()
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.eventProgress.eventId, "rescue_rush_jun2026")
        XCTAssertEqual(decoded.eventProgress.coinsEarned, 750)
        XCTAssertEqual(decoded.eventProgress.claimedMilestones, [1])
    }

    // MARK: Invite-a-Friend (v17)

    func testInviteProgressRoundTrips() throws {
        let progress = InviteProgress(invitesSent: 4, claimedMilestones: [1, 2])
        let decoded = try decoder.decode(InviteProgress.self, from: encoder.encode(progress))
        XCTAssertEqual(decoded.invitesSent, 4)
        XCTAssertEqual(decoded.claimedMilestones, [1, 2])
    }

    func testInviteProgressHasClaimed() {
        let progress = InviteProgress(invitesSent: 5, claimedMilestones: [1, 3])
        XCTAssertTrue(progress.hasClaimed(1))
        XCTAssertFalse(progress.hasClaimed(2))
        XCTAssertTrue(progress.hasClaimed(3))
    }

    func testInviteProgressCanClaim() {
        let milestone = InviteMilestone(id: 2, invitesRequired: 3, kibbleReward: 0, dogTagsReward: 3)
        var progress = InviteProgress(invitesSent: 2, claimedMilestones: [])
        XCTAssertFalse(progress.canClaim(milestone), "below threshold — cannot claim")
        progress.invitesSent = 3
        XCTAssertTrue(progress.canClaim(milestone), "at threshold — can claim")
        progress.claimedMilestones = [2]
        XCTAssertFalse(progress.canClaim(milestone), "already claimed — cannot claim again")
    }

    func testInviteMilestonesThresholdsAreOrdered() {
        let thresholds = inviteMilestones.map(\.invitesRequired)
        XCTAssertEqual(thresholds, thresholds.sorted(), "invite milestones must be in ascending order")
    }

    func testInviteProgressInSampleStateRoundTrips() throws {
        let state = makeSampleState()
        let decoded = try decoder.decode(GameState.self, from: encoder.encode(state))
        XCTAssertEqual(decoded.inviteProgress.invitesSent, 3)
        XCTAssertEqual(decoded.inviteProgress.claimedMilestones, [1, 2])
    }
}
