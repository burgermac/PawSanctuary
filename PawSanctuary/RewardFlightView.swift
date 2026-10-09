//
//  RewardFlightView.swift
//  PawSanctuary
//
//  Per-currency reward flights (specs/Spec_RewardFlight.md; measured in
//  `Spec_TravelTownReview_Draft.md` §2): when an order completes, each currency
//  it pays leaves the order card and arcs to its own HUD counter, so the
//  counters are the choreography rather than numbers that merely change.
//

import SwiftUI

// MARK: Model

/// A currency that flies, and the HUD element it flies to.
enum RewardFlightKind: String, CaseIterable, Hashable {
    case coins, dogTags, xp

    var symbol: String {
        switch self {
        case .coins:   return "dollarsign.circle.fill"
        case .dogTags: return "tag.fill"
        case .xp:      return "star.fill"
        }
    }

    var tint: Color {
        switch self {
        case .coins:   return Color(red: 0.85, green: 0.62, blue: 0.08)
        case .dogTags: return Color(red: 0.20, green: 0.45, blue: 0.80)
        case .xp:      return Color(red: 0.30, green: 0.70, blue: 0.40)
        }
    }

    /// How many sprites carry `amount` — a stream, capped so a big payout does
    /// not fill the screen.
    func spriteCount(for amount: Int) -> Int {
        switch self {
        case .coins:   return amount >= 100 ? 6 : amount >= 25 ? 4 : 3
        case .dogTags: return min(4, max(1, amount))
        case .xp:      return 3
        }
    }
}

struct RewardBurstItem: Equatable {
    let kind: RewardFlightKind
    let amount: Int
}

/// One order's payout, in flight. `sourceID` is the order whose card the
/// sprites leave from.
struct RewardBurst: Identifiable, Equatable {
    let id = UUID()
    let sourceID: UUID
    let items: [RewardBurstItem]
}

// MARK: Frame reporting

/// Global frames of the HUD counters the sprites fly to.
struct HUDFrameKey: PreferenceKey {
    static let defaultValue: [RewardFlightKind: CGRect] = [:]
    static func reduce(value: inout [RewardFlightKind: CGRect], nextValue: () -> [RewardFlightKind: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// Global frames of the order cards currently laid out, by order id.
struct OrderCardFrameKey: PreferenceKey {
    static let defaultValue: [UUID: CGRect] = [:]
    static func reduce(value: inout [UUID: CGRect], nextValue: () -> [UUID: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

extension View {
    func reportHUDFrame(_ kind: RewardFlightKind) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: HUDFrameKey.self, value: [kind: g.frame(in: .global)])
        })
    }

    func reportOrderCardFrame(_ id: UUID) -> some View {
        background(GeometryReader { g in
            Color.clear.preference(key: OrderCardFrameKey.self, value: [id: g.frame(in: .global)])
        })
    }
}

// MARK: Overlay

struct RewardFlightOverlay: View {
    let bursts: [RewardBurst]
    let hudFrames: [RewardFlightKind: CGRect]
    let orderFrames: [UUID: CGRect]
    /// Where sprites start when the order's card is not on screen (scrolled
    /// out of the lane): the middle of the lane.
    var fallbackSource: CGPoint

    var body: some View {
        GeometryReader { geo in
            let origin = geo.frame(in: .global).origin
            ZStack {
                ForEach(bursts) { burst in
                    let source = orderFrames[burst.sourceID].map { CGPoint(x: $0.midX, y: $0.midY) }
                        ?? fallbackSource
                    ForEach(Array(burst.items.enumerated()), id: \.offset) { slot, item in
                        if let target = hudFrames[item.kind] {
                            ForEach(0..<item.kind.spriteCount(for: item.amount), id: \.self) { i in
                                RewardFlightSprite(
                                    kind: item.kind,
                                    from: CGPoint(x: source.x - origin.x, y: source.y - origin.y),
                                    to: CGPoint(x: target.midX - origin.x, y: target.midY - origin.y),
                                    delay: Double(slot) * 0.12 + Double(i) * 0.07)
                            }
                        }
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct RewardFlightSprite: View {
    let kind: RewardFlightKind
    let from: CGPoint
    let to: CGPoint
    let delay: Double

    @State private var progress: CGFloat = 0
    /// 0 = not landed yet (no ring), 1 = ring at the counter, 2 = ring expanded
    /// and faded. Set from a timer rather than read off `progress`, because
    /// `progress` is already at its final value the instant the animation starts.
    @State private var ringPhase = 0

    private let duration = 0.55

    var body: some View {
        ZStack {
            Circle()
                .stroke(kind.tint.opacity(ringPhase == 1 ? 0.7 : 0), lineWidth: 3)
                .frame(width: ringPhase == 2 ? 46 : 18, height: ringPhase == 2 ? 46 : 18)
                .position(to)

            Image(systemName: kind.symbol)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(kind.tint)
                .shadow(color: .white.opacity(0.9), radius: 2)
                .modifier(RewardArcModifier(progress: progress, from: from, to: to))
        }
        .task {
            withAnimation(.easeIn(duration: duration).delay(delay)) { progress = 1 }
            try? await Task.sleep(for: .seconds(delay + duration))
            ringPhase = 1
            withAnimation(.easeOut(duration: 0.35)) { ringPhase = 2 }
        }
    }
}

/// Moves a view along a parabola from `from` to `to`, bowed upward by a
/// fraction of the trip, fading in at the start and out on arrival. Opacity and
/// position are both derived from the *animated* `progress`, so they follow the
/// animation rather than the final state.
private struct RewardArcModifier: ViewModifier, Animatable {
    var progress: CGFloat
    let from: CGPoint
    let to: CGPoint

    nonisolated var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let t = progress
        let lift = min(70, hypot(to.x - from.x, to.y - from.y) * 0.18)
        let x = from.x + (to.x - from.x) * t
        let y = from.y + (to.y - from.y) * t - 4 * lift * t * (1 - t)
        let opacity: Double = t <= 0 || t >= 1 ? 0 : (t < 0.1 ? Double(t) * 10 : (t > 0.85 ? Double(1 - t) / 0.15 : 1))
        return content
            .scaleEffect(1 - 0.3 * t)
            .opacity(opacity)
            .position(x: x, y: y)
    }
}
