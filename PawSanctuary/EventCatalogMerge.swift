//
//  EventCatalogMerge.swift
//  PawSanctuary
//
//  Remote event data, task 7.2.4 (specs/Spec_RemoteEventData.md §5.3, §5.5):
//  the downloaded file merged over the compiled calendar, with tombstones and
//  pins, plus the pin rules the lifecycle uses.
//
//  Pure: no network, no file system, no saved state. Nothing installs a merged
//  catalog yet (`EventCatalog.effective` is still `compiled`). Task 7.2.5
//  does that at launch, and has to hand this the save's pins when it does.
//

import SwiftUI

/// The result of a merge. `fileRejection` is set when the merged result broke
/// a rule, in which case `catalog` was built without the file (Q6).
struct EventCatalogMerge {
    let catalog: EventCatalog
    let fileRejection: RemoteEventFileRejection?
}

extension EventCatalog {

    /// This catalog as windows, one per scheduled event.
    var windows: [RemoteEventWindow] {
        RemoteEventFileValidator.compiledWindows(events: events, tracks: tracks,
                                                 parallelBoardEvents: parallelBoardEvents,
                                                 kibbleDriveEvents: kibbleDriveEvents)
    }

    // MARK: Pins

    /// A pin for every event running at `date`, as this catalog defines it.
    /// The legacy coin event has no kind and is never pinned.
    func pins(activeAt date: Date) -> [EventPin] {
        windows.compactMap { window in
            guard let kind = window.kind, date >= window.start, date < window.end else { return nil }
            return EventPin(id: window.id, kind: kind, start: window.start, end: window.end,
                            track: kind == .kibbleDrive ? nil : tracks[window.id])
        }
    }

    /// `pins` after the app has looked at this catalog at `date`: each running
    /// event that had no pin gets one, an existing pin is never overwritten
    /// (§5.5), and pins that ended `eventPinRetentionDays` or more ago go.
    func updatingPins(_ pins: [String: EventPin], at date: Date) -> [String: EventPin] {
        var updated = pins
        for pin in self.pins(activeAt: date) where updated[pin.id] == nil {
            updated[pin.id] = pin
        }
        let retention = Double(eventPinRetentionDays) * 86_400
        return updated.filter { date < $0.value.end.addingTimeInterval(retention) }
    }

    /// When the event `id` ends, if this build can tell: from its pin first,
    /// otherwise from this catalog. `nil` means the id is unknown, and saved
    /// state held under an unknown id is never destroyed (§5.5).
    func knownEnd(of id: String, pins: [String: EventPin]) -> Date? {
        if let pin = pins[id] { return pin.end }
        return windows.first { $0.id == id }?.end
    }

    /// Whether saved state held under `id` may be dropped at `date`: only when
    /// the id is known and its end has passed.
    func hasEnded(_ id: String, pins: [String: EventPin], at date: Date) -> Bool {
        guard let end = knownEnd(of: id, pins: pins) else { return false }
        return date >= end
    }

    // MARK: Merge (§5.3)

    /// `base` with `content` (a file that already passed V1–V9) applied, then
    /// the pins. A file event adds or replaces by id; a tombstone removes an
    /// event that has not started and is not pinned; compiled events the file
    /// does not mention stay; a pinned event keeps its pinned dates and track.
    /// V8 then runs on the result, and a violation drops the whole file.
    static func merging(base: EventCatalog, content: RemoteEventContent?,
                        pins: [String: EventPin], now: Date) -> EventCatalogMerge {
        var draft = EventCatalogDraft(base)
        if let content {
            let startByID = Dictionary(base.windows.map { ($0.id, $0.start) },
                                       uniquingKeysWith: { first, _ in first })
            for id in content.cancelledIDs where pins[id] == nil {
                if let start = startByID[id], start > now { draft.remove(id) }
            }
            draft.apply(content)
        }

        // Every pin still being kept applies, ended ones too: otherwise a
        // later file could reopen a finished event by moving its end.
        let retention = Double(eventPinRetentionDays) * 86_400
        let kept = pins.values.filter { now < $0.end.addingTimeInterval(retention) }
            .sorted { $0.id < $1.id }
        for pin in kept {
            draft.apply(pin, fallingBackTo: base)
        }

        let merged = draft.catalog
        let clash = RemoteEventFileValidator.firstConcurrencyViolation(in: merged.windows)

        guard content != nil else {
            // No file: a clash can only be a pinned event against a compiled
            // one the lost file had moved or removed. The pin wins.
            // Only a pin that has not ended displaces anything.
            let keptIDs = Set(kept.map(\.id))
            let liveIDs = Set(kept.filter { now < $0.end }.map(\.id))
            let pinned = merged.windows.filter { liveIDs.contains($0.id) }
            var trimmed = draft
            for window in merged.windows where !keptIDs.contains(window.id) {
                let displaced = pinned.contains {
                    $0.kind == window.kind && $0.start < window.end && window.start < $0.end
                }
                if displaced { trimmed.remove(window.id) }
            }
            return EventCatalogMerge(catalog: trimmed.catalog, fileRejection: nil)
        }

        guard let clash else { return EventCatalogMerge(catalog: merged, fileRejection: nil) }
        let rejection = RemoteEventFileRejection(
            rule: .v8, eventID: clash.1.id,
            reason: "after merging, \(clash.0.id) and \(clash.1.id) are both " +
                    "\(clash.0.kind?.rawValue ?? "?") events at once")
        let withoutFile = merging(base: base, content: nil, pins: pins, now: now)
        return EventCatalogMerge(catalog: withoutFile.catalog, fileRejection: rejection)
    }
}

/// An `EventCatalog` being edited. Replacing keeps an event's place in its
/// list; a new event goes at the end.
private struct EventCatalogDraft {
    var events: [EventDefinition]
    var tracks: [String: [TrackMilestone]]
    var parallelBoardEvents: [ParallelBoardEventDefinition]
    var kibbleDriveEvents: [KibbleDriveEventDefinition]

    init(_ catalog: EventCatalog) {
        events = catalog.events
        tracks = catalog.tracks
        parallelBoardEvents = catalog.parallelBoardEvents
        kibbleDriveEvents = catalog.kibbleDriveEvents
    }

    var catalog: EventCatalog {
        EventCatalog(events: events, tracks: tracks,
                     parallelBoardEvents: parallelBoardEvents,
                     kibbleDriveEvents: kibbleDriveEvents)
    }

    /// Removes a scheduled event. Its track goes only with it, so tracks that
    /// belong to no scheduled event (the reward ladder) are never touched.
    mutating func remove(_ id: String) {
        let count = events.count + parallelBoardEvents.count + kibbleDriveEvents.count
        events.removeAll { $0.id == id }
        parallelBoardEvents.removeAll { $0.id == id }
        kibbleDriveEvents.removeAll { $0.id == id }
        if events.count + parallelBoardEvents.count + kibbleDriveEvents.count < count {
            tracks[id] = nil
        }
    }

    mutating func apply(_ content: RemoteEventContent) {
        for event in content.events { Self.upsert(event, in: &events) }
        for event in content.parallelBoardEvents { Self.upsert(event, in: &parallelBoardEvents) }
        for event in content.kibbleDriveEvents { Self.upsert(event, in: &kibbleDriveEvents) }
        for (id, track) in content.tracks { tracks[id] = track }
    }

    /// Gives `pin`'s event its pinned dates and track. Names, icons and
    /// colours come from the current definition, then from `base`, then from
    /// the kind's fallback look when the event is in neither (a file-only
    /// event whose file is gone).
    mutating func apply(_ pin: EventPin, fallingBackTo base: EventCatalog) {
        switch pin.kind {
        case .milestoneTrack, .pass:
            let look = events.first { $0.id == pin.id } ?? base.events.first { $0.id == pin.id }
            let accent = ValidatedRemoteEventFile.fallbackAccent(for: pin.kind)
            let gradient = ValidatedRemoteEventFile.fallbackGradient(for: pin.kind)
            parallelBoardEvents.removeAll { $0.id == pin.id }
            kibbleDriveEvents.removeAll { $0.id == pin.id }
            Self.upsert(EventDefinition(
                id: pin.id,
                name: look?.name ?? Self.fallbackName(for: pin.kind),
                tagline: look?.tagline ?? "",
                startDate: pin.start, endDate: pin.end,
                milestones: look?.milestones ?? [],
                icon: look?.icon ?? ValidatedRemoteEventFile.fallbackIcon(for: pin.kind),
                accentColor: look?.accentColor ?? accent.color,
                gradientColors: look?.gradientColors ?? gradient.map(\.color),
                minLevel: look?.minLevel ?? 0, priority: look?.priority ?? 0), in: &events)
        case .parallelBoard:
            let look = parallelBoardEvents.first { $0.id == pin.id }
                ?? base.parallelBoardEvents.first { $0.id == pin.id }
            events.removeAll { $0.id == pin.id }
            kibbleDriveEvents.removeAll { $0.id == pin.id }
            Self.upsert(ParallelBoardEventDefinition(
                id: pin.id,
                name: look?.name ?? Self.fallbackName(for: pin.kind),
                icon: look?.icon ?? ValidatedRemoteEventFile.fallbackIcon(for: pin.kind),
                // One chain is supported today (V7), so a pin need not store it.
                chainID: look?.chainID ?? ContentRegistry.parallelBoardSecondChancesChainID,
                startDate: pin.start, endDate: pin.end), in: &parallelBoardEvents)
        case .kibbleDrive:
            let look = kibbleDriveEvents.first { $0.id == pin.id }
                ?? base.kibbleDriveEvents.first { $0.id == pin.id }
            events.removeAll { $0.id == pin.id }
            parallelBoardEvents.removeAll { $0.id == pin.id }
            Self.upsert(KibbleDriveEventDefinition(
                id: pin.id,
                name: look?.name ?? Self.fallbackName(for: pin.kind),
                icon: look?.icon ?? ValidatedRemoteEventFile.fallbackIcon(for: pin.kind),
                startDate: pin.start, endDate: pin.end), in: &kibbleDriveEvents)
        }
        tracks[pin.id] = pin.track
    }

    private static func fallbackName(for kind: RemoteEventKind) -> String {
        switch kind {
        case .pass:           return "Season Pass"
        case .milestoneTrack: return "Event"
        case .parallelBoard:  return "Special Board"
        case .kibbleDrive:    return "Kibble Drive"
        }
    }

    private static func upsert<T: Identifiable>(_ item: T, in list: inout [T]) where T.ID == String {
        if let index = list.firstIndex(where: { $0.id == item.id }) {
            list[index] = item
        } else {
            list.append(item)
        }
    }
}
