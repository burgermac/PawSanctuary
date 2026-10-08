//
//  KibbleDrivePanelView.swift
//  PawSanctuary
//
//  The Kibble Drive's sheet (specs/Spec_KibbleDrive_Draft.md §6f D-3).
//
//  6.1 is the header: name, countdown, points and a progress bar with the rung
//  thresholds as ticks. 6.2 adds the buy banner. The rung rows are 6.3, so this
//  opens a sheet that is honest about what it has rather than one that
//  pretends to be finished.
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
