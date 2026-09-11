//
//  ParallelBoardView.swift
//  PawSanctuary
//
//  Phase 6b, Task 3.6 — a dedicated full-screen board view for the Parallel
//  Board event type. EventSheetView (EventPanelView.swift) is a
//  milestone-lane sheet and cannot render a board; this is new SwiftUI,
//  structurally similar to MergeBoardView's own board-rendering code but
//  deliberately smaller — no basket routing, no row-unlock chrome, no
//  superpowers, matching ParallelBoardCoordinator's own scope.
//
//  CellView (CellView.swift) turned out to already be fully decoupled from
//  MergeBoardViewModel — it takes only plain value types (BoardCell,
//  isSelected, etc.) — so it's reused here directly against
//  ParallelBoardCoordinator's boardState with no protocol/generic seam
//  needed. Resolves the open question §3.6's spec text left unanswered.
//
//  Interaction matches the main board: drag a tile onto another to merge or
//  move it, with tap-to-select-then-tap-target kept as the secondary path
//  (MergeBoardView offers both on every cell too). The original version of
//  this view shipped tap-only on the reasoning that there was no
//  inventory/basket for a drag to route to — true, but the main board's
//  drag is how players have already been taught to merge, and a second
//  board that answers the same gesture differently reads as broken
//  (playtest feedback, 11 Sep 2026). The basket half is what doesn't apply
//  here, not the gesture: a drop that lands outside the grid simply clamps
//  back onto it instead of going to storage.
//
//  Presentation is the caller's responsibility (e.g. `.fullScreenCover`) —
//  this view doesn't decide how it's shown.
//

import SwiftUI

struct ParallelBoardView: View {
    let coordinator: ParallelBoardCoordinator
    let onDismiss: () -> Void

    @State private var selectedCell: GridPosition?
    /// Drag state lives here rather than on the coordinator for the same
    /// reason `MergeBoardView.dragOffset` does — only this view reads it,
    /// and it isn't part of the event's persisted board state.
    @State private var draggingFrom: GridPosition?
    @State private var dragOffset: CGSize = .zero

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
            // Regen is 90s a point, so an empty bar is three quarters of an
            // hour from full and a single generator tap is three minutes
            // away — long enough that a bare balance tells the player
            // nothing about when they can play again. Same treatment the
            // main board's kibble pill already gives the same problem
            // (`MergeBoardView.kibblePill`): smaller, muted, and gone once
            // there is nothing left to wait for.
            if !coordinator.energy.isFull {
                Text(coordinator.energy.statusText)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: coordinator.energy.isFull)
        .lineLimit(1)
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
                // A cell's own zIndex only out-ranks its same-row siblings —
                // SwiftUI scopes zIndex to one parent's children — so the
                // drag ghost needs the whole row raised to draw over the row
                // below it. Same reasoning as `MergeBoardView`'s
                // `rowHasAnimatingCell`.
                .zIndex(draggingFrom?.row == row ? 5 : 0)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 20)
            .fill(Color.white.opacity(0.5)).shadow(color: .black.opacity(0.1), radius: 8))
    }

    private func cellView(at pos: GridPosition) -> some View {
        let cell = coordinator.boardState.board[pos.row][pos.col]
        let isGenerator = pos == coordinator.generatorPosition
        return ZStack {
            if isGenerator && cell.isEmpty {
                ParallelBoardGeneratorTile(chainID: coordinator.chainID,
                                           cost: parallelBoardGeneratorCost,
                                           isReady: canCollectFromGenerator,
                                           cellSize: cellSize)
            } else {
                CellView(
                    cell: cell,
                    isSelected: selectedCell == pos,
                    isAnimating: false,
                    isDragging: draggingFrom == pos,
                    isNewlyUnlocked: false,
                    isSpotlight: false,
                    cellSize: cellSize
                )
                if isGenerator { blockedGeneratorChrome }
            }
            if draggingFrom == pos, let item = cell.item {
                dragGhost(for: item)
            }
        }
        .frame(width: cellSize, height: cellSize)
        .onTapGesture { handleTap(at: pos) }
        .gesture(dragGesture(from: pos))
    }

    /// Shown only when something is standing *on* the generator cell — a
    /// state the generator itself never creates (it always places elsewhere)
    /// but a player move can. Marks the cell as the van's spot so it reads
    /// as temporarily blocked rather than as an ordinary tile.
    private var blockedGeneratorChrome: some View {
        RoundedRectangle(cornerRadius: 12)
            .strokeBorder(Color(red: 0.70, green: 0.35, blue: 0.10).opacity(0.85),
                          style: StrokeStyle(lineWidth: 2.5, dash: [4, 3]))
            .allowsHitTesting(false)
    }

    /// Whether a generator tap would actually produce something — enough
    /// energy *and* somewhere to put the result. `collectFromGenerator`
    /// silently no-ops on either, so the tile dims instead of leaving the
    /// player tapping a live-looking van that does nothing.
    private var canCollectFromGenerator: Bool {
        guard coordinator.energy.balance >= parallelBoardGeneratorCost else { return false }
        return coordinator.boardState.emptyUnlockedCells
            .contains { $0.position != coordinator.generatorPosition }
    }

    /// The item under the finger mid-drag. Mirrors `MergeBoardView`'s ghost,
    /// but prefers the chain's delivered art when it has any (Second Chances
    /// ships `special_second_chances_t0N`), falling back to the tier symbol.
    private func dragGhost(for item: BoardItem) -> some View {
        Group {
            if let art = item.artImage {
                art.resizable().scaledToFit().frame(width: cellSize * 0.78, height: cellSize * 0.78)
            } else {
                Image(systemName: item.def?.symbol ?? "questionmark")
                    .font(.system(size: 44))
                    .foregroundColor(item.def?.tint ?? item.def?.color ?? .gray)
            }
        }
        .scaleEffect(1.2)
        .shadow(color: .black.opacity(0.25), radius: 8)
        .offset(dragOffset)
        .allowsHitTesting(false)
        .zIndex(99)
    }

    // MARK: Interaction

    /// Straight port of `MergeBoardView`'s board drag, minus the basket
    /// branch (this board has no storage to drop into) — the translation is
    /// still rounded to a whole cell offset and clamped to the grid, so a
    /// drop that overshoots the edge lands on the nearest real cell instead
    /// of being lost.
    private func dragGesture(from pos: GridPosition) -> some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { v in
                guard coordinator.boardState.item(at: pos) != nil else { return }
                if draggingFrom == nil {
                    draggingFrom = pos
                    // A drag supersedes any half-finished tap selection, so
                    // the tap that ends it can't be read as the second half
                    // of a merge the player has since abandoned.
                    selectedCell = nil
                    HapticManager.shared.lightTap()
                }
                // A second finger landing on another tile must not steer the
                // ghost already in flight.
                guard draggingFrom == pos else { return }
                dragOffset = v.translation
            }
            .onEnded { v in
                defer { draggingFrom = nil; dragOffset = .zero }
                guard draggingFrom == pos else { return }
                let rowOff = Int((v.translation.height / (cellSize + cellSpacing)).rounded())
                let colOff = Int((v.translation.width / (cellSize + cellSpacing)).rounded())
                let target = GridPosition(
                    row: max(0, min(parallelBoardRows - 1, pos.row + rowOff)),
                    col: max(0, min(parallelBoardCols - 1, pos.col + colOff)))
                guard target != pos else { return }
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    coordinator.attemptMerge(from: pos, to: target)
                }
            }
    }

    private func handleTap(at pos: GridPosition) {
        HapticManager.shared.lightTap()
        if pos == coordinator.generatorPosition, coordinator.boardState.item(at: pos) == nil {
            // Collecting is unrelated to any in-progress selection — clear it
            // rather than leaving a stale cell visually "selected" so the
            // player's *next* tap doesn't silently attempt a merge with a
            // selection they no longer have in mind (found reviewing
            // Parallel Board, 18 Aug 2026).
            selectedCell = nil
            coordinator.collectFromGenerator()
            return
        }
        if let sel = selectedCell {
            selectedCell = nil
            if sel != pos {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    coordinator.attemptMerge(from: sel, to: pos)
                }
            }
        } else if coordinator.boardState.item(at: pos) != nil {
            selectedCell = pos
        }
    }
}

// MARK: - Generator tile

/// The event board's generator, drawn.
///
/// On the main board a generator is a real `ProducerTile` and
/// `ProducerTileContent` gives it a face. Here the generator deliberately
/// isn't a cell type at all — it's an ordinary empty cell at a known
/// position (`ParallelBoardCoordinator.generatorPosition`, §3.3) — so there
/// was no producer for `CellView` to render and it drew as a bare empty
/// square with a ring around it, which is not a thing a player can read as
/// tappable (playtest feedback, 11 Sep 2026).
///
/// This is that missing face, in the family spawner's own visual grammar
/// (large icon, name, call to action, corner badge) so the event board reads
/// as the same game. Built from SF Symbols and the chain's own palette
/// rather than delivered art, which is what every spawner on the main board
/// uses — Second Chances ships item art for its five tiers but none for a
/// spawner, and inventing a sixth asset is a content job, not this one's.
private struct ParallelBoardGeneratorTile: View {
    let chainID: ChainID
    let cost: Int
    /// False when a tap would no-op — out of energy, or no free cell for the
    /// stray to land on.
    let isReady: Bool
    var cellSize: CGFloat = 62

    private var iconPts: CGFloat  { max(14, cellSize * 0.40) }
    private var labelPts: CGFloat { max(5,  cellSize * 0.13) }

    /// The chain's own top-tier colour — the warm "sanctuary" brown Second
    /// Chances ends on, so the van that starts the journey is tinted by
    /// where it's taking them.
    private var tint: Color {
        ContentRegistry.shared.chain(chainID)?.tiers.last?.color
            ?? Color(red: 0.70, green: 0.35, blue: 0.10)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [tint.opacity(0.28), tint.opacity(0.10)],
                                     startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(tint.opacity(0.9), lineWidth: 2.5))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)

            VStack(spacing: 1) {
                Image(systemName: "truck.box.fill")
                    .font(.system(size: iconPts))
                    .foregroundColor(tint)
                    // Same always-on pulse the main board's animal producers
                    // use to say "tappable" — dropped when a tap would do
                    // nothing, so the animation is never a lie.
                    .symbolEffect(.pulse, options: .repeating, isActive: isReady)

                Text("Rescue")
                    .font(.system(size: labelPts, weight: .bold))
                    .foregroundColor(tint)
                    .lineLimit(1).minimumScaleFactor(0.5)

                HStack(spacing: 1) {
                    Image(systemName: "bolt.fill")
                    Text("\(cost)")
                }
                .font(.system(size: labelPts, weight: .heavy))
                .foregroundColor(isReady ? .green : .secondary)
            }
            .padding(max(2, cellSize * 0.05))
        }
        .grayscale(isReady ? 0 : 0.7)
        .opacity(isReady ? 1 : 0.55)
        .animation(.easeInOut(duration: 0.2), value: isReady)
    }
}
