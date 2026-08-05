//
//  QuestCoordinator.swift
//  PawSanctuary
//
//  Owns active quests, daily challenges, weekly spotlight, and daily login state.
//  Methods that distribute rewards (kibble, dog tags, XP, coins) return a
//  `QuestRewards` bundle; MergeBoardViewModel applies those values to the correct
//  coordinators so QuestCoordinator stays free of cross-domain dependencies.
//

import SwiftUI
import Observation

// MARK: - Reward bundle

struct QuestRewards {
    var kibble: Int = 0
    var dogTags: Int = 0
    var xp: Int = 0
    var coins: Int = 0
    var bannerText: String = ""
    var showBonus: Bool = false
}

// MARK: - QuestCoordinator

@Observable
@MainActor
class QuestCoordinator {

    // MARK: Stored state

    var activeQuests: [Quest] = []
    var dailyChallenges: [DailyChallenge] = []
    var dailyChallengeStreak: Int = 0
    var dailyChallengeBonusClaimed: Bool = false

    var spotlightChainID: ChainID = ContentRegistry.animalChainID(.dog)
    var spotlightMergesThisWeek: Int = 0
    var lastSpotlightWeek: Int = 0

    var lastDailyChallengeReset: Date? = nil

    var lastLoginDate: Date? = nil
    var loginStreak: Int = 0
    var loginDayIndex: Int = 0
    var loginStreakDay: Int = 1
    var showLoginReward: Bool = false

    // MARK: Computed

    var spotlightProgressFraction: Double {
        min(Double(spotlightMergesThisWeek) / Double(spotlightWeeklyGoal), 1.0)
    }

    var dailyChallengeResetText: String {
        let calendar = Calendar.current
        let now = Date()
        if let tomorrow = calendar.date(byAdding: .day, value: 1,
                                        to: calendar.startOfDay(for: now)) {
            let diff = calendar.dateComponents([.hour, .minute], from: now, to: tomorrow)
            return "Resets in \(diff.hour ?? 0)h \(diff.minute ?? 0)m"
        }
        return "Resets at midnight"
    }

    // MARK: Quest generation

    func setupQuests(unlockedChainIDs: [ChainID], playerLevel: Int) {
        var used = Set<String>()
        activeQuests = (0..<3).map { _ in
            let q = generateQuest(unlockedChainIDs: unlockedChainIDs,
                                  playerLevel: playerLevel,
                                  excluding: used)
            used.insert(q.goal.dedupeKey)
            return q
        }
    }

    func generateQuest(unlockedChainIDs: [ChainID], playerLevel: Int = 1,
                       excluding: Set<String> = []) -> Quest {
        let unlockedMergeable = unlockedChainIDs.filter {
            let cat = ContentRegistry.shared.chain($0)?.category
            return cat == .animal || cat == .supply
        }
        let unlockedAnimals = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .animal
        }
        let unlockedSupply = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .supply
        }
        let mergeableID = unlockedMergeable.randomElement() ?? ContentRegistry.animalChainID(.dog)
        let animalID    = unlockedAnimals.randomElement()    ?? ContentRegistry.animalChainID(.dog)
        let supplyID    = unlockedSupply.randomElement()
        let hasSupply   = supplyID != nil

        let roll = Int.random(in: 1...20)
        let rawDiff: QuestDifficulty = roll <= 9 ? .easy
                                     : roll <= 15 ? .medium
                                     : roll <= 19 ? .hard
                                     : .legendary
        // Cap difficulty to what's reachable at the player's current level.
        let diff: QuestDifficulty
        switch playerLevel {
        case 1...2: diff = .easy
        case 3...4: diff = (rawDiff == .hard || rawDiff == .legendary) ? .medium : rawDiff
        case 5...7: diff = (rawDiff == .legendary) ? .hard : rawDiff
        default:    diff = rawDiff
        }

        let maxTier = maxAchievableOrderTier(forPlayerLevel: playerLevel)

        let goal: QuestGoal
        switch diff {
        case .easy:
            var pool: [QuestGoal] = [
                .mergeAny(count: 3),
                .mergeInChain(mergeableID, count: 2),
                .spawnBase(count: 5),
                .reachTier(.animal, tier: RescueStage.rescued.tierIndex, count: 3),
            ]
            if hasSupply { pool.append(.reachTier(.supply, tier: 1, count: 2)) }
            pool = pool.filter { !excluding.contains($0.dedupeKey) }
            goal = pool.randomElement() ?? .mergeAny(count: 3)

        case .medium:
            var pool: [QuestGoal] = [
                .mergeAny(count: 6),
                .mergeInChain(animalID, count: 4),
                .spawnBase(count: 8),
            ]
            if RescueStage.groomed.tierIndex     <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.groomed.tierIndex,     count: 2)) }
            if RescueStage.vaccinated.tierIndex  <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.vaccinated.tierIndex,  count: 2)) }
            if RescueStage.trained.tierIndex     <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.trained.tierIndex,     count: 1)) }
            if let sid = supplyID {
                pool.append(.mergeInChain(sid, count: 3))
                pool.append(.reachTier(.supply, tier: 2, count: 2))
            }
            pool = pool.filter { !excluding.contains($0.dedupeKey) }
            goal = pool.randomElement() ?? .mergeAny(count: 6)

        case .hard:
            var pool: [QuestGoal] = [
                .mergeAny(count: 10),
                .spawnBase(count: 12),
            ]
            if RescueStage.foster.tierIndex       <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.foster.tierIndex,       count: 2)) }
            if RescueStage.adopted.tierIndex      <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.adopted.tierIndex,      count: 1)) }
            if RescueStage.bondedPair.tierIndex   <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.bondedPair.tierIndex,   count: 1)) }
            if RescueStage.communityFav.tierIndex <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.communityFav.tierIndex, count: 1)) }
            if supplyID != nil { pool.append(.reachTier(.supply, tier: 3, count: 2)) }
            pool = pool.filter { !excluding.contains($0.dedupeKey) }
            goal = pool.randomElement() ?? .mergeAny(count: 10)

        case .legendary:
            var pool: [QuestGoal] = [
                .mergeInChain(animalID, count: 8),
            ]
            if RescueStage.bondedPair.tierIndex   <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.bondedPair.tierIndex,   count: 3)) }
            if RescueStage.communityFav.tierIndex  <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.communityFav.tierIndex, count: 2)) }
            if RescueStage.ambassador.tierIndex    <= maxTier { pool.append(.reachTier(.animal, tier: RescueStage.ambassador.tierIndex,   count: 1)) }
            // RescueStage tops out at tierIndex 8, but Phase 2b's animal chains run to tier 11
            // ("Mythic"/"Ancient"/"Primordial" — see AnimalSpecies.animalTierAppearance). Target
            // those top three tiers directly so the endgame of every chain is a reachable objective.
            if 9  <= maxTier { pool.append(.reachTier(.animal, tier: 9,  count: 1)) }
            if 10 <= maxTier { pool.append(.reachTier(.animal, tier: 10, count: 1)) }
            if 11 <= maxTier { pool.append(.reachTier(.animal, tier: 11, count: 1)) }
            if let sid = supplyID {
                pool.append(.reachTier(.supply, tier: 4, count: 1))
                pool.append(.mergeInChain(sid, count: 6))
            }
            pool = pool.filter { !excluding.contains($0.dedupeKey) }
            goal = pool.randomElement() ?? .mergeInChain(animalID, count: 8)
        }

        let tags: Int
        switch diff {
        case .easy:      tags = Int.random(in: 1...2)
        case .medium:    tags = Int.random(in: 3...4)
        case .hard:      tags = Int.random(in: 5...6)
        case .legendary: tags = Int.random(in: 10...15)
        }
        return Quest(goal: goal, difficulty: diff,
                     dogTagReward: tags, kibbleReward: diff.kibbleReward)
    }

    // MARK: Quest progress updates

    func updateQuestsAfterMerge(chainID: ChainID, tier: Int) {
        let mergedCategory = ContentRegistry.shared.chain(chainID)?.category
        for i in activeQuests.indices {
            guard !activeQuests[i].isComplete else { continue }
            switch activeQuests[i].goal {
            case .mergeAny:
                activeQuests[i].progress += 1
            case .mergeInChain(let id, _) where id == chainID:
                activeQuests[i].progress += 1
            case .reachTier(let category, let t, _) where t == tier && category == mergedCategory:
                activeQuests[i].progress += 1
            default: break
            }
        }
    }

    func updateQuestsAfterRescue() {
        for i in activeQuests.indices {
            guard !activeQuests[i].isComplete else { continue }
            if case .spawnBase = activeQuests[i].goal { activeQuests[i].progress += 1 }
        }
    }

    // MARK: Quest claiming
    // Returns the quest to grant rewards; replaces it with a fresh one.
    // Caller (MergeBoardViewModel) distributes the rewards and handles side effects
    // like producer drops and toolbox drops.

    func claimAndReplace(questID: UUID, unlockedChainIDs: [ChainID], playerLevel: Int) -> Quest? {
        guard let idx = activeQuests.firstIndex(where: { $0.id == questID }),
              activeQuests[idx].isComplete else { return nil }
        let quest = activeQuests[idx]
        let used = Set(activeQuests.indices
            .filter { $0 != idx }
            .map { activeQuests[$0].goal.dedupeKey })
        activeQuests[idx] = generateQuest(unlockedChainIDs: unlockedChainIDs,
                                          playerLevel: playerLevel,
                                          excluding: used)
        return quest
    }

    // MARK: Daily challenges

    func checkDailyChallengeReset(unlockedChainIDs: [ChainID]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let isSameDay = lastDailyChallengeReset.map {
            calendar.isDate($0, inSameDayAs: today)
        } ?? false

        if isSameDay && !dailyChallenges.isEmpty { return }
        if !isSameDay {
            lastDailyChallengeReset = today
            dailyChallengeBonusClaimed = false
        }
        generateDailyChallenges(unlockedChainIDs: unlockedChainIDs)
    }

    func generateDailyChallenges(unlockedChainIDs: [ChainID]) {
        dailyChallenges = [
            makeDailyChallenge(difficulty: .easy,   unlockedChainIDs: unlockedChainIDs),
            makeDailyChallenge(difficulty: .medium, unlockedChainIDs: unlockedChainIDs),
            makeDailyChallenge(difficulty: .hard,   unlockedChainIDs: unlockedChainIDs),
        ]
    }

    func makeDailyChallenge(difficulty: QuestDifficulty,
                            unlockedChainIDs: [ChainID]) -> DailyChallenge {
        let unlockedAnimals = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .animal
        }
        let unlockedSupply = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .supply
        }
        let animalID  = unlockedAnimals.randomElement() ?? ContentRegistry.animalChainID(.dog)
        let supplyID  = unlockedSupply.randomElement()
        let hasSupply = supplyID != nil
        let goal: QuestGoal
        switch difficulty {
        case .easy:
            var pool: [QuestGoal] = [
                .mergeAny(count: 3),
                .spawnBase(count: 4),
                .mergeInChain(animalID, count: 2),
                .reachTier(.animal, tier: RescueStage.groomed.tierIndex, count: 2),
            ]
            if hasSupply { pool.append(.reachTier(.supply, tier: 1, count: 2)) }
            goal = pool.randomElement()!

        case .medium:
            var pool: [QuestGoal] = [
                .mergeAny(count: 6),
                .reachTier(.animal, tier: RescueStage.vaccinated.tierIndex, count: 2),
                .reachTier(.animal, tier: RescueStage.trained.tierIndex, count: 1),
                .spawnBase(count: 8),
            ]
            if let sid = supplyID { pool.append(.mergeInChain(sid, count: 3)) }
            goal = pool.randomElement()!

        case .hard, .legendary:
            var pool: [QuestGoal] = [
                .reachTier(.animal, tier: RescueStage.foster.tierIndex, count: 2),
                .reachTier(.animal, tier: RescueStage.adopted.tierIndex, count: 1),
                .reachTier(.animal, tier: RescueStage.bondedPair.tierIndex, count: 1),
                // RescueStage tops out at tierIndex 8; target the top three tiers
                // (9-11, "Mythic"/"Ancient"/"Primordial") directly, same as the
                // legendary quest pool in generateQuest, so they stay reachable.
                .reachTier(.animal, tier: 9, count: 1),
                .reachTier(.animal, tier: 10, count: 1),
                .reachTier(.animal, tier: 11, count: 1),
                .mergeAny(count: 10),
                .spawnBase(count: 12),
            ]
            if supplyID != nil { pool.append(.reachTier(.supply, tier: 3, count: 1)) }
            goal = pool.randomElement()!
        }
        return DailyChallenge(goal: goal, difficulty: difficulty)
    }

    func updateDailyChallengesAfterMerge(chainID: ChainID, tier: Int) {
        let mergedCategory = ContentRegistry.shared.chain(chainID)?.category
        for i in dailyChallenges.indices {
            guard !dailyChallenges[i].isComplete else { continue }
            switch dailyChallenges[i].goal {
            case .mergeAny:
                dailyChallenges[i].progress += 1
            case .mergeInChain(let id, _) where id == chainID:
                dailyChallenges[i].progress += 1
            case .reachTier(let category, let t, _) where t == tier && category == mergedCategory:
                dailyChallenges[i].progress += 1
            default: break
            }
        }
    }

    func updateDailyChallengesAfterRescue() {
        for i in dailyChallenges.indices {
            guard !dailyChallenges[i].isComplete else { continue }
            if case .spawnBase = dailyChallenges[i].goal { dailyChallenges[i].progress += 1 }
        }
    }

    /// Called after each daily challenge update. If all three are now complete and
    /// the bonus hasn't been claimed yet, returns a reward bundle for MBVM to apply.
    func checkAllDailyChallengesComplete(coinsPerDailyComplete: Int) -> QuestRewards? {
        guard !dailyChallengeBonusClaimed,
              !dailyChallenges.isEmpty,
              dailyChallenges.allSatisfy({ $0.isComplete }) else { return nil }
        dailyChallengeBonusClaimed = true
        let newStreak = dailyChallengeStreak + 1
        dailyChallengeStreak = newStreak
        let isWeekStreak = newStreak % 7 == 0
        let bonusT = isWeekStreak ? 8 : 2
        let bannerText = isWeekStreak
            ? "7-Day Streak! +\(bonusT) Tags"
            : "Daily Complete! +\(bonusT) Tags"
        return QuestRewards(
            dogTags: bonusT, xp: xpDailyComplete,
            coins: coinsPerAllDailyChallenges + coinsPerDailyComplete,
            bannerText: bannerText, showBonus: true
        )
    }

    // MARK: Weekly spotlight

    func updateWeeklySpotlight(unlockedChainIDs: [ChainID]) {
        let calendar = Calendar.current
        let weekNum  = calendar.component(.weekOfYear, from: Date())
        let available = unlockedChainIDs.filter {
            ContentRegistry.shared.chain($0)?.category == .animal
        }
        let pool = available.isEmpty ? startingChainIDs : available
        spotlightChainID = pool[weekNum % pool.count]
        if lastSpotlightWeek != weekNum {
            lastSpotlightWeek = weekNum
            spotlightMergesThisWeek = 0
        }
    }

    /// Returns any rewards earned for hitting the weekly spotlight milestone.
    func recordSpotlightMerge(chainID: ChainID) -> QuestRewards? {
        guard chainID == spotlightChainID else { return nil }
        let prev = spotlightMergesThisWeek
        spotlightMergesThisWeek += 1
        if prev < spotlightWeeklyGoal && spotlightMergesThisWeek >= spotlightWeeklyGoal {
            return QuestRewards(dogTags: 5)
        }
        return nil
    }

    // MARK: Daily login

    /// Returns `true` if this is the player's first visit today and a reward popup
    /// should be shown. Mutates login state unconditionally.
    @discardableResult
    func checkDailyLogin() -> Bool {
        let calendar = Calendar.current
        let today    = calendar.startOfDay(for: Date())
        if let lastDate = lastLoginDate {
            let lastDay = calendar.startOfDay(for: lastDate)
            let diff    = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if diff == 0 {
                loginStreakDay = loginDayIndex + 1
                return false
            } else if diff == 1 {
                loginDayIndex = (loginDayIndex + 1) % 7
                loginStreak  += 1
            } else {
                loginDayIndex = 0
                loginStreak   = 1
            }
        } else {
            loginDayIndex = 0
            loginStreak   = 1
        }
        lastLoginDate  = today
        loginStreakDay = loginDayIndex + 1
        showLoginReward = true
        return true
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        activeQuests              = s.activeQuests
        dailyChallenges           = s.dailyChallenges
        dailyChallengeStreak      = s.dailyChallengeStreak
        dailyChallengeBonusClaimed = s.dailyChallengeBonusClaimed
        spotlightMergesThisWeek   = s.spotlightMergesThisWeek
        lastSpotlightWeek         = s.lastSpotlightWeek
        lastDailyChallengeReset   = s.lastDailyChallengeReset
        lastLoginDate             = s.lastLoginDate
        loginStreak               = s.loginStreak
        loginDayIndex             = s.loginDayIndex
    }

    func capture(into s: inout GameState) {
        s.activeQuests              = activeQuests
        s.dailyChallenges           = dailyChallenges
        s.dailyChallengeStreak      = dailyChallengeStreak
        s.dailyChallengeBonusClaimed = dailyChallengeBonusClaimed
        s.spotlightMergesThisWeek   = spotlightMergesThisWeek
        s.lastSpotlightWeek         = lastSpotlightWeek
        s.lastDailyChallengeReset   = lastDailyChallengeReset
        s.lastLoginDate             = lastLoginDate
        s.loginStreak               = loginStreak
        s.loginDayIndex             = loginDayIndex
    }
}
