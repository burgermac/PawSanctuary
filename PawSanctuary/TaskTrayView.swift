//
//  TaskTrayView.swift
//  PawSanctuary
//
//  The collapsing task tray that replaces TaskStripView's horizontal strip
//  (Spec_TaskTrayRedesign_Draft.md). A 3-wide grid of small tracker tiles that
//  collapses to 1-wide by horizontal translation, scrolling freely inside a
//  fixed two-row viewport.
//
//  Task 6.2 lands the tile primitive only. The container (6.3), the tile
//  content (6.4, 6.5) and the order lane (6.6) follow.
//

import SwiftUI

// ============================================================
// MARK: - GEOMETRY
// ============================================================

/// Edge of one tray tile. 40pt is not a taste call — it is what the vertical
/// budget allows. The board sits exactly at its own `csW`/`csH` crossover
/// (spec §2.1), so the tray is paid for entirely out of the header flattening
/// in Task 6.1, which freed ~19pt. Two rows of 40pt tiles plus padding come to
/// ~98pt against a ~116pt budget; the reference's own ~56pt tiles would need
/// ~150pt and would cost roughly 4pt off every board cell.
let trayTileSize: CGFloat = 40

/// Height of the status strip inset along the bottom of a tile.
private let trayStatusHeight: CGFloat = 7

// ============================================================
// MARK: - TILE STATUS
// ============================================================

/// What a tile shows below its icon.
///
/// There is no countdown-as-text case, and that is deliberate. At 40pt a
/// legible inset label holds about four characters — enough for `7/12` or
/// `0/3`, nowhere near enough for `16h 29m`, which would need roughly 7pt
/// type. Rather than abbreviate to `16h` and lose the minutes, or give
/// countdown tiles a taller external pill and break the uniform grid that
/// makes collapse a single translation, countdowns render as a bar that
/// drains (spec §3.11).
enum TrayTileStatus: Equatable {
    /// No status strip — the icon alone.
    case none

    /// Progress being earned, filling left to right. `fraction` is clamped 0...1.
    case progress(Double)

    /// Time draining away, emptying right to left. `fraction` is the share of
    /// the interval **remaining**, clamped 0...1, so a full bar means the whole
    /// window is still ahead.
    ///
    /// Tinted differently from `.progress` on purpose: two adjacent tiles, one
    /// filling and one draining, should not speak the same visual language.
    case countdown(Double)

    /// At most four characters — `7/12`, `0/3`, `×3`. Longer strings scale down
    /// rather than truncate, but the caller should not be relying on that.
    case label(String)
}

// ============================================================
// MARK: - TILE
// ============================================================

/// One tray tile: an icon, an optional inset status strip, an optional badge.
///
/// Pure presentation — it takes plain values and holds no view-model
/// reference, so it can be laid out and reasoned about without the game
/// running. Tap handling belongs to whatever mounts it.
struct TrayTileView: View {
    let icon: String
    let tint: Color
    var status: TrayTileStatus = .none
    /// Red dot in the top-trailing corner — "there is something to collect here".
    var showsBadge: Bool = false
    /// Spoken description. The tile is icon-only by design, so without this it
    /// is silent to VoiceOver.
    let accessibilityText: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(tint.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 9)
                    .strokeBorder(tint.opacity(0.45), lineWidth: 1))

            VStack(spacing: 0) {
                Spacer(minLength: 0)
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(tint)
                Spacer(minLength: 0)
                statusStrip
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
        }
        .frame(width: trayTileSize, height: trayTileSize)
        .overlay(alignment: .topTrailing) {
            if showsBadge {
                Circle()
                    .fill(Color(red: 0.85, green: 0.20, blue: 0.15))
                    .frame(width: 9, height: 9)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .offset(x: 3, y: -3)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityValue(accessibilityValue)
    }

    // MARK: Status strip

    @ViewBuilder
    private var statusStrip: some View {
        switch status {
        case .none:
            EmptyView()

        case .progress(let fraction):
            bar(fraction: fraction,
                fill: LinearGradient(colors: [tint.opacity(0.75), tint],
                                     startPoint: .leading, endPoint: .trailing))

        case .countdown(let fraction):
            // Amber, and draining rather than filling, so it does not read as
            // progress earned (spec §3.11).
            bar(fraction: fraction,
                fill: LinearGradient(
                    colors: [Color(red: 0.95, green: 0.72, blue: 0.20),
                             Color(red: 0.90, green: 0.55, blue: 0.10)],
                    startPoint: .leading, endPoint: .trailing))

        case .label(let text):
            Text(text)
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.horizontal, 3)
                .frame(maxWidth: .infinity)
                .frame(height: 12)
                .background(Capsule().fill(tint.opacity(0.85)))
        }
    }

    private func bar(fraction: Double, fill: LinearGradient) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.black.opacity(0.12))
                Capsule()
                    .fill(fill)
                    .frame(width: geo.size.width * fraction.clampedToUnitInterval)
            }
        }
        .frame(height: trayStatusHeight)
        .animation(.easeInOut(duration: 0.3), value: fraction)
    }

    private var accessibilityValue: String {
        switch status {
        case .none:                  return ""
        case .progress(let f):       return "\(Int((f.clampedToUnitInterval * 100).rounded())) percent complete"
        case .countdown(let f):      return "\(Int((f.clampedToUnitInterval * 100).rounded())) percent of the time remaining"
        case .label(let text):       return text
        }
    }
}

private extension Double {
    /// Bars are fed from live countdowns and progress counters, both of which
    /// can momentarily overshoot their own bounds (a timer read a tick after
    /// expiry, a counter past its goal before the claim lands). Clamp at the
    /// point of use rather than trusting every call site.
    var clampedToUnitInterval: Double {
        if isNaN { return 0 }
        return Swift.min(Swift.max(self, 0), 1)
    }
}
