//
//  CellView.swift
//  PawSanctuary
//

import SwiftUI

// ============================================================
// MARK: - MERGE BURST (Tier A, Spec_BoardAnimation_Draft.md §3)
// ============================================================

/// A one-shot celebration played over a merge result: a quick white bloom,
/// already fading by the time the item's own overshoot spring peaks, plus a
/// handful of gold sparkles that drift outward-and-up and keep going after
/// the bloom and the scale animation have both finished. Mounted and
/// unmounted by `CellView.mergeBurstActive` — this view has no state of its
/// own to reset between merges, so re-mounting is what makes each burst fresh.
///
/// Offsets are struct-literal per particle rather than `Int.random` at
/// render time: `@State`'s initial value only evaluates once per mount, which
/// is what we want (a stable target for the animation to ease toward), but
/// spelling that as a literal here makes the "4 particles, mild spread" shape
/// obvious at a glance instead of hidden behind a randomizer.
private struct MergeBurstView: View {
    @State private var expanded = false

    private let particles: [(dx: CGFloat, dy: CGFloat, delay: Double)] = [
        (dx: -14, dy: -20, delay: 0.00),
        (dx:  15, dy: -16, delay: 0.03),
        (dx:  -6, dy: -24, delay: 0.06),
        (dx:  10, dy: -22, delay: 0.02),
    ]

    var body: some View {
        ZStack {
            // Bloom — the reference's "already glowing white-hot" instant.
            // Short and quick so it reads as a flash, not a glow that lingers.
            Circle()
                .fill(Color.white)
                .frame(width: 26, height: 26)
                .blur(radius: 4)
                .opacity(expanded ? 0 : 0.8)
                .scaleEffect(expanded ? 1.7 : 0.4)
                .animation(.easeOut(duration: 0.22), value: expanded)

            ForEach(particles.indices, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Color(red: 1.0, green: 0.82, blue: 0.20))
                    .opacity(expanded ? 0 : 1)
                    .scaleEffect(expanded ? 0.35 : 1.0)
                    .offset(x: expanded ? particles[i].dx : 0,
                            y: expanded ? particles[i].dy : 0)
                    .animation(.easeOut(duration: 0.5).delay(particles[i].delay), value: expanded)
            }
        }
        .allowsHitTesting(false)
        .onAppear { expanded = true }
    }
}

// ============================================================
// MARK: - PRODUCER AFFORDANCE SHIMMER (Spec_BoardAnimation_Draft.md §5)
// ============================================================

/// Continuous idle shimmer on a family spawner's tile, shown only while the
/// player can actually afford to tap it — see `MergeBoardViewModel.
/// canAffordSpawnerTap`. Three soft, pale puffs drift and fade on their own
/// staggered cycles so the tile reads as "tappable right now" at a glance,
/// without the player ever needing to tap a spawner just to find out it's
/// unaffordable.
///
/// Deliberately one universal tuft shape tinted per species, not bespoke art
/// per family: at the ~5–9pt render size these particles occupy, a fur tuft,
/// a feather and a leaf are indistinguishable blobs, so fifteen bespoke
/// shapes would be invisible effort for real build cost. Colour still carries
/// the family's identity, but as a `.shadow` glow around a solid white core
/// rather than a tinted fill — an on-screen check against real (detailed,
/// often brown/orange) producer art showed a tint-gradient fill blending
/// straight into tiles of a similar colour, which is exactly the
/// "reads as a clump" failure mode flagged as a risk before any code was
/// written. A bright core plus a coloured halo stays legible against any
/// tile; the SF Symbol "cloud.fill" already reads as a soft puff shape
/// without any custom `Shape`.
///
/// Built entirely on `.animation(...).repeatForever` — the same idiom this
/// file already uses for the leap-mode selection ring (`isLeapSource`) —
/// rather than `TimelineView`. `CellView.familySpawnerContent`'s own doc
/// comment records why a per-second timer must never land on this specific
/// cell type: family spawners are the most common producer on the board, and
/// an earlier whole-board-redraw-per-second approach was removed for exactly
/// this cost. `.animation(...repeatForever...)` hands the loop to Core
/// Animation once and never re-evaluates this view's body to sustain it.
private struct SpawnerShimmerView: View {
    let tint: Color
    let size: CGFloat
    @State private var drift = false

    /// Fixed offsets-from-centre/timings rather than `Int.random` at render
    /// time — see `MergeBurstView`'s doc comment for the same reasoning:
    /// `@State`'s initial value evaluates once per mount, so a literal here
    /// keeps "three puffs, gently offset" legible instead of hidden behind a
    /// randomizer. Durations differ per puff so they drift out of phase with
    /// each other within a few cycles, which is what reads as "continuous"
    /// rather than "blinking on a beat."
    ///
    /// Offsets from centre, not fractional `.position()` coordinates: a
    /// ZStack whose children all use `.position()` has no other content to
    /// size itself against, so its own layout bounds can collapse to near
    /// zero and everything places relative to that collapsed origin instead
    /// of the tile — the puffs render, just not where intended, and can end
    /// up clipped by `CellView`'s own `.clipShape` at the cell edge. `.offset`
    /// has no such dependency: it nudges a view away from wherever the
    /// ZStack's normal centering already placed it, which is the same idiom
    /// `MergeBurstView` above and the rest of this file already rely on.
    private let puffs: [(dx: CGFloat, dy: CGFloat, delay: Double, duration: Double)] = [
        (dx: -0.20, dy:  0.14, delay: 0.00, duration: 1.10),
        (dx:  0.18, dy: -0.18, delay: 0.35, duration: 1.35),
        (dx: -0.02, dy:  0.08, delay: 0.65, duration: 1.00),
    ]

    var body: some View {
        ZStack {
            ForEach(puffs.indices, id: \.self) { i in
                let puff = puffs[i]
                Image(systemName: "cloud.fill")
                    .font(.system(size: max(7, size * 0.22)))
                    .foregroundColor(.white)
                    .shadow(color: tint.opacity(0.95), radius: 3)
                    .opacity(drift ? 0.9 : 0.0)
                    .scaleEffect(drift ? 1.0 : 0.4)
                    .offset(x: size * puff.dx,
                            y: size * puff.dy + (drift ? -size * 0.16 : 0))
                    .animation(
                        .easeInOut(duration: puff.duration)
                            .repeatForever(autoreverses: true)
                            .delay(puff.delay),
                        value: drift
                    )
            }
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .onAppear { drift = true }
    }
}

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
    /// Whether the player can afford to tap this cell's family spawner right
    /// now, at its true cost (Bask etc. included) — see
    /// `MergeBoardViewModel.canAffordSpawnerTap`. Ignored for every other
    /// cell content; computed by the caller rather than here so `CellView`
    /// stays a plain-value view with no `MergeBoardViewModel` dependency.
    var isFamilySpawnerAffordable: Bool = false

    /// Drives `MergeBurstView`'s lifetime. Deliberately its own state rather
    /// than reusing `isAnimating` directly — see `triggerMergeBurst`'s doc
    /// comment for why the two need different clocks.
    @State private var mergeBurstActive = false

    var body: some View {
        ZStack {
            // ── Background & borders ─────────────────────────────────
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

            // ── Content ──────────────────────────────────────────────
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
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onChange(of: isAnimating) { _, newValue in
            if newValue { triggerMergeBurst() }
        }
    }

    /// Fires the burst overlay on its own ~550ms clock, independent of
    /// `isAnimating`'s 600ms scale window that `MergeBoardViewModel` clears.
    ///
    /// Reference footage (Spec_BoardAnimation_Draft.md §1) showed the burst's
    /// particles visibly outliving the merged item's own settle by roughly
    /// half a second — sharing one flag would force them to cut off exactly
    /// when the scale spring finishes, which is the opposite of that effect.
    /// The two windows happen to be close in length here, but that's
    /// coincidental to this tuning pass, not a promise the two must match.
    private func triggerMergeBurst() {
        mergeBurstActive = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            mergeBurstActive = false
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
                // Phases 3–5 of the reference merge sequence (Tier A, additive —
                // see Spec_BoardAnimation_Draft.md §3): a bloom and a sparkle
                // burst layered over the existing overshoot spring above.
                .overlay { if mergeBurstActive { MergeBurstView() } }

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

    private var cellBackground: Color {
        if !cell.isUnlocked    { return Color.gray.opacity(0.12) }
        if isSelected           { return Color.yellow.opacity(0.3) }
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
// MARK: - PRODUCER TILE CONTENT
// ============================================================

/// The visual content of a producer tile on the board.
///
/// Animal producers use a kibble-based system (no cooldown/charges) — always show "Tap!".
/// Supply producers keep their charge/cooldown display.
struct ProducerTileContent: View {
    let producer: ProducerTile
    var cellSize: CGFloat = 62
    /// See `CellView.isFamilySpawnerAffordable` — only consulted by
    /// `familySpawnerContent`.
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
                    // Affordance shimmer (§5) — only while this spawner is
                    // actually tappable right now. Sized to roughly the art
                    // bounds regardless of whether real art or the fallback
                    // symbol is showing.
                    .overlay {
                        if isAffordable {
                            SpawnerShimmerView(tint: tint, size: cellSize * 0.72)
                        }
                    }

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
