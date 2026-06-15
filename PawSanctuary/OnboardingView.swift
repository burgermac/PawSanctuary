//
//  OnboardingView.swift
//  PawSanctuary
//
//  First-launch tutorial: rescue → merge → claim quest.
//  Persisted via UserDefaults "tutorialCompleted"; shows once and is always skippable.
//

import SwiftUI

// ============================================================
// MARK: - TUTORIAL STEP
// ============================================================

enum TutorialStep: Int {
    case rescue = 0   // tap the spawner to rescue an animal
    case merge  = 1   // select and merge two matching animals
    case quest  = 2   // open the quest panel and claim a reward
    case done   = 3   // tutorial complete — overlay hidden

    var isActive: Bool { self != .done }
}

// ============================================================
// MARK: - OVERLAY
// ============================================================

struct OnboardingOverlay: View {
    let step: TutorialStep
    /// Centre of the board grid in global (screen) coordinates.
    let boardCenter: CGPoint
    /// Centre of the task strip in global (screen) coordinates.
    let taskStripCenter: CGPoint
    let onSkip: () -> Void

    @State private var pulse = false

    private var targetCenter: CGPoint {
        switch step {
        case .rescue, .merge: return boardCenter
        case .quest:          return taskStripCenter
        case .done:           return .zero
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Semi-transparent scrim. allowsHitTesting(false) lets taps pass through
                // to the board so the player can act without dismissing the overlay first.
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                // Pulsing ring pointing at the current action target
                if targetCenter != .zero {
                    Circle()
                        .stroke(Color.yellow.opacity(pulse ? 0 : 0.9), lineWidth: 2.5)
                        .frame(width: pulse ? 90 : 56, height: pulse ? 90 : 56)
                        .position(targetCenter)
                        .allowsHitTesting(false)
                }

                // Speech bubble — floats above or below the target
                bubble(geo: geo)

                // Skip button — always reachable in the top-right corner
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onSkip) {
                            Label("Skip tutorial", systemImage: "xmark.circle")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Capsule().fill(Color.white.opacity(0.15)))
                        }
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .padding(.top, geo.safeAreaInsets.top + 8)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.85).repeatForever(autoreverses: false)) {
                pulse = true
            }
        }
    }

    // MARK: Bubble layout

    @ViewBuilder
    private func bubble(geo: GeometryProxy) -> some View {
        // Place bubble above the target when it is in the lower half of the screen,
        // and below it when the target is in the upper half (e.g. the task strip).
        let aboveTarget = targetCenter.y > geo.size.height * 0.42
        let bubbleY: CGFloat = aboveTarget
            ? max(targetCenter.y - 185, geo.safeAreaInsets.top + 130)
            : min(targetCenter.y + 185, geo.size.height - 130)

        VStack(spacing: 0) {
            if aboveTarget {
                card
                arrowTip(pointingDown: true)
            } else {
                arrowTip(pointingDown: false)
                card
            }
        }
        .frame(maxWidth: min(geo.size.width - 48, 300))
        .position(x: geo.size.width / 2, y: bubbleY)
    }

    private var card: some View {
        VStack(spacing: 8) {
            Image(systemName: stepIcon)
                .font(.system(size: 26))
                .foregroundColor(.yellow)
            Text(stepTitle)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
            Text(stepBody)
                .font(.system(size: 12.5))
                .foregroundColor(.white.opacity(0.9))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            Text(stepHint)
                .font(.system(size: 10.5, weight: .medium))
                .foregroundColor(Color.yellow.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 18).padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.07, green: 0.28, blue: 0.16))
                .overlay(RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1))
        )
        .shadow(color: .black.opacity(0.4), radius: 14)
    }

    private func arrowTip(pointingDown: Bool) -> some View {
        Canvas { ctx, size in
            var path = Path()
            if pointingDown {
                path.move(to: CGPoint(x: size.width / 2, y: size.height))
                path.addLine(to: CGPoint(x: size.width / 2 - 13, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2 + 13, y: 0))
            } else {
                path.move(to: CGPoint(x: size.width / 2, y: 0))
                path.addLine(to: CGPoint(x: size.width / 2 - 13, y: size.height))
                path.addLine(to: CGPoint(x: size.width / 2 + 13, y: size.height))
            }
            path.closeSubpath()
            ctx.fill(path, with: .color(Color(red: 0.07, green: 0.28, blue: 0.16)))
        }
        .frame(height: 14)
    }

    // MARK: Step content

    private var stepIcon: String {
        switch step {
        case .rescue: return "house.fill"
        case .merge:  return "arrow.triangle.merge"
        case .quest:  return "target"
        case .done:   return "checkmark.circle.fill"
        }
    }

    private var stepTitle: String {
        switch step {
        case .rescue: return "Rescue Your First Animal"
        case .merge:  return "Perform Your First Merge"
        case .quest:  return "Claim Your Quest Reward"
        case .done:   return ""
        }
    }

    private var stepBody: String {
        switch step {
        case .rescue:
            return "Tap the house icon (spawner tile) on the board to rescue your first animal. It costs 1 Kibble."
        case .merge:
            return "Tap an animal to select it, then tap a matching one to merge them into a higher stage!"
        case .quest:
            return "Your rescue and merge counted toward a quest. Tap 'Quests' in the strip above the board to open it and claim your reward."
        case .done:
            return ""
        }
    }

    private var stepHint: String {
        switch step {
        case .rescue: return "Kibble regenerates 1 every 2 min · max 100"
        case .merge:  return "Merges are free · a new animal auto-spawns after each merge"
        case .quest:  return "Quests reward Kibble and Dog Tags"
        case .done:   return ""
        }
    }
}
