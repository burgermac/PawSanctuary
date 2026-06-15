//
//  MilestoneOverlayView.swift
//  PawSanctuary
//
//  Full-screen celebratory overlay shown when the player earns a Sanctuary Star
//  milestone title. Styled to match LoginRewardView in PanelViews.swift.
//

import SwiftUI

struct MilestoneOverlayView: View {
    var viewModel: MergeBoardViewModel
    let milestone: StarMilestone

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 22) {

                // ── Star count badge ──────────────────────────────────
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color(red: 0.98, green: 0.82, blue: 0.15),
                                         Color(red: 0.90, green: 0.55, blue: 0.08)],
                                center: .center,
                                startRadius: 4,
                                endRadius: 38)
                        )
                        .frame(width: 76, height: 76)
                        .shadow(color: Color(red: 0.90, green: 0.60, blue: 0.10).opacity(0.6),
                                radius: 14)

                    Image(systemName: milestone.icon)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.white)
                }

                // ── Headline ─────────────────────────────────────────
                VStack(spacing: 6) {
                    Text("Milestone Reached!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))

                    Text("\(milestone.threshold) Sanctuary Stars")
                        .font(.title2.bold())
                        .foregroundColor(Color(red: 0.98, green: 0.82, blue: 0.15))
                }

                // ── Title badge ──────────────────────────────────────
                VStack(spacing: 4) {
                    Text("New Title")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.65))

                    Text(milestone.title)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 20).padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.white.opacity(0.18))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .strokeBorder(Color(red: 0.98, green: 0.82, blue: 0.15)
                                                        .opacity(0.6), lineWidth: 1.5)
                                )
                        )
                }

                // ── Reward card ──────────────────────────────────────
                HStack(spacing: 10) {
                    Image(systemName: rewardIcon)
                        .font(.title2)
                        .foregroundColor(Color(red: 0.98, green: 0.82, blue: 0.15))
                    Text(milestone.rewardDescription)
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(18)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.15)))

                // ── Claim button ─────────────────────────────────────
                Button(action: {
                    MilestoneManager.shared.claimPendingMilestone(viewModel: viewModel)
                }) {
                    Text("Claim Reward!")
                        .font(.headline.bold())
                        .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.05))
                        .padding(.horizontal, 50).padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 25)
                                .fill(Color(red: 0.98, green: 0.82, blue: 0.15))
                                .shadow(color: Color(red: 0.90, green: 0.60, blue: 0.10).opacity(0.4),
                                        radius: 8, y: 4)
                        )
                }
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.22, green: 0.18, blue: 0.05),
                                     Color(red: 0.38, green: 0.28, blue: 0.06)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 24)
            )
            .padding(28)
        }
    }

    private var rewardIcon: String {
        switch milestone.threshold {
        case 5:  return "pawprint.fill"
        case 15: return "tag.fill"
        case 30: return "tray.and.arrow.down.fill"
        case 50: return "fish.fill"
        default: return "gift.fill"
        }
    }
}
