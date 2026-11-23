//
//  RemoteEventFile.swift
//  PawSanctuary
//
//  Remote event data, task 7.2.2 (specs/Spec_RemoteEventData.md §4, §5.1):
//  the downloaded event file's model, its decoder, the V1–V9 validator, hex
//  colour parsing, and conversion of a valid file into the definition types
//  the registries already use.
//
//  Pure: no network, no file system, no saved state. Nothing in the game calls
//  this yet. The merge over the compiled calendar, pins and tombstone timing
//  (V10) are task 7.2.4; reading the cached file, `minAppBuild` and the
//  `revision > compiledCatalogRevision` rule are 7.2.5; the signature check
//  in V1 is 7.2.6.
//
//  A file that breaks any rule is rejected whole (Q6): `validate` returns the
//  first rule broken and no events.
//

import Foundation
import SwiftUI
import UIKit

// ============================================================
// MARK: - FILE MODEL (schema version 1, §4.1)
// ============================================================

/// The event kinds a file may schedule. A kind not in this list skips that
/// event only (§4.1): an older build meeting a newer kind.
enum RemoteEventKind: String, CaseIterable, Sendable {
    case milestoneTrack
    case pass
    case parallelBoard
    case kibbleDrive
}

/// The whole file as decoded. Every field a rule needs is optional here so
/// the validator, not the decoder, names the rule that failed. Unknown keys
/// are ignored at every level (synthesized `Decodable` skips them).
struct RemoteEventFile: Codable, Equatable, Sendable {
    var schemaVersion: Int
    var revision: Int
    var generatedAt: String?
    var minAppBuild: Int?
    var events: [RemoteEventEntry]
}

/// One event, or a tombstone (`cancelled: true`, §4.1).
struct RemoteEventEntry: Codable, Equatable, Sendable {
    var id: String
    var kind: String?
    var cancelled: Bool?
    var name: String?
    var tagline: String?
    var icon: String?
    var accentColor: String?
    var gradientColors: [String]?
    var start: String?
    var end: String?
    var priority: Int?
    var minLevel: Int?
    var chainID: String?
    var track: [RemoteMilestone]?
}

struct RemoteMilestone: Codable, Equatable, Sendable {
    var index: Int
    var threshold: Int
    var free: [RemoteReward]?
    var paid: [RemoteReward]?
}

/// An `OrderReward` with the same raw values (§4.1). `kind` stays a string so
/// an unknown reward kind is a V5 rejection rather than a decode error.
struct RemoteReward: Codable, Equatable, Sendable {
    var kind: String
    var amount: Int
    var payloadID: String?
    var payloadTier: Int?
}

// ============================================================
// MARK: - RESULT TYPES
// ============================================================

/// The rules of §5.1. V10 (pins) belongs to task 7.2.4.
enum RemoteEventRule: String, Sendable {
    case v1, v2, v3, v4, v5, v6, v7, v8, v9
}

/// Why a file was rejected. One rejection rejects the whole file.
struct RemoteEventFileRejection: Error, Equatable, Sendable {
    let rule: RemoteEventRule
    /// The event the rule failed on, when there is one.
    let eventID: String?
    let reason: String
}

/// One scheduled window, used for V2's id-collision check and V8's
/// concurrency check. `kind == nil` marks the legacy coin event
/// (`EventMilestone` shape), which a file cannot express: no file event may
/// reuse its id, and it counts toward no concurrency limit.
struct RemoteEventWindow: Equatable, Sendable {
    let id: String
    let kind: RemoteEventKind?
    let start: Date
    let end: Date
}

/// A file event that passed every rule, in typed form.
struct ValidatedRemoteEvent: Equatable, Sendable {
    let id: String
    let kind: RemoteEventKind
    let name: String
    let tagline: String
    let icon: String
    /// Parsed colours; `nil` when the file's hex was missing or bad, which
    /// is not an error (§5.1): conversion uses the kind's compiled colour.
    let accentColor: RemoteRGBA?
    let gradientColors: [RemoteRGBA]?
    let start: Date
    let end: Date
    let priority: Int
    let minLevel: Int
    /// Parallel Board only.
    let chainID: String?
    /// `nil` for Kibble Drive, whose ladder stays code (V7, Q5).
    let track: [TrackMilestone]?
}

/// A file that passed V1–V9.
struct ValidatedRemoteEventFile: Equatable, Sendable {
    let schemaVersion: Int
    let revision: Int
    let minAppBuild: Int
    let events: [ValidatedRemoteEvent]
    /// Tombstoned ids, in file order. Whether each one applies (unstarted
    /// only) is decided by the merge, task 7.2.4.
    let cancelledIDs: [String]
    /// Events skipped because their `kind` is unknown to this build.
    let skippedUnknownKindIDs: [String]
}

/// A valid file in the definition types the registries already hold. The
/// merge over the compiled calendar (task 7.2.4) consumes this.
struct RemoteEventContent {
    let events: [EventDefinition]
    let tracks: [String: [TrackMilestone]]
    let parallelBoardEvents: [ParallelBoardEventDefinition]
    let kibbleDriveEvents: [KibbleDriveEventDefinition]
    let cancelledIDs: [String]
}

// ============================================================
// MARK: - COLOURS
// ============================================================

/// An sRGB colour with components in 0...1, parsed from `#RRGGBB` or
/// `#RRGGBBAA`.
struct RemoteRGBA: Equatable, Sendable {
    let red: Double
    let green: Double
    let blue: Double
    let alpha: Double

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    /// `nil` for anything but `#` followed by exactly 6 or 8 hex digits
    /// (either case).
    init?(hex: String) {
        guard hex.hasPrefix("#") else { return nil }
        let digits = hex.dropFirst()
        guard digits.count == 6 || digits.count == 8,
              digits.allSatisfy({ $0.isHexDigit && $0.isASCII }),
              let value = UInt64(digits, radix: 16) else { return nil }
        let hasAlpha = digits.count == 8
        let rgb = hasAlpha ? value >> 8 : value
        self.red = Double((rgb >> 16) & 0xFF) / 255
        self.green = Double((rgb >> 8) & 0xFF) / 255
        self.blue = Double(rgb & 0xFF) / 255
        self.alpha = hasAlpha ? Double(value & 0xFF) / 255 : 1
    }

    var color: Color { Color(red: red, green: green, blue: blue, opacity: alpha) }
}

// ============================================================
// MARK: - VALIDATOR (§5.1)
// ============================================================

enum RemoteEventFileValidator {

    static let supportedSchemaVersion = 1

    /// Kinds of chain a Parallel Board event may name (V7).
    static let supportedParallelBoardChainIDs: Set<String> = [
        ContentRegistry.parallelBoardSecondChancesChainID,
    ]

    /// Reward kinds a file may not use in v1 (V5).
    static let rejectedRewardKinds: Set<RewardKind> = [.eventToken, .material]

    /// Decodes and validates `data` against `baseline`, the compiled
    /// calendar's windows (`compiledWindows`). Returns the first rule broken,
    /// or the whole file in typed form.
    static func validate(_ data: Data,
                         baseline: [RemoteEventWindow]) -> Result<ValidatedRemoteEventFile, RemoteEventFileRejection> {
        do {
            return .success(try validateOrThrow(data, baseline: baseline))
        } catch let rejection as RemoteEventFileRejection {
            return .failure(rejection)
        } catch {
            return .failure(RemoteEventFileRejection(rule: .v1, eventID: nil,
                                                     reason: "unexpected error: \(error)"))
        }
    }

    // MARK: V1 — size, JSON, schema version, revision

    private struct Header: Decodable { let schemaVersion: Int? }

    private static func validateOrThrow(_ data: Data,
                                        baseline: [RemoteEventWindow]) throws -> ValidatedRemoteEventFile {
        guard data.count <= remoteEventFileMaxBytes else {
            throw reject(.v1, nil, "file is \(data.count) bytes, over \(remoteEventFileMaxBytes)")
        }
        // Schema version first, from a header-only decode, so a newer file
        // whose shape changed is rejected for its version, not its shape.
        guard let header = try? JSONDecoder().decode(Header.self, from: data) else {
            throw reject(.v1, nil, "not a JSON object")
        }
        guard let version = header.schemaVersion else {
            throw reject(.v1, nil, "schemaVersion missing")
        }
        guard version == supportedSchemaVersion else {
            throw reject(.v1, nil, "schemaVersion \(version) is not supported (expected \(supportedSchemaVersion))")
        }
        let file: RemoteEventFile
        do {
            file = try JSONDecoder().decode(RemoteEventFile.self, from: data)
        } catch {
            throw reject(.v1, nil, "does not match schema version 1: \(error)")
        }
        guard file.revision > 0 else {
            throw reject(.v1, nil, "revision must be > 0, was \(file.revision)")
        }

        let compiledKindByID = Dictionary(baseline.map { ($0.id, $0.kind) },
                                          uniquingKeysWith: { first, _ in first })
        var seenIDs = Set<String>()
        var events: [ValidatedRemoteEvent] = []
        var cancelled: [String] = []
        var skipped: [String] = []

        for entry in file.events {
            // An unknown kind skips that event only, before any other rule:
            // a newer kind may follow rules this build does not know.
            if entry.cancelled != true, let raw = entry.kind, RemoteEventKind(rawValue: raw) == nil {
                skipped.append(entry.id)
                continue
            }

            // V2 — id shape and uniqueness (tombstones included).
            guard isValidID(entry.id) else {
                throw reject(.v2, entry.id, "id must match ^[a-z0-9_]{3,64}$")
            }
            guard seenIDs.insert(entry.id).inserted else {
                throw reject(.v2, entry.id, "id appears more than once in the file")
            }

            if entry.cancelled == true {
                cancelled.append(entry.id)
                continue
            }
            guard let rawKind = entry.kind, let kind = RemoteEventKind(rawValue: rawKind) else {
                throw reject(.v1, entry.id, "event has no kind and is not a tombstone")
            }
            // V2 — no collision with a compiled id of a different kind.
            if let compiledKind = compiledKindByID[entry.id], compiledKind != kind {
                let what = compiledKind.map(\.rawValue) ?? "legacy coin event"
                throw reject(.v2, entry.id, "id belongs to a compiled \(what), not a \(kind.rawValue)")
            }
            events.append(try validateEvent(entry, kind: kind))
        }

        // V8 — concurrency over the file merged onto the compiled windows.
        let fileWindows = events.map { RemoteEventWindow(id: $0.id, kind: $0.kind, start: $0.start, end: $0.end) }
        let merged = mergedWindows(baseline: baseline, fileWindows: fileWindows, cancelledIDs: Set(cancelled))
        let fileIDs = Set(fileWindows.map(\.id))
        if let clash = firstConcurrencyViolation(in: merged) {
            let blamed = fileIDs.contains(clash.0.id) ? clash.0.id : clash.1.id
            throw reject(.v8, blamed,
                         "\(clash.0.id) and \(clash.1.id) are both \(clash.0.kind?.rawValue ?? "?") events at once")
        }

        return ValidatedRemoteEventFile(schemaVersion: file.schemaVersion,
                                        revision: file.revision,
                                        minAppBuild: file.minAppBuild ?? 0,
                                        events: events,
                                        cancelledIDs: cancelled,
                                        skippedUnknownKindIDs: skipped)
    }

    // MARK: Per-event rules (V1 shape, V3–V7, V9)

    private static func validateEvent(_ entry: RemoteEventEntry,
                                      kind: RemoteEventKind) throws -> ValidatedRemoteEvent {
        let id = entry.id
        guard let name = entry.name, !name.isEmpty else { throw reject(.v1, id, "name missing") }
        guard let icon = entry.icon, !icon.isEmpty else { throw reject(.v1, id, "icon missing") }

        // V3 — dates and duration.
        guard let startText = entry.start, let start = parseUTCDate(startText) else {
            throw reject(.v3, id, "start missing or not ISO 8601 with Z")
        }
        guard let endText = entry.end, let end = parseUTCDate(endText) else {
            throw reject(.v3, id, "end missing or not ISO 8601 with Z")
        }
        guard start < end else { throw reject(.v3, id, "start must be before end") }
        let days = durationDays(for: kind)
        let seconds = end.timeIntervalSince(start)
        guard seconds >= Double(days.lowerBound) * 86_400,
              seconds <= Double(days.upperBound) * 86_400 else {
            throw reject(.v3, id, "a \(kind.rawValue) must last \(days.lowerBound)–\(days.upperBound) days, " +
                         "this lasts \(seconds / 86_400)")
        }

        // V7 — kind-specific shape.
        var chainID: String?
        switch kind {
        case .parallelBoard:
            guard let chain = entry.chainID, supportedParallelBoardChainIDs.contains(chain) else {
                throw reject(.v7, id, "chainID \(entry.chainID ?? "missing") is not a Parallel Board chain this build supports")
            }
            chainID = chain
        case .kibbleDrive:
            guard entry.track == nil else {
                throw reject(.v7, id, "a kibbleDrive has no track; its ladder stays code")
            }
        case .milestoneTrack, .pass:
            break
        }

        var track: [TrackMilestone]?
        if kind != .kibbleDrive {
            track = try validateTrack(entry.track, kind: kind, id: id)
        }

        return ValidatedRemoteEvent(
            id: id, kind: kind, name: name, tagline: entry.tagline ?? "", icon: icon,
            accentColor: entry.accentColor.flatMap(RemoteRGBA.init(hex:)),
            gradientColors: parseGradient(entry.gradientColors),
            start: start, end: end,
            priority: entry.priority ?? 0, minLevel: entry.minLevel ?? 0,
            chainID: chainID, track: track)
    }

    /// V4, V5, V6, V9 for one track.
    private static func validateTrack(_ raw: [RemoteMilestone]?, kind: RemoteEventKind,
                                      id: String) throws -> [TrackMilestone] {
        // V4 — shape.
        guard let raw, (1...remoteEventMaxMilestones).contains(raw.count) else {
            throw reject(.v4, id, "track must have 1–\(remoteEventMaxMilestones) milestones, has \(raw?.count ?? 0)")
        }
        var previousThreshold = 0
        for (position, milestone) in raw.enumerated() {
            guard milestone.index == position else {
                throw reject(.v4, id, "milestone at position \(position) has index \(milestone.index); indices run 0, 1, 2…")
            }
            guard milestone.threshold > previousThreshold else {
                throw reject(.v4, id, "threshold \(milestone.threshold) at index \(position) must be > 0 and above the one before")
            }
            previousThreshold = milestone.threshold
        }

        // V9 — paid rewards only on a pass.
        if kind != .pass, raw.contains(where: { !($0.paid ?? []).isEmpty }) {
            throw reject(.v9, id, "paid rewards are allowed only on a pass")
        }

        // V5 and V6 — reward kinds, payloads and caps.
        var totals: [RewardKind: Int] = [:]
        var milestones: [TrackMilestone] = []
        for milestone in raw {
            let free = try (milestone.free ?? []).map { try validateReward($0, id: id) }
            let paid = try (milestone.paid ?? []).map { try validateReward($0, id: id) }
            for reward in free + paid {
                let (sum, overflow) = totals[reward.kind, default: 0].addingReportingOverflow(reward.amount)
                guard !overflow, sum <= remoteEventTrackTotalCeiling[reward.kind, default: 0] else {
                    throw reject(.v6, id, "track total of \(reward.kind.rawValue) is over its ceiling " +
                                 "\(remoteEventTrackTotalCeiling[reward.kind, default: 0])")
                }
                totals[reward.kind] = sum
            }
            milestones.append(TrackMilestone(index: milestone.index, threshold: milestone.threshold,
                                             freeRewards: free, paidRewards: paid))
        }
        return milestones
    }

    /// V5 then V6 for one reward.
    private static func validateReward(_ raw: RemoteReward, id: String) throws -> OrderReward {
        guard let kind = RewardKind(rawValue: raw.kind) else {
            throw reject(.v5, id, "unknown reward kind \(raw.kind)")
        }
        guard !rejectedRewardKinds.contains(kind) else {
            throw reject(.v5, id, "reward kind \(kind.rawValue) is not allowed in a file")
        }
        switch kind {
        case .cardPack:
            guard let pack = raw.payloadID, CardPackType(rawValue: pack) != nil else {
                throw reject(.v5, id, "cardPack payloadID \(raw.payloadID ?? "missing") is not a card pack")
            }
        case .boardItem:
            guard let chain = raw.payloadID, let tier = raw.payloadTier,
                  ContentRegistry.shared.tier(chain, tier) != nil else {
                throw reject(.v5, id, "boardItem \(raw.payloadID ?? "missing") tier \(raw.payloadTier.map(String.init) ?? "missing") " +
                             "is not an item this build knows")
            }
        default:
            break
        }
        let ceiling = remoteEventRewardAmountCeiling[kind, default: 0]
        guard raw.amount >= 1, raw.amount <= ceiling else {
            throw reject(.v6, id, "\(kind.rawValue) amount \(raw.amount) is outside 1–\(ceiling)")
        }
        return OrderReward(kind: kind, amount: raw.amount, payloadID: raw.payloadID, payloadTier: raw.payloadTier)
    }

    // MARK: V8 — concurrency

    /// The compiled windows with the file applied: file events replace or
    /// add by id, tombstones remove. Pins and the "unstarted only" limit on
    /// tombstones are task 7.2.4, which runs V8 again on its own result.
    static func mergedWindows(baseline: [RemoteEventWindow], fileWindows: [RemoteEventWindow],
                              cancelledIDs: Set<String>) -> [RemoteEventWindow] {
        let replaced = Set(fileWindows.map(\.id))
        return baseline.filter { !replaced.contains($0.id) && !cancelledIDs.contains($0.id) } + fileWindows
    }

    /// The first pair of same-kind windows that overlap, or `nil`. At most one
    /// of each kind may run at any instant (Spec_Phase7_Calendar4.md §2.7):
    /// one pass and one milestone track (EventRegistry ≤ 2), one Parallel
    /// Board, one Kibble Drive. Overlap across kinds is allowed. Windows are
    /// half-open, `start` inclusive and `end` exclusive, so back-to-back
    /// windows do not clash. Legacy windows (`kind == nil`) are not counted.
    static func firstConcurrencyViolation(in windows: [RemoteEventWindow]) -> (RemoteEventWindow, RemoteEventWindow)? {
        for kind in RemoteEventKind.allCases {
            let sorted = windows.filter { $0.kind == kind }.sorted {
                $0.start != $1.start ? $0.start < $1.start : $0.id < $1.id
            }
            // Sorted by start, a clash exists only if some window starts
            // before the latest end seen so far.
            var latest: RemoteEventWindow?
            for window in sorted {
                if let open = latest, window.start < open.end { return (open, window) }
                if latest.map({ window.end > $0.end }) ?? true { latest = window }
            }
        }
        return nil
    }

    /// The compiled calendar as windows, for V2 and V8. Takes the lists
    /// rather than reading the registries so the caller chooses the compiled
    /// lists explicitly (after task 7.2.1 the registries' `allEvents` read the
    /// effective catalog, which will include a file).
    ///
    /// An `EventRegistry` entry is a `pass` when its track has any paid
    /// reward (the rule `EventSheetView.hasPaidLane` uses to show the Pass
    /// purchase), a `milestoneTrack` otherwise, and the legacy coin event
    /// (`kind == nil`) when it still carries `EventMilestone`s.
    static func compiledWindows(events: [EventDefinition],
                                tracks: [String: [TrackMilestone]],
                                parallelBoardEvents: [ParallelBoardEventDefinition],
                                kibbleDriveEvents: [KibbleDriveEventDefinition]) -> [RemoteEventWindow] {
        let eventWindows = events.map { event -> RemoteEventWindow in
            let kind: RemoteEventKind?
            if !event.milestones.isEmpty {
                kind = nil
            } else if (tracks[event.id] ?? []).contains(where: { !$0.paidRewards.isEmpty }) {
                kind = .pass
            } else {
                kind = .milestoneTrack
            }
            return RemoteEventWindow(id: event.id, kind: kind, start: event.startDate, end: event.endDate)
        }
        return eventWindows
            + parallelBoardEvents.map { RemoteEventWindow(id: $0.id, kind: .parallelBoard, start: $0.startDate, end: $0.endDate) }
            + kibbleDriveEvents.map { RemoteEventWindow(id: $0.id, kind: .kibbleDrive, start: $0.startDate, end: $0.endDate) }
    }

    // MARK: Helpers

    private static func reject(_ rule: RemoteEventRule, _ eventID: String?, _ reason: String) -> RemoteEventFileRejection {
        RemoteEventFileRejection(rule: rule, eventID: eventID, reason: reason)
    }

    /// `^[a-z0-9_]{3,64}$`
    static func isValidID(_ id: String) -> Bool {
        (3...64).contains(id.unicodeScalars.count) && id.unicodeScalars.allSatisfy {
            ("a"..."z").contains($0) || ("0"..."9").contains($0) || $0 == "_"
        }
    }

    /// ISO 8601 date-time in UTC, written with a trailing `Z` (V3).
    static func parseUTCDate(_ text: String) -> Date? {
        guard text.hasSuffix("Z") else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: text)
    }

    static func durationDays(for kind: RemoteEventKind) -> ClosedRange<Int> {
        switch kind {
        case .milestoneTrack: return remoteEventMilestoneTrackDays
        case .pass:           return remoteEventPassDays
        case .parallelBoard:  return remoteEventParallelBoardDays
        case .kibbleDrive:    return remoteEventKibbleDriveDays
        }
    }

    /// All entries parsed, or `nil` (fall back) if the list is missing, empty,
    /// or has any bad hex.
    private static func parseGradient(_ hexes: [String]?) -> [RemoteRGBA]? {
        guard let hexes, !hexes.isEmpty else { return nil }
        let parsed = hexes.compactMap(RemoteRGBA.init(hex:))
        return parsed.count == hexes.count ? parsed : nil
    }
}

// ============================================================
// MARK: - CONVERSION
// ============================================================

extension ValidatedRemoteEventFile {

    /// The kind's compiled look, used when the file's colours or icon do not
    /// resolve (§5.1, "not errors"). Copied from the compiled calendar:
    /// Sanctuary Circle for `pass`, Playtime Rush for `milestoneTrack`, and
    /// the only icon each of the other two kinds has ever used.
    static func fallbackIcon(for kind: RemoteEventKind) -> String {
        switch kind {
        case .pass:           return "trophy.fill"
        case .milestoneTrack: return "star.circle.fill"
        case .parallelBoard:  return "arrow.triangle.2.circlepath"
        case .kibbleDrive:    return "shippingbox.fill"
        }
    }

    static func fallbackAccent(for kind: RemoteEventKind) -> RemoteRGBA {
        kind == .pass
            ? RemoteRGBA(red: 0.72, green: 0.50, blue: 0.10)
            : RemoteRGBA(red: 0.15, green: 0.55, blue: 0.45)
    }

    static func fallbackGradient(for kind: RemoteEventKind) -> [RemoteRGBA] {
        kind == .pass
            ? [RemoteRGBA(red: 1.00, green: 0.96, blue: 0.85), RemoteRGBA(red: 0.96, green: 0.85, blue: 0.60)]
            : [RemoteRGBA(red: 0.85, green: 0.97, blue: 0.93), RemoteRGBA(red: 0.68, green: 0.90, blue: 0.82)]
    }

    /// Converts into the registries' definition types. `iconExists` decides
    /// whether an SF Symbol name resolves; injectable so tests stay
    /// deterministic.
    func content(iconExists: (String) -> Bool = { UIImage(systemName: $0) != nil }) -> RemoteEventContent {
        var events: [EventDefinition] = []
        var tracks: [String: [TrackMilestone]] = [:]
        var parallel: [ParallelBoardEventDefinition] = []
        var drives: [KibbleDriveEventDefinition] = []

        for event in self.events {
            let icon = iconExists(event.icon) ? event.icon : Self.fallbackIcon(for: event.kind)
            if let track = event.track { tracks[event.id] = track }
            switch event.kind {
            case .milestoneTrack, .pass:
                let accent = event.accentColor ?? Self.fallbackAccent(for: event.kind)
                let gradient = event.gradientColors ?? Self.fallbackGradient(for: event.kind)
                events.append(EventDefinition(
                    id: event.id, name: event.name, tagline: event.tagline,
                    startDate: event.start, endDate: event.end, milestones: [],
                    icon: icon, accentColor: accent.color, gradientColors: gradient.map(\.color),
                    minLevel: event.minLevel, priority: event.priority))
            case .parallelBoard:
                // Validated by V7, so always present here.
                let chain = event.chainID ?? ContentRegistry.parallelBoardSecondChancesChainID
                parallel.append(ParallelBoardEventDefinition(
                    id: event.id, name: event.name, icon: icon, chainID: chain,
                    startDate: event.start, endDate: event.end))
            case .kibbleDrive:
                drives.append(KibbleDriveEventDefinition(
                    id: event.id, name: event.name, icon: icon,
                    startDate: event.start, endDate: event.end))
            }
        }
        return RemoteEventContent(events: events, tracks: tracks, parallelBoardEvents: parallel,
                                  kibbleDriveEvents: drives, cancelledIDs: cancelledIDs)
    }
}
