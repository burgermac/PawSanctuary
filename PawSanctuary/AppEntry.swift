//
//  AppEntry.swift
//  PawSanctuary
//

import SwiftUI

@main
struct MergeGameApp: App {

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MergeBoardView()
                .task {
                    // Request notification permission only after the player has a save file
                    // (i.e., not on the very first cold launch — avoids the prompt firing
                    // before the player has seen any game content).
                    guard FileManager.default.fileExists(atPath: GameStore.mainFileURL.path) else { return }
                    await NotificationManager.shared.requestPermission()
                    NotificationManager.shared.scheduleAll()
                }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            // On every foreground: cancel the streak reminder (player is active) and
            // reschedule it for 8 PM tonight; also refresh the midnight daily-reset trigger.
            Task { @MainActor in
                NotificationManager.shared.cancelAndRescheduleStreakReminder()
                NotificationManager.shared.scheduleDailyReset()
            }
        }
    }
}
