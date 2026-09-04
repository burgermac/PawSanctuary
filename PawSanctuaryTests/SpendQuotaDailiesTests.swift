//
//  SpendQuotaDailiesTests.swift
//  PawSanctuaryTests
//
//  D6 (Spec_SpendQuotaDailies.md) Task 3.1 — QuestGoal.spendCurrency's generic
//  switches (targetCount, description, icon, iconColor, dedupeKey).
//
//  **Rescoped by Spec_DailyHandInTasks.md (4 Sep 2026).** Daily challenges are
//  no longer counted-event goals, so `QuestGoal.spendCurrency` now reaches the
//  player only through standing quests (the D6 follow-up,
//  Spec_StandingQuestSpendGoals.md). The goal-shape tests below are unchanged
//  and still load-bearing. What went with the daily half:
//
//   - `SpendQuotaDailiesProgressTests` — tested
//     `updateDailyChallengesAfterSpend`, which no longer exists. The standing-
//     quest equivalent (`updateQuestsAfterSpend`) is covered in
//     `StandingQuestSpendGoalsTests`.
//   - `SpendQuotaDailiesAnchorTests` — tested the shared-anchor daily pool,
//     removed with the anchor mechanic itself (spec D-C).
//   - `SpendQuotaDailiesChokepointTests` — the daily half is replaced by
//     `DailyHandInTasksTests`\' claim-driven sweep test.
//
//  `SpendQuotaDailiesWiringTests` survives intact and is the reason this file
//  still matters: it is the only coverage that every one of the nine real
//  spend sites actually calls `updateAllAfterSpend`. It now measures progress
//  on a standing quest rather than a daily challenge — the chokepoint being
//  proved is the same one.
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

/// Task 3.3 — every real spend site actually calls updateAllAfterSpend with
/// the right currency and the right amount, end to end through the public
/// action a player would trigger, not just the chokepoint in isolation
/// (already covered above). No existing test file covered any of these nine
/// functions before this task, so setup is built from scratch per site.
@MainActor
final class SpendQuotaDailiesWiringTests: XCTestCase {

    /// A viewmodel with a full empty unlocked board and a single standing
    /// quest carrying a spend goal for the given currency, generous enough
    /// (999) that no individual site's spend could complete it — keeps every
    /// test focused on "did progress advance by the right amount," not
    /// completion/reward interaction.
    ///
    /// Was a daily challenge until Spec_DailyHandInTasks.md; the chokepoint
    /// under test (`MergeBoardViewModel.updateAllAfterSpend`) is unchanged, and
    /// standing quests are now the only consumer of `spendCurrency`.
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
        vm.quests.activeQuests = [
            Quest(goal: .spendCurrency(dailyGoalCurrency, count: 999), difficulty: .easy,
                  dogTagReward: 1, kibbleReward: 2),
        ]
        return vm
    }

    private func progress(_ vm: MergeBoardViewModel) -> Int { vm.quests.activeQuests[0].progress }

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
