//
//  KibbleEngine.swift
//  PawSanctuary
//
//  Owns all kibble/dog-tag currency state, regeneration timer logic, and rewarded ad
//  bookkeeping. MergeBoardViewModel holds an instance of this class and exposes
//  forwarding computed properties so existing view code requires zero changes.
//

import SwiftUI
import Observation

@Observable
@MainActor
class KibbleEngine {

    // MARK: Stored state

    var kibble: Int = startingKibble
    var dogTags: Int = 0
    var secondsUntilNextKibble: Int = kibbleRegenSecs

    /// Mirrors PlayerProgression.playerLevel so KibbleEngine can compute the
    /// effective regen cap without a circular dependency. Updated by restore(from:)
    /// and by MergeBoardViewModel whenever the level changes.
    var playerLevel: Int = 1

    // Dog Tag → Kibble ladder (v27, Task 2.4) — escalating within a day, resets daily.
    var dogTagExchangesToday: Int = 0
    var lastExchangeResetDate: Date? = nil

    // Rewarded ads
    var adsWatchedToday: Int = 0
    var lastAdWatchDate: Date? = nil
    var isWatchingAd: Bool = false

    // Kibble refill sheet
    var showKibbleSheet: Bool = false

    // MARK: Computed

    /// At level 10+ the regen cap rises from 100 to 150, rewarding progression.
    var effectiveRegenCap: Int { playerLevel >= 10 ? 150 : kibbleRegenCap }

    /// Countdown string shown next to the kibble icon.
    var kibbleStatusText: String {
        let m = secondsUntilNextKibble / 60
        let s = secondsUntilNextKibble % 60
        return String(format: "%d:%02d", m, s)
    }

    var kibbleDisplayText: String { "\(kibble)" }

    /// UTC 09:00 today — the daily ad reset boundary.
    private var adResetUTC: Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var comps = cal.dateComponents([.year, .month, .day], from: Date())
        comps.hour = 9; comps.minute = 0; comps.second = 0
        return cal.date(from: comps) ?? Date()
    }

    /// Remaining ad watches today. Resets to `maxDailyAdWatches` at 09:00 UTC.
    var remainingAdWatches: Int {
        guard let last = lastAdWatchDate else { return maxDailyAdWatches }
        return last >= adResetUTC
            ? max(0, maxDailyAdWatches - adsWatchedToday)
            : maxDailyAdWatches
    }

    // MARK: Regen tick

    /// Called every second by MergeBoardViewModel's timer.
    /// `bonusPerRegen` comes from active area-upgrade bonuses.
    func tick(bonusPerRegen: Int) {
        let cap = effectiveRegenCap
        if kibble < cap {
            secondsUntilNextKibble -= 1
            if secondsUntilNextKibble <= 0 {
                kibble = min(cap, kibble + 1 + bonusPerRegen)
                secondsUntilNextKibble = kibbleRegenSecs
                if kibble >= cap {
                    // Bag just hit cap — cancel the pending notification.
                    NotificationManager.shared.cancelKibbleFull()
                } else if let secs = secondsUntilKibbleFull(bonusPerRegen: bonusPerRegen) {
                    // Reschedule for the updated time-to-full.
                    NotificationManager.shared.scheduleKibbleFull(secondsUntilFull: secs)
                }
            }
        } else {
            secondsUntilNextKibble = kibbleRegenSecs
        }
    }

    /// Time interval (seconds) until the kibble bar reaches `effectiveRegenCap`.
    /// Returns `nil` if already at cap.
    func secondsUntilKibbleFull(bonusPerRegen: Int) -> TimeInterval? {
        let cap = effectiveRegenCap
        guard kibble < cap else { return nil }
        let kibblePerTick = max(1, 1 + bonusPerRegen)
        let needed = cap - kibble
        let ticks  = Int(ceil(Double(needed) / Double(kibblePerTick)))
        return TimeInterval(secondsUntilNextKibble + max(0, ticks - 1) * kibbleRegenSecs)
    }

    // MARK: Dog Tag exchange

    /// Today's offer on the escalating ladder. Rolls over on a calendar-day change.
    var currentTagExchange: DogTagKibbleExchange {
        DogTagKibbleExchange.offer(purchasesToday: exchangesTodayAfterReset)
    }

    /// `dogTagExchangesToday`, treated as 0 once the day has rolled over.
    /// Read-only so the getter stays side-effect free; `rollOverExchangeDayIfNeeded`
    /// is what actually commits the reset.
    private var exchangesTodayAfterReset: Int {
        guard let last = lastExchangeResetDate,
              Calendar.current.isDateInToday(last) else { return 0 }
        return dogTagExchangesToday
    }

    /// Commits the daily reset if the calendar day has changed.
    func rollOverExchangeDayIfNeeded() {
        if let last = lastExchangeResetDate, Calendar.current.isDateInToday(last) { return }
        dogTagExchangesToday  = 0
        lastExchangeResetDate = Date()
    }

    /// Buys the current rung of today's ladder. Each purchase makes the next dearer.
    @discardableResult
    func exchangeTagsForKibble() -> Bool {
        rollOverExchangeDayIfNeeded()
        let offer = DogTagKibbleExchange.offer(purchasesToday: dogTagExchangesToday)
        guard dogTags >= offer.dogTagCost else { return false }
        dogTags -= offer.dogTagCost
        kibble  += offer.kibbleGain
        dogTagExchangesToday += 1
        return true
    }

    // MARK: Rewarded ads

    /// Presents a rewarded ad, counting it against the shared daily cap on
    /// success and then calling `onEarned` — callers decide what a watch
    /// grants (kibble, a bubble pop, etc.), matching the reference's "build
    /// one primitive and use it everywhere" (Merge2_Reference_Blueprint.md §3).
    func watchRewardedAd(provider: RewardedAdProvider = StubAdProvider(),
                         onEarned: @escaping @MainActor @Sendable () -> Void) {
        guard remainingAdWatches > 0, !isWatchingAd else { return }
        isWatchingAd = true
        provider.showRewardedAd { result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isWatchingAd = false
                guard result == .earned else { return }
                // Reset counter if the UTC window has rolled over.
                if (self.lastAdWatchDate ?? .distantPast) < self.adResetUTC {
                    self.adsWatchedToday = 0
                }
                self.adsWatchedToday += 1
                self.lastAdWatchDate  = Date()
                onEarned()
            }
        }
    }

    // MARK: Offline progress

    /// Advances kibble regen by `secs` seconds of elapsed offline time.
    func applyOfflineProgress(secs: Int) {
        let cap = effectiveRegenCap
        guard kibble < cap, secs >= 1 else { return }
        let need = secondsUntilNextKibble
        if secs >= need {
            let remainder = secs - need
            let gained    = 1 + remainder / kibbleRegenSecs
            kibble = min(cap, kibble + gained)
            secondsUntilNextKibble = (kibble >= cap)
                ? kibbleRegenSecs
                : kibbleRegenSecs - (remainder % kibbleRegenSecs)
        } else {
            secondsUntilNextKibble = need - secs
        }
    }

    // MARK: Persistence

    func restore(from s: GameState) {
        kibble                 = s.kibble
        dogTags                = s.dogTags
        secondsUntilNextKibble = s.secondsUntilNextKibble
        adsWatchedToday        = s.adsWatchedToday
        lastAdWatchDate        = s.lastAdWatchDate
        playerLevel            = s.playerLevel
        dogTagExchangesToday   = s.dogTagExchangesToday
        lastExchangeResetDate  = s.lastExchangeResetDate
    }

    func capture(into s: inout GameState) {
        s.kibble                 = kibble
        s.dogTags                = dogTags
        s.secondsUntilNextKibble = secondsUntilNextKibble
        s.adsWatchedToday        = adsWatchedToday
        s.lastAdWatchDate        = lastAdWatchDate
        s.dogTagExchangesToday   = dogTagExchangesToday
        s.lastExchangeResetDate  = lastExchangeResetDate
    }
}
