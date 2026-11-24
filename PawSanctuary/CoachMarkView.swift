//
//  CoachMarkView.swift
//  PawSanctuary
//
//  Context tutorial, task 4.3 stage 2 (specs/Spec_ContextTutorial.md §4.1).
//  One presentation for every tip: a small speech bubble with a pulsing ring and
//  a pointing hand on the real target, and no scrim. It never blocks play: only
//  the "×" and, on the first tip, "Skip tips" take touches; everything else
//  lets them through to the board. This replaces the dark-screen
//  `OnboardingOverlay` of the old three-step tutorial.
//

import SwiftUI

// MARK: - Frame reporting

/// Which on-screen thing a coach mark can point at, reported by the view that
/// draws it (the way `reportOrderCardFrame` and `reportHUDFrame` do).
enum TutorialFrameID: Hashable {
    case cell(GridPosition)
    case questClaim
    case deliverPill(UUID)
}

struct TutorialFrameKey: PreferenceKey {
    static let defaultValue: [TutorialFrameID: CGRect] = [:]
    static func reduce(value: inout [TutorialFrameID: CGRect], nextValue: () -> [TutorialFrameID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    /// Reports this view's global frame as `id` while `enabled`, and nothing
    /// otherwise. The reader is always present so turning a tip on or off never
    /// changes the view's identity (a cell keeps its animation state).
    func reportTutorialFrame(_ id: TutorialFrameID, enabled: Bool = true) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: TutorialFrameKey.self,
                                   value: enabled ? [id: g.frame(in: .global)] : [:])
        })
    }
}

// MARK: - Overlay

struct CoachMarkOverlay: View {
    let moment: TutorialMoment
    let text: String
    /// Global frames of what the tip points at, in order (the merge tip's hand
    /// slides from the first to the second).
    let targets: [CGRect]
    /// "Skip tips" is offered inside the first tip of a session only (owner Q1).
    let showsSkipAll: Bool
    let onClose: () -> Void
    let onSkipAll: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var slide = false

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            let local = targets.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
            ZStack {
                // Rings and hand: decoration only, never touchable.
                ForEach(Array(local.enumerated()), id: \.offset) { _, rect in
                    // Follows the target's own shape: a cell is squarish, the
                    // quest Claim button is wide.
                    RoundedRectangle(cornerRadius: min(rect.width, rect.height) * 0.3)
                        .stroke(Color.yellow.opacity(pulse ? 0 : 0.95), lineWidth: 3)
                        .frame(width: rect.width + (pulse ? 22 : 4),
                               height: rect.height + (pulse ? 22 : 4))
                        .position(x: rect.midX, y: rect.midY)
                        .allowsHitTesting(false)
                }
                if let hand = handPosition(local) {
                    Image(systemName: "hand.point.up.left.fill")
                        .font(.system(size: 34))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.55), radius: 3, y: 2)
                        .position(x: hand.x + 14, y: hand.y + 18)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                bubble(in: geo.size, targets: local, safeTop: geo.safeAreaInsets.top)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 0.9).repeatForever(autoreverses: false)) { pulse = true }
            withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: false)) { slide = true }
        }
    }

    /// The hand sits on the single target, or slides from the first target to the
    /// second (the merge tip). Under Reduce Motion it stays on the first.
    private func handPosition(_ local: [CGRect]) -> CGPoint? {
        guard let first = local.first else { return nil }
        let a = CGPoint(x: first.midX, y: first.midY)
        guard local.count > 1, !reduceMotion else { return a }
        let b = CGPoint(x: local[1].midX, y: local[1].midY)
        let t: CGFloat = slide ? 1 : 0
        return CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    // MARK: Bubble

    @ViewBuilder
    private func bubble(in size: CGSize, targets: [CGRect], safeTop: CGFloat) -> some View {
        let focus = targets.reduce(CGRect.null) { $0.union($1) }
        // Above the target when it is in the lower half of the screen, else below.
        let above = focus.isNull ? true : focus.midY > size.height * 0.5
        let width = min(size.width - 48, 300)
        let y: CGFloat = {
            guard !focus.isNull else { return size.height * 0.35 }
            return above ? max(focus.minY - 84, safeTop + 70)
                         : min(focus.maxY + 84, size.height - 120)
        }()

        // The pointer aims at the target sideways too, kept inside the bubble's corners.
        let reach = width / 2 - 28
        let pointerShift = focus.isNull ? 0 : max(-reach, min(reach, focus.midX - size.width / 2))

        VStack(spacing: 0) {
            if !above { pointer(down: false).offset(x: pointerShift) }
            card
            if above { pointer(down: true).offset(x: pointerShift) }
        }
        .frame(width: width)
        .position(x: size.width / 2, y: y)
        .animation(.easeInOut(duration: 0.25), value: moment)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(text)
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundColor(.white)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .allowsHitTesting(false)
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(Color.white.opacity(0.16)))
                }
                .accessibilityLabel("Close tip")
            }
            if showsSkipAll {
                Button(action: onSkipAll) {
                    Text("Skip tips")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.yellow.opacity(0.95))
                        .padding(.vertical, 2)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.07, green: 0.28, blue: 0.16))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.14), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.35), radius: 10, y: 3)
    }

    private func pointer(down: Bool) -> some View {
        Canvas { ctx, s in
            var path = Path()
            if down {
                path.move(to: CGPoint(x: s.width / 2, y: s.height))
                path.addLine(to: CGPoint(x: s.width / 2 - 11, y: 0))
                path.addLine(to: CGPoint(x: s.width / 2 + 11, y: 0))
            } else {
                path.move(to: CGPoint(x: s.width / 2, y: 0))
                path.addLine(to: CGPoint(x: s.width / 2 - 11, y: s.height))
                path.addLine(to: CGPoint(x: s.width / 2 + 11, y: s.height))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(red: 0.07, green: 0.28, blue: 0.16)))
        }
        .frame(height: 12)
        .allowsHitTesting(false)
    }
}
