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

    // MARK: Streak reminder skipped on days already played (owner decision, 10 Nov 2026)

    private let otherThree: Set<String> = [
        NotificationID.dailyReset,
        NotificationID.dailyRewards,
        NotificationID.reengagement,
    ]

    /// Login registered today, before 20:00: no streak reminder, the other three stay.
    func testPlayedTodaySkipsStreakReminder() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let login = Calendar.current.startOfDay(for: clock)   // checkDailyLogin stores start of day
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { login })

        manager.scheduleStandingOnBackground()

        XCTAssertEqual(centre.pendingIDs, otherThree)
    }

    /// Last login was yesterday: today's 20:00 reminder is scheduled as before.
    func testNotPlayedTodaySchedulesStreakReminderForTonight() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1,
                                                            to: Calendar.current.startOfDay(for: clock)))
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { yesterday })

        manager.scheduleStandingOnBackground()

        XCTAssertEqual(centre.pendingIDs, otherThree.union([NotificationID.streakReminder]))
        let trigger = try XCTUnwrap(centre.pending[NotificationID.streakReminder]?.trigger
                                    as? UNCalendarNotificationTrigger)
        // Read the components, not nextTriggerDate(): that uses the real clock.
        let today = Calendar.current.dateComponents([.year, .month, .day], from: clock)
        XCTAssertEqual(trigger.dateComponents.year, today.year)
        XCTAssertEqual(trigger.dateComponents.month, today.month)
        XCTAssertEqual(trigger.dateComponents.day, today.day)
        XCTAssertEqual(trigger.dateComponents.hour, 20)
        XCTAssertFalse(trigger.repeats)
    }

    /// Past 20:00 nothing changes: skipped whether or not the player played today.
    func testAfterEightPMSkipsStreakReminderEitherWay() throws {
        let clock = try today(atHour: 21)
        let yesterday = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: clock))
        for login in [Optional(clock), Optional(yesterday), nil] {
            let centre = RecordingCentre()
            let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                              lastLoginDate: { login })
            manager.scheduleStandingOnBackground()
            XCTAssertEqual(centre.pendingIDs, otherThree)
        }
    }

    /// Warm-return sequence on a day already played: the other three survive
    /// every background pass and no streak reminder is ever pending.
    func testWarmReturnOnPlayedDayKeepsOtherThree() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { clock })

        manager.scheduleAll()                    // cold launch
        XCTAssertFalse(centre.pendingIDs.contains(NotificationID.streakReminder))
        manager.scheduleStandingOnBackground()   // first .background
        XCTAssertEqual(centre.pendingIDs, otherThree)
        manager.cancelAll()                      // warm return
        manager.scheduleStandingOnBackground()   // next .background
        XCTAssertEqual(centre.pendingIDs, otherThree)
    }

    /// Across midnight: skipped on the day played, scheduled again the next
    /// day once the clock moves on and the login date has not.
    func testSkipDoesNotCarryOverToNextDay() throws {
        let centre = RecordingCentre()
        let day1 = try today(atHour: 10)
        var clock = day1
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { Calendar.current.startOfDay(for: day1) })

        manager.scheduleStandingOnBackground()
        XCTAssertFalse(centre.pendingIDs.contains(NotificationID.streakReminder))

        clock = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: day1))
        manager.cancelAll()
        manager.scheduleStandingOnBackground()
        XCTAssertTrue(centre.pendingIDs.contains(NotificationID.streakReminder))
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
