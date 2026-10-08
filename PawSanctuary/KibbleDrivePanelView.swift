//
//  KibbleDrivePanelView.swift
//  PawSanctuary
//
//  The Kibble Drive's sheet (specs/Spec_KibbleDrive_Draft.md §6f D-3).
//
//  Task 6.1 is the header only: name, countdown, points and a progress bar
//  with the rung thresholds as ticks. The buy banner is 6.2 and the rung rows
//  are 6.3, so this opens a sheet that is honest about what it has rather than
//  one that pretends to be finished.
//

import SwiftUI

struct KibbleDrivePanelView: View {
    var viewModel: MergeBoardViewModel

    private let accent = Color(red: 0.85, green: 0.5, blue: 0.15)

    var body: some View {
        if let drive = viewModel.kibbleDrive,
           let event = KibbleDriveRegistry.activeEvent(),
           event.id == drive.eventID {
            header(drive: drive, event: event)
        } else {
            // The window closed while the sheet was open: forfeit on close
            // (§7 Q4) leaves nothing to show.
            Text("This Kibble Drive has ended.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
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
