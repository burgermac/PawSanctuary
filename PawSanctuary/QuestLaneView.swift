//
//  QuestLaneView.swift
//  PawSanctuary
//
//  Standing-quest cards on the horizontal lane (Spec_QuestLaneCards_Draft.md,
//  Task 5.1). One card per active quest, leading the lane so they sit next to
//  the task tray.
//
//  Lane order is a developer decision, not a measured convention: quests lead
//  (claimable first), then daily tasks, the urgent order, and the orders.
//  This supersedes the draft spec's Q2, which trailed the quests.
//

import SwiftUI

private let questLaneCardWidth: CGFloat = 160

// ============================================================
// MARK: - ORDERING
// ============================================================

/// The kinds of card the lane can hold, in the order the lane lays them out.
enum LaneCardKind: Equatable {
    case claimableQuest, inProgressQuest, dailyTask, urgentOrder, order
}

/// The lane's card order as a pure function of what exists, so it can be
/// tested without a view. `OrderLaneView` renders in exactly this order.
func laneCardKinds(claimableQuests: Int, inProgressQuests: Int,
                   dailyTasks: Int, hasUrgentOrder: Bool, orders: Int) -> [LaneCardKind] {
    Array(repeating: .claimableQuest, count: claimableQuests)
    + Array(repeating: .inProgressQuest, count: inProgressQuests)
    + Array(repeating: .dailyTask, count: dailyTasks)
    + (hasUrgentOrder ? [.urgentOrder] : [])
    + Array(repeating: .order, count: orders)
}

/// Quests in lane order: complete ones first, otherwise the coordinator's
/// order (a stable partition, so slots do not reshuffle as progress ticks).
func laneOrderedQuests(_ quests: [Quest]) -> [Quest] {
    quests.filter(\.isComplete) + quests.filter { !$0.isComplete }
}

// ============================================================
// MARK: - CARD
// ============================================================

struct QuestLaneCard: View {
    let quest: Quest
    let onClaim: () -> Void
    let onOpenSheet: () -> Void

    private var blue: Color { Color(red: 0.10, green: 0.55, blue: 0.98) }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "target")
                    .font(.system(size: 8))
                    .foregroundColor(quest.difficulty.color)
                Text(quest.difficulty.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(quest.difficulty.color)
                Spacer(minLength: 0)
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 8))
                    .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.10))
                Text("\(quest.difficulty.coinReward)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.05))
            }

            HStack(alignment: .top, spacing: 5) {
                Image(systemName: quest.goal.icon)
                    .font(.system(size: 15))
                    .foregroundColor(quest.goal.iconColor)
                    .frame(width: 22)
                Text(quest.goal.description)
                    .font(.system(size: 9))
                    .foregroundColor(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if quest.isComplete {
                Button(action: onClaim) {
                    Text("Claim")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 20)
                        .background(RoundedRectangle(cornerRadius: 7).fill(blue))
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 2) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.black.opacity(0.10))
                            Capsule().fill(quest.difficulty.color)
                                .frame(width: geo.size.width * quest.progressFraction)
                        }
                    }
                    .frame(height: 4)
                    Text(quest.progressText)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .frame(minHeight: 20)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: questLaneCardWidth, height: trayBandHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(quest.isComplete ? blue.opacity(0.13) : Color(red: 0.95, green: 0.95, blue: 0.93))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(quest.isComplete ? blue.opacity(0.60) : Color.gray.opacity(0.25),
                                  lineWidth: quest.isComplete ? 1.5 : 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onOpenSheet() }
    }
}
