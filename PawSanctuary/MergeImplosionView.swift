//
//  MergeImplosionView.swift
//  PawSanctuary
//
//  Merge phases 1-2 (specs/Spec_BoardAnimation_Draft.md section 8, task 8.4):
//  the two merging items start side by side in the target cell, slide
//  together, then shrink and fade to a point, after which the Tier A burst
//  fires. Offset, scale and opacity only: no blur, shadow, mask or
//  compositing group (memory rule, section 8c).
//

import SwiftUI

/// Draws every in-flight merge implosion above the board grid. Positioned in
/// the grid's own coordinate space, like `SpawnFlightOverlay`.
struct MergeImplosionOverlay: View {
    let implosions: [MergeBoardViewModel.MergeImplosion]
    let cellSize: CGFloat
    let spacing: CGFloat

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(implosions) { implosion in
                MergeImplosionSprites(implosion: implosion, cellSize: cellSize, spacing: spacing)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// How far, as a fraction of a cell, the dragged item starts from the target's
/// centre toward its origin. Matches the idle merge-hint nudge.
func mergeImplosionStartOffset(from: GridPosition, to: GridPosition, cellSize: CGFloat) -> CGSize {
    let dRow = Double(from.row - to.row)
    let dCol = Double(from.col - to.col)
    let length = (dRow * dRow + dCol * dCol).squareRoot()
    guard length > 0 else { return .zero }
    let magnitude = cellSize * 0.22
    return CGSize(width: dCol / length * magnitude, height: dRow / length * magnitude)
}

private struct MergeImplosionSprites: View {
    let implosion: MergeBoardViewModel.MergeImplosion
    let cellSize: CGFloat
    let spacing: CGFloat

    @State private var progress: CGFloat = 0

    private var pitch: CGFloat { cellSize + spacing }
    private var origin: CGPoint {
        CGPoint(x: CGFloat(implosion.to.col) * pitch, y: CGFloat(implosion.to.row) * pitch)
    }

    var body: some View {
        ZStack {
            BoardItemSprite(item: implosion.targetItem, cellSize: cellSize)
                .modifier(MergeImplodeEffect(progress: progress, startOffset: .zero))
            BoardItemSprite(item: implosion.sourceItem, cellSize: cellSize)
                .modifier(MergeImplodeEffect(
                    progress: progress,
                    startOffset: mergeImplosionStartOffset(from: implosion.from, to: implosion.to,
                                                           cellSize: cellSize)))
        }
        .frame(width: cellSize, height: cellSize)
        .offset(x: origin.x, y: origin.y)
        .transition(.identity)
        .onAppear {
            // One linear run; the modifier splits it into slide then implode.
            withAnimation(.linear(duration: mergeImplosionDuration)) { progress = 1 }
        }
    }
}

/// Slide from `startOffset` to the centre over the first part of `progress`,
/// then scale down to `mergeImplodeMinScale` and fade over the rest.
private struct MergeImplodeEffect: ViewModifier, @preconcurrency Animatable {
    var progress: CGFloat
    let startOffset: CGSize

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func body(content: Content) -> some View {
        let slideShare = CGFloat(mergeSlideDuration / mergeImplosionDuration)
        let slide = min(1, progress / slideShare)
        let implode = max(0, (progress - slideShare) / (1 - slideShare))
        let scale = 1 - (1 - CGFloat(mergeImplodeMinScale)) * implode
        return content
            .offset(x: startOffset.width * (1 - slide), y: startOffset.height * (1 - slide))
            .scaleEffect(scale)
            .opacity(1 - implode)
    }
}
