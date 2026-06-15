//
//  EventPanelView.swift
//  PawSanctuary
//
//  Sheet panel for time-limited events.
//

import SwiftUI

// ============================================================
// MARK: - SHEET VIEW
// ============================================================

struct EventSheetView: View {
    let viewModel: MergeBoardViewModel
    let event: EventDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    progressSection
                    milestonesSection
                }
                .padding(24)
            }
            .background(
                LinearGradient(
                    colors: event.gradientColors,
                    startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
            )
            .navigationTitle(event.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(event.accentColor)
                }
            }
        }
    }

    // MARK: Subviews

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: event.icon)
                    .font(.system(size: 26, weight: .bold))
                    .foregroundColor(event.accentColor)
                Text(event.name)
                    .font(.title2.bold())
                    .foregroundColor(event.accentColor)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(event.timerLabel)
                        .font(.caption.bold())
                        .foregroundColor(event.isUrgent ? .red : event.accentColor)
                    if event.isUrgent {
                        Text("Hurry!")
                            .font(.caption2)
                            .foregroundColor(.red)
                    }
                }
            }
            Text(event.tagline)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var progressSection: some View {
        let maxCoins = event.milestones.last?.coinsRequired ?? 1
        let earned = viewModel.eventProgress.coinsEarned
        let progress = min(1.0, Double(earned) / Double(maxCoins))

        return VStack(spacing: 8) {
            HStack {
                Label("Event Coins", systemImage: "circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(event.accentColor)
                Spacer()
                Text("\(earned) / \(maxCoins)")
                    .font(.subheadline.bold())
                    .foregroundColor(event.accentColor)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.black.opacity(0.10))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [event.accentColor, event.accentColor.opacity(0.65)],
                            startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * progress, height: 12)
                    // Milestone tick marks
                    ForEach(event.milestones) { m in
                        let x = geo.size.width * (Double(m.coinsRequired) / Double(maxCoins))
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 2, height: 12)
                            .offset(x: x - 1)
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.45)))
    }

    private var milestonesSection: some View {
        VStack(spacing: 10) {
            ForEach(event.milestones) { milestone in
                MilestoneRowView(
                    viewModel: viewModel,
                    event: event,
                    milestone: milestone
                )
            }
        }
    }
}

// ============================================================
// MARK: - MILESTONE ROW
// ============================================================

private struct MilestoneRowView: View {
    let viewModel: MergeBoardViewModel
    let event: EventDefinition
    let milestone: EventMilestone

    private var isClaimed: Bool  { viewModel.eventProgress.hasClaimed(milestone.id) }
    private var isReached: Bool  { viewModel.eventProgress.coinsEarned >= milestone.coinsRequired }
    private var canClaim: Bool   { viewModel.eventProgress.canClaim(milestone) }

    var body: some View {
        HStack(spacing: 12) {
            // Tier badge
            ZStack {
                Circle()
                    .fill(isClaimed ? Color.green.opacity(0.8)
                          : isReached ? event.accentColor
                          : Color.gray.opacity(0.3))
                    .frame(width: 36, height: 36)
                if isClaimed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(milestone.id)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isReached ? .white : .secondary)
                }
            }

            // Reward description
            VStack(alignment: .leading, spacing: 3) {
                Text("\(milestone.coinsRequired) coins")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    if milestone.kibbleReward > 0 {
                        Label("+\(milestone.kibbleReward) Kibble", systemImage: "pawprint.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                    }
                    if milestone.dogTagsReward > 0 {
                        Label("+\(milestone.dogTagsReward) Tags", systemImage: "tag.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.blue)
                    }
                }
            }

            Spacer()

            // Action
            if isClaimed {
                Text("Claimed")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            } else if canClaim {
                Button(action: { viewModel.claimEventMilestone(tier: milestone.id) }) {
                    Text("Claim!")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(event.accentColor))
                }
            } else {
                Text("\(milestone.coinsRequired - viewModel.eventProgress.coinsEarned) to go")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 60)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isClaimed ? Color.green.opacity(0.08)
                      : isReached ? event.accentColor.opacity(0.08)
                      : Color.white.opacity(0.35))
        )
    }
}
