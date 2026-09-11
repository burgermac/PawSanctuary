//
//  PlaytestMetricsTests.swift
//  PawSanctuaryTests
//
//  Local play instrumentation (schema v41) — the counters that close
//  `Spec_DailyHandInTasks.md` §5c's "no playtest data" gap.
//
//  Three things can independently go wrong here: the arithmetic that turns
//  counters into rates, the wiring that increments them from real gameplay, and
//  the app-side copies of the model's assumptions drifting from the model.
//

import XCTest
@testable import PawSanctuary

// ============================================================
// MARK: - THE MODEL/APP BOUNDARY
// ============================================================

/// `PlaytestBaseline` restates `EconomySimulation`'s assumptions on the app side
/// so the debug panel can show measured-against-assumed without the app
/// depending on the test target. They are copies, and copies drift — these tests
/// are the only thing stopping the panel quietly lying to whoever reads it.
@MainActor
final class PlaytestBaselineAgreementTests: XCTestCase {

    func testQuestClaimsPerDayMatchesTheModel() {
        XCTAssertEqual(PlaytestBaseline.questClaimsPerDay,
                       EconomySimulation.questClaimsPerDay, accuracy: 0.001)
    }

    func testToolboxesPerQuestClaimMatchesTheModel() {
        // Level 60: past every difficulty cap in `generateQuest`, which is the
        // regime the baseline describes.
        XCTAssertEqual(PlaytestBaseline.toolboxesPerQuestClaim,
                       EconomySimulation.expectedToolboxesPerQuestClaim(level: 60),
                       accuracy: 0.001)
    }

    func testSaturatedMaterialRateMatchesTheModel() {
        XCTAssertEqual(PlaytestBaseline.materialUnitsPerDaySaturated,
                       EconomySimulation.materialUnitsPerDay(level: 60), accuracy: 0.5)
        // And it really is saturated — the baseline is a single number only
        // because the faucet is flat from L20.
        XCTAssertEqual(EconomySimulation.materialUnitsPerDay(level: 20),
                       EconomySimulation.materialUnitsPerDay(level: 60), accuracy: 0.001)
    }

    func testDailyTaskClaimsPerDayMatchesTheSlotCount() {
        XCTAssertEqual(PlaytestBaseline.dailyTaskClaimsPerDay,
                       Double(dailyTaskSlotDifficulties.count), accuracy: 0.001)
    }

    func testQuestMixMatchesTheGenerator() {
        let coordinator = QuestCoordinator()
        let dog = ContentRegistry.animalChainID(.dog)
        var counts: [QuestDifficulty: Int] = [:]
        let samples = 20_000
        for _ in 0..<samples {
            counts[coordinator.generateQuest(unlockedChainIDs: [dog], playerLevel: 60).difficulty,
                   default: 0] += 1
        }
        for (difficulty, share) in PlaytestBaseline.questMix {
            let measured = Double(counts[difficulty] ?? 0) / Double(samples)
            XCTAssertEqual(measured, share, accuracy: 0.02,
                           "\(difficulty.rawValue): generator rolls \(measured), baseline says \(share)")
        }
    }

    /// The app has to duplicate the tier-0 conversion because the model lives in
    /// the test target. Four characters of arithmetic, but if they ever disagree
    /// the recorded faucet and the modelled faucet are in different units.
    func testMaterialUnitConversionAgreesAcrossTargets() {
        for tier in 0...5 {
            XCTAssertEqual(PlaytestMetrics.materialUnits(tier: tier),
                           EconomySimulation.materialUnits(tier: tier),
                           "tier \(tier) converts differently in the app than in the model")
        }
    }
}

// ============================================================
// MARK: - ARITHMETIC
// ============================================================

@MainActor
final class PlaytestMetricsArithmeticTests: XCTestCase {

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Date()) ?? Date()
    }

    /// An absent measurement is not a measurement of zero. Reporting 0.0 for
    /// "no data yet" would read as play contradicting the model.
    func testRatesAreNilRatherThanZeroBeforeAnyData() {
        let m = PlaytestMetrics()
        XCTAssertNil(m.measuredQuestClaimsPerDay)
        XCTAssertNil(m.measuredMaterialUnitsPerDay)
        XCTAssertNil(m.measuredToolboxesPerQuestClaim)
        XCTAssertNil(m.measuredStashRate)
        XCTAssertNil(m.measuredBoardOccupancy)
        XCTAssertNil(m.measuredQuestMix)
    }

    func testActiveDaysCountDistinctDaysNotEvents() {
        var m = PlaytestMetrics()
        for _ in 0..<5 { m.recordQuestClaim(.easy, on: day(0)) }
        XCTAssertEqual(m.activeDayCount, 1, "five claims in one day is one active day")

        m.recordQuestClaim(.easy, on: day(1))
        m.recordQuestClaim(.easy, on: day(2))
        XCTAssertEqual(m.activeDayCount, 3)
        XCTAssertEqual(m.totalQuestClaims, 7)
        XCTAssertEqual(m.measuredQuestClaimsPerDay ?? 0, 7.0 / 3.0, accuracy: 0.001)
    }

    func testFirstAndLastActiveDayBracketTheRun() {
        var m = PlaytestMetrics()
        m.recordQuestClaim(.easy, on: day(-10))
        m.recordQuestClaim(.hard, on: day(0))
        XCTAssertEqual(m.firstActiveDay, PlaytestMetrics.dayStamp(day(-10)))
        XCTAssertEqual(m.lastActiveDay, PlaytestMetrics.dayStamp(day(0)))
    }

    func testQuestMixIsShareOfClaimsByDifficulty() throws {
        var m = PlaytestMetrics()
        for _ in 0..<9 { m.recordQuestClaim(.easy) }
        for _ in 0..<6 { m.recordQuestClaim(.medium) }
        for _ in 0..<4 { m.recordQuestClaim(.hard) }
        m.recordQuestClaim(.legendary)

        let mix = try XCTUnwrap(m.measuredQuestMix)
        XCTAssertEqual(mix[.easy] ?? 0, 0.45, accuracy: 0.001)
        XCTAssertEqual(mix[.medium] ?? 0, 0.30, accuracy: 0.001)
        XCTAssertEqual(mix[.hard] ?? 0, 0.20, accuracy: 0.001)
        XCTAssertEqual(mix[.legendary] ?? 0, 0.05, accuracy: 0.001)
    }

    func testBoardSamplingIsCappedAtOnePerDay() {
        var m = PlaytestMetrics()
        XCTAssertTrue(m.recordBoardSample(spawnersOnBoard: 4, spawnersStashed: 1,
                                          occupiedCells: 20, unlockedCells: 35, on: day(0)))
        XCTAssertFalse(m.recordBoardSample(spawnersOnBoard: 99, spawnersStashed: 99,
                                           occupiedCells: 99, unlockedCells: 99, on: day(0)),
                       "a second launch the same day must not re-weight the day")
        XCTAssertEqual(m.boardSampleCount, 1)
        XCTAssertEqual(m.spawnersOnBoardTotal, 4, "the rejected sample must not land")

        XCTAssertTrue(m.recordBoardSample(spawnersOnBoard: 6, spawnersStashed: 3,
                                          occupiedCells: 30, unlockedCells: 35, on: day(1)))
        XCTAssertEqual(m.boardSampleCount, 2)
        XCTAssertEqual(m.measuredSpawnersOnBoard ?? 0, 5.0, accuracy: 0.001)
        XCTAssertEqual(m.measuredStashRate ?? 0, 4.0 / 14.0, accuracy: 0.001)
        XCTAssertEqual(m.measuredBoardOccupancy ?? 0, 50.0 / 70.0, accuracy: 0.001)
    }

    func testMaterialUnitsIgnoreNonMaterialItemsInALot() {
        let wood = BoardItem(chainID: ContentRegistry.woodChainID, tier: 3)   // 8 units
        let dog  = BoardItem(chainID: ContentRegistry.animalChainID(.dog), tier: 5)
        XCTAssertEqual(PlaytestMetrics.materialUnits(in: [wood, dog]), 8,
                       "an animal in the lot is not material and absorbMaterialItems drops it too")
    }

    func testTheSevenDayFloorGatesInterpretation() {
        var m = PlaytestMetrics()
        for offset in 0..<6 { m.recordQuestClaim(.easy, on: day(-offset)) }
        XCTAssertFalse(m.hasEnoughDataToInterpret)
        m.recordQuestClaim(.easy, on: day(-6))
        XCTAssertTrue(m.hasEnoughDataToInterpret)
    }
}

// ============================================================
// MARK: - WIRING
// ============================================================

/// The counters are only worth anything if real gameplay actually increments
/// them. Driven through the same public entry points a player triggers.
@MainActor
final class PlaytestMetricsWiringTests: XCTestCase {

    private let dog = ContentRegistry.animalChainID(.dog)

    private func makeViewModel() -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.progression.playerLevel = 45
        return vm
    }

    func testClaimingAQuestRecordsItsDifficulty() {
        let vm = makeViewModel()
        vm.quests.activeQuests = [
            Quest(goal: .mergeAny(count: 1), difficulty: .hard, progress: 1,
                  dogTagReward: 1, kibbleReward: 1),
        ]
        vm.claimQuest(id: vm.quests.activeQuests[0].id)

        XCTAssertEqual(vm.playtestMetrics.questClaimsHard, 1)
        XCTAssertEqual(vm.playtestMetrics.totalQuestClaims, 1)
        XCTAssertEqual(vm.playtestMetrics.activeDayCount, 1)
    }

    /// A hard quest places two toolboxes; both must be counted, and the material
    /// they carry must be banked in the same units the model uses.
    func testClaimingAQuestRecordsToolboxesAndTheirMaterial() {
        let vm = makeViewModel()
        vm.quests.activeQuests = [
            Quest(goal: .mergeAny(count: 1), difficulty: .hard, progress: 1,
                  dogTagReward: 1, kibbleReward: 1),
        ]
        vm.claimQuest(id: vm.quests.activeQuests[0].id)

        XCTAssertEqual(vm.playtestMetrics.toolboxesPlaced, 2,
                       "a hard quest places two toolboxes")
        // Material banks on absorb, not on placement — the lots are queued.
        XCTAssertEqual(vm.playtestMetrics.materialUnitsAbsorbed, 0)

        for row in 0..<boardRows {
            for col in 0..<7 {
                let pos = GridPosition(row: row, col: col)
                if vm.boardState.item(at: pos)?.chainID == ContentRegistry.toolboxChainID {
                    vm.absorbToolbox(at: pos)
                }
            }
        }
        XCTAssertGreaterThan(vm.playtestMetrics.materialUnitsAbsorbed, 0,
                             "absorbing the toolboxes must bank their tier-0 equivalents")
    }

    func testClaimingADailyTaskIsRecordedAndTheSweepIsFlaggedOnlyOnTheLast() {
        let vm = makeViewModel()
        vm.quests.dailyChallenges = (0..<3).map { i in
            DailyChallenge(lines: [DailyTaskLine(chainID: dog, tier: 0, count: 1)],
                           difficulty: [.easy, .medium, .hard][i], coinReward: 20)
        }
        for col in 0..<3 {
            vm.boardState.setItem(BoardItem(chainID: dog, tier: 0),
                                  at: GridPosition(row: 0, col: col))
        }

        vm.claimDailyTask(id: vm.quests.dailyChallenges[0].id)
        XCTAssertEqual(vm.playtestMetrics.dailyTaskClaims, 1)
        XCTAssertEqual(vm.playtestMetrics.dailyTaskDaysFullySwept, 0)

        vm.claimDailyTask(id: vm.quests.dailyChallenges[1].id)
        vm.claimDailyTask(id: vm.quests.dailyChallenges[2].id)
        XCTAssertEqual(vm.playtestMetrics.dailyTaskClaims, 3)
        XCTAssertEqual(vm.playtestMetrics.dailyTaskDaysFullySwept, 1,
                       "the sweep is flagged once, on the claim that completes it")
    }

    func testABoardSampleCountsSpawnersOnBoardAgainstThoseStashed() {
        let vm = makeViewModel()
        vm.boardState.setProducer(ProducerTile(level: .familySpawner, species: .dog),
                                  at: GridPosition(row: 0, col: 0))
        vm.boardState.setProducer(ProducerTile(level: .familySpawner, species: .cat),
                                  at: GridPosition(row: 0, col: 1))
        vm.inventoryStore.familySpawnerStorage[AnimalSpecies.rabbit.rawValue] =
            ProducerTile(level: .familySpawner, species: .rabbit)
        vm.boardState.setItem(BoardItem(chainID: dog, tier: 0), at: GridPosition(row: 1, col: 0))

        vm.recordBoardSample()

        let m = vm.playtestMetrics
        XCTAssertEqual(m.boardSampleCount, 1)
        XCTAssertEqual(m.spawnersOnBoardTotal, 2)
        XCTAssertEqual(m.spawnersStashedTotal, 1)
        XCTAssertEqual(m.occupiedCellsTotal, 3, "two spawners plus one animal")
        XCTAssertEqual(m.unlockedCellsTotal, boardRows * 7)
        XCTAssertEqual(m.measuredStashRate ?? 0, 1.0 / 3.0, accuracy: 0.001)
    }

    /// **Regression.** The first version of this sampled inside `freshStart`,
    /// *before* `buildEmptyBoard` — so it recorded an empty board (zero unlocked
    /// cells) and then marked the day sampled, meaning the real sample never
    /// landed. Caught by looking at the debug panel on device, not by a test,
    /// because every other test here calls `recordBoardSample()` directly on a
    /// board it prepared itself. This one drives the real load path.
    func testLoadingAGameSamplesAPopulatedBoardNotAnEmptyOne() {
        GameStore.clear()
        defer { GameStore.clear() }

        let vm = MergeBoardViewModel()
        vm.loadGame()

        XCTAssertEqual(vm.playtestMetrics.boardSampleCount, 1)
        XCTAssertGreaterThan(vm.playtestMetrics.unlockedCellsTotal, 0,
                             "a sample taken before the board exists records nothing usable")
        XCTAssertGreaterThan(vm.playtestMetrics.occupiedCellsTotal, 0,
                             "a fresh game starts with animals and a spawner on the board")
        XCTAssertNotNil(vm.playtestMetrics.measuredBoardOccupancy)
        XCTAssertEqual(vm.playtestMetrics.spawnersOnBoardTotal, 1,
                       "a fresh game places exactly the day-one Canines spawner")
    }

    /// A board sample must not itself count as player activity — it fires on
    /// load, and a launch where nothing is done should not inflate the
    /// denominator every rate divides by.
    func testABoardSampleDoesNotMarkTheDayActive() {
        let vm = makeViewModel()
        vm.recordBoardSample()
        XCTAssertEqual(vm.playtestMetrics.boardSampleCount, 1)
        XCTAssertEqual(vm.playtestMetrics.activeDayCount, 0,
                       "opening the app and doing nothing is not an active day")
    }
}
