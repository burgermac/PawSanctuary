//
//  NotificationManager.swift
//  PawSanctuary
//
//  Centralises all UNUserNotificationCenter scheduling.
//  Four notification types:
//    • kibble.full      — fires when regen would top up the bar
//    • daily.rewards    — 09:00 local daily reminder to claim login/pass/loyalty rewards
//    • order.expiry.*   — 5-min warning per incomplete adoption order
//    • reengagement     — 48-hour nudge if the player hasn't returned
//

import Foundation
import UserNotifications
import Observation

// MARK: - Notification identifiers

enum NotificationID {
    static let kibbleFull      = "pawsanctuary.kibble.full"
    static let dailyRewards    = "pawsanctuary.daily.rewards"
    static let dailyReset      = "pawsanctuary.daily.reset"
    static let rescueExpiring  = "pawsanctuary.rescue.expiring"
    static let streakReminder  = "pawsanctuary.streak.reminder"
    static let reengagement    = "pawsanctuary.reengagement"
    static func orderExpiry(_ id: String) -> String { "pawsanctuary.order.expiry.\(id)" }
    static func eventExpiry(_ id: String) -> String { "pawsanctuary.event.expiry.\(id)" }
}

// MARK: - Centre seam

/// The slice of `UNUserNotificationCenter` the scheduling code uses. It exists
/// so `NotificationManagerTests` can replay the foreground/background sequence
/// against a recording stand-in; production always uses the system centre.
/// Method names deliberately differ from the system API's, so the conformance
/// below cannot collide with its default-argument overloads.
protocol NotificationCentre: AnyObject {
    func addRequest(_ request: UNNotificationRequest)
    func removePending(ids: [String])
    func removeDelivered(ids: [String])
    func removeAllPending()
    func removeAllDelivered()
    func clearBadge()
}

extension UNUserNotificationCenter: NotificationCentre {
    func addRequest(_ request: UNNotificationRequest) { add(request) }
    func removePending(ids: [String]) { removePendingNotificationRequests(withIdentifiers: ids) }
    func removeDelivered(ids: [String]) { removeDeliveredNotifications(withIdentifiers: ids) }
    func removeAllPending() { removeAllPendingNotificationRequests() }
    func removeAllDelivered() { removeAllDeliveredNotifications() }
    func clearBadge() { setBadgeCount(0) }
}

// MARK: - Manager

@Observable
@MainActor
final class NotificationManager: NSObject {

    // MARK: Singleton

    static let shared = NotificationManager()

    // MARK: Permission

    /// True once the player has granted authorisation (alert + badge + sound).
    var isAuthorised: Bool = false

    private let centre: any NotificationCentre
    private let now: () -> Date

    override init() {
        centre = UNUserNotificationCenter.current()
        now = Date.init
        super.init()
        UNUserNotificationCenter.current().delegate = self
        Task { await refreshAuthStatus() }
    }

    /// Test seam: a manager over a stand-in centre and clock. It neither
    /// becomes the system centre's delegate nor reads the real authorisation
    /// status, so `isAuthorised` stays exactly what the caller passed.
    init(centre: any NotificationCentre, now: @escaping () -> Date, isAuthorised: Bool) {
        self.centre = centre
        self.now = now
        super.init()
        self.isAuthorised = isAuthorised
    }

    /// Fetches just the authorization status, never letting the non-Sendable
    /// `UNNotificationSettings` itself cross back into this @MainActor type —
    /// older SDKs (pre-iOS 26) don't mark it Sendable, which strict
    /// concurrency rejects at the await site otherwise.
    private nonisolated func fetchAuthorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Requests permission if not already determined.
    /// Returns true when permission is granted (existing or newly approved).
    @discardableResult
    func requestPermission() async -> Bool {
        let centre = UNUserNotificationCenter.current()
        let authorizationStatus = await fetchAuthorizationStatus()
        switch authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            isAuthorised = true
            return true
        case .notDetermined:
            let granted = (try? await centre.requestAuthorization(
                options: [.alert, .badge, .sound])) ?? false
            isAuthorised = granted
            return granted
        default:
            isAuthorised = false
            return false
        }
    }

    // MARK: Schedule — kibble full

    /// Schedules the kibble-full notification.
    ///
    /// There used to be a second overload here taking
    /// `(currentKibble, regenCap, secsUntilNext, regenSecs, kibblePerTick)`
    /// and doing the time-to-full arithmetic itself. It was a verbatim copy
    /// of `KibbleEngine.secondsUntilKibbleFull(bonusPerRegen:)` that also
    /// asked its caller which cap to use — and one of the two callers passed
    /// the flat `kibbleRegenCap`, so level-10+ players were told the bag was
    /// full with a third of it still regenerating. Correcting that argument
    /// left the same mistake available to the next caller, so the parameter
    /// is gone instead: there is now exactly one place that knows how to
    /// compute time-to-full, and no way to schedule this against the wrong
    /// cap. (Removed 11 Sep 2026.)
    ///
    /// Cancel the old one and replace whenever the time-to-full changes.
    func scheduleKibbleFull(secondsUntilFull: TimeInterval) {
        guard isAuthorised, secondsUntilFull > 0 else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Kibble bag is full!"
        content.body      = "Your kibble bag is full! 🐾 Come collect before it overflows."
        content.sound     = .default
        content.badge     = 1

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: secondsUntilFull, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.kibbleFull, content: content, trigger: trigger)

        cancel(ids: [NotificationID.kibbleFull])
        centre.addRequest(request)
    }

    /// Cancels any pending kibble-full notification (call when kibble is spent).
    func cancelKibbleFull() {
        cancel(ids: [NotificationID.kibbleFull])
    }

    // MARK: Schedule — daily rewards

    /// Schedules a daily repeating notification at 09:00 local time.
    /// Safe to call multiple times — removes the old one first.
    func scheduleDailyRewards() {
        guard isAuthorised else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Daily rewards waiting!"
        content.body      = "Your login bonus, Loyalty Club, and Sanctuary Pass rewards are ready to claim."
        content.sound     = .default
        content.badge     = 1

        var comps         = DateComponents()
        comps.hour        = 9
        comps.minute      = 0
        let trigger       = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request       = UNNotificationRequest(
            identifier: NotificationID.dailyRewards, content: content, trigger: trigger)

        cancel(ids: [NotificationID.dailyRewards])
        centre.addRequest(request)
    }

    // MARK: Schedule — adoption order expiry

    /// Schedules a 5-minute warning for an incomplete adoption order.
    /// - Parameters:
    ///   - orderID:       Stable string ID for cancellation.
    ///   - timeRemaining: Seconds left on the order timer.
    ///   - summary:       Short order description for the notification body.
    func scheduleOrderExpiry(orderID: String, timeRemaining: Double, summary: String) {
        guard isAuthorised else { return }
        let warnAt = timeRemaining - 300   // 5-minute warning
        guard warnAt > 10 else { return }  // not worth notifying if already nearly expired

        let content       = UNMutableNotificationContent()
        content.title     = "Adoption order expiring soon!"
        content.body      = "\(summary) — 5 minutes left. Finish the merge!"
        content.sound     = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: warnAt, repeats: false)
        let id      = NotificationID.orderExpiry(orderID)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        cancel(ids: [id])
        centre.addRequest(request)
    }

    // MARK: Schedule — live-ops event expiry (Phase 6a — EventTimer)

    /// Schedules a notification at `date` for an ending live-ops event.
    /// - Parameters:
    ///   - eventID: Stable string ID for cancellation.
    ///   - date:    When to fire — the caller decides how far ahead of the
    ///              event's actual end this should be (see `EventTimer`).
    ///   - summary: Notification body, resolved by the caller from the event's
    ///              own name/tagline.
    func scheduleEventExpiry(eventID: String, at date: Date, summary: String) {
        guard isAuthorised else { return }
        let interval = date.timeIntervalSinceNow
        guard interval > 10 else { return }   // not worth notifying if already nearly there

        let content       = UNMutableNotificationContent()
        content.title     = "Event ending soon!"
        content.body      = summary
        content.sound     = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let id      = NotificationID.eventExpiry(eventID)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

        cancel(ids: [id])
        centre.addRequest(request)
    }

    /// Cancels any pending expiry notification for a specific event.
    func cancelEventExpiry(eventID: String) {
        cancel(ids: [NotificationID.eventExpiry(eventID)])
    }

    // MARK: Schedule — daily challenges reset

    /// Schedules a repeating midnight notification for daily challenges.
    /// Safe to call multiple times — removes the old one first.
    func scheduleDailyReset() {
        guard isAuthorised else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Daily challenges ready!"
        content.body      = "New daily challenges are ready! 🌟 Come check your quests."
        content.sound     = .default
        content.badge     = 1

        var comps         = DateComponents()
        comps.hour        = 0
        comps.minute      = 0
        let trigger       = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request       = UNNotificationRequest(
            identifier: NotificationID.dailyReset, content: content, trigger: trigger)

        cancel(ids: [NotificationID.dailyReset])
        centre.addRequest(request)
    }

    // MARK: Schedule — rescue expiring

    /// Schedules a warning 2 minutes before a rescue order expires.
    /// - Parameter expiresAt: The moment the order expires.
    func scheduleRescueExpiring(expiresAt: Date) {
        guard isAuthorised else { return }
        let warnAt = expiresAt.timeIntervalSinceNow - 120
        guard warnAt > 0 else { return }    // already past the 2-minute window

        let content       = UNMutableNotificationContent()
        content.title     = "Rescue order expiring soon!"
        content.body      = "A rescue animal needs you — time is running out! 🐶"
        content.sound     = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: warnAt, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.rescueExpiring, content: content, trigger: trigger)

        cancel(ids: [NotificationID.rescueExpiring])
        centre.addRequest(request)
    }

    /// Cancels any pending rescue-expiring notification.
    func cancelRescueExpiring() {
        cancel(ids: [NotificationID.rescueExpiring])
    }

    // MARK: Schedule — login streak reminder

    /// Cancels any existing streak reminder and schedules a fresh one for 8 PM tonight.
    /// Call on every app launch/foreground. If it's already past 8 PM, skips (no retroactive fire).
    func cancelAndRescheduleStreakReminder() {
        cancel(ids: [NotificationID.streakReminder])
        guard isAuthorised else { return }

        let current = now()
        var comps   = Calendar.current.dateComponents([.year, .month, .day], from: current)
        comps.hour  = 20
        comps.minute = 0
        guard let fireDate = Calendar.current.date(from: comps),
              fireDate > current else { return }   // already past 8 PM — skip

        let content       = UNMutableNotificationContent()
        content.title     = "Don't lose your streak!"
        content.body      = "Don't lose your streak! 🔥 Log in to Paw Sanctuary before midnight."
        content.sound     = .default
        content.badge     = 1

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.streakReminder, content: content, trigger: trigger)
        centre.addRequest(request)
    }

    // MARK: Schedule — all persistent notifications

    /// Convenience: (re)schedules all repeating/standing notifications.
    /// Call once after permission is granted and again on every foreground.
    func scheduleAll() {
        scheduleDailyReset()
        cancelAndRescheduleStreakReminder()
    }

    /// The backgrounding pass's standing notifications: the ones that do not
    /// depend on board state (kibble-full and order expiry stay with the view,
    /// which owns that state).
    ///
    /// `MergeBoardView` cancels every notification when the app becomes active,
    /// so whatever should be pending while the player is away has to be put
    /// back here. `daily.reset` and `streak.reminder` used to be missing from
    /// this pass: they were only scheduled at cold launch and by `AppEntry`'s
    /// `.active` handler, which that same `cancelAll()` wiped, so a warm return
    /// lost both until the next cold launch (found 10 Nov 2026, TODO.md).
    func scheduleStandingOnBackground() {
        scheduleDailyRewards()
        scheduleAll()
        scheduleReengagement()
    }

    // MARK: Schedule — re-engagement

    /// Schedules a 48-hour re-engagement nudge.
    /// Cancelled immediately when the player opens the app.
    func scheduleReengagement() {
        guard isAuthorised else { return }

        let content       = UNMutableNotificationContent()
        content.title     = "Your sanctuary misses you!"
        content.body      = "Animals are waiting to be rescued. Come back and keep merging!"
        content.sound     = .default
        content.badge     = 1

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 48 * 3600, repeats: false)
        let request = UNNotificationRequest(
            identifier: NotificationID.reengagement, content: content, trigger: trigger)

        cancel(ids: [NotificationID.reengagement])
        centre.addRequest(request)
    }

    // MARK: Cancel

    /// Cancels all pending and delivered notifications.
    func cancelAll() {
        centre.removeAllPending()
        centre.removeAllDelivered()
        centre.clearBadge()
    }

    /// Cancels specific notifications by ID.
    func cancel(ids: [String]) {
        centre.removePending(ids: ids)
        centre.removeDelivered(ids: ids)
    }

    // MARK: Private helpers

    private func refreshAuthStatus() async {
        let authorizationStatus = await fetchAuthorizationStatus()
        isAuthorised = authorizationStatus == .authorized
            || authorizationStatus == .provisional
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationManager: UNUserNotificationCenterDelegate {
    /// Allows notifications to be shown as banners while the app is in the foreground.
    nonisolated func userNotificationCenter(
        _ centre: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Suppress banners while the app is in the foreground — the game's own UI
        // provides real-time feedback, so a system banner would be redundant noise.
        handler([])
    }
}
