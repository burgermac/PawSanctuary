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

    // MARK: Streak reminder moves to tomorrow on days already played (owner decision, 10 Nov 2026)

    private let allFour: Set<String> = [
        NotificationID.dailyReset,
        NotificationID.streakReminder,
        NotificationID.dailyRewards,
        NotificationID.reengagement,
    ]

    private var otherThree: Set<String> { allFour.subtracting([NotificationID.streakReminder]) }

    /// The pending streak reminder's trigger. Read its components, not
    /// nextTriggerDate(): that uses the real clock.
    private func streakTrigger(_ centre: RecordingCentre) throws -> UNCalendarNotificationTrigger {
        try XCTUnwrap(centre.pending[NotificationID.streakReminder]?.trigger
                      as? UNCalendarNotificationTrigger)
    }

    /// Asserts the trigger is a one-shot at 20:00 on the calendar day `day`.
    private func assertFires(_ trigger: UNCalendarNotificationTrigger, at20On day: Date,
                             file: StaticString = #filePath, line: UInt = #line) {
        let want = Calendar.current.dateComponents([.year, .month, .day], from: day)
        XCTAssertEqual(trigger.dateComponents.year, want.year, file: file, line: line)
        XCTAssertEqual(trigger.dateComponents.month, want.month, file: file, line: line)
        XCTAssertEqual(trigger.dateComponents.day, want.day, file: file, line: line)
        XCTAssertEqual(trigger.dateComponents.hour, 20, file: file, line: line)
        XCTAssertEqual(trigger.dateComponents.minute, 0, file: file, line: line)
        XCTAssertFalse(trigger.repeats, file: file, line: line)
    }

    private func dayAfter(_ date: Date) throws -> Date {
        try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 1, to: date))
    }

    private func dayBefore(_ date: Date) throws -> Date {
        try XCTUnwrap(Calendar.current.date(byAdding: .day, value: -1, to: date))
    }

    /// Login registered today, before 20:00: the reminder is for tomorrow 20:00.
    func testPlayedTodaySchedulesStreakReminderForTomorrow() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let login = Calendar.current.startOfDay(for: clock)   // checkDailyLogin stores start of day
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { login })

        manager.scheduleStandingOnBackground()

        XCTAssertEqual(centre.pendingIDs, allFour)
        assertFires(try streakTrigger(centre), at20On: try dayAfter(clock))
    }

    /// Last login was yesterday: tonight's 20:00, as before.
    func testNotPlayedTodaySchedulesStreakReminderForTonight() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let yesterday = try dayBefore(Calendar.current.startOfDay(for: clock))
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { yesterday })

        manager.scheduleStandingOnBackground()

        XCTAssertEqual(centre.pendingIDs, allFour)
        assertFires(try streakTrigger(centre), at20On: clock)
    }

    /// No login date known (nil, the default before MergeBoardView wires it):
    /// tonight's 20:00, the pre-change behaviour.
    func testUnknownLoginSchedulesStreakReminderForTonight() throws {
        let (manager, centre) = try makeManager(atHour: 10)

        manager.scheduleStandingOnBackground()

        assertFires(try streakTrigger(centre), at20On: try today(atHour: 10))
    }

    /// Past 20:00 and not played today (yesterday or never): skipped, no
    /// retroactive fire.
    func testAfterEightPMNotPlayedTodaySkipsStreakReminder() throws {
        let clock = try today(atHour: 21)
        let yesterday = try dayBefore(clock)
        for login in [Optional(yesterday), nil] {
            let centre = RecordingCentre()
            let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                              lastLoginDate: { login })
            manager.scheduleStandingOnBackground()
            XCTAssertEqual(centre.pendingIDs, otherThree)
        }
    }

    /// Past 20:00 and played today: tomorrow's 20:00 is still scheduled.
    func testAfterEightPMPlayedTodaySchedulesStreakReminderForTomorrow() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 21)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { clock })

        manager.scheduleStandingOnBackground()

        XCTAssertEqual(centre.pendingIDs, allFour)
        assertFires(try streakTrigger(centre), at20On: try dayAfter(clock))
    }

    /// Warm-return sequence on a day already played: all four reminders are
    /// pending after every background pass, the streak one for tomorrow.
    func testWarmReturnOnPlayedDayKeepsAllFour() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { clock })

        manager.scheduleAll()                    // cold launch
        assertFires(try streakTrigger(centre), at20On: try dayAfter(clock))
        manager.scheduleStandingOnBackground()   // first .background
        XCTAssertEqual(centre.pendingIDs, allFour)
        manager.cancelAll()                      // warm return
        XCTAssertTrue(centre.pendingIDs.isEmpty, "the .active pass clears everything")
        manager.scheduleStandingOnBackground()   // next .background
        XCTAssertEqual(centre.pendingIDs, allFour)
        assertFires(try streakTrigger(centre), at20On: try dayAfter(clock))
    }

    /// Opening the app (the .active cancelAll) removes tomorrow's reminder, so
    /// it only fires if the player has not come back by then.
    func testOpeningAppCancelsTomorrowsStreakReminder() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { clock })

        manager.scheduleStandingOnBackground()
        XCTAssertTrue(centre.pendingIDs.contains(NotificationID.streakReminder))

        manager.cancelAll()

        XCTAssertFalse(centre.pendingIDs.contains(NotificationID.streakReminder))
    }

    /// Across midnight: tomorrow's 20:00 on the day played; once the clock
    /// moves on and the login date has not, it is that (new) day's 20:00.
    func testNextDayClockMoveSchedulesThatEvening() throws {
        let centre = RecordingCentre()
        let day1 = try today(atHour: 10)
        var clock = day1
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: true,
                                          lastLoginDate: { Calendar.current.startOfDay(for: day1) })

        manager.scheduleStandingOnBackground()
        let day2 = try dayAfter(day1)
        assertFires(try streakTrigger(centre), at20On: day2)

        clock = day2
        manager.cancelAll()
        manager.scheduleStandingOnBackground()
        assertFires(try streakTrigger(centre), at20On: day2)
    }

    /// Without permission nothing is scheduled, played today or not.
    func testPlayedTodayWithoutPermissionSchedulesNothing() throws {
        let centre = RecordingCentre()
        let clock = try today(atHour: 10)
        let manager = NotificationManager(centre: centre, now: { clock }, isAuthorised: false,
                                          lastLoginDate: { clock })

        manager.scheduleStandingOnBackground()

        XCTAssertTrue(centre.pendingIDs.isEmpty)
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
