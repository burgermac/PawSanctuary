//
//  LiveOpsEngineTests.swift
//  PawSanctuaryTests
//
//  Phase 6a — coverage for the real primitive implementations behind
//  LiveOpsPrimitives.swift. Each primitive is tested standalone, with no
//  dependency on MergeBoardViewModel (nothing wires these in yet).
//

import XCTest
import SwiftUI
@testable import PawSanctuary

@MainActor
final class EventSchedulerTests: XCTestCase {

    private func day(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f.date(from: iso)!
    }

    private func makeEvent(id: String, start: String, end: String,
                            minLevel: Int = 0, priority: Int = 0) -> EventDefinition {
        EventDefinition(
            id: id, name: id, tagline: "", startDate: day(start), endDate: day(end),
            milestones: [], icon: "star.fill", accentColor: .blue, gradientColors: [.blue, .white],
            minLevel: minLevel, priority: priority
        )
    }

    func testActiveEventsReturnsEveryOverlappingEvent() {
        let events = [
            makeEvent(id: "weekly", start: "2026-08-01", end: "2026-08-05"),
            makeEvent(id: "pass",   start: "2026-07-15", end: "2026-08-14"),
            makeEvent(id: "past",   start: "2026-01-01", end: "2026-01-02"),
        ]
        let scheduler = EventScheduler(events: events)
        let active = Set(scheduler.activeEvents(at: day("2026-08-02")))
        XCTAssertEqual(active, ["weekly", "pass"])
    }

    func testIsEligibleGatesOnMinLevel() {
        let events = [makeEvent(id: "highLevel", start: "2026-08-01", end: "2026-08-05", minLevel: 20)]
        let scheduler = EventScheduler(events: events)
        XCTAssertFalse(scheduler.isEligible(eventID: "highLevel", playerLevel: 5))
        XCTAssertTrue(scheduler.isEligible(eventID: "highLevel", playerLevel: 20))
        XCTAssertFalse(scheduler.isEligible(eventID: "unknown", playerLevel: 999))
    }

    func testPriorityLooksUpTheDeclaredValue() {
        let events = [makeEvent(id: "a", start: "2026-08-01", end: "2026-08-05", priority: 7)]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.priority(for: "a"), 7)
        XCTAssertEqual(scheduler.priority(for: "unknown"), 0)
    }

    func testContestedSlotWinnerPicksHighestPriority() {
        let events = [
            makeEvent(id: "low",  start: "2026-08-01", end: "2026-08-05", priority: 1),
            makeEvent(id: "high", start: "2026-08-01", end: "2026-08-05", priority: 5),
        ]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.contestedSlotWinner(at: day("2026-08-02"), playerLevel: 99), "high")
    }

    func testContestedSlotWinnerExcludesIneligibleEvents() {
        let events = [
            makeEvent(id: "highPriorityLocked", start: "2026-08-01", end: "2026-08-05", minLevel: 50, priority: 10),
            makeEvent(id: "openLowPriority",    start: "2026-08-01", end: "2026-08-05", minLevel: 0,  priority: 1),
        ]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.contestedSlotWinner(at: day("2026-08-02"), playerLevel: 5), "openLowPriority")
    }

    func testContestedSlotWinnerBreaksTiesByEarliestStart() {
        let events = [
            makeEvent(id: "later",   start: "2026-08-03", end: "2026-08-10", priority: 3),
            makeEvent(id: "earlier", start: "2026-08-01", end: "2026-08-10", priority: 3),
        ]
        let scheduler = EventScheduler(events: events)
        XCTAssertEqual(scheduler.contestedSlotWinner(at: day("2026-08-04"), playerLevel: 99), "earlier")
    }

    func testContestedSlotWinnerIsNilWhenNothingQualifies() {
        let scheduler = EventScheduler(events: [])
        XCTAssertNil(scheduler.contestedSlotWinner(at: day("2026-08-02"), playerLevel: 99))
    }
}

/// A bare-minimum, valid `GameState` — empty collections, zero counters — for
/// tests that only care about round-tripping one or two fields and don't need
/// PersistenceTests.swift's fully-populated `makeSampleState()`.
private func emptyGameState() -> GameState {
    GameState(
        board: [],
        kibble: 0, dogTags: 0, score: 0,
        rescueCount: 0, ambassadors: 0, mergeCount: 0,
        secondsUntilNextKibble: 0,
        playerLevel: 1, playerXP: 0,
        unlockedChainIDs: [],
        inventory: [],
        inventoryRow1Unlocked: false, inventoryRow2Unlocked: false,
        activeQuests: [],
        dailyChallenges: [],
        dailyChallengeStreak: 0, dailyChallengeBonusClaimed: false,
        adoptionOrders: [],
        spotlightMergesThisWeek: 0,
        materialCounts: [:],
        producerStorage: [:],
        overflowProducerStorage: [],
        completedAreaIDs: [],
        areaUpgradeLevels: [:],
        spawnMultiplier: 1,
        cardInventory: [:],
        starCount: 0,
        completedAlbumIDs: [],
        pendingCardPacks: [],
        jokerCards: 0,
        rareJokerCards: 0,
        pendingOutgoingTrades: [],
        pendingIncomingTrades: [],
        cardsSentToday: 0,
        lastCardSendDate: nil,
        coins: 0, coinsEarnedThisWeek: 0,
        weeklyGoalBronzeClaimed: false, weeklyGoalSilverClaimed: false, weeklyGoalGoldClaimed: false,
        lastWeeklyGoalReset: nil,
        weeklyGoldCompletions: 0, monthlyGoalClaimed: false, lastMonthlyGoalReset: nil,
        lastLoginDate: nil,
        loginStreak: 0, loginDayIndex: 0,
        lastDailyChallengeReset: nil,
        lastSpotlightWeek: 0,
        adsWatchedToday: 0, lastAdWatchDate: nil,
        passLastClaimDate: nil,
        loyaltyClubDayIndex: 0, loyaltyClubLastClaimDate: nil, loyaltyClubStreak: 0,
        eventProgress: EventProgress(),
        inviteProgress: InviteProgress(),
        lastActiveDate: nil
    )
}

@MainActor
final class TokenWalletTests: XCTestCase {

    func testCreditAndDebitRoundTrip() {
        let wallet = TokenWallet()
        wallet.credit("rescue_rush_jun2026", 100)
        XCTAssertEqual(wallet.balance("rescue_rush_jun2026"), 100)
        XCTAssertTrue(wallet.debit("rescue_rush_jun2026", 40))
        XCTAssertEqual(wallet.balance("rescue_rush_jun2026"), 60)
    }

    func testDebitBelowZeroIsRejectedAndBalanceUnchanged() {
        let wallet = TokenWallet()
        wallet.credit("t", 10)
        XCTAssertFalse(wallet.debit("t", 11))
        XCTAssertEqual(wallet.balance("t"), 10)
    }

    func testBalanceForUnknownTokenIsZero() {
        let wallet = TokenWallet()
        XCTAssertEqual(wallet.balance("nope"), 0)
    }

    func testPurgeRemovesTheKeyEntirelyNotJustZeroesIt() {
        let wallet = TokenWallet()
        wallet.credit("t", 5)
        wallet.purge(tokensFor: "t")
        XCTAssertEqual(wallet.balance("t"), 0)
        XCTAssertFalse(wallet.wallets.keys.contains("t"), "purge should drop the key, not leave a 0 entry")
    }

    func testRestoreAndCaptureRoundTripThroughGameState() {
        var state = emptyGameState()
        state.eventTokenWallets = ["a": 3, "b": 7]

        let wallet = TokenWallet()
        wallet.restore(from: state)
        XCTAssertEqual(wallet.balance("a"), 3)
        XCTAssertEqual(wallet.balance("b"), 7)

        wallet.credit("c", 1)
        var captured = state
        wallet.capture(into: &captured)
        XCTAssertEqual(captured.eventTokenWallets, ["a": 3, "b": 7, "c": 1])
    }
}

@MainActor
final class ProgressTrackTests: XCTestCase {

    private let milestones = [
        TrackMilestone(index: 0, threshold: 10,
                        freeRewards: [OrderReward(kind: .coins, amount: 5)],
                        paidRewards: [OrderReward(kind: .coins, amount: 50)]),
        TrackMilestone(index: 1, threshold: 20,
                        freeRewards: [OrderReward(kind: .coins, amount: 10)],
                        paidRewards: [OrderReward(kind: .coins, amount: 100)]),
    ]

    private func makeTrack() -> ProgressTrack {
        ProgressTrack(registry: ["t": milestones])
    }

    func testAdvancePastThresholdMakesItClaimable() {
        let track = makeTrack()
        XCTAssertEqual(track.claimable(trackID: "t", paidLaneUnlocked: false), [])
        track.advance(trackID: "t", by: 10)
        XCTAssertEqual(track.progress(trackID: "t"), 10)
        XCTAssertEqual(track.claimable(trackID: "t", paidLaneUnlocked: false).map(\.index), [0])
    }

    func testClaimReturnsTheRightLaneAndIsIdempotent() {
        let track = makeTrack()
        track.advance(trackID: "t", by: 10)

        let free = track.claim(trackID: "t", milestone: 0, paidLane: false)
        XCTAssertEqual(free, [OrderReward(kind: .coins, amount: 5)])
        XCTAssertEqual(track.claim(trackID: "t", milestone: 0, paidLane: false), [],
                       "claiming the free lane twice should return nothing the second time")

        let paid = track.claim(trackID: "t", milestone: 0, paidLane: true)
        XCTAssertEqual(paid, [OrderReward(kind: .coins, amount: 50)])
        XCTAssertEqual(track.claim(trackID: "t", milestone: 0, paidLane: true), [],
                       "claiming the paid lane twice should return nothing the second time")
    }

    func testClaimBelowThresholdReturnsNothing() {
        let track = makeTrack()
        XCTAssertEqual(track.claim(trackID: "t", milestone: 0, paidLane: false), [])
    }

    /// A milestone whose free reward is already claimed and whose paid lane
    /// isn't unlocked must not appear in `claimable`, even past threshold.
    func testPaidLaneMilestoneInvisibleWhenLocked() {
        let track = makeTrack()
        track.advance(trackID: "t", by: 10)
        _ = track.claim(trackID: "t", milestone: 0, paidLane: false)

        XCTAssertEqual(track.claimable(trackID: "t", paidLaneUnlocked: false), [],
                       "free reward already claimed and paid lane locked -> nothing claimable")
        XCTAssertEqual(track.claimable(trackID: "t", paidLaneUnlocked: true).map(\.index), [0],
                       "same milestone reappears once the paid lane unlocks")
    }

    func testRestoreAndCaptureRoundTripThroughGameState() {
        var state = emptyGameState()
        state.progressTracks = ["t": TrackState(progress: 15, claimedFree: [0], claimedPaid: [])]

        let track = makeTrack()
        track.restore(from: state)
        XCTAssertEqual(track.progress(trackID: "t"), 15)
        XCTAssertEqual(track.claimable(trackID: "t", paidLaneUnlocked: false), [])

        track.advance(trackID: "t", by: 5)
        var captured = state
        track.capture(into: &captured)
        XCTAssertEqual(captured.progressTracks["t"]?.progress, 20)
        XCTAssertEqual(captured.progressTracks["t"]?.claimedFree, [0])
    }
}

@MainActor
final class RewardTableRegistryTests: XCTestCase {

    func testUnregisteredTableIDRollsEmptyRatherThanTrapping() {
        let registry = RewardTableRegistry(tables: [:])
        XCTAssertEqual(registry.roll(tableID: "nope"), [])
        XCTAssertEqual(registry.table("nope"), [])
    }

    func testEmptyTableRollsEmpty() {
        let registry = RewardTableRegistry(tables: ["t": []])
        XCTAssertEqual(registry.roll(tableID: "t"), [])
    }

    func testTableLookupReturnsWhatWasRegistered() {
        let entries = [WeightedReward(weight: 1, rewards: [OrderReward(kind: .coins, amount: 5)])]
        let registry = RewardTableRegistry(tables: ["t": entries])
        XCTAssertEqual(registry.table("t"), entries)
    }

    /// Statistical: roll a known-weight table many times and check each entry's
    /// observed frequency lands within a generous tolerance of weight/total.
    /// No injected RNG in this codebase's convention (see SubObjectSystem), so
    /// this is inherently probabilistic — the tolerance is wide enough to keep
    /// it non-flaky at 20,000 trials.
    func testRollDistributionMatchesDeclaredWeights() {
        let common = OrderReward(kind: .coins, amount: 1)
        let rare   = OrderReward(kind: .coins, amount: 100)
        let table: [WeightedReward] = [
            WeightedReward(weight: 90, rewards: [common]),
            WeightedReward(weight: 10, rewards: [rare]),
        ]
        let registry = RewardTableRegistry(tables: ["t": table])

        let trials = 20_000
        var commonCount = 0
        for _ in 0..<trials {
            if registry.roll(tableID: "t") == [common] { commonCount += 1 }
        }
        let observed = Double(commonCount) / Double(trials)
        XCTAssertEqual(observed, 0.9, accuracy: 0.03,
                       "expected ~90% common rolls, observed \(observed * 100)%")
    }
}

@MainActor
final class EventTimerTests: XCTestCase {

    private func makeEvent(id: String, start: Date, end: Date) -> EventDefinition {
        EventDefinition(id: id, name: id, tagline: "tag", startDate: start, endDate: end,
                        milestones: [], icon: "star.fill", accentColor: .blue,
                        gradientColors: [.blue, .white])
    }

    func testRemainingAndUrgentForAFutureEvent() {
        let future = makeEvent(id: "e", start: Date(), end: Date().addingTimeInterval(7200))
        let timer = EventTimer(events: [future])
        XCTAssertGreaterThan(timer.remaining(eventID: "e"), 7000)
        XCTAssertFalse(timer.isUrgent(eventID: "e"), "2 hours out should not read as urgent")
    }

    func testUrgentWhenLessThanAnHourRemains() {
        let soon = makeEvent(id: "e", start: Date().addingTimeInterval(-3600),
                             end: Date().addingTimeInterval(1800))
        let timer = EventTimer(events: [soon])
        XCTAssertTrue(timer.isUrgent(eventID: "e"))
    }

    func testRemainingClampsToZeroForAPastEvent() {
        let past = makeEvent(id: "e", start: Date(timeIntervalSince1970: 0),
                             end: Date(timeIntervalSince1970: 1))
        let timer = EventTimer(events: [past])
        XCTAssertEqual(timer.remaining(eventID: "e"), 0)
        // isUrgent is `timeRemaining < 3600` (EventDefinition, pre-existing) --
        // 0 remaining still satisfies that, so an expired event reads as urgent.
        XCTAssertTrue(timer.isUrgent(eventID: "e"))
    }

    func testUnknownEventIDIsNotRemainingOrUrgentRatherThanTrapping() {
        let timer = EventTimer(events: [])
        XCTAssertEqual(timer.remaining(eventID: "nope"), 0)
        XCTAssertFalse(timer.isUrgent(eventID: "nope"))
    }
}

@MainActor
final class OfferHookRegistryTests: XCTestCase {

    func testRegisterAndActiveOffers() {
        let hook = OfferHookRegistry()
        hook.registerOffer(eventID: "e1", offerID: "o1")
        hook.registerOffer(eventID: "e1", offerID: "o2")
        hook.registerOffer(eventID: "e2", offerID: "o3")
        XCTAssertEqual(Set(hook.activeOffers()), ["o1", "o2", "o3"])
    }

    func testRegisteringTheSameOfferTwiceDoesNotDuplicate() {
        let hook = OfferHookRegistry()
        hook.registerOffer(eventID: "e1", offerID: "o1")
        hook.registerOffer(eventID: "e1", offerID: "o1")
        XCTAssertEqual(hook.activeOffers(), ["o1"])
    }

    func testUnregisterRemovesOnlyThatEventsOffers() {
        let hook = OfferHookRegistry()
        hook.registerOffer(eventID: "e1", offerID: "o1")
        hook.registerOffer(eventID: "e2", offerID: "o2")
        hook.unregister(offersFor: "e1")
        XCTAssertEqual(hook.activeOffers(), ["o2"])
    }
}

@MainActor
final class ParallelBoardStubTests: XCTestCase {

    func testMakeBoardIsStableForTheSameEventID() {
        let stub = ParallelBoardStub()
        let first = stub.makeBoard(eventID: "e1")
        let second = stub.makeBoard(eventID: "e1")
        XCTAssertEqual(first, second)
    }

    func testMakeBoardIsDistinctAcrossEventIDs() {
        let stub = ParallelBoardStub()
        let a = stub.makeBoard(eventID: "e1")
        let b = stub.makeBoard(eventID: "e2")
        XCTAssertNotEqual(a, b)
    }

    func testTeardownRemovesTheBoard() {
        let stub = ParallelBoardStub()
        let first = stub.makeBoard(eventID: "e1")
        stub.teardownBoard(eventID: "e1")
        let second = stub.makeBoard(eventID: "e1")
        XCTAssertNotEqual(first, second, "a fresh makeBoard after teardown should mint a new UUID")
    }

    func testEnergyBalanceIsAlwaysZero() {
        let stub = ParallelBoardStub()
        _ = stub.makeBoard(eventID: "e1")
        XCTAssertEqual(stub.energyBalance(eventID: "e1"), 0)
        XCTAssertEqual(stub.energyBalance(eventID: "unknown"), 0)
    }
}
