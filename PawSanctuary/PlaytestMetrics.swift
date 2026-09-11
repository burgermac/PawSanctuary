//
//  PlaytestMetrics.swift
//  PawSanctuary
//
//  Local play instrumentation, added 4 Sep 2026.
//
//  Every "per day" figure in `EconomySimulation` rests on assumptions that were
//  never measured against this game — `Spec_DailyHandInTasks.md` §5c's "Still
//  open" names two of them by name. The model has been validated against the
//  *code* (`ToolboxDropRateTests`), which catches model-vs-code drift but cannot
//  catch a model that describes the code correctly and players incorrectly.
//  This is what closes that gap: real counters, from real play.
//
//  **Local only. Nothing is transmitted.** These are plain integers on the save
//  file, read back through a debug panel. No network, no identifiers, no
//  third-party SDK — so no `PrivacyInfo.xcprivacy` change is required. If this
//  ever grows a reporting backend, that decision needs making explicitly and the
//  privacy manifest revisiting with it.
//
//  Recording is **always on**, including release builds, so a TestFlight
//  playtest collects data without a special build. Only the readout is
//  `#if DEBUG`.
//

import Foundation

/// The modelled values the instrumentation exists to check, restated on the app
/// side so the debug panel can show measured-against-assumed without the app
/// depending on the test target.
///
/// **These are copies, and copies drift.** `PlaytestMetricsTests` asserts every
/// one of them equals the real figure in `EconomySimulation`, so a retune there
/// fails the build rather than quietly leaving this panel lying to the reader.
enum PlaytestBaseline {
    /// `EconomySimulation.questClaimsPerDay`.
    static let questClaimsPerDay = 2.0
    /// `generateQuest`'s d20 roll, uncapped: 45/30/20/5.
    static let questMix: [QuestDifficulty: Double] = [
        .easy: 0.45, .medium: 0.30, .hard: 0.20, .legendary: 0.05,
    ]
    /// `EconomySimulation.expectedToolboxesPerQuestClaim` at a level past all
    /// difficulty capping.
    static let toolboxesPerQuestClaim = 0.9625
    /// `EconomySimulation.materialUnitsPerDay` once `toolboxMaxTier` saturates
    /// at L20 — flat from there to L60.
    static let materialUnitsPerDaySaturated = 130.0
    /// `dailyTaskKibbleHandedIn` assumes the player clears every slot.
    static var dailyTaskClaimsPerDay: Double { Double(dailyTaskSlotDifficulties.count) }
    /// `Spec_DailyHandInTasks.md` §5c assumes every owned spawner sits on the
    /// board — i.e. that nothing is ever stashed.
    static let spawnerStashRate = 0.0
}

/// Counters that answer the questions `EconomySimulation` has to assume.
///
/// Mirrors `PlayerCommerceState`'s shape deliberately: a flat `Codable` struct
/// of defaulted scalars hanging off `GameState`, record-only, with the
/// interpretation done in computed properties rather than at the write sites.
/// That keeps the recording calls one-liners that cannot get the arithmetic
/// wrong.
///
/// **Every counter here exists to check one specific modelled number.** If a
/// counter cannot name the assumption it tests, it should not be here — an
/// instrumentation surface that collects "everything, just in case" is how a
/// save file grows fields nobody reads.
struct PlaytestMetrics: Codable, Equatable {

    // MARK: The denominator

    /// `yyyy-MM-dd` of the first day anything was recorded.
    var firstActiveDay: String? = nil
    /// `yyyy-MM-dd` of the most recent day anything was recorded.
    var lastActiveDay: String? = nil
    /// Distinct calendar days on which the player did anything counted here.
    ///
    /// A count rather than the set of days: every rate below divides by this,
    /// and storing 365 date strings a year to compute one integer is storage
    /// for nothing. The cost is that gaps are invisible — 30 active days could
    /// be a month straight or spread over six. `firstActiveDay`/`lastActiveDay`
    /// bracket that if it ever matters.
    var activeDayCount: Int = 0

    // MARK: Quest claims — tests `EconomySimulation.questClaimsPerDay` (2.0)
    //                     and `generateQuest`'s 45/30/20/5 difficulty mix.

    var questClaimsEasy: Int = 0
    var questClaimsMedium: Int = 0
    var questClaimsHard: Int = 0
    var questClaimsLegendary: Int = 0

    // MARK: Material faucet — tests `EconomySimulation.materialUnitsPerDay`
    //                        and `expectedToolboxesPerQuestClaim`.

    /// Toolboxes actually placed, by any source.
    var toolboxesPlaced: Int = 0
    /// Materials banked, in tier-0 equivalents (a tier-N material counts 2^N),
    /// the same denomination `EconomySimulation` uses.
    var materialUnitsAbsorbed: Int = 0

    // MARK: Daily hand-in tasks — tests `dailyTaskKibbleHandedIn`'s assumption
    //                             that the player clears all three.

    var dailyTaskClaims: Int = 0
    /// Days on which all three were claimed.
    var dailyTaskDaysFullySwept: Int = 0

    // MARK: Board occupancy — tests `Spec_DailyHandInTasks.md` §5c's assumption
    //                        that a player leaves every spawner on the board.

    /// Samples taken. Every total below is summed across this many samples;
    /// divide to get the average.
    var boardSampleCount: Int = 0
    var spawnersOnBoardTotal: Int = 0
    var spawnersStashedTotal: Int = 0
    var occupiedCellsTotal: Int = 0
    var unlockedCellsTotal: Int = 0
    /// `yyyy-MM-dd` of the last board sample — sampling is capped at one a day
    /// so a player who relaunches ten times does not get ten times the weight.
    var lastBoardSampleDay: String? = nil

    // MARK: Interpretation

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayStamp(_ date: Date = Date()) -> String { dayFormatter.string(from: date) }

    var totalQuestClaims: Int {
        questClaimsEasy + questClaimsMedium + questClaimsHard + questClaimsLegendary
    }

    /// `nil` until there is at least one active day — a rate with a zero
    /// denominator is not "0.0", it is "unknown", and reporting it as 0 would
    /// read as a measurement contradicting the model.
    private func perDay(_ total: Int) -> Double? {
        guard activeDayCount > 0 else { return nil }
        return Double(total) / Double(activeDayCount)
    }

    /// Measured against `EconomySimulation.questClaimsPerDay` (assumed 2.0).
    var measuredQuestClaimsPerDay: Double? { perDay(totalQuestClaims) }
    /// Measured against `EconomySimulation.materialUnitsPerDay(level:)`.
    var measuredMaterialUnitsPerDay: Double? { perDay(materialUnitsAbsorbed) }
    /// Measured against `EconomySimulation.expectedToolboxesPerQuestClaim(level:)`.
    var measuredToolboxesPerQuestClaim: Double? {
        guard totalQuestClaims > 0 else { return nil }
        return Double(toolboxesPlaced) / Double(totalQuestClaims)
    }
    /// Measured against `dailyTaskSlotDifficulties.count` (3 — the model assumes
    /// the player clears all of them).
    var measuredDailyTaskClaimsPerDay: Double? { perDay(dailyTaskClaims) }
    /// Share of active days on which all three dailies were handed in.
    var measuredFullSweepRate: Double? {
        guard activeDayCount > 0 else { return nil }
        return Double(dailyTaskDaysFullySwept) / Double(activeDayCount)
    }

    /// The observed quest difficulty mix, against the model's 45/30/20/5.
    var measuredQuestMix: [QuestDifficulty: Double]? {
        let total = totalQuestClaims
        guard total > 0 else { return nil }
        return [.easy:      Double(questClaimsEasy)      / Double(total),
                .medium:    Double(questClaimsMedium)    / Double(total),
                .hard:      Double(questClaimsHard)      / Double(total),
                .legendary: Double(questClaimsLegendary) / Double(total)]
    }

    private func perSample(_ total: Int) -> Double? {
        guard boardSampleCount > 0 else { return nil }
        return Double(total) / Double(boardSampleCount)
    }

    /// The number §5c assumes is every spawner the player owns.
    var measuredSpawnersOnBoard: Double? { perSample(spawnersOnBoardTotal) }
    var measuredSpawnersStashed: Double? { perSample(spawnersStashedTotal) }

    /// Share of owned spawners the player keeps off the board. §5c's congestion
    /// figure assumes this is 0.
    var measuredStashRate: Double? {
        let owned = spawnersOnBoardTotal + spawnersStashedTotal
        guard owned > 0 else { return nil }
        return Double(spawnersStashedTotal) / Double(owned)
    }

    /// Measured against `EconomySimulation.CongestionRow.occupancy`.
    var measuredBoardOccupancy: Double? {
        guard unlockedCellsTotal > 0 else { return nil }
        return Double(occupiedCellsTotal) / Double(unlockedCellsTotal)
    }

    /// True once there is enough data that the rates above mean anything.
    ///
    /// Seven days is not a statistical threshold, it is a floor below which a
    /// single unusual session dominates every average. The panel says
    /// "gathering" rather than showing numbers that would invite a retune.
    var hasEnoughDataToInterpret: Bool { activeDayCount >= 7 }

    // MARK: Denomination

    /// Tier-0 equivalents one material at `tier` is worth.
    ///
    /// Materials cascade 2-for-1 without limit in
    /// `InventoryStore.absorbMaterialItems`, so a tier-N material really is
    /// worth 2^N of tier 0 — the denomination is exact, not an approximation.
    ///
    /// **This must agree with `EconomySimulation.materialUnits(tier:)`**, which
    /// lives in the test target and so cannot be shared. Duplicating four
    /// characters of arithmetic across a target boundary is the lesser evil
    /// against moving the whole economy model into the app binary; a test
    /// asserts the two agree at every tier so they cannot drift.
    static func materialUnits(tier: Int) -> Int { 1 << max(0, min(tier, 5)) }

    /// Tier-0 equivalents in a whole toolbox lot. Non-material items are
    /// ignored, matching `absorbMaterialItems`, which drops them too — counting
    /// them here would inflate the faucet against what the player actually
    /// banked.
    static func materialUnits(in lot: [BoardItem]) -> Int {
        lot.reduce(0) { total, item in
            guard ContentRegistry.shared.chain(item.chainID)?.category == .material else { return total }
            return total + materialUnits(tier: item.tier)
        }
    }

    // MARK: Recording

    /// Marks today active. Called by every record site, so "active day" means
    /// "day the player did something counted here" rather than "day the app
    /// launched" — a launch that does nothing should not dilute a rate.
    mutating func noteActivity(on date: Date = Date()) {
        let today = Self.dayStamp(date)
        guard lastActiveDay != today else { return }
        if firstActiveDay == nil { firstActiveDay = today }
        lastActiveDay = today
        activeDayCount += 1
    }

    mutating func recordQuestClaim(_ difficulty: QuestDifficulty, on date: Date = Date()) {
        noteActivity(on: date)
        switch difficulty {
        case .easy:      questClaimsEasy += 1
        case .medium:    questClaimsMedium += 1
        case .hard:      questClaimsHard += 1
        case .legendary: questClaimsLegendary += 1
        }
    }

    mutating func recordToolboxPlaced(on date: Date = Date()) {
        noteActivity(on: date)
        toolboxesPlaced += 1
    }

    mutating func recordMaterialUnits(_ units: Int, on date: Date = Date()) {
        guard units > 0 else { return }
        noteActivity(on: date)
        materialUnitsAbsorbed += units
    }

    mutating func recordDailyTaskClaim(sweptAll: Bool, on date: Date = Date()) {
        noteActivity(on: date)
        dailyTaskClaims += 1
        if sweptAll { dailyTaskDaysFullySwept += 1 }
    }

    /// Records one board snapshot, at most once per calendar day.
    ///
    /// Returns `false` if today is already sampled. Once-a-day rather than
    /// per-launch because a player who opens the app ten times in a day would
    /// otherwise weight that day ten times over — and the thing being measured
    /// (how many spawners sit on the board) changes on the scale of days, not
    /// sessions.
    @discardableResult
    mutating func recordBoardSample(spawnersOnBoard: Int,
                                    spawnersStashed: Int,
                                    occupiedCells: Int,
                                    unlockedCells: Int,
                                    on date: Date = Date()) -> Bool {
        let today = Self.dayStamp(date)
        guard lastBoardSampleDay != today else { return false }
        lastBoardSampleDay = today
        boardSampleCount += 1
        spawnersOnBoardTotal += max(0, spawnersOnBoard)
        spawnersStashedTotal += max(0, spawnersStashed)
        occupiedCellsTotal   += max(0, occupiedCells)
        unlockedCellsTotal   += max(0, unlockedCells)
        return true
    }
}
