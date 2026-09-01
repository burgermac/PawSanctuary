//
//  ProfileView.swift
//  PawSanctuary
//
//  Player identity and lifetime stats. Created for the task-tray redesign
//  (Spec_TaskTrayRedesign_Draft.md, Task 6.1) as the destination for the
//  "Rescued" and "Ambassadors" counters that used to sit in the middle of the
//  HUD. Those two lines were what made the currency row three lines tall; the
//  tray needs that vertical space, and neither number is a moment-to-moment
//  decision input, so they live one tap away instead.
//
//  Reached from the level badge at the left of the HUD.
//

import SwiftUI

struct ProfileView: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(spacing: 20) {
            levelHeader

            VStack(spacing: 0) {
                statRow(icon: "pawprint.fill",
                        iconColor: Color(red: 0.28, green: 0.15, blue: 0.02),
                        label: "Rescued",
                        value: "\(viewModel.rescueCount)")
                divider
                statRow(icon: "medal.fill",
                        iconColor: Color(red: 0.85, green: 0.68, blue: 0.08),
                        label: "Ambassadors",
                        value: "\(viewModel.ambassadors)")
                divider
                statRow(icon: "arrow.triangle.merge",
                        iconColor: Color(red: 0.30, green: 0.55, blue: 0.75),
                        label: "Merges",
                        value: "\(viewModel.mergeCount)")
            }
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.97, green: 0.97, blue: 0.95)))

            if viewModel.isPassActive {
                HStack(spacing: 8) {
                    Image(systemName: "medal.fill")
                        .font(.system(size: 14))
                    Text("Sanctuary Pass active")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                }
                .foregroundColor(Color(red: 0.6, green: 0.2, blue: 0.8))
                .padding(.horizontal, 14).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14)
                    .fill(Color(red: 0.6, green: 0.2, blue: 0.8).opacity(0.10)))
            }

            Spacer(minLength: 0)
        }
        .padding()
    }

    // MARK: Level header

    private var levelHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(red: 0.08, green: 0.38, blue: 0.15).opacity(0.18), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: viewModel.xpProgressFraction)
                    .stroke(
                        LinearGradient(
                            colors: [Color(red: 0.30, green: 0.70, blue: 0.40),
                                     Color(red: 0.20, green: 0.55, blue: 0.30)],
                            startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("Lv.")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(Color(red: 0.08, green: 0.38, blue: 0.15))
                    Text("\(viewModel.playerLevel)")
                        .font(.system(size: 26, weight: .heavy))
                        .foregroundColor(Color(red: 0.20, green: 0.45, blue: 0.28))
                }
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 5) {
                Text("Sanctuary Keeper")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.18, green: 0.18, blue: 0.18))
                Text("\(viewModel.playerXP) / \(viewModel.xpToNextLevel) XP")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.20, green: 0.45, blue: 0.28))
                Text("to level \(viewModel.playerLevel + 1)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer(minLength: 0)
        }
    }

    // MARK: Stat row

    private var divider: some View {
        Rectangle()
            .fill(Color.black.opacity(0.07))
            .frame(height: 1)
            .padding(.leading, 46)
    }

    private func statRow(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(iconColor)
                .frame(width: 22)
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color(red: 0.20, green: 0.20, blue: 0.20))
            Spacer()
            Text(value)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(Color(red: 0.15, green: 0.15, blue: 0.15))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
    }
}
