//
//  HapticManager.swift
//  PawSanctuary
//
//  Singleton haptic controller. Reads SoundManager.shared.isMuted — if sound
//  is muted, all haptic methods no-op. No separate mute setting or UserDefaults key.
//

import UIKit

@MainActor
final class HapticManager {

    static let shared = HapticManager()

    private let lightGenerator  = UIImpactFeedbackGenerator(style: .light)
    private let mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let notifyGenerator = UINotificationFeedbackGenerator()

    private init() {
        lightGenerator.prepare()
        mediumGenerator.prepare()
        notifyGenerator.prepare()
    }

    // MARK: - Methods

    /// Board cell taps.
    func lightTap() {
        guard !SoundManager.shared.isMuted else { return }
        lightGenerator.impactOccurred()
    }

    /// Successful animal merge.
    func mediumImpact() {
        guard !SoundManager.shared.isMuted else { return }
        mediumGenerator.impactOccurred()
    }

    /// Cell unlock, quest claim, daily challenge complete.
    func successPattern() {
        guard !SoundManager.shared.isMuted else { return }
        notifyGenerator.notificationOccurred(.success)
    }
}
