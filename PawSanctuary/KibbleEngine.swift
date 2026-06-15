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

    // Rewarded ads
    var adsWatchedToday: Int = 0
    var lastAdWatchDate: Date? = nil
    var isWatchingAd: Bool = false

    // Kibble refill sheet
    var showKibbleSheet: Bool = false

    // MARK: Computed

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
        if kibble < kibbleRegenCap {
            secondsUntilNextKibble -= 1
            if secondsUntilNextKibble <= 0 {
                kibble = min(kibbleRegenCap, kibble + 1 + bonusPerRegen)
                secondsUntilNextKibble = kibbleRegenSecs
                if kibble >= kibbleRegenCap {
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

    /// Time interval (seconds) until the kibble bar reaches `kibbleRegenCap`.
    /// Returns `nil` if already at cap.
    func secondsUntilKibbleFull(bonusPerRegen: Int) -> TimeInterval? {
        guard kibble < kibbleRegenCap else { return nil }
        let kibblePerTick = max(1, 1 + bonusPerRegen)
        let needed = kibbleRegenCap - kibble
        let ticks  = Int(ceil(Double(needed) / Double(kibblePerTick)))
        return TimeInterval(secondsUntilNextKibble + max(0, ticks - 1) * kibbleRegenSecs)
    }

    // MARK: Dog Tag exchange

    func exchangeTagsForKibble(_ exchange: DogTagKibbleExchange) {
        guard dogTags >= exchange.dogTagCost else { return }
        dogTags -= exchange.dogTagCost
        kibble  += exchange.kibbleGain
    }

    // MARK: Rewarded ads

    /// Presents a rewarded ad and grants kibble on success.
    /// `effectiveKibble` is pre-computed by the caller (pass bonus applied there).
    func watchRewardedAd(effectiveKibble: Int,
                         provider: RewardedAdProvider = StubAdProvider()) {
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
                self.kibble           += effectiveKibble
            }
        }
    }

    // MARK: Offline progress

    /// Advances kibble regen by `secs` seconds of elapsed offline time.
    func applyOfflineProgress(secs: Int) {
        guard kibble < kibbleRegenCap, secs >= 1 else { return }
        let need = secondsUntilNextKibble
        if secs >= need {
            let remainder = secs - need
            let gained    = 1 + remainder / kibbleRegenSecs
            kibble = min(kibbleRegenCap, kibble + gained)
            secondsUntilNextKibble = (kibble >= kibbleRegenCap)
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
    }

    func capture(into s: inout GameState) {
        s.kibble                 = kibble
        s.dogTags                = dogTags
        s.secondsUntilNextKibble = secondsUntilNextKibble
        s.adsWatchedToday        = adsWatchedToday
        s.lastAdWatchDate        = lastAdWatchDate
    }
}
