//
//  InviteSystem.swift
//  PawSanctuary
//
//  Invite-a-friend models, milestone definitions, and share sheet wrapper.
//

import SwiftUI

// TODO: replace with real App Store URL before launch
let pawSanctuaryAppStoreURL = "https://apps.apple.com/app/pawsanctuary/id0000000000"

// ============================================================
// MARK: - PERSISTED STATE
// ============================================================

struct InviteProgress: Codable, Equatable {
    var invitesSent: Int = 0
    var claimedMilestones: [Int] = []

    func hasClaimed(_ tier: Int) -> Bool { claimedMilestones.contains(tier) }

    func canClaim(_ milestone: InviteMilestone) -> Bool {
        invitesSent >= milestone.invitesRequired && !hasClaimed(milestone.id)
    }
}

// ============================================================
// MARK: - MILESTONE DEFINITIONS
// ============================================================

struct InviteMilestone: Identifiable {
    let id: Int
    let invitesRequired: Int
    let kibbleReward: Int
    let dogTagsReward: Int
}

let inviteMilestones: [InviteMilestone] = [
    InviteMilestone(id: 1, invitesRequired: 1, kibbleReward: 50,  dogTagsReward: 0),
    InviteMilestone(id: 2, invitesRequired: 3, kibbleReward: 0,   dogTagsReward: 3),
    InviteMilestone(id: 3, invitesRequired: 5, kibbleReward: 100, dogTagsReward: 5),
]

// ============================================================
// MARK: - SHARE SHEET
// ============================================================

/// Wraps UIActivityViewController for SwiftUI presentation.
/// `onShared` fires only when the user completes an activity (not on cancel).
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onShared: (() -> Void)?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: items, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, completed, _, _ in
            if completed { onShared?() }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
