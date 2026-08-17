//
//  ParallelBoardView.swift
//  PawSanctuary
//
//  Phase 6b, Task 3.6 — a dedicated full-screen board view for the Parallel
//  Board event type. EventSheetView (EventPanelView.swift) is a
//  milestone-lane sheet and cannot render a board; this is new SwiftUI,
//  structurally similar to MergeBoardView's own board-rendering code but
//  deliberately smaller — no drag/basket routing, no row-unlock chrome, no
//  superpowers, matching ParallelBoardCoordinator's own scope.
//
//  CellView (CellView.swift) turned out to already be fully decoupled from
//  MergeBoardViewModel — it takes only plain value types (BoardCell,
//  isSelected, etc.) — so it's reused here directly against
//  ParallelBoardCoordinator's boardState with no protocol/generic seam
//  needed. Resolves the open question §3.6's spec text left unanswered.
//
//  Interaction is tap-to-select-then-tap-target, not the main board's
//  drag gesture — simpler, and this board has no inventory/basket for a
//  drag to route to. Tapping the (empty) generator cell collects from it
//  instead of selecting it, since it never holds a mergeable item in
//  normal play.
//
//  Presentation is the caller's responsibility (e.g. `.fullScreenCover`) —
//  this view doesn't decide how it's shown. No entry point wires to this
//  yet: that needs `MergeBoardViewModel` to expose an active-event
//  reference, which is §3.7's job (event lifecycle), not this task's.
//

import SwiftUI

struct ParallelBoardView: View {
    let coordinator: ParallelBoardCoordinator
    let onDismiss: () -> Void

    @State private var selectedCell: GridPosition?

    private let cellSize: CGFloat = 62
    private let cellSpacing: CGFloat = 4

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.85, green: 0.95, blue: 0.85),
                         Color(red: 0.95, green: 0.88, blue: 0.75)],
                startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()

            VStack(spacing: 16) {
                header
                progressBar
                Spacer(minLength: 0)
                boardGrid
                Spacer(minLength: 0)
            }
            .padding()
        }
    }

    // MARK: Header

    private var header: some View {
        HStack {
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.secondary)
            }
            Spacer()
            energyMeter
        }
    }

    private var energyMeter: some View {
        HStack(spacing: 6) {
            Image(systemName: "bolt.fill").foregroundColor(.yellow)
            Text("\(coordinator.energy.balance)/\(parallelBoardEnergyCap)")
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Capsule().fill(Color.white.opacity(0.7)))
    }

    // MARK: Progress

    private var progressBar: some View {
        let maxTokens = ProgressTrackRegistry.tracks[coordinator.eventID]?.last?.threshold ?? 1
        let earned = coordinator.progressTrack.progress(trackID: coordinator.eventID)
        let fraction = Double(earned) / Double(max(1, maxTokens))
        return TaskProgressBar(fraction: fraction, color: Color.orange.opacity(0.7))
            .frame(height: 10)
    }

    // MARK: Board grid

    private var boardGrid: some View {
        VStack(spacing: cellSpacing) {
            ForEach(0..<parallelBoardRows, id: \.self) { row in
                HStack(spacing: cellSpacing) {
                    ForEach(0..<parallelBoardCols, id: \.self) { col in
                        cellView(at: GridPosition(row: row, col: col))
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.5)).shadow(color: .black.opacity(0.1), radius: 8))
    }

    private func cellView(at pos: GridPosition) -> some View {
        let cell = coordinator.boardState.board[pos.row][pos.col]
        return ZStack {
            CellView(
                cell: cell,
                isSelected: selectedCell == pos,
                isAnimating: false,
                isDragging: false,
                isNewlyUnlocked: false,
                isSpotlight: false,
                cellSize: cellSize
            )
            if pos == coordinator.generatorPosition {
                generatorChrome(isClear: cell.isEmpty)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .onTapGesture { handleTap(at: pos) }
    }

    private func generatorChrome(isClear: Bool) -> some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(Color.blue, lineWidth: 2.5)
            .overlay(alignment: .topTrailing) {
                Image(systemName: "bolt.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .opacity(isClear ? 1 : 0)
            }
            .allowsHitTesting(false)
    }

    // MARK: Interaction

    private func handleTap(at pos: GridPosition) {
        HapticManager.shared.lightTap()
        if pos == coordinator.generatorPosition, coordinator.boardState.item(at: pos) == nil {
            coordinator.collectFromGenerator()
            return
        }
        if let sel = selectedCell {
            selectedCell = nil
            if sel != pos {
                coordinator.attemptMerge(from: sel, to: pos)
            }
        } else if coordinator.boardState.item(at: pos) != nil {
            selectedCell = pos
        }
    }
}
