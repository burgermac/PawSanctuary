//
//  RemoteEventFileTests.swift
//  PawSanctuaryTests
//
//  Remote event data, task 7.2.2 (specs/Spec_RemoteEventData.md §10 item 2):
//  the file model, decoder, V1–V9 validator, hex colours and conversion.
//  One fixture per rule that must fail, a valid fixture that converts to the
//  expected definitions, and the compiled calendar expressed as a file.
//
//  Fixtures are dated in 2030, after every compiled window, so the compiled
//  baseline only matters where a test means it to.
//

import XCTest
import SwiftUI
import UIKit
@testable import PawSanctuary

final class RemoteEventFileTests: XCTestCase {

    // MARK: - Fixture helpers

    typealias JSON = [String: Any]

    /// The compiled calendar's windows, read from the registries (on this
    /// branch they hold only the compiled lists).
    private var compiledBaseline: [RemoteEventWindow] {
        RemoteEventFileValidator.compiledWindows(events: EventRegistry.allEvents,
                                                 tracks: ProgressTrackRegistry.tracks,
                                                 parallelBoardEvents: ParallelBoardEventRegistry.allEvents,
                                                 kibbleDriveEvents: KibbleDriveRegistry.allEvents)
    }

    private func milestone(_ index: Int, _ threshold: Int, free: [JSON] = [["kind": "kibble", "amount": 50]],
                           paid: [JSON] = []) -> JSON {
        ["index": index, "threshold": threshold, "free": free, "paid": paid]
    }

    private func weekly(id: String = "playtime_rush_20300104",
                        start: String = "2030-01-04T00:00:00Z", end: String = "2030-01-08T00:00:00Z") -> JSON {
        ["id": id, "kind": "milestoneTrack", "name": "Playtime Rush", "tagline": "Play it up!",
         "icon": "star.circle.fill", "accentColor": "#D9731A", "gradientColors": ["#FFEDCC", "#FCDDAD"],
         "start": start, "end": end, "priority": 0, "minLevel": 0,
         "track": [milestone(0, 60), milestone(1, 140, free: [["kind": "kibble", "amount": 75],
                                                              ["kind": "dogTags", "amount": 3]])]]
    }

    private func pass(id: String = "sanctuary_circle_s20_20300101") -> JSON {
        ["id": id, "kind": "pass", "name": "Sanctuary Circle", "tagline": "A season of rewards.",
         "icon": "trophy.fill", "accentColor": "#B8801A", "gradientColors": ["#FFF5D9", "#F5D999"],
         "start": "2030-01-01T00:00:00Z", "end": "2030-01-31T00:00:00Z", "priority": 1, "minLevel": 3,
         "track": [milestone(0, 60, free: [["kind": "kibble", "amount": 25]],
                             paid: [["kind": "kibble", "amount": 55], ["kind": "dogTags", "amount": 2]]),
                   milestone(1, 120, free: [["kind": "kibble", "amount": 40]],
                             paid: [["kind": "cardPack", "amount": 1, "payloadID": "star4"]])]]
    }

    private func parallelBoard(id: String = "second_chances_20300110") -> JSON {
        ["id": id, "kind": "parallelBoard", "name": "Second Chances", "icon": "arrow.triangle.2.circlepath",
         "chainID": "parallelboard.secondchances",
         "start": "2030-01-10T00:00:00Z", "end": "2030-01-13T00:00:00Z",
         "track": [milestone(0, 20, free: [["kind": "kibble", "amount": 30]])]]
    }

    private func drive(id: String = "kibble_drive_20300117") -> JSON {
        ["id": id, "kind": "kibbleDrive", "name": "Kibble Drive", "icon": "shippingbox.fill",
         "start": "2030-01-17T00:00:00Z", "end": "2030-01-20T00:00:00Z"]
    }

    private func file(_ events: [JSON], extra: JSON = [:]) -> JSON {
        var f: JSON = ["schemaVersion": 1, "revision": 7, "generatedAt": "2029-12-20T09:00:00Z",
                       "minAppBuild": 0, "events": events]
        for (k, v) in extra { f[k] = v }
        return f
    }

    private var validFile: JSON {
        file([pass(), weekly(), parallelBoard(), drive(),
              ["id": "rescue_relay_20270625", "cancelled": true]])
    }

    private func data(_ json: JSON) -> Data {
        // Fixtures are literal dictionaries of JSON types; a failure here is
        // a broken test, so fall back to empty data (which fails V1 loudly).
        (try? JSONSerialization.data(withJSONObject: json, options: [.sortedKeys])) ?? Data()
    }

    private func validate(_ json: JSON) -> Result<ValidatedRemoteEventFile, RemoteEventFileRejection> {
        RemoteEventFileValidator.validate(data(json), baseline: compiledBaseline)
    }

    private func assertRejected(_ json: JSON, _ rule: RemoteEventRule, eventID: String? = nil,
                                file: StaticString = #filePath, line: UInt = #line) {
        assertRejected(data(json), rule, eventID: eventID, file: file, line: line)
    }

    private func assertRejected(_ bytes: Data, _ rule: RemoteEventRule, eventID: String? = nil,
                                file: StaticString = #filePath, line: UInt = #line) {
        switch RemoteEventFileValidator.validate(bytes, baseline: compiledBaseline) {
        case .success:
            XCTFail("expected a \(rule.rawValue) rejection, the file was accepted", file: file, line: line)
        case .failure(let rejection):
            XCTAssertEqual(rejection.rule, rule, "wrong rule: \(rejection.reason)", file: file, line: line)
            if let eventID {
                XCTAssertEqual(rejection.eventID, eventID, file: file, line: line)
            }
        }
    }

    private func accepted(_ json: JSON, file: StaticString = #filePath,
                          line: UInt = #line) -> ValidatedRemoteEventFile? {
        switch validate(json) {
        case .success(let valid): return valid
        case .failure(let rejection):
            XCTFail("expected acceptance, got \(rejection.rule.rawValue): \(rejection.reason)", file: file, line: line)
            return nil
        }
    }

    /// `weekly()` with one field replaced.
    private func weekly(_ key: String, _ value: Any) -> JSON {
        var e = weekly(); e[key] = value; return e
    }

    private func utc(_ text: String) -> Date {
        RemoteEventFileValidator.parseUTCDate(text) ?? .distantPast
    }

    // MARK: - The valid fixture

    func testTheValidFixtureIsAccepted() throws {
        let valid = try XCTUnwrap(accepted(validFile))
        XCTAssertEqual(valid.schemaVersion, 1)
        XCTAssertEqual(valid.revision, 7)
        XCTAssertEqual(valid.minAppBuild, 0)
        XCTAssertEqual(valid.events.map(\.id), ["sanctuary_circle_s20_20300101", "playtime_rush_20300104",
                                                "second_chances_20300110", "kibble_drive_20300117"])
        XCTAssertEqual(valid.cancelledIDs, ["rescue_relay_20270625"])
        XCTAssertEqual(valid.skippedUnknownKindIDs, [])
    }

    func testTheValidFixtureConvertsToTheExpectedDefinitions() throws {
        let content = try XCTUnwrap(accepted(validFile)).content(iconExists: { _ in true })

        XCTAssertEqual(content.events.map(\.id), ["sanctuary_circle_s20_20300101", "playtime_rush_20300104"])
        let season = try XCTUnwrap(content.events.first)
        XCTAssertEqual(season.name, "Sanctuary Circle")
        XCTAssertEqual(season.tagline, "A season of rewards.")
        XCTAssertEqual(season.icon, "trophy.fill")
        XCTAssertEqual(season.startDate, utc("2030-01-01T00:00:00Z"))
        XCTAssertEqual(season.endDate, utc("2030-01-31T00:00:00Z"))
        XCTAssertEqual(season.priority, 1)
        XCTAssertEqual(season.minLevel, 3)
        XCTAssertTrue(season.milestones.isEmpty, "file events never use the legacy EventMilestone shape")
        XCTAssertEqual(season.accentColor, Color(red: 0xB8 / 255.0, green: 0x80 / 255.0, blue: 0x1A / 255.0, opacity: 1))
        XCTAssertEqual(season.gradientColors.count, 2)

        XCTAssertEqual(content.tracks["sanctuary_circle_s20_20300101"], [
            TrackMilestone(index: 0, threshold: 60,
                           freeRewards: [OrderReward(kind: .kibble, amount: 25)],
                           paidRewards: [OrderReward(kind: .kibble, amount: 55), OrderReward(kind: .dogTags, amount: 2)]),
            TrackMilestone(index: 1, threshold: 120,
                           freeRewards: [OrderReward(kind: .kibble, amount: 40)],
                           paidRewards: [OrderReward(kind: .cardPack, amount: 1, payloadID: CardPackType.star4.rawValue)]),
        ])
        XCTAssertEqual(content.tracks["playtime_rush_20300104"]?.count, 2)
        XCTAssertEqual(content.tracks["second_chances_20300110"],
                       [TrackMilestone(index: 0, threshold: 20,
                                       freeRewards: [OrderReward(kind: .kibble, amount: 30)], paidRewards: [])])
        XCTAssertNil(content.tracks["kibble_drive_20300117"], "a Drive's ladder stays code")

        let board = try XCTUnwrap(content.parallelBoardEvents.first)
        XCTAssertEqual(content.parallelBoardEvents.count, 1)
        XCTAssertEqual(board.id, "second_chances_20300110")
        XCTAssertEqual(board.chainID, ContentRegistry.parallelBoardSecondChancesChainID)
        XCTAssertEqual(board.startDate, utc("2030-01-10T00:00:00Z"))
        XCTAssertEqual(board.endDate, utc("2030-01-13T00:00:00Z"))

        let kibbleDrive = try XCTUnwrap(content.kibbleDriveEvents.first)
        XCTAssertEqual(content.kibbleDriveEvents.count, 1)
        XCTAssertEqual(kibbleDrive.id, "kibble_drive_20300117")
        XCTAssertEqual(kibbleDrive.icon, "shippingbox.fill")
        XCTAssertEqual(kibbleDrive.endDate.timeIntervalSince(kibbleDrive.startDate), 3 * 86_400)

        XCTAssertEqual(content.cancelledIDs, ["rescue_relay_20270625"])
    }

    func testAnUnresolvedIconFallsBackToTheKindsSymbol() throws {
        let content = try XCTUnwrap(accepted(validFile)).content(iconExists: { _ in false })
        XCTAssertEqual(content.events.map(\.icon), ["trophy.fill", "star.circle.fill"])
        XCTAssertEqual(content.parallelBoardEvents.first?.icon, "arrow.triangle.2.circlepath")
        XCTAssertEqual(content.kibbleDriveEvents.first?.icon, "shippingbox.fill")
    }

    func testReplacingACompiledEventOfTheSameKindIsAccepted() {
        // playtime_rush_20270604 is a compiled weekly; same id, same kind,
        // same window, new rewards.
        let replacement = weekly(id: "playtime_rush_20270604",
                                 start: "2027-06-04T00:00:00Z", end: "2027-06-08T00:00:00Z")
        XCTAssertNotNil(accepted(file([replacement])))
    }

    // MARK: - Forward compatibility

    func testUnknownKeysAreIgnoredAtEveryLevel() throws {
        var e = weekly()
        e["sparkles"] = ["future": true]
        var m = milestone(0, 60, free: [["kind": "kibble", "amount": 50, "glow": "gold"]])
        m["banner"] = "new"
        e["track"] = [m]
        let f = file([e], extra: ["publisher": "owner", "notes": [1, 2, 3]])
        let valid = try XCTUnwrap(accepted(f))
        XCTAssertEqual(valid.events.first?.track,
                       [TrackMilestone(index: 0, threshold: 60,
                                       freeRewards: [OrderReward(kind: .kibble, amount: 50)], paidRewards: [])])
    }

    func testAnUnknownKindSkipsThatEventOnly() throws {
        // A future kind, with fields this build's rules would reject: it is
        // skipped before any rule runs.
        let future: JSON = ["id": "Weekend-Blitz!", "kind": "weekendBlitz", "start": "soon",
                            "track": [["index": 4, "threshold": -1]]]
        let valid = try XCTUnwrap(accepted(file([weekly(), future])))
        XCTAssertEqual(valid.events.map(\.id), ["playtime_rush_20300104"])
        XCTAssertEqual(valid.skippedUnknownKindIDs, ["Weekend-Blitz!"])
    }

    func testANewerSchemaVersionIsRejected() {
        // A version-2 file whose shape this build cannot read: rejected for
        // its version, not its shape.
        let v2: JSON = ["schemaVersion": 2, "catalog": ["events": "elsewhere"]]
        assertRejected(v2, .v1)
        assertRejected(file([weekly()], extra: ["schemaVersion": 2]), .v1)
    }

    // MARK: - V1

    func testV1RejectsAFileThatIsNotJSON() {
        assertRejected(Data("{ \"schemaVersion\": 1, \"events\": [".utf8), .v1)
        assertRejected(Data("[1, 2, 3]".utf8), .v1)
    }

    func testV1RejectsAFileOverTheSizeCap() {
        // Valid JSON padded with an unknown key until it is one byte over.
        let base = data(file([weekly()], extra: ["padding": ""]))
        let pad = remoteEventFileMaxBytes - base.count + 1
        let big = data(file([weekly()], extra: ["padding": String(repeating: "x", count: pad)]))
        XCTAssertEqual(big.count, remoteEventFileMaxBytes + 1)
        assertRejected(big, .v1)
        let atCap = data(file([weekly()], extra: ["padding": String(repeating: "x", count: pad - 1)]))
        XCTAssertEqual(atCap.count, remoteEventFileMaxBytes)
        XCTAssertNotNil(accepted(file([weekly()], extra: ["padding": String(repeating: "x", count: pad - 1)])))
    }

    func testV1RejectsAMissingOrZeroRevisionAndAMissingSchemaVersion() {
        assertRejected(file([weekly()], extra: ["revision": 0]), .v1)
        var noRevision = file([weekly()]); noRevision["revision"] = nil
        assertRejected(noRevision, .v1)
        var noVersion = file([weekly()]); noVersion["schemaVersion"] = nil
        assertRejected(noVersion, .v1)
    }

    func testV1RejectsAnEventMissingItsNameOrKind() {
        var noName = weekly(); noName["name"] = nil
        assertRejected(file([noName]), .v1, eventID: "playtime_rush_20300104")
        var noKind = weekly(); noKind["kind"] = nil
        assertRejected(file([noKind]), .v1, eventID: "playtime_rush_20300104")
    }

    // MARK: - V2

    func testV2RejectsABadlyShapedID() {
        assertRejected(file([weekly(id: "Playtime-Rush")]), .v2)
        assertRejected(file([weekly(id: "ab")]), .v2)
        assertRejected(file([weekly(id: String(repeating: "a", count: 65))]), .v2)
        XCTAssertTrue(RemoteEventFileValidator.isValidID(String(repeating: "a", count: 64)))
        XCTAssertTrue(RemoteEventFileValidator.isValidID("abc"))
        XCTAssertFalse(RemoteEventFileValidator.isValidID("caf\u{E9}_event"))
    }

    func testV2RejectsADuplicateIDIncludingATombstone() {
        assertRejected(file([weekly(), weekly(id: "playtime_rush_20300104",
                                              start: "2030-02-04T00:00:00Z", end: "2030-02-08T00:00:00Z")]),
                       .v2, eventID: "playtime_rush_20300104")
        assertRejected(file([weekly(), ["id": "playtime_rush_20300104", "cancelled": true]]),
                       .v2, eventID: "playtime_rush_20300104")
    }

    func testV2RejectsAnIDThatBelongsToACompiledEventOfAnotherKind() {
        // A compiled weekly id reused for a Parallel Board.
        assertRejected(file([parallelBoard(id: "playtime_rush_20270604")]), .v2, eventID: "playtime_rush_20270604")
        // The legacy coin event's id, which no file kind may take.
        assertRejected(file([weekly(id: "rescue_rush_jun2026")]), .v2, eventID: "rescue_rush_jun2026")
    }

    // MARK: - V3

    func testV3RejectsStartNotBeforeEnd() {
        assertRejected(file([weekly(start: "2030-01-08T00:00:00Z", end: "2030-01-04T00:00:00Z")]), .v3)
        assertRejected(file([weekly(start: "2030-01-04T00:00:00Z", end: "2030-01-04T00:00:00Z")]), .v3)
    }

    func testV3RejectsADateWithoutZOrNotISO8601() {
        assertRejected(file([weekly(start: "2030-01-04T00:00:00+00:00")]), .v3)
        assertRejected(file([weekly(start: "2030-01-04")]), .v3)
        assertRejected(file([weekly(end: "next Tuesday")]), .v3)
        var noEnd = weekly(); noEnd["end"] = nil
        assertRejected(file([noEnd]), .v3)
    }

    func testV3EnforcesEachKindsDurationBounds() {
        // milestoneTrack 1–7 days.
        assertRejected(file([weekly(start: "2030-01-04T00:00:00Z", end: "2030-01-12T00:00:00Z")]), .v3)
        assertRejected(file([weekly(start: "2030-01-04T00:00:00Z", end: "2030-01-04T23:00:00Z")]), .v3)
        XCTAssertNotNil(accepted(file([weekly(start: "2030-01-04T00:00:00Z", end: "2030-01-11T00:00:00Z")])))
        // pass 7–35 days.
        var shortPass = pass(); shortPass["end"] = "2030-01-07T00:00:00Z"
        assertRejected(file([shortPass]), .v3)
        var longPass = pass(); longPass["end"] = "2030-02-06T00:00:00Z"
        assertRejected(file([longPass]), .v3)
        // kibbleDrive exactly 3 days.
        var longDrive = drive(); longDrive["end"] = "2030-01-21T00:00:00Z"
        assertRejected(file([longDrive]), .v3, eventID: "kibble_drive_20300117")
        var shortDrive = drive(); shortDrive["end"] = "2030-01-19T23:00:00Z"
        assertRejected(file([shortDrive]), .v3)
        // parallelBoard 1–7 days.
        var longBoard = parallelBoard(); longBoard["end"] = "2030-01-18T00:00:00Z"
        assertRejected(file([longBoard]), .v3)
    }

    // MARK: - V4

    func testV4RejectsAMissingEmptyOrOverlongTrack() {
        assertRejected(file([weekly("track", [])]), .v4)
        var noTrack = weekly(); noTrack["track"] = nil
        assertRejected(file([noTrack]), .v4)
        let twentyOne = (0..<21).map { milestone($0, ($0 + 1) * 10) }
        assertRejected(file([weekly("track", twentyOne)]), .v4)
        let twenty = (0..<20).map { milestone($0, ($0 + 1) * 10, free: [["kind": "dogTags", "amount": 1]]) }
        XCTAssertNotNil(accepted(file([weekly("track", twenty)])))
    }

    func testV4RejectsNonContiguousIndices() {
        assertRejected(file([weekly("track", [milestone(0, 60), milestone(2, 140)])]), .v4)
        assertRejected(file([weekly("track", [milestone(1, 60)])]), .v4)
    }

    func testV4RejectsThresholdsThatAreNotStrictlyIncreasingAndPositive() {
        assertRejected(file([weekly("track", [milestone(0, 0)])]), .v4)
        assertRejected(file([weekly("track", [milestone(0, 60), milestone(1, 60)])]), .v4)
        assertRejected(file([weekly("track", [milestone(0, 60), milestone(1, 40)])]), .v4)
    }

    // MARK: - V5

    func testV5RejectsEventTokenAndMaterialRewards() {
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "eventToken", "amount": 5,
                                                                       "payloadID": "playtime_rush_20300104"]])])]), .v5)
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "material", "amount": 1,
                                                                       "payloadID": "material.wood", "payloadTier": 0]])])]), .v5)
    }

    func testV5RejectsAnUnknownRewardKind() {
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "gems", "amount": 5]])])]), .v5)
    }

    func testV5RejectsACardPackThatIsNotACardPackType() {
        var p = pass()
        p["track"] = [milestone(0, 60, free: [["kind": "cardPack", "amount": 1, "payloadID": "star9"]])]
        assertRejected(file([p]), .v5)
        p["track"] = [milestone(0, 60, free: [["kind": "cardPack", "amount": 1]])]
        assertRejected(file([p]), .v5)
    }

    func testV5RejectsABoardItemTheBuildDoesNotKnow() {
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "boardItem", "amount": 1,
                                                                       "payloadID": "animal.dragon", "payloadTier": 0]])])]), .v5)
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "boardItem", "amount": 1,
                                                                       "payloadID": "animal.dog", "payloadTier": 99]])])]), .v5)
    }

    // MARK: - V6

    func testV6RejectsAnAmountBelowOneOrAboveItsCeiling() {
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "kibble", "amount": 0]])])]), .v6)
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "kibble", "amount": 701]])])]), .v6)
        XCTAssertNotNil(accepted(file([weekly("track", [milestone(0, 60, free: [["kind": "kibble", "amount": 700]])])])))
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "dogTags", "amount": 41]])])]), .v6)
    }

    func testV6RejectsATrackWhoseTotalIsOverItsCeiling() {
        // 8 x 700 kibble = 5,600, over the 5,480 track ceiling, though each
        // reward is at its own ceiling.
        let track = (0..<8).map { milestone($0, ($0 + 1) * 10, free: [["kind": "kibble", "amount": 700]]) }
        assertRejected(file([weekly("track", track)]), .v6)
        let underCap = (0..<7).map { milestone($0, ($0 + 1) * 10, free: [["kind": "kibble", "amount": 700]]) }
        XCTAssertNotNil(accepted(file([weekly("track", underCap)])))
    }

    func testV6RejectsKindsNoCompiledEventTablePays() {
        // V5 allows coins, xp and boardItem, but no compiled event track pays
        // them, so 2x the compiled maximum is 0 (decision recorded in the
        // tuning constants and the PR).
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "coins", "amount": 100]])])]), .v6)
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "xp", "amount": 10]])])]), .v6)
        assertRejected(file([weekly("track", [milestone(0, 60, free: [["kind": "boardItem", "amount": 1,
                                                                       "payloadID": "animal.dog", "payloadTier": 0]])])]), .v6)
    }

    /// The ceilings are 2x the compiled event tracks' maxima (§5.1 V6). If a
    /// calendar raises a compiled maximum, re-set the ceiling on purpose.
    func testV6CeilingsAreTwiceTheCompiledEventTracksMaxima() {
        let eventTrackIDs = Set(EventRegistry.allEvents.map(\.id)).union(ParallelBoardEventRegistry.allEvents.map(\.id))
        var single: [RewardKind: Int] = [:]
        var total: [RewardKind: Int] = [:]
        for (id, track) in ProgressTrackRegistry.tracks where eventTrackIDs.contains(id) {
            var perTrack: [RewardKind: Int] = [:]
            for reward in track.flatMap({ $0.freeRewards + $0.paidRewards }) {
                single[reward.kind] = max(single[reward.kind, default: 0], reward.amount)
                perTrack[reward.kind, default: 0] += reward.amount
            }
            for (kind, sum) in perTrack { total[kind] = max(total[kind, default: 0], sum) }
        }
        for kind in RewardKind.allCases where !RemoteEventFileValidator.rejectedRewardKinds.contains(kind) {
            XCTAssertEqual(remoteEventRewardAmountCeiling[kind, default: 0], 2 * single[kind, default: 0], "\(kind)")
            XCTAssertEqual(remoteEventTrackTotalCeiling[kind, default: 0], 2 * total[kind, default: 0], "\(kind)")
        }
    }

    // MARK: - V7

    func testV7RejectsAParallelBoardOnAnUnsupportedChain() {
        var board = parallelBoard(); board["chainID"] = "animal.dog"
        assertRejected(file([board]), .v7, eventID: "second_chances_20300110")
        board["chainID"] = nil
        assertRejected(file([board]), .v7)
    }

    func testV7RejectsAKibbleDriveWithATrack() {
        var d = drive(); d["track"] = [milestone(0, 60)]
        assertRejected(file([d]), .v7, eventID: "kibble_drive_20300117")
        d["track"] = []
        assertRejected(file([d]), .v7)
    }

    // MARK: - V8

    func testV8RejectsTwoOfTheSameKindAtOnceInTheFile() {
        let second = weekly(id: "rescue_relay_20300106", start: "2030-01-06T00:00:00Z", end: "2030-01-10T00:00:00Z")
        assertRejected(file([weekly(), second]), .v8)
        var secondPass = pass(id: "founders_circle_20300115")
        secondPass["start"] = "2030-01-15T00:00:00Z"; secondPass["end"] = "2030-02-14T00:00:00Z"
        assertRejected(file([pass(), secondPass]), .v8)
    }

    func testV8RejectsAFileEventOverlappingACompiledOneOfTheSameKind() {
        // Overlaps compiled playtime_rush_20270604 (06-04 to 06-08).
        let clash = weekly(id: "rescue_relay_20270606", start: "2027-06-06T00:00:00Z", end: "2027-06-09T00:00:00Z")
        assertRejected(file([clash]), .v8, eventID: "rescue_relay_20270606")
    }

    func testV8AllowsBackToBackWindowsAndOverlapAcrossKinds() {
        let next = weekly(id: "rescue_relay_20300108", start: "2030-01-08T00:00:00Z", end: "2030-01-12T00:00:00Z")
        // The valid fixture already overlaps a pass, a weekly, a board and a Drive.
        XCTAssertNotNil(accepted(file([pass(), weekly(), next, parallelBoard(), drive()])))
    }

    func testV8CountsATombstoneAsFreeingItsWindow() {
        // Cancelling compiled playtime_rush_20270604 makes room for a
        // differently-dated weekly in its place.
        let moved = weekly(id: "rescue_relay_20270606", start: "2027-06-05T00:00:00Z", end: "2027-06-09T00:00:00Z")
        XCTAssertNotNil(accepted(file([["id": "playtime_rush_20270604", "cancelled": true], moved])))
    }

    // MARK: - V9

    func testV9RejectsPaidRewardsOutsideAPass() {
        assertRejected(file([weekly("track", [milestone(0, 60, paid: [["kind": "kibble", "amount": 50]])])]),
                       .v9, eventID: "playtime_rush_20300104")
        var board = parallelBoard()
        board["track"] = [milestone(0, 20, paid: [["kind": "dogTags", "amount": 2]])]
        assertRejected(file([board]), .v9)
    }

    // MARK: - Colours

    func testHexColoursParse() throws {
        let orange = try XCTUnwrap(RemoteRGBA(hex: "#D9731A"))
        XCTAssertEqual(orange, RemoteRGBA(red: 217 / 255, green: 115 / 255, blue: 26 / 255, alpha: 1))
        XCTAssertEqual(RemoteRGBA(hex: "#d9731a"), orange)
        XCTAssertEqual(RemoteRGBA(hex: "#00000080"), RemoteRGBA(red: 0, green: 0, blue: 0, alpha: 128 / 255))
        XCTAssertEqual(RemoteRGBA(hex: "#FFFFFF"), RemoteRGBA(red: 1, green: 1, blue: 1))
    }

    func testBadHexColoursDoNotParse() {
        for bad in ["D9731A", "#D9731", "#D9731A0", "#GG0000", "#+9731A", "# D9731", "", "#", "#ＤＤＤＤＤＤ"] {
            XCTAssertNil(RemoteRGBA(hex: bad), bad)
        }
    }

    func testABadColourIsNotAnErrorAndFallsBackToTheKindsCompiledColour() throws {
        var e = weekly(); e["accentColor"] = "orange"; e["gradientColors"] = ["#FFEDCC", "nope"]
        var p = pass(); p["accentColor"] = nil; p["gradientColors"] = []
        let content = try XCTUnwrap(accepted(file([p, e]))).content(iconExists: { _ in true })
        let season = try XCTUnwrap(content.events.first { $0.id == "sanctuary_circle_s20_20300101" })
        let rush = try XCTUnwrap(content.events.first { $0.id == "playtime_rush_20300104" })
        XCTAssertEqual(season.accentColor, ValidatedRemoteEventFile.fallbackAccent(for: .pass).color)
        XCTAssertEqual(season.gradientColors, ValidatedRemoteEventFile.fallbackGradient(for: .pass).map(\.color))
        XCTAssertEqual(rush.accentColor, ValidatedRemoteEventFile.fallbackAccent(for: .milestoneTrack).color)
        XCTAssertEqual(rush.gradientColors, ValidatedRemoteEventFile.fallbackGradient(for: .milestoneTrack).map(\.color))
        // The fallbacks are the compiled calendar's own colours.
        let compiledSeason = try XCTUnwrap(EventRegistry.allEvents.first { $0.id == "sanctuary_circle_s1_20260904" })
        let compiledRush = try XCTUnwrap(EventRegistry.allEvents.first { $0.id == "playtime_rush_20270604" })
        XCTAssertEqual(season.accentColor, compiledSeason.accentColor)
        XCTAssertEqual(season.gradientColors, compiledSeason.gradientColors)
        XCTAssertEqual(rush.accentColor, compiledRush.accentColor)
        XCTAssertEqual(rush.gradientColors, compiledRush.gradientColors)
    }

    // MARK: - Cross-check: the compiled calendar as a file

    private func hex(_ color: Color) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", byte(r), byte(g), byte(b))
    }

    private func iso(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }

    private func remoteTrack(_ track: [TrackMilestone]) -> [RemoteMilestone] {
        func rewards(_ list: [OrderReward]) -> [RemoteReward] {
            list.map { RemoteReward(kind: $0.kind.rawValue, amount: $0.amount, payloadID: $0.payloadID, payloadTier: $0.payloadTier) }
        }
        return track.map { RemoteMilestone(index: $0.index, threshold: $0.threshold,
                                           free: rewards($0.freeRewards), paid: rewards($0.paidRewards)) }
    }

    /// Every compiled calendar event the file format can express (all but the
    /// legacy coin event), as a schema-1 file.
    private func compiledCalendarAsFile() -> RemoteEventFile {
        let windows = Dictionary(compiledBaseline.map { ($0.id, $0.kind) }, uniquingKeysWith: { a, _ in a })
        var entries: [RemoteEventEntry] = []
        for event in EventRegistry.allEvents {
            guard let kind = windows[event.id] ?? nil else { continue }
            entries.append(RemoteEventEntry(
                id: event.id, kind: kind.rawValue, name: event.name, tagline: event.tagline, icon: event.icon,
                accentColor: hex(event.accentColor), gradientColors: event.gradientColors.map(hex),
                start: iso(event.startDate), end: iso(event.endDate), priority: event.priority, minLevel: event.minLevel,
                track: ProgressTrackRegistry.tracks[event.id].map(remoteTrack)))
        }
        for board in ParallelBoardEventRegistry.allEvents {
            entries.append(RemoteEventEntry(
                id: board.id, kind: RemoteEventKind.parallelBoard.rawValue, name: board.name, icon: board.icon,
                start: iso(board.startDate), end: iso(board.endDate), chainID: board.chainID,
                track: ProgressTrackRegistry.tracks[board.id].map(remoteTrack)))
        }
        for drive in KibbleDriveRegistry.allEvents {
            entries.append(RemoteEventEntry(
                id: drive.id, kind: RemoteEventKind.kibbleDrive.rawValue, name: drive.name, icon: drive.icon,
                start: iso(drive.startDate), end: iso(drive.endDate)))
        }
        return RemoteEventFile(schemaVersion: 1, revision: 1, generatedAt: nil, minAppBuild: 0, events: entries)
    }

    func testTheCompiledCalendarExpressedAsAFileValidatesAndConvertsBack() throws {
        let exported = compiledCalendarAsFile()
        let bytes = try JSONEncoder().encode(exported)
        let result = RemoteEventFileValidator.validate(bytes, baseline: compiledBaseline)
        let valid: ValidatedRemoteEventFile
        switch result {
        case .success(let v): valid = v
        case .failure(let rejection):
            return XCTFail("compiled calendar rejected: \(rejection.rule.rawValue) \(rejection.eventID ?? "") \(rejection.reason)")
        }

        // Every expressible compiled event survived, none skipped.
        XCTAssertEqual(valid.events.count, EventRegistry.allEvents.count - 1 // the legacy coin event
                       + ParallelBoardEventRegistry.allEvents.count + KibbleDriveRegistry.allEvents.count)
        XCTAssertEqual(valid.skippedUnknownKindIDs, [])

        let content = valid.content(iconExists: { _ in true })
        let compiledByID = Dictionary(EventRegistry.allEvents.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for event in content.events {
            let compiled = try XCTUnwrap(compiledByID[event.id])
            XCTAssertEqual(event.name, compiled.name)
            XCTAssertEqual(event.tagline, compiled.tagline)
            XCTAssertEqual(event.icon, compiled.icon)
            XCTAssertEqual(event.startDate, compiled.startDate, event.id)
            XCTAssertEqual(event.endDate, compiled.endDate, event.id)
            XCTAssertEqual(event.priority, compiled.priority)
            XCTAssertEqual(event.minLevel, compiled.minLevel)
            XCTAssertEqual(hex(event.accentColor), hex(compiled.accentColor), event.id)
            XCTAssertEqual(event.gradientColors.map(hex), compiled.gradientColors.map(hex), event.id)
            XCTAssertEqual(content.tracks[event.id], ProgressTrackRegistry.tracks[event.id], event.id)
        }
        for (converted, compiled) in zip(content.parallelBoardEvents, ParallelBoardEventRegistry.allEvents) {
            XCTAssertEqual(converted.id, compiled.id)
            XCTAssertEqual(converted.chainID, compiled.chainID)
            XCTAssertEqual(converted.startDate, compiled.startDate)
            XCTAssertEqual(converted.endDate, compiled.endDate)
            XCTAssertEqual(content.tracks[converted.id], ProgressTrackRegistry.tracks[converted.id], converted.id)
        }
        XCTAssertEqual(content.parallelBoardEvents.count, ParallelBoardEventRegistry.allEvents.count)
        XCTAssertEqual(content.kibbleDriveEvents.map(\.id), KibbleDriveRegistry.allEvents.map(\.id))
        XCTAssertEqual(content.kibbleDriveEvents.map(\.startDate), KibbleDriveRegistry.allEvents.map(\.startDate))
        XCTAssertEqual(content.kibbleDriveEvents.map(\.endDate), KibbleDriveRegistry.allEvents.map(\.endDate))
    }

    func testTheCompiledCalendarHasNoSameKindOverlap() {
        XCTAssertNil(RemoteEventFileValidator.firstConcurrencyViolation(in: compiledBaseline).map { "\($0.0.id) / \($0.1.id)" })
        let kinds = Dictionary(grouping: compiledBaseline, by: { $0.kind?.rawValue ?? "legacy" }).mapValues(\.count)
        XCTAssertEqual(kinds["legacy"], 1, "only rescue_rush_jun2026 uses the legacy coin-event shape")
        XCTAssertGreaterThan(kinds["pass"] ?? 0, 0)
        XCTAssertGreaterThan(kinds["milestoneTrack"] ?? 0, 0)
    }
}
