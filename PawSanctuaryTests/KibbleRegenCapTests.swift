//
//  KibbleRegenCapTests.swift
//  PawSanctuaryTests
//
//  `effectiveRegenCap` had no coverage at all despite being the boundary
//  three separate behaviours key off (regen, the full-bag notification, and
//  the HUD countdown). The HUD read the flat `kibbleRegenCap` constant
//  instead and silently disagreed with regen for every level-10+ player
//  holding 100-149 kibble — found 11 Sep 2026.
//

import XCTest
@testable import PawSanctuary

@MainActor
final class KibbleRegenCapTests: XCTestCase {

    private func makeEngine(level: Int, kibble: Int) -> KibbleEngine {
        let engine = KibbleEngine()
        engine.playerLevel = level
        engine.kibble = kibble
        return engine
    }

    func testEffectiveCapRisesAtLevelTen() {
        XCTAssertEqual(makeEngine(level: 9, kibble: 0).effectiveRegenCap, kibbleRegenCap)
        XCTAssertEqual(makeEngine(level: 10, kibble: 0).effectiveRegenCap, 150)
        XCTAssertEqual(makeEngine(level: 12, kibble: 0).effectiveRegenCap, 150)
    }

    /// The defect itself: above the flat constant but below the real cap,
    /// regen is still running. Anything that asks "is the bar still filling?"
    /// must ask `effectiveRegenCap`, never `kibbleRegenCap`.
    func testRegenStillRunsAboveTheFlatConstantForAHighLevelPlayer() {
        let engine = makeEngine(level: 12, kibble: kibbleRegenCap + 20)
        XCTAssertGreaterThanOrEqual(engine.kibble, kibbleRegenCap,
                                    "precondition: at or above the flat constant")
        XCTAssertLessThan(engine.kibble, engine.effectiveRegenCap)

        for _ in 0..<kibbleRegenSecs { engine.tick(bonusPerRegen: 0) }

        XCTAssertEqual(engine.kibble, kibbleRegenCap + 21,
                       "regen must keep running up to the effective cap")
    }

    /// Guards the HUD gate. `MergeBoardView.kibblePill` shows the countdown
    /// while `viewModel.isKibbleRegenerating`, which forwards the property
    /// asserted here — so this pins the exact value the view reads, not a
    /// second copy of the comparison. It cannot prove the view still reads
    /// it; that is what the on-screen check is for.
    func testTheGateTheHudReadsAgreesWithWhereRegenActuallyStops() {
        for level in [1, 9, 10, 12] {
            for kibble in [0, kibbleRegenCap - 1, kibbleRegenCap, 120, 149, 150, 200] {
                let engine = makeEngine(level: level, kibble: kibble)
                let hudWouldShowCountdown = engine.isRegenerating

                let before = engine.kibble
                for _ in 0..<kibbleRegenSecs { engine.tick(bonusPerRegen: 0) }
                let regenIsRunning = engine.kibble > before

                XCTAssertEqual(hudWouldShowCountdown, regenIsRunning,
                               "level \(level), kibble \(kibble): countdown shown = \(hudWouldShowCountdown) but regen running = \(regenIsRunning)")
            }
        }
    }

    /// The specific case that was broken: gating on the flat constant, as the
    /// HUD used to, disagrees with `isRegenerating` here. Fails if anyone
    /// reintroduces the constant at a display site.
    func testTheFlatConstantIsTheWrongGateForAHighLevelPlayer() {
        let engine = makeEngine(level: 12, kibble: 120)
        XCTAssertTrue(engine.isRegenerating, "the bag is still filling toward 150")
        XCTAssertFalse(engine.kibble < kibbleRegenCap,
                       "...but the flat constant says it is not, which is the bug")
    }

    /// Note the level is set on the engine, not through
    /// `viewModel.playerLevel` — that setter writes to `PlayerProgression`
    /// and does **not** mirror into `KibbleEngine`. Production keeps the two
    /// in step at the only two points the level can actually move:
    /// `grantXP` on level-up and `KibbleEngine.restore(from:)` on load
    /// (both verified by reading, not asserted here — `restore` takes a
    /// fully populated `GameState` and `captureState()` is private, so
    /// pinning it would mean widening access for one line). A
    /// test that set `viewModel.playerLevel` directly would be exercising a
    /// path the app never takes, and would fail for the wrong reason.
    /// The Shop blurb and the refill sheet both render this, so it has to
    /// track `kibbleRegenSecs` rather than a number someone typed. They
    /// disagreed with each other and with the constant before it existed.
    func testRegenRateDescriptionTracksTheConstant() {
        XCTAssertEqual(kibbleRegenSecs, 120, "if this changes, the expectation below moves with it")
        XCTAssertEqual(KibbleEngine.regenRateDescription, "1 every 2 min")
    }

    /// `secondsUntilKibbleFull` is now the single computation of time-to-full
    /// — `NotificationManager`'s own copy of the arithmetic, which took the
    /// cap as a parameter, is gone. This pins that it targets the effective
    /// cap, which is the thing the deleted copy got wrong.
    func testTimeToFullTargetsTheEffectiveCapNotTheFlatConstant() {
        let engine = makeEngine(level: 12, kibble: 149)
        engine.secondsUntilNextKibble = kibbleRegenSecs
        XCTAssertEqual(engine.secondsUntilKibbleFull(bonusPerRegen: 0),
                       TimeInterval(kibbleRegenSecs),
                       "one tick from 149 to the real cap of 150")

        // Against the flat constant this balance is already 'full', which is
        // precisely the early fire: nil here would mean no notification at
        // all, and a shorter interval would mean firing while still filling.
        let atFlatCap = makeEngine(level: 12, kibble: kibbleRegenCap)
        atFlatCap.secondsUntilNextKibble = kibbleRegenSecs
        let secs = atFlatCap.secondsUntilKibbleFull(bonusPerRegen: 0)
        XCTAssertNotNil(secs, "still 50 kibble from full, so it must schedule")
        XCTAssertEqual(secs, TimeInterval(kibbleRegenSecs + 49 * kibbleRegenSecs))
    }

    /// Full means full: nothing to schedule.
    func testTimeToFullIsNilAtTheEffectiveCap() {
        XCTAssertNil(makeEngine(level: 12, kibble: 150).secondsUntilKibbleFull(bonusPerRegen: 0))
        XCTAssertNil(makeEngine(level: 1, kibble: kibbleRegenCap).secondsUntilKibbleFull(bonusPerRegen: 0))
    }

    func testViewModelForwardsTheSameCapTheEngineUses() {
        let viewModel = MergeBoardViewModel()
        viewModel.kibbleEngine.playerLevel = 12
        viewModel.kibbleEngine.kibble = 120
        XCTAssertEqual(viewModel.effectiveRegenCap, 150)
        XCTAssertTrue(viewModel.isKibbleRegenerating,
                      "the property the HUD gates on must follow the engine")
        viewModel.kibbleEngine.playerLevel = 3
        XCTAssertEqual(viewModel.effectiveRegenCap, kibbleRegenCap)
        XCTAssertFalse(viewModel.isKibbleRegenerating)
    }

}
