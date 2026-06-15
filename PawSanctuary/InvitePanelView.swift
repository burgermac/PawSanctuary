//
//  InvitePanelView.swift
//  PawSanctuary
//
//  Inline panel for the Invite-a-Friend feature with share sheet and milestone track.
//

import SwiftUI

struct InvitePanelView: View {
    let viewModel: MergeBoardViewModel

    @State private var showShareSheet = false

    private let teal   = Color(red: 0.10, green: 0.52, blue: 0.52)
    private let light  = Color(red: 0.88, green: 0.98, blue: 0.97)
    private let light2 = Color(red: 0.80, green: 0.95, blue: 0.94)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            progressBar
            milestonesTrack
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [light, light2],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
                .shadow(color: teal.opacity(0.15), radius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(teal.opacity(0.30), lineWidth: 1)
        )
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(
                items: [inviteMessage()],
                onShared: { viewModel.recordInviteSent() }
            )
            .presentationDetents([.medium, .large])
        }
    }

    // MARK: Subviews

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.badge.plus").foregroundColor(teal)
            Text("Invite a Friend")
                .font(.headline).foregroundColor(teal)
            Spacer()
            Text("\(viewModel.inviteProgress.invitesSent) sent")
                .font(.caption).foregroundColor(.secondary)
            Button(action: { showShareSheet = true }) {
                Label("Invite", systemImage: "square.and.arrow.up")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 10).fill(teal))
            }
        }
    }

    private var progressBar: some View {
        let max = inviteMilestones.last?.invitesRequired ?? 1
        let progress = min(1.0, Double(viewModel.inviteProgress.invitesSent) / Double(max))
        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4).fill(Color.black.opacity(0.07)).frame(height: 6)
                RoundedRectangle(cornerRadius: 4)
                    .fill(LinearGradient(colors: [teal, teal.opacity(0.6)],
                                        startPoint: .leading, endPoint: .trailing))
                    .frame(width: geo.size.width * progress, height: 6)
            }
        }
        .frame(height: 6)
    }

    private var milestonesTrack: some View {
        HStack(spacing: 8) {
            ForEach(inviteMilestones) { milestone in
                InviteMilestoneChip(
                    viewModel: viewModel,
                    milestone: milestone,
                    teal: teal
                )
            }
        }
    }

    // MARK: Helper

    private func inviteMessage() -> String {
        "I'm rescuing animals in PawSanctuary — a relaxing merge game! Come join me. \(pawSanctuaryAppStoreURL)"
    }
}

// ============================================================
// MARK: - MILESTONE CHIP
// ============================================================

private struct InviteMilestoneChip: View {
    let viewModel: MergeBoardViewModel
    let milestone: InviteMilestone
    let teal: Color

    private var isClaimed: Bool { viewModel.inviteProgress.hasClaimed(milestone.id) }
    private var isReached: Bool { viewModel.inviteProgress.invitesSent >= milestone.invitesRequired }
    private var canClaim: Bool  { viewModel.inviteProgress.canClaim(milestone) }

    var body: some View {
        VStack(spacing: 5) {
            // Badge
            ZStack {
                Circle()
                    .fill(isClaimed ? Color.green.opacity(0.75)
                          : isReached ? teal
                          : Color.gray.opacity(0.25))
                    .frame(width: 32, height: 32)
                if isClaimed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                } else {
                    Text("\(milestone.invitesRequired)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(isReached ? .white : .secondary)
                }
            }

            // Reward label
            VStack(spacing: 1) {
                if milestone.kibbleReward > 0 {
                    Text("+\(milestone.kibbleReward)")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.green)
                    Text("Kibble")
                        .font(.system(size: 8)).foregroundColor(.secondary)
                }
                if milestone.dogTagsReward > 0 {
                    Text("+\(milestone.dogTagsReward)")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.blue)
                    Text("Tags")
                        .font(.system(size: 8)).foregroundColor(.secondary)
                }
            }

            // Claim button
            if canClaim {
                Button(action: { viewModel.claimInviteMilestone(tier: milestone.id) }) {
                    Text("Claim")
                        .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(RoundedRectangle(cornerRadius: 6).fill(teal))
                }
            } else if isClaimed {
                Text("Done")
                    .font(.system(size: 9)).foregroundColor(.green)
            } else {
                Text("\(milestone.invitesRequired - viewModel.inviteProgress.invitesSent) to go")
                    .font(.system(size: 8)).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isClaimed ? Color.green.opacity(0.07)
                      : isReached ? teal.opacity(0.08)
                      : Color.white.opacity(0.45))
        )
    }
}
