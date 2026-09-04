//
//  ToolboxDropRateTests.swift
//  PawSanctuaryTests
//
//  Validates `EconomySimulation`'s toolbox terms against the **live generator**,
//  by Monte-Carlo sampling the real `claimQuest` -> `placeToolbox` ->
//  `buildToolboxLot` path rather than re-deriving the arithmetic a second time.
//
//  Why this and not a closed-form check. The material faucet
//  (`Spec_DailyHandInTasks.md` §5c) is the model's least directly observable
//  term: `buildToolboxLot` is private, rolls three chains independently, draws a
//  random count per chain, and rolls each item's tier off a weighted
//  distribution. A closed-form test would just restate the model's own algebra
//  and pass for the same reason the model is wrong, if it is wrong. Sampling the
//  real path is the only check that can actually catch drift between the model
//  and the game.
//
//  There is no PawSanctuary playtest telemetry to calibrate against — the only
//  gameplay counter the app records is `commerce.wallEventsTotal`, and every
//  "measured" figure in the specs comes from reference-title video capture, not
//  from this game. Until real drop data exists, the live generator is the
//  ground truth, and this file is what holds the model to it.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class ToolboxDropRateTests: XCTestCase {

    // MARK: Fixtures

    /// A view model with a fully unlocked, empty board. `placeToolbox` needs a
    /// free cell — with none it absorbs the lot directly and never queues it in
    /// `pendingMaterialLots`, which would silently sample nothing.
    private func makeViewModel(level: Int) -> MergeBoardViewModel {
        let vm = MergeBoardViewModel()
        vm.board = (0..<boardRows).map { row in
            (0..<7).map { col in
                BoardCell(position: GridPosition(row: row, col: col), item: nil, isUnlocked: true)
            }
        }
        vm.boardState.recalc()
        vm.progression.playerLevel = level
        return vm
    }

    private func completedQuest(_ difficulty: QuestDifficulty) -> Quest {
        Quest(goal: .mergeAny(count: 1), difficulty: difficulty, progress: 1,
              dogTagReward: 1, kibbleReward: 1)
    }

    /// Claims one quest of `difficulty` and returns the lots it queued.
    ///
    /// The board and the pending queue are reset each time, and the level is
    /// re-pinned because `claimQuest` grants XP and a level-up mid-sample would
    /// move `toolboxMaxTier` underneath the measurement.
    private func sampleClaim(_ vm: MergeBoardViewModel,
                             difficulty: QuestDifficulty,
                             level: Int) -> [[BoardItem]] {
        vm.progression.playerLevel = level
        vm.pendingMaterialLots = []
        for row in 0..<boardRows {
            for col in 0..<7 { vm.boardState.clearItem(at: GridPosition(row: row, col: col)) }
        }
        vm.boardState.recalc()
        vm.quests.activeQuests = [completedQuest(difficulty)]
        vm.claimQuest(id: vm.quests.activeQuests[0].id)
        return vm.pendingMaterialLots
    }

    private func units(in lot: [BoardItem]) -> Double {
        lot.reduce(0.0) { $0 + Double(EconomySimulation.materialUnits(tier: $1.tier)) }
    }

    // MARK: Lot contents

    /// `expectedToolboxUnits` against what `buildToolboxLot` actually produces.
    /// Sampled at two levels because `toolboxMaxTier` differs between them — L10
    /// caps at tier 3, L45 at the chain top — so a model that had the cap wrong
    /// would pass at one and fail at the other.
    func testToolboxLotValueMatchesTheModelAtTwoLevels() {
        for level in [10, 45] {
            let vm = makeViewModel(level: level)
            var lots: [[BoardItem]] = []
            let samples = 800
            for _ in 0..<samples {
                lots += sampleClaim(vm, difficulty: .medium, level: level)
            }
            XCTAssertEqual(lots.count, samples,
                           "a medium quest places exactly one toolbox, every time")

            let measured = lots.reduce(0.0) { $0 + units(in: $1) } / Double(lots.count)
            let modelled = EconomySimulation.expectedToolboxUnits(level: level)
            XCTAssertEqual(measured, modelled, accuracy: modelled * 0.12,
                           "L\(level): generator averages \(measured) tier-0 units per toolbox, model says \(modelled)")
        }
    }

    /// The lot's *shape*, not just its total: three chains, 1-3 items each.
    /// A model that got the right total from the wrong composition would still
    /// mispredict once any of those three numbers changes.
    func testToolboxLotShapeMatchesWhatTheModelAssumes() {
        let vm = makeViewModel(level: 45)
        var lots: [[BoardItem]] = []
        for _ in 0..<400 { lots += sampleClaim(vm, difficulty: .medium, level: 45) }

        for lot in lots {
            let chains = Set(lot.map(\.chainID))
            XCTAssertEqual(chains.count, 3, "every lot should carry all three material chains")
            for chainID in chains {
                let count = lot.filter { $0.chainID == chainID }.count
                XCTAssertTrue((1...3).contains(count), "per-chain count \(count) outside 1...3")
            }
        }
        let averageItems = Double(lots.reduce(0) { $0 + $1.count }) / Double(lots.count)
        XCTAssertEqual(averageItems, 6.0, accuracy: 0.35,
                       "three chains x an expected 2 items each")
    }

    /// No lot may contain a material above the chain top, whatever the level —
    /// `buildToolboxLot` clamps with `min(5, ...)` and the model relies on it.
    func testNoLotEverExceedsTheMaterialChainTop() {
        let vm = makeViewModel(level: 60)
        for _ in 0..<300 {
            for lot in sampleClaim(vm, difficulty: .hard, level: 60) {
                for item in lot {
                    XCTAssertLessThanOrEqual(item.tier, 5, "material chains top out at tier 5")
                    XCTAssertGreaterThanOrEqual(item.tier, 0)
                }
            }
        }
    }

    // MARK: Toolboxes per claim

    /// The deterministic arms of `claimQuest`'s difficulty switch.
    func testDeterministicToolboxCountsPerDifficulty() {
        let vm = makeViewModel(level: 45)
        for (difficulty, expected) in [(QuestDifficulty.medium, 1),
                                       (.hard, 2),
                                       (.legendary, 3)] {
            for _ in 0..<40 {
                XCTAssertEqual(sampleClaim(vm, difficulty: difficulty, level: 45).count, expected,
                               "\(difficulty.rawValue) should place \(expected) toolboxes")
            }
        }
    }

    /// The one random arm: an easy quest drops a toolbox 1 time in 4.
    func testEasyQuestDropRateIsOneInFour() {
        let vm = makeViewModel(level: 45)
        var drops = 0
        let samples = 1_200
        for _ in 0..<samples {
            drops += sampleClaim(vm, difficulty: .easy, level: 45).count
        }
        let rate = Double(drops) / Double(samples)
        XCTAssertEqual(rate, 0.25, accuracy: 0.045,
                       "easy quests dropped \(rate) toolboxes per claim, expected 0.25")
    }

    /// `expectedToolboxesPerQuestClaim` weights the per-difficulty counts by
    /// `generateQuest`'s d20 roll (45/30/20/5). Sampled against the real
    /// generator, at a level high enough that no difficulty capping applies.
    func testTheModelsQuestDifficultyMixMatchesTheGenerator() {
        let coordinator = QuestCoordinator()
        let dog = ContentRegistry.animalChainID(.dog)
        var counts: [QuestDifficulty: Int] = [:]
        let samples = 20_000
        for _ in 0..<samples {
            let quest = coordinator.generateQuest(unlockedChainIDs: [dog], playerLevel: 60)
            counts[quest.difficulty, default: 0] += 1
        }
        let expected: [QuestDifficulty: Double] = [
            .easy: 0.45, .medium: 0.30, .hard: 0.20, .legendary: 0.05,
        ]
        for (difficulty, share) in expected {
            let measured = Double(counts[difficulty] ?? 0) / Double(samples)
            XCTAssertEqual(measured, share, accuracy: 0.02,
                           "\(difficulty.rawValue): generator rolls \(measured), model assumes \(share)")
        }
    }

    /// End to end: the model's toolboxes-per-claim against claims made with the
    /// generator's own difficulty mix, rather than a hand-picked difficulty.
    func testToolboxesPerClaimMatchTheModelUnderTheRealDifficultyMix() {
        let vm = makeViewModel(level: 45)
        let coordinator = QuestCoordinator()
        let dog = ContentRegistry.animalChainID(.dog)
        var drops = 0
        let samples = 1_500
        for _ in 0..<samples {
            let rolled = coordinator.generateQuest(unlockedChainIDs: [dog], playerLevel: 60)
            drops += sampleClaim(vm, difficulty: rolled.difficulty, level: 45).count
        }
        let measured = Double(drops) / Double(samples)
        let modelled = EconomySimulation.expectedToolboxesPerQuestClaim(level: 45)
        XCTAssertEqual(measured, modelled, accuracy: 0.12,
                       "generator drops \(measured) toolboxes per claim, model says \(modelled)")
    }
}
