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
