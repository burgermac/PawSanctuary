//
//  EventPanelView.swift
//  PawSanctuary
//
//  Sheet panel for time-limited events.
//
//  Phase 6b: reads milestones from ProgressTrackRegistry/ProgressTrack
//  (Phase 6a primitive) rather than EventDefinition.milestones/eventProgress —
//  the old EventMilestone/EventProgress path is left inert, not deleted (see
//  specs/Spec_Phase6b_MilestoneTrack.md §3.6).
//

import SwiftUI

// ============================================================
// MARK: - SHEET VIEW
// ============================================================

struct EventSheetView: View {
    let viewModel: MergeBoardViewModel
    let event: EventDefinition
    @Environment(\.dismiss) private var dismiss

    private var milestones: [TrackMilestone] {
        ProgressTrackRegistry.tracks[event.id] ?? []
    }

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
        let maxTokens = milestones.last?.threshold ?? 1
        let earned = viewModel.progressTrack.progress(trackID: event.id)
        let progress = min(1.0, Double(earned) / Double(maxTokens))

        return VStack(spacing: 8) {
            HStack {
                Label("Event Coins", systemImage: "circle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(event.accentColor)
                Spacer()
                Text("\(earned) / \(maxTokens)")
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
                    ForEach(milestones, id: \.index) { m in
                        let x = geo.size.width * (Double(m.threshold) / Double(maxTokens))
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
            ForEach(milestones, id: \.index) { milestone in
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
    let milestone: TrackMilestone

    /// `claimable` returns exactly "reached and the free lane isn't claimed
    /// yet" for a paidLaneUnlocked:false query — everything else (isReached,
    /// isClaimed) is derived from that plus `progress`, rather than adding a
    /// direct "is this claimed" query to `ProgressTrack`'s public surface for
    /// a UI-only need.
    private var canClaim: Bool {
        viewModel.progressTrack.claimable(trackID: event.id, paidLaneUnlocked: false)
            .contains { $0.index == milestone.index }
    }
    private var isReached: Bool {
        viewModel.progressTrack.progress(trackID: event.id) >= milestone.threshold
    }
    private var isClaimed: Bool { isReached && !canClaim }

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
                    Text("\(milestone.index)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isReached ? .white : .secondary)
                }
            }

            // Reward description
            VStack(alignment: .leading, spacing: 3) {
                Text("\(milestone.threshold) coins")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(Array(milestone.freeRewards.enumerated()), id: \.offset) { _, reward in
                        rewardPill(reward)
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
                Button(action: {
                    viewModel.claimMilestoneTrack(trackID: event.id, milestone: milestone.index)
                }) {
                    Text("Claim!")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(event.accentColor))
                }
            } else {
                Text("\(milestone.threshold - viewModel.progressTrack.progress(trackID: event.id)) to go")
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

    /// Only the reward kinds a milestone track actually pays today (kibble,
    /// dog tags — Spec_Phase6b_MilestoneTrack.md §4) get a dedicated pill;
    /// anything else renders as a plain amount rather than guessing an icon
    /// for a kind this track doesn't use yet.
    @ViewBuilder
    private func rewardPill(_ reward: OrderReward) -> some View {
        switch reward.kind {
        case .kibble:
            Label("+\(reward.amount) Kibble", systemImage: "pawprint.fill")
                .font(.subheadline.bold())
                .foregroundColor(.green)
        case .dogTags:
            Label("+\(reward.amount) Tags", systemImage: "tag.fill")
                .font(.subheadline.bold())
                .foregroundColor(.blue)
        default:
            Text("+\(reward.amount)")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
        }
    }
}
