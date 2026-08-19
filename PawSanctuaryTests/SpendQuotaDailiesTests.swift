//
//  SpendQuotaDailiesTests.swift
//  PawSanctuaryTests
//
//  D6 (Spec_SpendQuotaDailies.md) Task 3.1 — QuestGoal.spendCurrency's generic
//  switches (targetCount, description, icon, iconColor, dedupeKey). Both
//  currencies are covered since both generate in v1 (spec §2).
//

import XCTest
@testable import PawSanctuary

final class SpendQuotaDailiesGoalTests: XCTestCase {

    func testTargetCountReturnsTheSpendAmount() {
        XCTAssertEqual(QuestGoal.spendCurrency(.kibble, count: 40).targetCount, 40)
        XCTAssertEqual(QuestGoal.spendCurrency(.dogTags, count: 8).targetCount, 8)
    }

    func testDescriptionNamesTheCurrencyAndAmount() {
        XCTAssertEqual(QuestGoal.spendCurrency(.kibble, count: 40).description, "Spend 40 Kibble")
        XCTAssertEqual(QuestGoal.spendCurrency(.dogTags, count: 8).description, "Spend 8 Dog Tags")
    }

    func testIconAndColorMatchShopViewsExistingIconographyPerCurrency() {
        let kibble = QuestGoal.spendCurrency(.kibble, count: 40)
        XCTAssertEqual(kibble.icon, "pawprint")
        XCTAssertEqual(kibble.iconColor, .green)

        let dogTags = QuestGoal.spendCurrency(.dogTags, count: 8)
        XCTAssertEqual(dogTags.icon, "tag.fill")
        XCTAssertEqual(dogTags.iconColor, .blue)
    }

    func testDedupeKeyDiffersByCurrency() {
        let kibbleKey  = QuestGoal.spendCurrency(.kibble, count: 40).dedupeKey
        let dogTagsKey = QuestGoal.spendCurrency(.dogTags, count: 8).dedupeKey
        XCTAssertEqual(kibbleKey, "spendCurrency:kibble")
        XCTAssertEqual(dogTagsKey, "spendCurrency:dogTags")
        XCTAssertNotEqual(kibbleKey, dogTagsKey)
    }

    /// Guards the invariant every other QuestGoal case already has to respect:
    /// two instances differing only by count still share a dedupeKey (dedup is
    /// about goal *shape*, not the rolled count) — matters if this case is
    /// ever reused for standing quests (spec §2), even though nothing
    /// generates it there yet.
    func testDedupeKeyIgnoresCount() {
        XCTAssertEqual(QuestGoal.spendCurrency(.kibble, count: 40).dedupeKey,
                       QuestGoal.spendCurrency(.kibble, count: 999).dedupeKey)
    }
}

@MainActor
final class SpendQuotaDailiesProducerNeededTests: XCTestCase {

    /// MergeBoardViewModel.producerIsNeeded(_:by:) (private) is exercised
    /// indirectly through retirableProducers, which is the real, public
    /// consequence of that switch being exhaustive. A spendCurrency goal
    /// isn't tied to any specific producer (spec §2's comment on this exact
    /// switch), so a producer with no other goal referencing it should still
    /// show up as retirable — proving the new case falls into the same
    /// "doesn't block retirement" bucket as mergeAny/reachTier, not silently
    /// falling through to some other behavior.
    func testASpendGoalAloneDoesNotBlockProducerRetirement() {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.setProducer(ProducerTile(level: .rescueCrate), at: GridPosition(row: 0, col: 0))
        vm.quests.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy),
        ]

        XCTAssertTrue(vm.retirableProducers.contains { $0.position == GridPosition(row: 0, col: 0) },
                      "a spendCurrency-only goal must not keep a producer from being offered for retirement")
    }
}

/// Task 3.2 — QuestCoordinator.updateDailyChallengesAfterSpend, the first
/// daily-challenge update in the codebase that advances progress by a
/// variable amount rather than +1 per discrete event.
@MainActor
final class SpendQuotaDailiesProgressTests: XCTestCase {

    func testAdvancesByTheFullAmountNotOne() {
        let coordinator = QuestCoordinator()
        coordinator.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy),
        ]

        coordinator.updateDailyChallengesAfterSpend(kind: .kibble, amount: 15)

        XCTAssertEqual(coordinator.dailyChallenges[0].progress, 15,
                       "must add the real spend amount, not +1 the way every other daily-challenge update does")
    }

    func testOnlyAdvancesSlotsMatchingTheSpentCurrency() {
        let coordinator = QuestCoordinator()
        coordinator.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy),
            DailyChallenge(goal: .spendCurrency(.dogTags, count: 8), difficulty: .medium),
        ]

        coordinator.updateDailyChallengesAfterSpend(kind: .dogTags, amount: 5)

        XCTAssertEqual(coordinator.dailyChallenges[0].progress, 0, "a dog-tag spend must not advance a kibble slot")
        XCTAssertEqual(coordinator.dailyChallenges[1].progress, 5)
    }

    func testIgnoresNonSpendGoals() {
        let coordinator = QuestCoordinator()
        coordinator.dailyChallenges = [DailyChallenge(goal: .mergeAny(count: 3), difficulty: .easy)]

        coordinator.updateDailyChallengesAfterSpend(kind: .kibble, amount: 100)

        XCTAssertEqual(coordinator.dailyChallenges[0].progress, 0)
    }

    func testSkipsAlreadyCompleteSlots() {
        let coordinator = QuestCoordinator()
        coordinator.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy, progress: 40),
        ]

        coordinator.updateDailyChallengesAfterSpend(kind: .kibble, amount: 10)

        XCTAssertEqual(coordinator.dailyChallenges[0].progress, 40,
                       "an already-complete slot must not keep accumulating")
    }
}

/// Task 3.2 — MergeBoardViewModel.updateAllAfterSpend, the chokepoint every
/// real spend site (Task 3.3) will call into.
@MainActor
final class SpendQuotaDailiesChokepointTests: XCTestCase {

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        return vm
    }

    func testAdvancesTheMatchingDailyChallengeToCompletion() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy),
        ]

        vm.updateAllAfterSpend(kind: .kibble, amount: 40)

        XCTAssertTrue(vm.quests.dailyChallenges[0].isComplete)
    }

    func testCompletingAllThreeViaSpendStillPaysTheExistingBonus() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(.kibble, count: 40), difficulty: .easy),
            DailyChallenge(goal: .spendCurrency(.kibble, count: 50), difficulty: .medium),
            DailyChallenge(goal: .spendCurrency(.kibble, count: 65), difficulty: .hard),
        ]
        let dogTagsBefore = vm.dogTags
        XCTAssertFalse(vm.quests.dailyChallengeBonusClaimed)

        vm.updateAllAfterSpend(kind: .kibble, amount: 65)

        XCTAssertTrue(vm.quests.dailyChallengeBonusClaimed)
        XCTAssertGreaterThan(vm.dogTags, dogTagsBefore,
                             "the existing all-three-complete bonus (spec §2) must still pay out — no new reward mechanic")
    }
}

/// Task 3.3 — every real spend site actually calls updateAllAfterSpend with
/// the right currency and the right amount, end to end through the public
/// action a player would trigger, not just the chokepoint in isolation
/// (already covered above). No existing test file covered any of these nine
/// functions before this task, so setup is built from scratch per site.
@MainActor
final class SpendQuotaDailiesWiringTests: XCTestCase {

    /// A viewmodel with a full empty unlocked board and a single easy daily
    /// challenge for the given currency, generous enough (999) that no
    /// individual site's spend could complete it — keeps every test focused
    /// on "did progress advance by the right amount," not completion/bonus
    /// interaction (already covered by SpendQuotaDailiesChokepointTests).
    private func makeViewModel(dailyGoalCurrency: RewardKind) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        // The board setter doesn't recompute BoardStateManager's cached
        // emptyUnlockedCells on its own (see freshStart()'s own comment on
        // this exact gotcha) — without this, buyProducer/activateProducer
        // see a stale empty cache and silently no-op via their "nowhere to
        // place it" guard, never reaching the spend at all.
        vm.boardState.recalc()
        vm.quests.dailyChallenges = [
            DailyChallenge(goal: .spendCurrency(dailyGoalCurrency, count: 999), difficulty: .easy),
        ]
        return vm
    }

    private func progress(_ vm: MergeBoardViewModel) -> Int { vm.quests.dailyChallenges[0].progress }

    func testBuyProducerAdvancesTheKibbleGoalByItsDogTagCost() {
        // buyProducer spends dog tags, not kibble — this confirms the wiring
        // uses .dogTags (not accidentally .kibble) by pointing the daily
        // goal at dog tags and expecting real progress.
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = 100

        vm.buyProducer(.rescueCrate)

        XCTAssertEqual(progress(vm), ProducerLevel.rescueCrate.dogTagCost)
    }

    func testPaidRefreshDogTagStoreAdvancesTheDogTagGoal() {
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = 100

        XCTAssertTrue(vm.paidRefreshDogTagStore())

        XCTAssertEqual(progress(vm), dogTagStoreRefreshCost)
    }

    func testPurchaseDogTagStoreSlotAdvancesByTheSlotsActualPrice() {
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = 100
        let slot = DogTagStoreSlot(chainID: ContentRegistry.animalChainID(.dog), tier: 0, priceDogTags: 33)
        vm.dogTagStore.slots = [slot]

        XCTAssertTrue(vm.purchaseDogTagStoreSlot(slot))

        XCTAssertEqual(progress(vm), 33)
    }

    func testPurchaseWildcardAdvancesByTheWildcardCost() {
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = wildcardCostDogTags

        XCTAssertTrue(vm.purchaseWildcard())

        XCTAssertEqual(progress(vm), wildcardCostDogTags)
    }

    func testPopBubbleWithDogTagsAdvancesByTheTierDependentCost() {
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = 100
        let pos = GridPosition(row: 0, col: 0)
        let item = BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: 2,
                             bubbledAt: Date().timeIntervalSince1970)
        vm.boardState.setItem(item, at: pos)
        let expectedCost = bubblePopDogTagCost(tier: 2)

        vm.popBubbleWithDogTags(at: pos)

        XCTAssertEqual(progress(vm), expectedCost)
    }

    func testCrackPiggyBankAdvancesByItsFixedCost() {
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = 100
        vm.piggyBankCoins = piggyBankCap   // isPiggyBankFull

        XCTAssertTrue(vm.crackPiggyBank())

        XCTAssertEqual(progress(vm), piggyBankCrackCostDogTags)
    }

    func testClaimOrSkipFreeChestOnThePaidSkipPathAdvancesBySkipCost() {
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.kibbleEngine.dogTags = 100
        vm.freeChestReadyAt = Date().addingTimeInterval(3600)   // not ready -> forces the paid-skip branch

        XCTAssertTrue(vm.claimOrSkipFreeChest())

        XCTAssertEqual(progress(vm), freeChestSkipCostDogTags)
    }

    func testClaimingAReadyFreeChestForFreeDoesNotAdvanceTheDogTagGoal() {
        // The free (not skipped) path must NOT count as a spend.
        let vm = makeViewModel(dailyGoalCurrency: .dogTags)
        vm.freeChestReadyAt = .distantPast   // already ready — free path

        XCTAssertTrue(vm.claimOrSkipFreeChest())

        XCTAssertEqual(progress(vm), 0)
    }

    func testSkipOrderAdvancesTheKibbleGoalByTheSkipCost() {
        let vm = makeViewModel(dailyGoalCurrency: .kibble)
        vm.kibbleEngine.kibble = 100
        vm.adoptionBoardCoordinator.adoptionOrders = [
            AdoptionOrder(familyIndex: 0, wantedChainID: ContentRegistry.animalChainID(.dog),
                         wantedTier: 0, wantedCount: 1),
        ]

        vm.skipOrder(at: 0)

        XCTAssertEqual(progress(vm), adoptionSkipCost)
    }

    func testFinishSpawnViaActivateProducerAdvancesTheKibbleGoalBySpawnCost() {
        let vm = makeViewModel(dailyGoalCurrency: .kibble)
        vm.kibbleEngine.kibble = 100
        let pos = GridPosition(row: 0, col: 0)
        vm.boardState.setProducer(ProducerTile(level: .rescueCrate), at: pos)

        vm.activateProducer(at: pos)

        XCTAssertGreaterThan(progress(vm), 0, "activating a producer must spend kibble and advance the kibble goal")
    }
}

/// Task 3.4 — the two new DailyChallengeAnchor.spendCurrency pool entries in
/// pickDailyChallengeAnchor/generateDailyChallenges. Mirrors the existing
/// statistical style QuestCoordinatorTests.swift already uses for anchor
/// reachability (e.g. testDailyChallengeReachTierAnchorCanTargetTopThreeTiers)
/// rather than trying to force a specific anchor deterministically — the
/// picker is private and genuinely random by design.
@MainActor
final class SpendQuotaDailiesAnchorTests: XCTestCase {

    private func anySpendCurrency(_ goal: QuestGoal) -> RewardKind? {
        if case .spendCurrency(let kind, _) = goal { return kind }
        return nil
    }

    func testBothCurrenciesAreReachableAsAnchors() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        var seenKinds: Set<RewardKind> = []
        for _ in 0..<500 {
            coordinator.generateDailyChallenges(unlockedChainIDs: [dogID])
            if let kind = anySpendCurrency(coordinator.dailyChallenges[0].goal) {
                seenKinds.insert(kind)
            }
        }
        XCTAssertEqual(seenKinds, [.kibble, .dogTags],
                       "both currencies must be independently pickable, per spec §3.4's two-separate-pool-entries design")
    }

    func testWhenASpendAnchorIsPickedAllThreeSlotsShareTheSameCurrency() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        var checkedAtLeastOneSpendDay = false
        for _ in 0..<500 {
            coordinator.generateDailyChallenges(unlockedChainIDs: [dogID])
            guard let easyKind = anySpendCurrency(coordinator.dailyChallenges[0].goal) else { continue }
            checkedAtLeastOneSpendDay = true
            XCTAssertEqual(anySpendCurrency(coordinator.dailyChallenges[1].goal), easyKind,
                           "confirmed §3.4: all three slots share one spend anchor, not a mix")
            XCTAssertEqual(anySpendCurrency(coordinator.dailyChallenges[2].goal), easyKind)
        }
        XCTAssertTrue(checkedAtLeastOneSpendDay, "test is meaningless if a spend anchor was never picked in 500 tries")
    }

    func testEasySlotUsesTheConfirmedSection4SeedForEachCurrency() {
        let coordinator = QuestCoordinator()
        let dogID = ContentRegistry.animalChainID(.dog)
        for _ in 0..<500 {
            coordinator.generateDailyChallenges(unlockedChainIDs: [dogID])
            guard let kind = anySpendCurrency(coordinator.dailyChallenges[0].goal) else { continue }
            let expected = kind == .kibble ? 40 : 8
            XCTAssertEqual(coordinator.dailyChallenges[0].goal.targetCount, expected,
                           "easy-slot seed must match spec §4 exactly (40 kibble / 8 dog tags)")
        }
    }
}
