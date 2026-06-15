//
//  SoundManager.swift
//  PawSanctuary
//
//  Singleton sound controller using AudioToolbox system sounds.
//  Swap AudioServicesPlaySystemSound IDs for custom assets when final audio is ready.
//

import Foundation
import AudioToolbox
import Combine

@MainActor
final class SoundManager: ObservableObject {

    static let shared = SoundManager()

    private let mutedKey = "soundMuted"

    @Published var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: mutedKey) }
    }

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: "soundMuted")
    }

    // MARK: - Play methods

    /// Successful animal merge.
    func playMerge() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1104) // key press click
    }

    /// Board cell (row) unlocked.
    func playCellUnlock() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1057) // unlock
    }

    /// Ambassador quest reward claimed.
    func playQuestClaim() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1025) // positive
    }

    /// All daily challenges complete.
    func playDailyChallenge() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1016) // complete
    }

    /// Rescue / adoption order claimed.
    func playRescueClaim() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1013)
    }

    /// Generic primary button tap.
    func playButtonTap() {
        guard !isMuted else { return }
        AudioServicesPlaySystemSound(1306) // tock
    }
}
