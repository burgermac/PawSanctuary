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

            #if DEBUG
            playtestMetricsPanel
            #endif

            Spacer(minLength: 0)
        }
        .padding()
    }

    #if DEBUG
    /// Measured play against what `EconomySimulation` assumes
    /// (`Spec_DailyHandInTasks.md` §5c). Debug-only: *recording* runs in every
    /// build so a TestFlight playtest gathers data, but the readout is a
    /// developer tool and has no place in a shipped Profile screen.
    private var playtestMetricsPanel: some View {
        let m = viewModel.playtestMetrics
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.doc.horizontal")
                    .font(.system(size: 12))
                Text("Playtest metrics")
                    .font(.system(size: 12, weight: .bold))
                Spacer()
                Text("\(m.activeDayCount) active day\(m.activeDayCount == 1 ? "" : "s")")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(Color(red: 0.35, green: 0.30, blue: 0.55))

            if !m.hasEnoughDataToInterpret {
                // Below a week, one unusual session dominates every average, and
                // a number on screen invites a retune it cannot support.
                Text("Gathering — rates shown from 7 active days.")
                    .font(.system(size: 10)).foregroundColor(.secondary)
            }

            metricRow("Quest claims / day",
                      m.measuredQuestClaimsPerDay, PlaytestBaseline.questClaimsPerDay)
            metricRow("Toolboxes / claim",
                      m.measuredToolboxesPerQuestClaim, PlaytestBaseline.toolboxesPerQuestClaim)
            metricRow("Material units / day",
                      m.measuredMaterialUnitsPerDay, PlaytestBaseline.materialUnitsPerDaySaturated)
            metricRow("Daily tasks claimed / day",
                      m.measuredDailyTaskClaimsPerDay, PlaytestBaseline.dailyTaskClaimsPerDay)
            metricRow("Spawners stashed",
                      m.measuredStashRate, PlaytestBaseline.spawnerStashRate)

            if let occupancy = m.measuredBoardOccupancy {
                Text(String(format: "Board occupancy %.0f%% · %.1f spawners out, %.1f stashed",
                            occupancy * 100,
                            m.measuredSpawnersOnBoard ?? 0,
                            m.measuredSpawnersStashed ?? 0))
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }
            if let first = m.firstActiveDay, let last = m.lastActiveDay {
                Text("\(first) → \(last) · \(m.boardSampleCount) board sample\(m.boardSampleCount == 1 ? "" : "s")")
                    .font(.system(size: 9)).foregroundColor(.secondary)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.35, green: 0.30, blue: 0.55).opacity(0.08)))
    }

    /// One measured-vs-assumed line. A `nil` measurement reads as "—", never as
    /// 0.0 — an absent measurement is not a measurement of zero, and showing it
    /// as one would look like play contradicting the model.
    @ViewBuilder
    private func metricRow(_ label: String, _ measured: Double?, _ assumed: Double) -> some View {
        HStack(spacing: 6) {
            Text(label).font(.system(size: 10))
            Spacer(minLength: 4)
            if let measured {
                Text(String(format: "%.2f", measured))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(divergence(measured, assumed) ? .orange : .primary)
            } else {
                Text("—").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
            }
            Text(String(format: "vs %.2f", assumed))
                .font(.system(size: 9)).foregroundColor(.secondary)
        }
    }

    /// Flags a measurement far enough from the assumption to be worth acting on.
    /// Only once there is enough data to mean anything.
    private func divergence(_ measured: Double, _ assumed: Double) -> Bool {
        guard viewModel.playtestMetrics.hasEnoughDataToInterpret else { return false }
        if assumed == 0 { return measured > 0.05 }
        return abs(measured - assumed) / assumed > 0.25
    }
    #endif

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
