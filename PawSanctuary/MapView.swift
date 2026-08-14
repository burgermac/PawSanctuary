//
//  MapView.swift  —  Phase 4: Sanctuary map & area construction
//  PawSanctuary
//

import SwiftUI

// ============================================================
// MARK: - MAP SCREEN
// ============================================================

struct MapView: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack {
                Label("Sanctuary Map", systemImage: "map.fill")
                    .font(.title2.bold())
                    .foregroundColor(Color(red: 0.10, green: 0.28, blue: 0.06))
                Spacer()
                Text("\(viewModel.completedAreaIDs.count)/\(sanctuaryAreas.count)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            Text("Build sanctuary areas by spending materials. Each area unlocks board space, new species, and resources.")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal).padding(.bottom, 8)

            // ── Material summary bar ─────────────────────────────
            materialSummaryBar.padding(.horizontal).padding(.bottom, 8)

            // ── Area cards ───────────────────────────────────────
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sanctuaryAreas) { area in
                        AreaCardView(viewModel: viewModel, area: area)
                    }

                    // Card Album entry point
                    CardAlbumEntryButton(viewModel: viewModel)
                        .padding(.top, 4)

                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
            }
        }
    }

    /// Quick overview of how many material items the player currently holds.
    private var materialSummaryBar: some View {
        let chains: [(ChainID, String, Color)] = [
            (ContentRegistry.woodChainID,   "Wood",   Color(red: 0.42, green: 0.28, blue: 0.08)),
            (ContentRegistry.metalChainID,  "Metal",  Color(red: 0.22, green: 0.28, blue: 0.52)),
            (ContentRegistry.cementChainID, "Cement", Color(red: 0.35, green: 0.32, blue: 0.28)),
        ]
        return HStack(spacing: 0) {
            ForEach(chains, id: \.0) { (chainID, label, color) in
                let count = viewModel.completedMaterialCount(chainID: chainID)
                VStack(spacing: 2) {
                    Text("\(count)").font(.system(size: 15, weight: .bold)).foregroundColor(color)
                    Text(label).font(.system(size: 9)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.96, green: 0.93, blue: 0.85).opacity(0.9))
            .shadow(color: .black.opacity(0.05), radius: 3))
    }
}

// ============================================================
// MARK: - AREA CARD
// ============================================================

struct AreaCardView: View {
    var viewModel: MergeBoardViewModel
    let area: SanctuaryArea
    @State private var showConfirm = false

    private var isComplete:  Bool { viewModel.completedAreaIDs.contains(area.id) }
    private var isAvailable: Bool { viewModel.isAreaAvailable(area) }
    private var canAfford:   Bool { viewModel.canAffordArea(area) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow
            if isAvailable || isComplete {
                Text(area.description)
                    .font(.system(size: 12)).foregroundColor(.secondary)
            }
            if isComplete {
                rewardSummary
                upgradeSection
            } else if isAvailable {
                costRows
                rewardSummary
                buildButton
            }
        }
        .padding(14)
        .background(cardBackground)
        .overlay(cardBorder)
        .confirmationDialog(
            "Build \(area.displayName)?",
            isPresented: $showConfirm,
            titleVisibility: .visible
        ) {
            Button("Build — Spend Materials") { viewModel.buildArea(area) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will consume the listed materials from your storage.")
        }
    }

    // MARK: Sub-views

    private var headerRow: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        isComplete  ? area.color.opacity(0.25) :
                        isAvailable ? area.color.opacity(0.15) :
                                      Color.gray.opacity(0.10)
                    )
                    .frame(width: 48, height: 48)

                Group {
                    if isComplete {
                        Image(systemName: "checkmark.circle.fill").foregroundColor(area.color)
                    } else if !isAvailable {
                        Image(systemName: "lock.fill").foregroundColor(.gray.opacity(0.45))
                    } else {
                        Image(systemName: area.sfSymbol).foregroundColor(area.color)
                    }
                }
                .font(.system(size: isComplete ? 26 : 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(area.displayName)
                    .font(.headline)
                    .foregroundColor(
                        isComplete  ? area.color :
                        isAvailable ? .primary   : .secondary
                    )
                Text(
                    isComplete  ? "Built" :
                    isAvailable ? "Ready to build" :
                    !viewModel.isAreaPreviousBuilt(area) ? "Build the previous area first" :
                    !viewModel.isPreviousFullyUpgraded(area) ? "Fully upgrade the previous area first" :
                                  "Locked"
                )
                .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            if isComplete {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 22)).foregroundColor(area.color)
            }
        }
    }

    private var costRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Materials needed:").font(.caption.bold()).foregroundColor(.secondary)
            ForEach(area.costs) { cost in
                let have = viewModel.countMaterial(chainID: cost.chainID, tier: cost.tier)
                HStack(spacing: 8) {
                    Image(systemName: cost.tierSymbol)
                        .font(.system(size: 13)).foregroundColor(cost.tierColor).frame(width: 18)
                    Text(cost.tierName).font(.system(size: 12))
                    Text("×\(cost.count)").font(.system(size: 12, weight: .bold))
                    Spacer()
                    Text("\(min(have, cost.count))/\(cost.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(have >= cost.count ? .green : .orange)
                }
            }
        }
    }

    private var rewardSummary: some View {
        HStack(spacing: 4) {
            Image(systemName: "gift.fill")
                .font(.system(size: 11)).foregroundColor(area.color)
            Text(area.reward.primaryMessage())
                .font(.system(size: 11)).foregroundColor(area.color)
        }
    }

    private var buildButton: some View {
        Button(action: { showConfirm = true }) {
            HStack(spacing: 6) {
                Image(systemName: "hammer.fill")
                Text(canAfford ? "Build" : "Need more materials").fontWeight(.semibold)
            }
            .font(.subheadline)
            .foregroundColor(canAfford ? .white : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(canAfford ? area.color : Color.gray.opacity(0.18))
            )
        }
        .disabled(!canAfford)
    }

    @ViewBuilder
    private var upgradeSection: some View {
        let currentLevel = viewModel.areaUpgradeLevels[area.id] ?? 0
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("Upgrades")
                    .font(.caption.bold()).foregroundColor(.secondary)
                Spacer()
                Text("\(currentLevel)/\(area.upgrades.count)")
                    .font(.caption).foregroundColor(.secondary)
            }
            ForEach(Array(area.upgrades.enumerated()), id: \.element.id) { idx, upgrade in
                let isUnlocked  = currentLevel > idx
                let isAvail     = viewModel.isUpgradeAvailable(area, tier: idx)
                let canAfford   = viewModel.canAffordUpgrade(area, tier: idx)
                UpgradeTierRow(
                    upgrade: upgrade,
                    isUnlocked: isUnlocked,
                    isAvailable: isAvail,
                    canAfford: canAfford,
                    playerCoins: viewModel.coins,
                    onUpgrade: { viewModel.upgradeArea(area) }
                )
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(
                isComplete  ? area.color.opacity(0.07) :
                isAvailable ? Color(red: 0.97, green: 0.94, blue: 0.88).opacity(0.95) :
                              Color.gray.opacity(0.05)
            )
            .shadow(color: .black.opacity(isAvailable ? 0.06 : 0.02), radius: 4)
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: 16)
            .strokeBorder(
                isComplete              ? area.color.opacity(0.40) :
                isAvailable && canAfford ? area.color.opacity(0.30) :
                                           Color.clear,
                lineWidth: 1.5
            )
    }
}

// ============================================================
// MARK: - UPGRADE TIER ROW
// ============================================================

struct UpgradeTierRow: View {
    let upgrade: AreaUpgradeTier
    let isUnlocked:  Bool
    let isAvailable: Bool
    let canAfford:   Bool
    let playerCoins: Int
    let onUpgrade: () -> Void

    @State private var showConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                // Status icon
                Image(systemName: isUnlocked ? "checkmark.circle.fill"
                      : isAvailable ? "hammer.circle.fill" : "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(isUnlocked ? .green : isAvailable ? Color(red: 0.38, green: 0.22, blue: 0.02) : .gray.opacity(0.4))

                VStack(alignment: .leading, spacing: 1) {
                    Text(upgrade.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isUnlocked ? .green : isAvailable ? .primary : .secondary)
                    Text(upgrade.bonus.primaryDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                Spacer()
            }

            if isAvailable && !isUnlocked {
                // Cost row
                HStack(spacing: 6) {
                    // Coin cost
                    HStack(spacing: 3) {
                        Image(systemName: "dollarsign.circle.fill").font(.system(size: 10))
                            .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
                        Text("\(upgrade.coinCost)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(playerCoins >= upgrade.coinCost
                                             ? Color(red: 0.38, green: 0.22, blue: 0.02) : .red)
                    }
                    // Material costs
                    ForEach(upgrade.materialCosts) { cost in
                        HStack(spacing: 2) {
                            Image(systemName: cost.tierSymbol).font(.system(size: 9))
                                .foregroundColor(cost.tierColor)
                            Text("×\(cost.count) \(cost.tierName)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)
                        }
                    }
                    Spacer()
                    // Upgrade button
                    Button(action: { showConfirm = true }) {
                        Text(canAfford ? "Upgrade" : "Need more")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(canAfford ? .white : .secondary)
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(canAfford
                                      ? Color(red: 0.38, green: 0.22, blue: 0.02)
                                      : Color.gray.opacity(0.15)))
                    }
                    .disabled(!canAfford)
                    .confirmationDialog("Upgrade to \(upgrade.displayName)?",
                                        isPresented: $showConfirm, titleVisibility: .visible) {
                        Button("Upgrade — Spend Resources") { onUpgrade() }
                        Button("Cancel", role: .cancel) {}
                    } message: {
                        Text("Costs \(upgrade.coinCost) coins and the listed materials.")
                    }
                }
            } else if isUnlocked {
                Text("Active: \(upgrade.bonus.primaryDescription)")
                    .font(.system(size: 9)).foregroundColor(.green.opacity(0.8))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(isUnlocked ? Color.green.opacity(0.06)
                  : isAvailable ? Color(red: 1.0, green: 0.97, blue: 0.88).opacity(0.8)
                  : Color.gray.opacity(0.04))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .stroke(isUnlocked ? Color.green.opacity(0.20) : Color.clear, lineWidth: 1)))
    }
}

// ============================================================
// MARK: - CARD ALBUM ENTRY BUTTON
// ============================================================

/// Tappable banner in the map scroll view that opens the Card Album.
struct CardAlbumEntryButton: View {
    var viewModel: MergeBoardViewModel
    @State private var showAlbum = false

    private var pendingCount: Int { viewModel.pendingCardPacks.count }
    private var totalCards: Int { CardRegistry.allCards.count }
    private var ownedCards: Int { CardRegistry.allCards.filter { viewModel.cardInventory[$0.id, default: 0] > 0 }.count }

    var body: some View {
        Button(action: { showAlbum = true }) {
            HStack(spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    ZStack {
                        Circle()
                            .fill(Color(red: 0.42, green: 0.28, blue: 0.68).opacity(0.15))
                            .frame(width: 46, height: 46)
                        Image(systemName: "rectangle.stack.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.68))
                    }
                    if pendingCount > 0 {
                        Text("\(pendingCount)")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(3)
                            .background(Circle().fill(Color(red: 0.75, green: 0.25, blue: 0.25)))
                            .offset(x: 6, y: -4)
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Card Album")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                    Text("\(ownedCards)/\(totalCards) cards · \(viewModel.starCount) stars")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if pendingCount > 0 {
                        Text("\(pendingCount) pack\(pendingCount == 1 ? "" : "s") waiting to be opened")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.55, green: 0.25, blue: 0.75))
                    }
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(red: 0.42, green: 0.28, blue: 0.68).opacity(0.6))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.96, green: 0.93, blue: 1.00))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color(red: 0.62, green: 0.45, blue: 0.85).opacity(0.3), lineWidth: 1))
                .shadow(color: Color(red: 0.42, green: 0.28, blue: 0.68).opacity(0.10), radius: 6, y: 2))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAlbum) {
            NavigationStack {
                CardAlbumView(viewModel: viewModel)
                    .navigationTitle("Card Album")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showAlbum = false }
                    }}
            }
        }
    }
}
