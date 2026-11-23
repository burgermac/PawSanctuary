//
//  EventCatalog.swift
//  PawSanctuary
//
//  Remote event data, task 7.2.1 (specs/Spec_RemoteEventData.md §3, §10):
//  the seam every event registry reads through, so a later step can merge a
//  downloaded event file over the calendar compiled into the build.
//
//  Compiled-only for now. `effective` always returns `compiled`, so this
//  step changes nothing a player can see: no network, no file, no save
//  change. What it adds is one place where the effective lists come from:
//
//      EventRegistry.allEvents              → effective.events
//      ProgressTrackRegistry.tracks         → effective.tracks
//      ParallelBoardEventRegistry.allEvents → effective.parallelBoardEvents
//      KibbleDriveRegistry.allEvents        → effective.kibbleDriveEvents
//
//  The literals themselves stay in their registries, renamed `compiled…`,
//  as the fallback (§5.2). Out of scope here and staying code: the Kibble
//  Drive ladder (`KibbleDriveLadder.rungs`), rider numbers, and
//  `RewardTableRegistry` (§4.2, Q5).
//

import Foundation

/// One complete set of event content: the four schedules and the track
/// tables they key into. A value type so a merged catalog (task 7.2.4) can
/// be built off to the side and installed whole.
struct EventCatalog: Sendable {
    let events: [EventDefinition]
    let tracks: [String: [TrackMilestone]]
    let parallelBoardEvents: [ParallelBoardEventDefinition]
    let kibbleDriveEvents: [KibbleDriveEventDefinition]

    /// The calendar compiled into this build. Always valid, always
    /// available: the fallback for offline, first launch, no cache, or a
    /// rejected file (§5.2).
    static let compiled = EventCatalog(
        events: EventRegistry.compiledEvents,
        tracks: ProgressTrackRegistry.compiledTracks,
        parallelBoardEvents: ParallelBoardEventRegistry.compiledEvents,
        kibbleDriveEvents: KibbleDriveRegistry.compiledEvents
    )

    /// The catalog every registry reads. Compiled-only until the cache
    /// loader (task 7.2.5) installs a merged catalog once at launch, before
    /// `MergeBoardViewModel` is built (`ProgressTrack` captures its registry
    /// at init, §5.4); a running session never sees it change.
    static var effective: EventCatalog { compiled }
}
