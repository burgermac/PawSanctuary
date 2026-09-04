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
                // D6 follow-up (Spec_StandingQuestSpendGoals.md §3.1/§4) — both
                // currencies, unconditional, at every difficulty: kibble and
                // dog tags both exist from the start of a save, unlike the
                // reachTier goals above which are conditional on real
                // unlock progression.
                .spendCurrency(.kibble, count: 40),
                .spendCurrency(.dogTags, count: 8),
            ]
            if hasSupply { pool.append(.reachTier(.supply, tier: 1, count: 2)) }
            pool = pool.filter { !excluding.contains($0.dedupeKey) }
            goal = pool.randomElement() ?? .mergeAny(count: 3)

        case .medium:
            var pool: [QuestGoal] = [
                .mergeAny(count: 6),
                .mergeInChain(animalID, count: 4),
                .spawnBase(count: 8),
                .spendCurrency(.kibble, count: 70),
                .spendCurrency(.dogTags, count: 14),
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
                .spendCurrency(.kibble, count: 110),
                .spendCurrency(.dogTags, count: 22),
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
                .spendCurrency(.kibble, count: 220),
                .spendCurrency(.dogTags, count: 44),
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

    func updateQuestsAfterSpend(kind: RewardKind, amount: Int) {
        for i in activeQuests.indices {
            guard !activeQuests[i].isComplete else { continue }
            if case .spendCurrency(let k, _) = activeQuests[i].goal, k == kind {
                activeQuests[i].progress += amount
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

    func checkDailyChallengeReset(unlockedAnimalChainIDs: [ChainID], playerLevel: Int) {
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
        generateDailyChallenges(unlockedAnimalChainIDs: unlockedAnimalChainIDs,
                                playerLevel: playerLevel)
    }

    // ── Daily hand-in tasks (Spec_DailyHandInTasks.md) ──────────────
    //
    // These used to be counted-event goals sharing one "anchor" shape, so that
    // finishing the easy one left the medium one 60-90% done — the deliberate
    // near-miss stagger of Merge2_Reference_Blueprint.md §5 /
    // Gap_Analysis_Round2.md 3.1. That stagger is **gone for dailies**, an
    // explicit override recorded as D-C in Spec_DailyHandInTasks.md: three
    // baskets of freely-mixed creatures at mixed stages cannot share an anchor,
    // and the reference titles' own daily tasks do not stagger either. It still
    // operates on standing quests and on the fixed order-slot difficulty
    // spread. If it is ever wanted back here, nest the baskets (task 2 ⊃ task
    // 1) — but note that claiming task 1 then eats task 2's pieces.

    /// Rolls one task's basket: distinct creatures from the player's own
    /// unlocked families, at stages drawn from the shared order tier bands so
    /// this demand channel stays comparable with adoption orders in
    /// `EconomySimulation`.
    private func generateDailyTask(unlockedAnimalChainIDs: [ChainID],
                                   playerLevel: Int,
                                   difficulty: QuestDifficulty) -> DailyChallenge {
        let fallback  = ContentRegistry.animalChainID(.dog)
        let pool      = unlockedAnimalChainIDs.isEmpty ? [fallback] : unlockedAnimalChainIDs
        let band      = difficulty.dailyTaskOrderBand
        let maxTier   = maxAchievableOrderTier(forPlayerLevel: playerLevel)
        let lineCount = AdoptionBoard.rollLineCount(difficulty: band)

        // Line 0 carries the task's headline stage; further lines draw one band
        // easier, exactly as order baskets do — the cost of a basket should be
        // board space and attention, not a tripled kibble bill.
        let rolled: [DailyTaskLine] = (0..<lineCount).map { index in
            let lineBand = index == 0 ? band : band.basketFillerDifficulty
            let tier = min(AdoptionBoard.rollTier(difficulty: lineBand), maxTier)
            return DailyTaskLine(chainID: pool.randomElement() ?? fallback,
                                 tier: tier, count: 1)
        }

        // Collapse duplicate (chain, stage) pairs into one line with a higher
        // count. A card listing the same creature twice would render two
        // identical slots and read as two separate asks.
        var lines: [DailyTaskLine] = []
        for line in rolled {
            if let i = lines.firstIndex(where: { $0.key == line.key }) {
                lines[i].count += line.count
            } else {
                lines.append(line)
            }
        }

        let coins = dailyTaskCoinPayout(
            lines: lines,
            spreadFactor: Double.random(in: (1 - orderCoinSpread)...(1 + orderCoinSpread)))
        return DailyChallenge(lines: lines, difficulty: difficulty, coinReward: coins)
    }

    func generateDailyChallenges(unlockedAnimalChainIDs: [ChainID], playerLevel: Int) {
        dailyChallenges = dailyTaskSlotDifficulties.map {
            generateDailyTask(unlockedAnimalChainIDs: unlockedAnimalChainIDs,
                              playerLevel: playerLevel, difficulty: $0)
        }
    }

    /// Marks one task claimed and returns it so the caller can surrender the
    /// pieces and pay out. Returns `nil` if it is already claimed or the board
    /// no longer holds what it asks for — the stock check runs against the live
    /// census passed in, never against anything cached on the card.
    func claimDailyTask(id: UUID, census: [ChainTierKey: Int]) -> DailyChallenge? {
        guard let idx = dailyChallenges.firstIndex(where: { $0.id == id }),
              !dailyChallenges[idx].isClaimed,
              dailyChallenges[idx].isStocked(census: census) else { return nil }
        dailyChallenges[idx].isClaimed = true
        return dailyChallenges[idx]
    }

    /// Called after each daily task claim. If all three are now claimed and the
    /// sweep bonus hasn't been paid yet, returns a reward bundle for MBVM to apply.
    func checkAllDailyChallengesComplete(coinsPerDailyComplete: Int) -> QuestRewards? {
        guard !dailyChallengeBonusClaimed,
              !dailyChallenges.isEmpty,
              dailyChallenges.allSatisfy({ $0.isClaimed }) else { return nil }
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
