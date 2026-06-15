//
//  AdProvider.swift
//  PawSanctuary
//
//  Thin abstraction over rewarded ad SDKs.
//  Swap StubAdProvider for an AdMob / AppLovin implementation at integration time.
//

import Foundation

// MARK: - Result

enum AdResult {
    case earned      // player watched to completion — grant the reward
    case cancelled   // player dismissed early — no reward
    case failed      // SDK error — no reward
}

// MARK: - Protocol

/// Any rewarded-ad SDK can conform to this protocol.
/// The caller receives the result on the main thread.
protocol RewardedAdProvider {
    func showRewardedAd(completion: @escaping @Sendable (AdResult) -> Void)
}

// MARK: - Stub (used until a real SDK is integrated)

/// Simulates a short ad: waits 1.5 s then calls back with .earned.
/// Replace this with the real provider before App Store submission.
struct StubAdProvider: RewardedAdProvider {
    func showRewardedAd(completion: @escaping @Sendable (AdResult) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            completion(.earned)
        }
    }
}
