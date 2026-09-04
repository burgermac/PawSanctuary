//
//  DailyTaskLaneView.swift
//  PawSanctuary
//
//  The daily hand-in task cards (Spec_DailyHandInTasks.md).
//
//  These lead the same horizontal band the order lane owns, ahead of the
//  orders (spec D-D). They do not get a row of their own: the board sits
//  exactly at its own csW/csH crossover (Spec_TaskTrayRedesign_Draft.md §2),
//  so any new vertical space comes straight out of every board cell. Sharing
//  the band costs nothing.
//
//  What makes these different from an order card, and the whole reason the
//  file exists: a slot shows the creature's **real illustrated art at its
//  exact merge stage** (`DailyTaskLine.artImage`), not the SF Symbol every
//  other card surface still uses, and the count it shows is what is standing
//  on the board *right now* — not what the player has merged over the day.
//

import SwiftUI

// ============================================================
// MARK: - GEOMETRY
// ============================================================

/// Slightly wider than `orderLaneCardWidth` (148). The extra 12pt is the Claim
/// button: an order card has no control on it, this one does, and a 148pt card
/// forced the button's label to shrink below the lane's smallest legible size.
private let dailyTaskCardWidth: CGFloat = 160

/// Edge of one requested-creature thumbnail.
private let dailyTaskSlotSize: CGFloat = 34

// ============================================================
// MARK: - SLOT
// ============================================================

/// One requested creature: its art, and how many of it the board holds.
///
/// The count pill is always shown, even at 1, because "do I have it" is the
/// single question this card exists to answer — an order slot can get away
/// with a bare tick since orders track deliveries, which only ever go up.
private struct DailyTaskSlot: View {
    let line: DailyTaskLine
    let held: Int

    private var isFilled: Bool { held >= line.count }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(isFilled ? Color.blue.opacity(0.18) : Color.gray.opacity(0.10))
                    .overlay(RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(isFilled ? Color.blue.opacity(0.65)
                                               : Color.gray.opacity(0.25),
                                      lineWidth: isFilled ? 1.5 : 1))

                if let art = line.artImage {
                    art.resizable().scaledToFit()
                        .frame(width: dailyTaskSlotSize * 0.80,
                               height: dailyTaskSlotSize * 0.80)
                        .saturation(isFilled ? 1.0 : 0.35)
                        .opacity(isFilled ? 1.0 : 0.55)
                } else {
                    // Only reachable for a chain with no delivered art.
                    Image(systemName: line.symbol)
                        .font(.system(size: 15))
                        .foregroundColor(isFilled ? line.tint : line.tint.opacity(0.45))
                }
            }
            .frame(width: dailyTaskSlotSize, height: dailyTaskSlotSize)

            Text("\(held)/\(line.count)")
                .font(.system(size: 8, weight: isFilled ? .bold : .regular))
                .foregroundColor(isFilled ? Color(red: 0.05, green: 0.45, blue: 0.85) : .secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(line.count) \(line.tierName), \(line.stageLabel). \(held) on the board.")
    }
}

// ============================================================
// MARK: - CARD
// ============================================================

struct DailyTaskLaneCard: View {
    let task: DailyChallenge
    let census: [ChainTierKey: Int]
    let onClaim: () -> Void
    let onOpenSheet: () -> Void

    private var isStocked: Bool { task.isStocked(census: census) }
    private var isClaimable: Bool { isStocked && !task.isClaimed }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: "checklist")
                    .font(.system(size: 8))
                    .foregroundColor(task.difficulty.color)
                Text(task.difficulty.rawValue)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(task.difficulty.color)
                Spacer(minLength: 0)
                if !task.isClaimed {
                    HStack(spacing: 2) {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(red: 0.85, green: 0.65, blue: 0.10))
                        Text("\(task.coinReward)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Color(red: 0.55, green: 0.40, blue: 0.05))
                    }
                }
            }

            HStack(spacing: 4) {
                ForEach(task.lines.indices, id: \.self) { i in
                    DailyTaskSlot(line: task.lines[i],
                                  held: task.held(task.lines[i], census: census))
                }
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            claimControl
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(width: dailyTaskCardWidth, height: trayBandHeight, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(background)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(border, lineWidth: isClaimable ? 1.5 : 1))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture { onOpenSheet() }
    }

    /// The button is the mechanic: a task never self-completes, the player
    /// hands the creatures in. Disabled rather than hidden while short, so the
    /// card always says what it is waiting for.
    @ViewBuilder
    private var claimControl: some View {
        if task.isClaimed {
            HStack(spacing: 3) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 9))
                Text("Handed in").font(.system(size: 9, weight: .semibold))
            }
            .foregroundColor(.green)
            .frame(maxWidth: .infinity, minHeight: 20)
        } else {
            Button(action: onClaim) {
                Text(isClaimable ? "Claim" : "Keep merging")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isClaimable ? .white : .secondary)
                    .frame(maxWidth: .infinity, minHeight: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(isClaimable
                                  ? Color(red: 0.10, green: 0.55, blue: 0.98)
                                  : Color.gray.opacity(0.15)))
            }
            .buttonStyle(.plain)
            .disabled(!isClaimable)
        }
    }

    private var background: Color {
        if task.isClaimed { return Color.green.opacity(0.08) }
        return isStocked ? Color(red: 0.10, green: 0.55, blue: 0.98).opacity(0.13)
                         : Color(red: 0.93, green: 0.96, blue: 1.0)
    }

    private var border: Color {
        if task.isClaimed { return Color.green.opacity(0.45) }
        return isStocked ? Color(red: 0.10, green: 0.55, blue: 0.98).opacity(0.60)
                         : Color(red: 0.30, green: 0.45, blue: 0.70).opacity(0.20)
    }
}
