//
//  CellView.swift
//  PawSanctuary
//

import SwiftUI
import Foundation

// ============================================================
// MARK: - BOARD CELL VIEW
// ============================================================

/// Renders a single board cell — animal, producer, locked, or empty.
/// Receives only plain value types so SwiftUI can skip unchanged cells.
struct CellView: View {
    let cell: BoardCell
    let isSelected: Bool
    let isAnimating: Bool
    let isDragging: Bool
    let isNewlyUnlocked: Bool
    let isSpotlight: Bool
    var cellSize: CGFloat = 62  // default keeps non-board usages (inventory preview etc.) unchanged
    var unlockedSuperpowerSpecies: [String] = []
    var isLeapSource: Bool = false
    /// Small directional nudge toward a matching item elsewhere on the board —
    /// the idle "these two can merge" hint. `.zero` outside a hint pulse; see
    /// `MergeBoardViewModel.mergeHintPair`.
    var mergeHintOffset: CGSize = .zero
    /// True when `cell` holds a family spawner the player can currently
    /// afford to tap — gates the producer affordance shimmer
    /// (`Spec_BoardAnimation_Draft.md` §5). Ignored for every other cell
    /// content; `ProducerTileContent` only reads it on the family-spawner path.
    var isFamilySpawnerAffordable: Bool = false
    /// Whether an unclaimed daily hand-in task wants what is standing in this
    /// cell, and whether that task is fully stocked
    /// (`Spec_DailyHandInTasks.md` D-B). Drives the muted/bright blue tint
    /// that tells the player where a task's pieces are.
    var dailyTaskHighlight: MergeBoardViewModel.DailyTaskHighlight = .none

    /// Merge-burst sparkles (`Spec_BoardAnimation_Draft.md` §3 Tier A), spawned
    /// when `isAnimating` goes true. Each `MergeSparkleView` runs its own
    /// ~0.9s fade-and-drift independent of `isAnimating`'s lifetime, so the
    /// star trail deliberately outlives the 600ms scale animation the view
    /// model clears it after — matching the reference, where the sparkles
    /// linger after the item itself has settled.
    @State private var mergeSparkles: [MergeSparkle] = []
    /// White-hot flash at the peak of the merge overshoot, decaying fast.
    @State private var mergeBloomOpacity: Double = 0

    var body: some View {
        ZStack {
            // ── Background & borders ─────────────────────────────────
            // Clipped on its own, separately from content below, so a
            // merging item's overshoot (Tier A) can visually breach the
            // cell's rounded-rect bounds instead of being cut off at them —
            // matching the reference, which deliberately lets the burst
            // overlap neighbouring cells rather than clipping it.
            RoundedRectangle(cornerRadius: 12).fill(cellBackground)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor, lineWidth: isSelected ? 3 : 1))
                .shadow(color: .black.opacity(0.08), radius: 3, x: 0, y: 2)
                // Newly-unlocked green flash
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .fill(Color.green.opacity(isNewlyUnlocked ? 0.4 : 0.0))
                    .animation(.easeOut(duration: 0.6), value: isNewlyUnlocked))
                // Spotlight yellow ring (animals only)
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.yellow.opacity(isSpotlight && cell.item != nil ? 0.8 : 0.0),
                            lineWidth: 2.5))
                // Daily hand-in task ring. The fill alone is legible at rest,
                // but the board already tints every cell by its item's stage
                // colour, so a stocked task needs an edge as well to survive a
                // board full of other tints.
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(dailyTaskBorder, lineWidth: dailyTaskHighlight == .stocked ? 2.5 : 0)
                    .animation(.easeInOut(duration: 0.25), value: dailyTaskHighlight))
                // Top-tier gold gradient ring
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(colors: [.yellow, Color(red: 1, green: 0.75, blue: 0.1), .yellow],
                                       startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: (cell.item?.isTopTier ?? false) ? 2.5 : 0))
                // Leap-mode source selection pulse
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.cyan.opacity(isLeapSource ? 0.9 : 0), lineWidth: 3)
                    .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isLeapSource))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            // ── Content ──────────────────────────────────────────────
            // Deliberately unclipped: the merge overshoot and its sparkle
            // burst need to render past the cell's own bounds. Everything
            // else here already sits within them during normal play.
            ZStack {
                // Locked is checked before item (Task 4.2): a locked row's cache
                // renders as a dimmed preview under a lock badge, never as a fully
                // interactive tile — checkTierUnlock only flips isUnlocked, so the
                // same item just becomes normal itemContent the instant it unlocks.
                if !cell.isUnlocked {
                    lockedContent(cachedItem: cell.item)
                } else if let producer = cell.producer {
                    ProducerTileContent(producer: producer, cellSize: cellSize,
                                        isAffordable: isFamilySpawnerAffordable)
                        .opacity(isDragging ? 0.25 : 1.0)
                } else if let item = cell.item {
                    itemContent(item)
                        .opacity(isDragging ? 0.25 : 1.0)
                        .grayscale(item.tier == 0 ? 0.6 : 0.0)   // base tier looks faded
                        .overlay(bubbleOverlay(for: item))
                        .offset(mergeHintOffset)
                        // White-hot bloom at the peak of the overshoot
                        .shadow(color: .white.opacity(mergeBloomOpacity), radius: cellSize * 0.16)
                }
                ForEach(mergeSparkles) { sparkle in
                    MergeSparkleView(sparkle: sparkle, cellSize: cellSize)
                }
            }
        }
        .onChange(of: isAnimating) { _, animating in
            guard animating else { return }
            // Replaces rather than appends: the next burst on this cell
            // simply swaps in a fresh array, and SwiftUI drops the old
            // (by then fully faded, inert) sparkle views on its own — no
            // separate cleanup timer needed for a set this small.
            mergeSparkles = (0..<Int.random(in: 3...5)).map { _ in MergeSparkle() }
            mergeBloomOpacity = 0.85
            withAnimation(.easeOut(duration: 0.22)) { mergeBloomOpacity = 0 }
        }
    }

    // MARK: Sub-views

    @ViewBuilder
    private func itemContent(_ item: BoardItem) -> some View {
        let def = item.def
        let isAnimal = item.chain?.category == .animal
        let itemSpecies = isAnimal
            ? AnimalSpecies(rawValue: item.chainID.replacingOccurrences(of: "animal.", with: ""))
            : nil
        let hasUnlockedSuperpower = itemSpecies.map { unlockedSuperpowerSpecies.contains($0.rawValue) } ?? false
        let art = item.artImage
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    if let art {
                        // Real art already distinguishes species/tier at a glance, so it
                        // fills the cell instead of sharing space with a name label. 0.78
                        // is sized against the board's smallest computed cell (32pt, see
                        // boardSection) so the art plus this VStack's 3pt padding never
                        // exceeds the cell bounds at any board size.
                        art.resizable().scaledToFit()
                            .frame(width: cellSize * 0.78, height: cellSize * 0.78)
                    } else {
                        Image(systemName: def?.symbol ?? "questionmark")
                            .font(.system(size: 24))
                            .foregroundColor(item.isTopTier ? .yellow : (def?.tint ?? def?.color ?? .gray))
                    }
                    if let badge = def?.badge {
                        Image(systemName: badge)
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.10))
                            .offset(x: 4, y: -4)
                    }
                }
                .scaleEffect(isAnimating ? 1.5 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isAnimating)

                if art == nil {
                    Text(isAnimal ? (item.chain?.displayName ?? "") : (def?.shortLabel ?? ""))
                        .font(.system(size: 7, weight: .bold)).foregroundColor(def?.color ?? .gray)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(isAnimal ? (def?.shortLabel ?? "") : (item.chain?.displayName ?? ""))
                        .font(.system(size: 7)).foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
            }
            .padding(3)

            // Superpower badge — shown when this family has unlocked its superpower.
            if hasUnlockedSuperpower, let sp = itemSpecies {
                Group {
                    if let badge = sp.superpower.badgeImage {
                        badge.resizable().scaledToFit().frame(width: 9, height: 9)
                    } else {
                        Image(systemName: sp.superpower.sfSymbol)
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .padding(2)
                .background(Circle().fill(Color.purple.opacity(0.85)))
                .offset(x: 2, y: 2)
            }
        }
    }

    /// A locked cell with no cache shows the plain "Locked" placeholder. A
    /// pre-seeded cache (Task 4.2) shows a dimmed preview of what's waiting,
    /// with a small lock badge — visible, but read as not-yet-interactive.
    @ViewBuilder
    private func lockedContent(cachedItem: BoardItem?) -> some View {
        if let item = cachedItem, let def = item.def {
            let art = item.artImage
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 2) {
                    if let art {
                        art.resizable().scaledToFit()
                            .frame(width: cellSize * 0.78, height: cellSize * 0.78)
                            .opacity(0.45)
                    } else {
                        Image(systemName: def.symbol).font(.system(size: 22))
                            .foregroundColor((def.tint ?? def.color).opacity(0.45))
                    }
                    if art == nil {
                        Text(def.shortLabel).font(.system(size: 7)).foregroundColor(.gray.opacity(0.55))
                            .lineLimit(1).minimumScaleFactor(0.5)
                    }
                }
                .padding(3)
                Image(systemName: "lock.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(3)
                    .background(Circle().fill(Color.white.opacity(0.75)))
                    .offset(x: 2, y: -2)
            }
        } else {
            VStack(spacing: 3) {
                Image(systemName: "lock.fill").font(.system(size: 16)).foregroundColor(.gray.opacity(0.4))
                Text("Locked").font(.system(size: 7)).foregroundColor(.gray.opacity(0.4))
            }
        }
    }

    /// Tints a bubbled item cyan (still poppable for full value) or grey (Task
    /// 4.4: decayed — a tap now just collects the lesser reward), with a small
    /// badge marking which state it's in.
    @ViewBuilder
    private func bubbleOverlay(for item: BoardItem) -> some View {
        if item.bubbledAt != nil {
            let decayed = item.isBubbleDecayed()
            let tint = decayed ? Color.gray : Color.cyan
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12).fill(tint.opacity(0.22))
                Image(systemName: decayed ? "sparkles" : "circle.hexagongrid.fill")
                    .font(.system(size: 8))
                    .foregroundColor(.white)
                    .padding(3)
                    .background(Circle().fill(tint.opacity(0.9)))
                    .offset(x: 2, y: 2)
            }
        }
    }

    // MARK: Computed colours

    /// Muted blue — a task wants this creature but is still short.
    private var dailyTaskWantedTint: Color {
        Color(red: 0.30, green: 0.52, blue: 0.78).opacity(0.22)
    }
    /// Bright blue — every line of a task this cell serves is stocked.
    private var dailyTaskStockedTint: Color {
        Color(red: 0.10, green: 0.55, blue: 0.98).opacity(0.55)
    }
    private var dailyTaskBorder: Color {
        dailyTaskHighlight == .stocked
            ? Color(red: 0.05, green: 0.45, blue: 0.95)
            : .clear
    }

    private var cellBackground: Color {
        if !cell.isUnlocked    { return Color.gray.opacity(0.12) }
        if isSelected           { return Color.yellow.opacity(0.3) }
        // Daily-task tint outranks the item's own stage colour: the whole
        // point is that it reads as *different from the board*, and the item
        // tint it replaces is already carried by the art itself.
        switch dailyTaskHighlight {
        case .stocked: return dailyTaskStockedTint
        case .wanted:  return dailyTaskWantedTint
        case .none:    break
        }
        if let p = cell.producer { return p.level.tintColor.opacity(0.12) }
        if let item = cell.item  { return (item.def?.color ?? .gray).opacity(0.12) }
        return Color.white.opacity(0.7)
    }
    private var borderColor: Color {
        if isSelected            { return Color.yellow }
        if let p = cell.producer { return p.level.tintColor.opacity(0.6) }
        if let item = cell.item  { return (item.def?.color ?? .gray).opacity(0.5) }
        return Color.gray.opacity(0.2)
    }
}

// ============================================================
// MARK: - MERGE SPARKLE BURST
// ============================================================

/// One gold, four-pointed spark from a merge's Tier A burst
/// (`Spec_BoardAnimation_Draft.md` §3). Its direction is fixed at spawn so
/// `MergeSparkleView` can animate purely from `Bool` state rather than a
/// per-frame timer.
private struct MergeSparkle: Identifiable {
    let id = UUID()
    /// Radians, biased to the upper hemisphere so every spark drifts
    /// outward *and up*, never down, per the reference.
    let angle = Double.random(in: -Double.pi...0)
    let travel = CGFloat.random(in: 0.5...0.9)
}

/// Renders and self-animates one `MergeSparkle`: pops in at the merge point,
/// drifts outward along its fixed angle while shrinking and fading. Driven
/// by `withAnimation` on plain `@State`, not `TimelineView` — see
/// `Spec_BoardAnimation_Draft.md` §6 on why a per-frame timer is off the
/// table for board-cell content.
private struct MergeSparkleView: View {
    let sparkle: MergeSparkle
    let cellSize: CGFloat
    @State private var drifted = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: cellSize * 0.16, weight: .bold))
            .foregroundColor(Color(red: 1, green: 0.82, blue: 0.15))
            .opacity(drifted ? 0 : 1)
            .scaleEffect(drifted ? 0.35 : 1.0)
            .offset(
                x: drifted ? cos(sparkle.angle) * cellSize * sparkle.travel : 0,
                y: drifted ? sin(sparkle.angle) * cellSize * sparkle.travel : 0
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { drifted = true }
            }
    }
}

// ============================================================
// MARK: - PRODUCER TILE CONTENT
// ============================================================

/// The visual content of a producer tile on the board.
///
/// Animal producers use a kibble-based system (no cooldown/charges) — always show "Tap!".
/// Supply producers keep their charge/cooldown display.
struct ProducerTileContent: View {
    let producer: ProducerTile
    var cellSize: CGFloat = 62
    /// True when the player can currently afford to tap this family spawner —
    /// drives the shimmer in `familySpawnerContent` (`Spec_BoardAnimation_Draft.md`
    /// §5). Read only on that path; supply/animal producers already carry
    /// their own affordance signal (cooldown ring, charge pips, pulse) and
    /// adding a second one there would be redundant noise.
    var isAffordable: Bool = false

    // Icon occupies ~45% of the cell; labels use ~13% each.
    private var iconPts: CGFloat  { max(14, cellSize * 0.45) }
    private var labelPts: CGFloat { max(5,  cellSize * 0.13) }
    private var dotSize:  CGFloat { max(3,  cellSize * 0.08) }
    private var pad:      CGFloat { max(2,  cellSize * 0.05) }

    var body: some View {
        // .familySpawner must be checked first: its own targetCategory is
        // .animal (it produces animals), so checking that generic condition
        // first would always route it into animalProducerContent instead —
        // silently discarding the species-specific symbol/name/art below and
        // making familySpawnerContent dead code for every real spawner tile.
        if producer.level == .familySpawner {
            familySpawnerContent
        } else if producer.level.targetCategory == .animal {
            animalProducerContent
        } else {
            supplyProducerContent
        }
    }

    // MARK: Animal producer — always ready, kibble-based

    private var animalProducerContent: some View {
        VStack(spacing: 1) {
            Image(systemName: producer.level.sfSymbol)
                .font(.system(size: iconPts))
                .foregroundColor(producer.level.tintColor)
                .symbolEffect(.pulse, options: .repeating, isActive: true)

            Text(producer.level.displayName)
                .font(.system(size: labelPts, weight: .bold))
                .foregroundColor(producer.level.tintColor)
                .lineLimit(1).minimumScaleFactor(0.5)

            Text("Tap!")
                .font(.system(size: labelPts, weight: .heavy))
                .foregroundColor(.green)
        }
        .padding(pad)
    }

    // MARK: Family spawner — species-specific, kibble-based (no cooldown or charge pips)

    /// Deliberately not wrapped in a `TimelineView` the way `supplyProducerContent`
    /// is: `speedBurstActive` is derived live from `speedBurstEndsAt`, so the
    /// glow below is never wrong when this cell renders, but nothing forces a
    /// re-render the instant a burst naturally expires — it can linger until
    /// the next unrelated board change (any tap/merge/purchase). Family
    /// spawners are the most common producer on the board, so giving every
    /// one of them a standing per-second timer to fix a rare, few-second
    /// cosmetic lag on a decorative glow would reintroduce a smaller version
    /// of the exact per-second cost this change removes. See `ProducerTile.
    /// readyAt`'s doc comment for the cooldown case this multi-cell cost
    /// actually matters for.
    private var familySpawnerContent: some View {
        let sp     = producer.species
        let art    = sp?.spawnerArtImage
        let symbol = sp?.spawnerSFSymbol ?? producer.level.sfSymbol
        let label  = sp.map { $0.spawnerName } ?? producer.level.displayName
        let tint   = sp?.tintColor ?? producer.level.tintColor
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 1) {
                Group {
                    if let art {
                        // Real art already identifies the family at a glance, so
                        // it fills the tile instead of sharing space with a name
                        // label — same treatment as animal board-square art. 0.78
                        // is sized against the board's smallest computed cell so
                        // it never breaches the tile at any board size.
                        art.resizable().scaledToFit()
                            .frame(width: cellSize * 0.78, height: cellSize * 0.78)
                    } else {
                        Image(systemName: symbol)
                            .font(.system(size: iconPts))
                            .symbolEffect(.pulse, options: .repeating, isActive: true)
                    }
                }
                    .foregroundColor(tint)
                    // Golden glow ring when speed burst is active
                    .shadow(color: producer.speedBurstActive ? Color.yellow.opacity(0.9) : .clear,
                            radius: producer.speedBurstActive ? 6 : 0)

                if art == nil {
                    Text(label)
                        .font(.system(size: labelPts, weight: .bold))
                        .foregroundColor(tint)
                        .lineLimit(1).minimumScaleFactor(0.5)

                    Text("Tap!")
                        .font(.system(size: labelPts, weight: .heavy))
                        .foregroundColor(.green)
                }
            }
            .padding(pad)

            // Buff badges — stacked in the top-trailing corner
            VStack(spacing: 2) {
                if producer.speedBurstActive {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(Color.yellow))
                        .offset(x: 3, y: -3)
                }
                if producer.nextDropGuaranteedHighTier {
                    Image(systemName: "star.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(Color.purple))
                        .offset(x: 3, y: producer.speedBurstActive ? 2 : -3)
                }
                // Scout (Avians .bird): preview of this spawner's next drop, rolled and
                // cached the moment it last spawned. Only the sub-object case is worth a
                // badge — an animal coming next is the default, unremarkable outcome.
                if producer.scoutPreviewIsSubObject == true {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(3)
                        .background(Circle().fill(Color.teal))
                        .offset(x: 3, y: (producer.speedBurstActive ? 2 : -3)
                                          + (producer.nextDropGuaranteedHighTier ? 5 : 0))
                }
            }
        }
        .overlay {
            if isAffordable {
                SpawnerShimmerView(tint: tint, size: cellSize)
            }
        }
    }

    // MARK: Supply producer — charge/cooldown display

    /// `producer.isReady`/`.cooldownFraction`/`.cooldownRemaining` are derived
    /// live from `producer.readyAt` (a fixed timestamp), not ticked by hand —
    /// see `ProducerTile.readyAt`'s doc comment. That means this cell's own
    /// `producer` value never goes stale, but it also means nothing external
    /// re-renders this cell once a second anymore to reveal the passage of
    /// time. `TimelineView` supplies that locally, in this one cell only,
    /// instead of the old approach of mutating the whole board array every
    /// second to force every cell to redraw.
    private var supplyProducerContent: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(spacing: 1) {
                ZStack {
                    if !producer.isReady {
                        Circle()
                            .trim(from: 0, to: 1 - producer.cooldownFraction)
                            .stroke(producer.level.tintColor.opacity(0.35), lineWidth: max(2, cellSize * 0.06))
                            .rotationEffect(.degrees(-90))
                    }
                    Image(systemName: producer.isReady ? producer.level.sfSymbol : "clock.fill")
                        .font(.system(size: iconPts))
                        .foregroundColor(producer.level.tintColor)
                        .opacity(producer.isReady ? 1.0 : 0.55)
                        .symbolEffect(.pulse, options: .repeating, isActive: producer.isReady)
                }
                .frame(width: iconPts * 1.1, height: iconPts * 1.1)

                Text(producer.level.displayName)
                    .font(.system(size: labelPts, weight: .bold))
                    .foregroundColor(producer.level.tintColor)
                    .lineLimit(1).minimumScaleFactor(0.5)

                if producer.isReady {
                    Text("Tap!")
                        .font(.system(size: labelPts, weight: .heavy))
                        .foregroundColor(.green)
                } else {
                    Text(cooldownString(producer.cooldownRemaining))
                        .font(.system(size: labelPts))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 1) {
                    ForEach(0..<producer.level.maxCharges, id: \.self) { i in
                        Circle()
                            .fill(i < producer.chargesRemaining
                                  ? chargePipColor(producer.chargesRemaining)
                                  : Color.gray.opacity(0.25))
                            .frame(width: dotSize, height: dotSize)
                    }
                }
            }
            .padding(pad)
        }
    }

    private func cooldownString(_ seconds: Double) -> String {
        let s = Int(seconds)
        return s < 60 ? "\(s)s" : "\(s / 60)m \(s % 60)s"
    }

    private func chargePipColor(_ remaining: Int) -> Color {
        switch remaining {
        case 1:  return .red
        case 2:  return .orange
        default: return producer.level.tintColor
        }
    }
}

// ============================================================
// MARK: - PRODUCER AFFORDANCE SHIMMER
// ============================================================

/// One rising fluff mote in a family spawner's affordance shimmer
/// (`Spec_BoardAnimation_Draft.md` §5) — the pet-themed stand-in for the
/// reference title's white star twinkle. Its geometry is fixed at spawn so
/// `SpawnerPuffView` can animate purely from a `Bool`, the same idiom
/// `MergeSparkle`/`MergeSparkleView` use above.
private struct SpawnerPuff: Identifiable {
    let id = UUID()
    /// Origin within the tile, as a fraction of `size` from centre.
    let originX = CGFloat.random(in: -0.28...0.28)
    let originY = CGFloat.random(in: -0.22...0.22)
    /// Upward drift and slight horizontal wander, in points at `size == 62`
    /// (the cell default); scaled by `size / 62` at render time.
    let drift = CGFloat.random(in: 14...22)
    let wander = CGFloat.random(in: -5...5)
    /// Slow on purpose. At the original 0.5–0.8s a mote completed its whole
    /// rise in about half a second, which the eye reads as a blink rather than
    /// as something drifting — the motion was over before it registered as
    /// motion. A ~3s cycle over a slightly longer travel is what makes it
    /// legible as drift.
    let duration = Double.random(in: 2.6...3.6)
    /// Spread wide enough that three motes never pulse together; at the old
    /// 0–0.6s against a 0.65s cycle they were effectively in phase, so the
    /// tile brightened and dimmed as a unit.
    let delay = Double.random(in: 0...2.4)
}

/// Continuous "you can afford to tap this" shimmer over a family spawner —
/// three soft, rising fluff motes tinted with the family's own colour.
/// Driven entirely by `.repeatForever` animations (`Spec_BoardAnimation_Draft.md`
/// §6): this cell type is deliberately never wrapped in a `TimelineView` or
/// any other per-frame/per-second timer, since family spawners are the most
/// common producer on the board and a standing timer on every one of them
/// would reintroduce exactly the per-second redraw cost `ProducerTile.readyAt`
/// was built to remove (see `familySpawnerContent`'s own doc comment).
private struct SpawnerShimmerView: View {
    let tint: Color
    let size: CGFloat
    @State private var puffs: [SpawnerPuff] = (0..<3).map { _ in SpawnerPuff() }

    var body: some View {
        ZStack {
            ForEach(puffs) { puff in
                SpawnerPuffView(puff: puff, tint: tint, size: size)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Renders and self-animates one `SpawnerPuff`. Positioned with `.offset`
/// from the overlay's own centre, **never `.position(x:,y:)`**: inside a
/// `ZStack` that carries no other sized content of its own, `.position`
/// silently collapses the stack's layout bounds toward zero, so the puff
/// would render somewhere other than the tile it's meant to shimmer on.
/// `.offset` has no layout participation, so it can't do that. (Documented
/// here because an earlier on-device attempt at this same shimmer hit
/// exactly this bug — see `Spec_BoardAnimation_Draft.md` §5a.)
///
/// Colour is a plain white core plus a tinted `.shadow` glow, not a tinted
/// fill: that earlier attempt also found a white-to-tint gradient at low
/// opacity — the fur/fluff look this asks for — blends invisibly into real
/// board art (a doghouse's own browns and oranges, say). White-plus-glow
/// reads against any tile colour underneath it.
private struct SpawnerPuffView: View {
    let puff: SpawnerPuff
    let tint: Color
    let size: CGFloat
    @State private var risen = false

    var body: some View {
        let scale = size / 62
        Image(systemName: "cloud.fill")
            .font(.system(size: size * 0.16))
            .foregroundColor(.white)
            .shadow(color: tint.opacity(0.95), radius: 3)
            .opacity(risen ? 0 : 0.9)
            .scaleEffect(risen ? 1.15 : 0.7)
            .offset(
                x: size * puff.originX + (risen ? puff.wander * scale : 0),
                y: size * puff.originY - (risen ? puff.drift * scale : 0)
            )
            .onAppear {
                // autoreverses, where this used to hard-cut. With
                // `autoreverses: false` the mote snapped from fully risen and
                // invisible back to its origin at 0.9 opacity between cycles,
                // with no interpolation across that boundary — an instant
                // bright pop every cycle. That discontinuity, not the speed
                // alone, is what made the effect flash. Reversing means the
                // mote settles back down as gently as it rose and there is no
                // seam anywhere in the loop.
                withAnimation(
                    .easeInOut(duration: puff.duration)
                        .repeatForever(autoreverses: true)
                        .delay(puff.delay)
                ) {
                    risen = true
                }
            }
    }
}

// ============================================================
// MARK: - INVENTORY SLOT VIEW
// ============================================================

struct InventorySlotView: View {
    let item: BoardItem?
    let isSelected: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10).fill(slotBackground)
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(borderColor, lineWidth: isSelected ? 2.5 : 1))
                .shadow(color: .black.opacity(0.06), radius: 2)
            if let item, let def = item.def {
                let isAnimal = item.chain?.category == .animal
                let art = item.artImage
                VStack(spacing: 1) {
                    ZStack(alignment: .topTrailing) {
                        if let art {
                            art.resizable().scaledToFit().frame(width: 34, height: 34)
                        } else {
                            Image(systemName: def.symbol)
                                .font(.system(size: 20))
                                .foregroundColor(def.tint ?? def.color)
                        }
                        if let badge = def.badge {
                            Image(systemName: badge)
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.10))
                                .offset(x: 3, y: -3)
                        }
                    }
                    Text(isAnimal ? (item.chain?.displayName ?? "") : def.shortLabel)
                        .font(.system(size: 6, weight: .bold)).foregroundColor(def.color)
                        .lineLimit(1).minimumScaleFactor(0.5)
                    Text(isAnimal ? def.shortLabel : (item.chain?.displayName ?? ""))
                        .font(.system(size: 6)).foregroundColor(.secondary)
                        .lineLimit(1).minimumScaleFactor(0.5)
                }
                .padding(2).grayscale(item.tier == 0 ? 0.6 : 0.0)
            } else {
                Image(systemName: "tray").font(.system(size: 13))
                    .foregroundColor(Color(red: 0.6, green: 0.45, blue: 0.3).opacity(0.35))
            }
        }
    }

    private var slotBackground: Color {
        if isSelected  { return Color.purple.opacity(0.2) }
        if item != nil { return Color(red: 0.93, green: 0.86, blue: 0.72) }
        return Color(red: 0.88, green: 0.80, blue: 0.65).opacity(0.4)
    }
    private var borderColor: Color {
        if isSelected  { return .purple }
        if item != nil { return Color(red: 0.65, green: 0.48, blue: 0.3).opacity(0.5) }
        return Color(red: 0.65, green: 0.48, blue: 0.3).opacity(0.2)
    }
}

// ============================================================
// MARK: - TOAST VIEW
// ============================================================

struct ToastView: View {
    let toast: Toast
    var body: some View {
        VStack {
            Spacer()
            Text(toast.message)
                .font(.system(size: 14, weight: .semibold)).foregroundColor(.white)
                .padding(.horizontal, 24).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 25).fill(toast.color)
                    .shadow(color: .black.opacity(0.25), radius: 8))
                .padding(.bottom, 80)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}
