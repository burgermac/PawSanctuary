//
//  NotificationManagerTests.swift
//  PawSanctuaryTests
//
//  Guards the lost-reminder bug found 10 Nov 2026 (TODO.md): MergeBoardView
//  cancels every notification when the app becomes active, and the
//  backgrounding pass did not put `daily.reset` or `streak.reminder` back, so
//  a warm return lost both until the next cold launch.
//
//  These replay the scene-phase sequence against a recording stand-in centre
//  and a fixed clock: the system centre refuses requests from an unauthorised
//  test host, and the streak reminder depends on the time of day.
//

import XCTest
import UserNotifications
@testable import PawSanctuary

/// Records pending requests by identifier, the way the system centre keys them.
private final class RecordingCentre: NotificationCentre {
    private(set) var pending: [String: UNNotificationRequest] = [:]

    var pendingIDs: Set<String> { Set(pending.keys) }

    func addRequest(_ request: UNNotificationRequest) { pending[request.identifier] = request }
    func removePending(ids: [String]) { ids.forEach { pending[$0] = nil } }
    func removeDelivered(ids: [String]) {}
    func removeAllPending() { pending.removeAll() }
    func removeAllDelivered() {}
    func clearBadge() {}
}

@MainActor
final class NotificationManagerTests: XCTestCase {

    /// Today at the given local hour, so the 20:00 streak cut-off is deterministic.
    private func today(atHour hour: Int) throws -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        comps.hour = hour
        comps.minute = 0
        return try XCTUnwrap(Calendar.current.date(from: comps))
    }

    private func makeManager(atHour hour: Int) throws -> (NotificationManager, RecordingCentre) {
        let centre = RecordingCentre()
        let clock = try today(atHour: hour)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true)
        return (manager, centre)
    }

    /// Cold launch, background, warm return, background again: both reminders
    /// must be pending after the second background, as they were after the first.
    func testWarmReturnThenBackgroundKeepsDailyResetAndStreakReminder() throws {
        let (manager, centre) = try makeManager(atHour: 10)

        manager.scheduleAll()                    // AppEntry .task, cold launch
        manager.scheduleStandingOnBackground()   // first .background
        manager.cancelAll()                      // MergeBoardView .active, warm return
        XCTAssertTrue(centre.pendingIDs.isEmpty, "the .active pass clears everything")

        manager.scheduleStandingOnBackground()   // next .background

        XCTAssertEqual(centre.pendingIDs, [
            NotificationID.dailyReset,
            NotificationID.streakReminder,
            NotificationID.dailyRewards,
            NotificationID.reengagement,
        ])
    }

    /// Past 20:00 the streak reminder is skipped (no retroactive fire), but the
    /// midnight reset must still be put back.
    func testBackgroundAfterEightPMStillSchedulesDailyReset() throws {
        let (manager, centre) = try makeManager(atHour: 21)

        manager.cancelAll()
        manager.scheduleStandingOnBackground()

        XCTAssertTrue(centre.pendingIDs.contains(NotificationID.dailyReset))
        XCTAssertFalse(centre.pendingIDs.contains(NotificationID.streakReminder))
    }

    /// Without permission the pass schedules nothing.
    func testBackgroundWithoutPermissionSchedulesNothing() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: false)

        manager.scheduleStandingOnBackground()

        XCTAssertTrue(centre.pendingIDs.isEmpty)
    }
}
