//
//  MilestoneManager.swift
//  PawSanctuary
//
//  Tracks Sanctuary Star milestone progress and queues the celebratory overlay.
//  Earned titles and rewards are defined by the GDD (section 6):
//
//    5 Stars  → "Junior Rescuer"      + 10 Kibble
//    15 Stars → "Animal Friend"       + 5 Dog Tags
//    30 Stars → "Sanctuary Guardian"  + free inventory row
//    50 Stars → "Legendary Rescuer"   + 50 Dog Tags + 100 Kibble
//              (Aquatics unlocks via the Coral Reef map area — Phase 5 Q4 decision)
//

import SwiftUI
import Observation

// ============================================================
// MARK: - STAR MILESTONE MODEL
// ============================================================

struct StarMilestone: Equatable {
    let threshold: Int          // ambassador count that triggers this milestone
    let title: String           // honorary title awarded to the player
    let rewardDescription: String
    let icon: String            // SF Symbol name for display
}

// ============================================================
// MARK: - MILESTONE MANAGER
// ============================================================

@Observable
@MainActor
final class MilestoneManager {

    // Shared singleton — views observe it by accessing properties directly.
    // nonisolated(unsafe) matches the pattern used in MergeBoardViewModel for static
    // storage that is only ever accessed from the main actor.
    static let shared = MilestoneManager()
    private init() {}

    // Non-nil while the overlay should be visible.
    var pendingMilestone: StarMilestone? = nil

    // Ordered list — check fires through all of them so no milestone is skipped
    // even if the player earns several stars in rapid succession.
    let milestones: [StarMilestone] = [
        StarMilestone(threshold:  5, title: "Junior Rescuer",
                      rewardDescription: "+10 Kibble",
                      icon: "heart.circle.fill"),
        StarMilestone(threshold: 15, title: "Animal Friend",
                      rewardDescription: "+5 Dog Tags",
                      icon: "tag.circle.fill"),
        StarMilestone(threshold: 30, title: "Sanctuary Guardian",
                      rewardDescription: "Free Inventory Row",
                      icon: "tray.full.fill"),
        StarMilestone(threshold: 50, title: "Legendary Rescuer",
                      rewardDescription: "+100 Kibble  ·  +50 Dog Tags",
                      icon: "star.circle.fill"),
    ]

    // MARK: - Persistence

    /// The set of thresholds the player has already claimed, stored in UserDefaults.
    private var claimedThresholds: [Int] {
        get { UserDefaults.standard.array(forKey: "claimedMilestones") as? [Int] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: "claimedMilestones") }
    }

    // MARK: - Public API

    /// Call this every time `ambassadors` (sanctuary-star count) changes.
    /// Finds the highest unclaimed threshold ≤ `stars` and queues the overlay.
    /// If an overlay is already pending, it waits until the current one is claimed.
    func checkMilestones(stars: Int) {
        guard pendingMilestone == nil else { return }
        let claimed = claimedThresholds
        let candidate = milestones
            .filter { $0.threshold <= stars && !claimed.contains($0.threshold) }
            .max(by: { $0.threshold < $1.threshold })
        pendingMilestone = candidate
    }

    /// Applies the queued milestone's reward, persists the claim, and dismisses the overlay.
    func claimPendingMilestone(viewModel: MergeBoardViewModel) {
        guard let milestone = pendingMilestone else { return }
        applyReward(milestone, viewModel: viewModel)

        var claimed = claimedThresholds
        claimed.append(milestone.threshold)
        claimedThresholds = claimed

        withAnimation(.easeOut(duration: 0.3)) {
            pendingMilestone = nil
        }

        // Persist immediately so the claim survives a force-quit.
        viewModel.persist()

        // If another unclaimed milestone is already reachable, queue it after a
        // brief delay so the player sees each overlay individually.
        let currentStars = viewModel.ambassadors
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            self?.checkMilestones(stars: currentStars)
        }
    }

    // MARK: - Reward application

    private func applyReward(_ milestone: StarMilestone, viewModel: MergeBoardViewModel) {
        switch milestone.threshold {

        case 5:
            // +10 Kibble (does not exceed kibble regen cap for milestone rewards)
            viewModel.kibbleEngine.kibble += 10
            SoundManager.shared.playQuestClaim()
            HapticManager.shared.successPattern()

        case 15:
            // +5 Dog Tags
            viewModel.kibbleEngine.dogTags += 5
            SoundManager.shared.playQuestClaim()
            HapticManager.shared.successPattern()

        case 30:
            // Unlock a free inventory row (row 1 first, then row 2)
            if !viewModel.inventoryRow1Unlocked {
                viewModel.inventoryRow1Unlocked = true
            } else if !viewModel.inventoryRow2Unlocked {
                viewModel.inventoryRow2Unlocked = true
            } else {
                // Both rows already unlocked — compensate with kibble
                viewModel.kibbleEngine.kibble += 20
            }
            SoundManager.shared.playQuestClaim()
            HapticManager.shared.successPattern()

        case 50:
            // Aquatics now unlocks via the Coral Reef map area (Phase 5, Q4 decision).
            // The 50-star milestone instead awards a large kibble + dog tag bonus.
            viewModel.kibbleEngine.kibble   += 100
            viewModel.kibbleEngine.dogTags  += 50
            SoundManager.shared.playQuestClaim()
            HapticManager.shared.successPattern()

        default:
            break
        }
    }
}
