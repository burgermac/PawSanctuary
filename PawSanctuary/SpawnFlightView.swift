//
//  SpawnFlightView.swift
//  PawSanctuary
//
//  The producer-to-cell arc a freshly spawned item flies
//  (specs/Spec_SpawnFlight.md; measured in `Spec_ParallelBoardReview_Draft.md`
//  §3.3 and `Spec_BoardAnimation_Draft.md` §4): the item materialises at the
//  generator, arcs over the cells between, and lands in its destination in
//  about a tenth of a second.
//

import SwiftUI

/// Draws every in-flight spawn above the board grid. Positioned in the grid's
/// own coordinate space, so it must be applied as an overlay on the grid
/// before any padding or background is added.
struct SpawnFlightOverlay: View {
    let flights: [MergeBoardViewModel.SpawnFlight]
    let cellSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(flights) { flight in
                SpawnFlightSprite(flight: flight, cellSize: cellSize, spacing: spacing)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct SpawnFlightSprite: View {
    let flight: MergeBoardViewModel.SpawnFlight
    let cellSize: CGFloat
    let spacing: CGFloat

    @State private var progress: CGFloat = 0

    private var pitch: CGFloat { cellSize + spacing }
    private var origin: CGPoint {
        CGPoint(x: CGFloat(flight.from.col) * pitch, y: CGFloat(flight.from.row) * pitch)
    }
    private var dx: CGFloat { CGFloat(flight.to.col - flight.from.col) * pitch }
    private var dy: CGFloat { CGFloat(flight.to.row - flight.from.row) * pitch }
    /// The arc's peak height: a quarter of the trip, capped so a far corner
    /// does not launch the item off the board.
    private var lift: CGFloat {
        min(cellSize * 0.9, (dx * dx + dy * dy).squareRoot() * 0.25)
    }

    var body: some View {
        // The head, then two fainter copies lagging behind it on the same path:
        // a short comet trail. The reference's trail colour is unresolved
        // (`Spec_BoardAnimation_Draft.md` §7 #4), so it takes the item's own tint.
        ZStack {
            ForEach([0.22, 0.11, 0.0], id: \.self) { lag in
                sprite
                    .opacity(lag == 0 ? 1 : (lag > 0.15 ? 0.18 : 0.35))
                    .modifier(SpawnArcEffect(progress: progress, dx: dx, dy: dy, lift: lift, lag: lag))
            }
        }
        .frame(width: cellSize, height: cellSize)
        .offset(x: origin.x, y: origin.y)
        .onAppear {
            withAnimation(.easeInOut(duration: spawnFlightDuration)) { progress = 1 }
        }
    }

    @ViewBuilder
    private var sprite: some View {
        if let art = flight.item.artImage {
            art.resizable().scaledToFit()
                .frame(width: cellSize * 0.78, height: cellSize * 0.78)
        } else {
            Image(systemName: flight.item.def?.symbol ?? "pawprint.fill")
                .font(.system(size: cellSize * 0.5))
                .foregroundColor(flight.item.def?.tint ?? flight.item.def?.color ?? .brown)
        }
    }
}

/// Moves a view along a parabola from its origin by (dx, dy), peaking `lift`
/// points above the straight line. `lag` shifts the progress back so a copy
/// trails the head. Animatable through `progress`.
private struct SpawnArcEffect: GeometryEffect {
    var progress: CGFloat
    let dx: CGFloat
    let dy: CGFloat
    let lift: CGFloat
    let lag: Double

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let t = max(0, progress - CGFloat(lag))
        let x = dx * t
        let y = dy * t - 4 * lift * t * (1 - t)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: y))
    }
}
