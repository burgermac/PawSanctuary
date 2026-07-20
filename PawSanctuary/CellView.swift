//
//  CellView.swift
//  PawSanctuary
//

import SwiftUI

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
            if let producer = cell.producer {
                ProducerTileContent(producer: producer, cellSize: cellSize)
                    .opacity(isDragging ? 0.25 : 1.0)
            } else if let item = cell.item {
                itemContent(item)
                    .opacity(isDragging ? 0.25 : 1.0)
                    .grayscale(item.tier == 0 ? 0.6 : 0.0)   // base tier looks faded
            } else if !cell.isUnlocked {
                lockedContent
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 2) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: def?.symbol ?? "questionmark")
                        .font(.system(size: 24))
                        .foregroundColor(item.isTopTier ? .yellow : (def?.tint ?? def?.color ?? .gray))
                    if let badge = def?.badge {
                        Image(systemName: badge)
                            .font(.system(size: 9))
                            .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.10))
                            .offset(x: 4, y: -4)
                    }
                }
                .scaleEffect(isAnimating ? 1.5 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isAnimating)

                Text(isAnimal ? (item.chain?.displayName ?? "") : (def?.shortLabel ?? ""))
                    .font(.system(size: 7, weight: .bold)).foregroundColor(def?.color ?? .gray)
                    .lineLimit(1).minimumScaleFactor(0.5)
                Text(isAnimal ? (def?.shortLabel ?? "") : (item.chain?.displayName ?? ""))
                    .font(.system(size: 7)).foregroundColor(.secondary)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .padding(3)

            // Superpower badge — shown when this family has unlocked its superpower.
            if hasUnlockedSuperpower, let sp = itemSpecies {
                Image(systemName: sp.superpower.sfSymbol)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundColor(.white)
                    .padding(2)
                    .background(Circle().fill(Color.purple.opacity(0.85)))
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var lockedContent: some View {
        VStack(spacing: 3) {
            Image(systemName: "lock.fill").font(.system(size: 16)).foregroundColor(.gray.opacity(0.4))
            Text("Locked").font(.system(size: 7)).foregroundColor(.gray.opacity(0.4))
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

    // Icon occupies ~45% of the cell; labels use ~13% each.
    private var iconPts: CGFloat  { max(14, cellSize * 0.45) }
    private var labelPts: CGFloat { max(5,  cellSize * 0.13) }
    private var dotSize:  CGFloat { max(3,  cellSize * 0.08) }
    private var pad:      CGFloat { max(2,  cellSize * 0.05) }

    var body: some View {
        if producer.level.targetCategory == .animal {
            animalProducerContent
        } else if producer.level == .familySpawner {
            familySpawnerContent
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

    private var familySpawnerContent: some View {
        let sp     = producer.species
        let symbol = sp?.spawnerSFSymbol ?? producer.level.sfSymbol
        let label  = sp.map { $0.spawnerName } ?? producer.level.displayName
        let tint   = sp?.tintColor ?? producer.level.tintColor
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 1) {
                Image(systemName: symbol)
                    .font(.system(size: iconPts))
                    .foregroundColor(tint)
                    .symbolEffect(.pulse, options: .repeating, isActive: true)
                    // Golden glow ring when speed burst is active
                    .shadow(color: producer.speedBurstActive ? Color.yellow.opacity(0.9) : .clear,
                            radius: producer.speedBurstActive ? 6 : 0)

                Text(label)
                    .font(.system(size: labelPts, weight: .bold))
                    .foregroundColor(tint)
                    .lineLimit(1).minimumScaleFactor(0.5)

                Text("Tap!")
                    .font(.system(size: labelPts, weight: .heavy))
                    .foregroundColor(.green)
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
            }
        }
    }

    // MARK: Supply producer — charge/cooldown display

    private var supplyProducerContent: some View {
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
                VStack(spacing: 1) {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: def.symbol)
                            .font(.system(size: 20))
                            .foregroundColor(def.tint ?? def.color)
                        if let badge = def.badge {
                            Image(systemName: badge)
                                .font(.system(size: 8))
                                .foregroundColor(Color(red: 0.95, green: 0.80, blue: 0.10))
                                .offset(x: 3, y: -3)
                        }
                    }
                    let isAnimal = item.chain?.category == .animal
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
