//
//  KibbleDrivePanelView.swift
//  PawSanctuary
//
//  The Kibble Drive's sheet (specs/Spec_KibbleDrive_Draft.md §6f D-3).
//
//  6.1 is the header: name, countdown, points and a progress bar with the rung
//  thresholds as ticks. 6.2 adds the buy banner. 6.3 adds the 15 rung rows and
//  the per-rung Claim.
//

import SwiftUI
import StoreKit

struct KibbleDrivePanelView: View {
    var viewModel: MergeBoardViewModel
    var storeManager: StoreManager

    private let accent = Color(red: 0.85, green: 0.5, blue: 0.15)

    var body: some View {
        if let drive = viewModel.kibbleDrive,
           let event = KibbleDriveRegistry.activeEvent(),
           event.id == drive.eventID {
            VStack(alignment: .leading, spacing: 12) {
                header(drive: drive, event: event)
                if !drive.purchased {
                    buyBanner(drive: drive)
                }
                VStack(spacing: 8) {
                    ForEach(KibbleDriveLadder.rungs, id: \.index) { rung in
                        KibbleDriveRungRow(rung: rung, drive: drive, accent: accent) {
                            viewModel.claimKibbleDriveRung(index: rung.index)
                        }
                    }
                }
                Text("Unclaimed rewards are lost when the Drive ends.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } else {
            // The window closed while the sheet was open: forfeit on close
            // (§7 Q4) leaves nothing to show.
            Text("This Kibble Drive has ended.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var product: Product? {
        storeManager.products.first { $0.id == IAPProduct.kibbleDrive.rawValue }
    }

    /// Only while the Drive is unbought (§6f D-3). The *tile* shows before
    /// monetization unlocks, but the offer must not: the buy control respects
    /// `isMonetizationUnlocked` or D7's "no monetization in session one" would
    /// be bypassed through the Drive.
    @ViewBuilder
    private func buyBanner(drive: KibbleDriveState) -> some View {
        let bonus = viewModel.kibbleDriveCatchUpGrant()
        VStack(alignment: .leading, spacing: 8) {
            Text("Earn up to \(KibbleDriveLadder.totalKibble) Kibble")
                .font(.subheadline.bold())
                .foregroundColor(accent)
            Text("Points keep adding up either way. Unlock the Drive to release every reward you reach, including the ones already behind you.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if bonus > 0 {
                Text("+\(bonus) bonus points on purchase")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
            if viewModel.isMonetizationUnlocked, let product {
                Button(action: {
                    // Captured before the async purchase so the TOCTOU guard
                    // has something to check — see
                    // `pendingKibbleDriveEventID`'s doc comment.
                    viewModel.pendingKibbleDriveEventID = drive.eventID
                    Task { await storeManager.purchase(product) }
                }) {
                    Text("Unlock for \(product.displayPrice)")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent))
                }
            }
            #if DEBUG
            // A simctl-installed build has no StoreKit configuration, so the
            // real button above stays hidden. This drives the same
            // `applyKibbleDrivePurchase` without it. Replaces the HUD button
            // §6d added for the same reason.
            Button("Simulate purchase (Debug)") {
                viewModel.simulateKibbleDrivePurchaseForTesting()
            }
            .font(.caption.bold())
            #endif
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.45)))
    }

    private func header(drive: KibbleDriveState, event: KibbleDriveEventDefinition) -> some View {
        let top = max(1, KibbleDriveLadder.topThreshold)
        let fraction = min(1, Double(drive.points) / Double(top))
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: event.icon)
                    .font(.system(size: 22))
                    .foregroundColor(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.name)
                        .font(.headline)
                        .foregroundColor(accent)
                    Text(event.timerLabel)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("\(drive.points) / \(top)")
                    .font(.subheadline.bold())
                    .foregroundColor(accent)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.black.opacity(0.10))
                    Capsule().fill(accent)
                        .frame(width: geo.size.width * fraction)
                    // One tick per rung threshold.
                    ForEach(KibbleDriveLadder.rungs, id: \.index) { rung in
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 1.5, height: 12)
                            .offset(x: geo.size.width * Double(rung.threshold) / Double(top) - 0.75)
                    }
                }
            }
            .frame(height: 12)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.45)))
    }
}

// ============================================================
// MARK: - RUNG ROW
// ============================================================

/// One rung (§6f D-3). Four states, derived from the Drive's points, purchase
/// flag and claimed list rather than stored:
///
/// - below its threshold: muted, "N more points"
/// - reached but unpurchased: full colour with a padlock — the visible-but-
///   locked accumulation that *is* the offer (§2)
/// - reached and purchased: a Claim button, one tap per rung (no "Claim all";
///   §2 treats the serial tapping as the payoff)
/// - claimed: a tick, dimmed
private struct KibbleDriveRungRow: View {
    let rung: TrackMilestone
    let drive: KibbleDriveState
    let accent: Color
    let onClaim: () -> Void

    private var isReached: Bool { drive.points >= rung.threshold }
    private var isClaimed: Bool { drive.claimedRungs.contains(rung.index) }
    private var canClaim: Bool { isReached && drive.purchased && !isClaimed }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(isClaimed ? Color.green.opacity(0.8)
                          : isReached ? accent
                          : Color.gray.opacity(0.3))
                    .frame(width: 34, height: 34)
                if isClaimed {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                } else {
                    Text("\(rung.index + 1)")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(isReached ? .white : .secondary)
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(rung.threshold) points")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(Array(rung.paidRewards.enumerated()), id: \.offset) { _, reward in
                        rewardPill(reward)
                    }
                }
            }
            .opacity(isClaimed ? 0.55 : (isReached ? 1.0 : 0.6))

            Spacer()

            if isClaimed {
                Text("Claimed")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            } else if canClaim {
                Button(action: onClaim) {
                    Text("Claim!")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18).padding(.vertical, 9)
                        .background(RoundedRectangle(cornerRadius: 12).fill(accent))
                }
            } else if isReached {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("\(rung.threshold - drive.points) more")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.45)))
        .accessibilityElement(children: .combine)
    }

    /// The Drive only pays kibble and card packs, so the pill set is narrower
    /// than `EventPanelView`'s, which this mirrors in look.
    @ViewBuilder
    private func rewardPill(_ reward: OrderReward) -> some View {
        switch reward.kind {
        case .kibble:
            Label("+\(reward.amount) Kibble", systemImage: "pawprint.fill")
                .font(.subheadline.bold())
                .foregroundColor(.green)
        case .cardPack:
            if let raw = reward.payloadID, let pack = CardPackType(rawValue: raw) {
                Label(pack.displayName, systemImage: pack.sfSymbol)
                    .font(.subheadline.bold())
                    .foregroundColor(pack.accentColor)
            }
        default:
            Text("+\(reward.amount)")
                .font(.subheadline.bold())
                .foregroundColor(.secondary)
        }
    }
}
