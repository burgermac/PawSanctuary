//
//  InventoryScreen.swift
//  PawSanctuary
//

import SwiftUI

struct InventoryScreenView: View {
    var viewModel: MergeBoardViewModel
    let slotSize: CGFloat = 55
    @State private var selectedTab: Int = 0

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ──────────────────────────────────────────
            HStack {
                Label("Storage", systemImage: "basket.fill")
                    .font(.title2.bold())
                    .foregroundColor(Color(red: 0.45, green: 0.3, blue: 0.15))
                Spacer()
                actionButton
            }
            .padding(.horizontal).padding(.top, 8).padding(.bottom, 4)

            // ── Tab picker ───────────────────────────────────────
            Picker("Storage Tab", selection: $selectedTab) {
                Text("Animals").tag(0)
                Text("Producers").tag(1)
                Text("Materials").tag(2)
                Text("Supplies").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal).padding(.bottom, 8)

            // ── Tab content ──────────────────────────────────────
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case 0: animalsTab
                    case 1: producersTab
                    case 2: materialsTab
                    default: suppliesTab
                    }
                    Spacer(minLength: 20)
                }
            }
        }
    }

    // MARK: Action button (context-sensitive per tab)

    @ViewBuilder
    private var actionButton: some View {
        switch selectedTab {
        case 0:
            if viewModel.selectedInventorySlot != nil {
                placeButton(label: "Place on Board") { viewModel.placeSelectedInventoryItemOnBoard() }
            }
        case 1:
            if viewModel.selectedProducerLevel != nil {
                placeButton(label: "Return to Board") { viewModel.placeDesignatedProducerOnBoard() }
            } else if viewModel.selectedOverflowProducerSlot != nil {
                placeButton(label: "Return to Board") { viewModel.placeOverflowProducerOnBoard() }
            }
        case 3:
            if viewModel.selectedPowerUpSlot != nil {
                placeButton(label: "Apply to Spawner",
                            color: Color(red: 0.50, green: 0.22, blue: 0.72)) {}
            }
        default:
            EmptyView()
        }
    }

    private func placeButton(label: String,
                              color: Color = Color(red: 0.3, green: 0.6, blue: 0.4),
                              action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "pawprint.fill")
                Text(label).fontWeight(.semibold)
            }
            .font(.subheadline).foregroundColor(.white)
            .padding(.horizontal, 12).padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12).fill(color))
        }
    }

    // MARK: Animals tab

    private var animalsTab: some View {
        VStack(spacing: 12) {
            // Overflow producers — shown only when producers are parked here temporarily
            let overflowProducers = viewModel.overflowProducerStorage.compactMap { $0 }
            if !overflowProducers.isEmpty {
                overflowProducerSection
            }

            Text("Tap to select, tap another slot to swap.")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            inventorySection(title: "Row 1 — Free", slots: 0..<6, isLocked: false)
            inventorySection(title: "Row 2", slots: 6..<12,
                             isLocked: !viewModel.inventoryRow1Unlocked,
                             unlockCost: inventoryRow1Cost,
                             canAfford: viewModel.dogTags >= inventoryRow1Cost,
                             onUnlock: { viewModel.unlockInventoryRow1() })
            inventorySection(title: "Row 3", slots: 12..<18,
                             isLocked: !viewModel.inventoryRow2Unlocked,
                             requiresPrevious: !viewModel.inventoryRow1Unlocked,
                             unlockCost: inventoryRow2Cost,
                             canAfford: viewModel.dogTags >= inventoryRow2Cost,
                             onUnlock: { viewModel.unlockInventoryRow2() })
        }
    }

    private var overflowProducerSection: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Temporary Producer Storage", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.bold())
                    .foregroundColor(Color(red: 0.75, green: 0.45, blue: 0.10))
                Spacer()
            }
            .padding(.horizontal)
            Text("Advance to the required level to move these to the Producer Library.")
                .font(.system(size: 10)).foregroundColor(.secondary)
                .multilineTextAlignment(.leading).padding(.horizontal)

            HStack(spacing: 4) {
                ForEach(0..<viewModel.producerOverflowCapacity, id: \.self) { slot in
                    ProducerStorageSlotView(
                        producer: viewModel.overflowProducerStorage[slot],
                        isSelected: viewModel.selectedOverflowProducerSlot == slot,
                        isLocked: false,
                        unlockLevel: nil
                    )
                    .frame(width: slotSize, height: slotSize)
                    .onTapGesture { viewModel.overflowSlotTapped(slot) }
                }
            }
            .padding(.horizontal)

            if viewModel.selectedOverflowProducerSlot != nil {
                Button(action: { viewModel.placeOverflowProducerOnBoard() }) {
                    Text("Return to Board")
                        .font(.subheadline.bold()).foregroundColor(.white)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 10)
                            .fill(Color(red: 0.30, green: 0.45, blue: 0.65)))
                }
            }
        }
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(red: 0.99, green: 0.93, blue: 0.82).opacity(0.9))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color(red: 0.75, green: 0.45, blue: 0.10).opacity(0.4), lineWidth: 1))
            .shadow(color: .black.opacity(0.05), radius: 4))
        .padding(.horizontal)
    }

    @ViewBuilder
    private func inventorySection(title: String, slots: Range<Int>, isLocked: Bool,
                                  requiresPrevious: Bool = false, unlockCost: Int = 0,
                                  canAfford: Bool = true, onUnlock: (() -> Void)? = nil) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text(title).font(.subheadline.bold())
                    .foregroundColor(isLocked ? .secondary : Color(red: 0.45, green: 0.3, blue: 0.15))
                if !isLocked { Text("Unlocked").font(.caption).foregroundColor(.green) }
                Spacer()
            }
            .padding(.horizontal)

            if isLocked {
                ZStack {
                    RoundedRectangle(cornerRadius: 16).fill(Color.gray.opacity(0.1)).frame(height: 90)
                    if requiresPrevious {
                        Text("Unlock Row 2 first").font(.subheadline).foregroundColor(.secondary)
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "lock.fill").font(.system(size: 20)).foregroundColor(.gray)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("6 more storage slots").font(.subheadline.bold())
                                Text("Unlock for \(unlockCost) Dog Tags").font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            Button(action: { onUnlock?() }) {
                                Text(canAfford ? "Unlock" : "Need \(unlockCost)")
                                    .font(.subheadline.bold())
                                    .foregroundColor(canAfford ? .white : .secondary)
                                    .padding(.horizontal, 14).padding(.vertical, 8)
                                    .background(RoundedRectangle(cornerRadius: 10)
                                        .fill(canAfford ? Color(red: 0.3, green: 0.5, blue: 0.7)
                                                        : Color.gray.opacity(0.3)))
                            }
                            .disabled(!canAfford)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
            } else {
                HStack(spacing: 4) {
                    ForEach(Array(slots), id: \.self) { slot in
                        InventorySlotView(item: viewModel.inventory[slot],
                                          isSelected: viewModel.selectedInventorySlot == slot)
                            .frame(width: slotSize, height: slotSize)
                            .onTapGesture { viewModel.inventorySlotTapped(slot) }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(isLocked ? Color.gray.opacity(0.05)
                           : Color(red: 0.96, green: 0.91, blue: 0.80).opacity(0.7))
            .shadow(color: .black.opacity(0.05), radius: 4))
        .padding(.horizontal)
    }

    // MARK: Producers tab

    private var producersTab: some View {
        VStack(spacing: 10) {
            Text("One slot per producer type, unlocked as you level up. Tap an occupied slot to select it, then return it to the board.")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            ForEach(ProducerLevel.allCases.filter(\.isShopProducer), id: \.rawValue) { level in
                designatedProducerRow(level: level)
            }
        }
    }

    private func designatedProducerRow(level: ProducerLevel) -> some View {
        let isLocked   = viewModel.playerLevel < level.storageUnlockLevel
        let occupant   = viewModel.producerStorage[level.rawValue]
        let isSelected = viewModel.selectedProducerLevel == level

        return HStack(spacing: 12) {
            // Producer icon + name
            ZStack {
                Circle()
                    .fill(isLocked ? Color.gray.opacity(0.12) : level.tintColor.opacity(0.15))
                    .frame(width: 44, height: 44)
                if isLocked {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18)).foregroundColor(.gray.opacity(0.5))
                } else {
                    Image(systemName: level.sfSymbol)
                        .font(.system(size: 20)).foregroundColor(level.tintColor)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(level.displayName)
                    .font(.subheadline.bold())
                    .foregroundColor(isLocked ? .secondary : .primary)
                if isLocked {
                    Text("Unlocks at Level \(level.storageUnlockLevel)")
                        .font(.caption).foregroundColor(.secondary)
                } else if let p = occupant {
                    Text("\(p.chargesRemaining) charge\(p.chargesRemaining == 1 ? "" : "s") remaining")
                        .font(.caption).foregroundColor(level.tintColor)
                } else {
                    Text("Empty").font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            // Status badge
            if !isLocked {
                if occupant != nil {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(isSelected ? .green : level.tintColor.opacity(0.5))
                } else {
                    Image(systemName: "circle.dashed")
                        .font(.system(size: 22)).foregroundColor(.gray.opacity(0.3))
                }
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(isLocked   ? Color.gray.opacity(0.06) :
                  isSelected ? level.tintColor.opacity(0.18) :
                               Color(red: 0.96, green: 0.93, blue: 0.98).opacity(0.8))
            .shadow(color: .black.opacity(isLocked ? 0 : 0.05), radius: 3))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(isSelected ? level.tintColor : Color.clear, lineWidth: 2))
        .padding(.horizontal)
        .onTapGesture { viewModel.designatedSlotTapped(level: level) }
    }

    // MARK: Materials tab

    private var materialsTab: some View {
        VStack(spacing: 16) {
            Text("Tap a toolbox on the board to collect its materials. Merging is handled automatically — completed materials appear here ready to spend on map areas.")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            // Completed materials — one card per chain
            HStack(spacing: 10) {
                materialCard(chainID: ContentRegistry.woodChainID,
                             icon: "house.fill",
                             label: "Hardwood\nKit",
                             cardColor: Color(red: 0.62, green: 0.48, blue: 0.28))
                materialCard(chainID: ContentRegistry.metalChainID,
                             icon: "gearshape.fill",
                             label: "Steel\nGirder",
                             cardColor: Color(red: 0.34, green: 0.40, blue: 0.54))
                materialCard(chainID: ContentRegistry.cementChainID,
                             icon: "hammer.fill",
                             label: "Foundation\nKit",
                             cardColor: Color(red: 0.44, green: 0.42, blue: 0.38))
            }
            .padding(.horizontal)

            // In-progress components (sub-tier accumulation)
            let inProgress = inProgressRows()
            if !inProgress.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("In Progress")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                    ForEach(inProgress, id: \.label) { row in
                        HStack {
                            Image(systemName: row.icon)
                                .font(.system(size: 12))
                                .foregroundColor(row.color)
                                .frame(width: 20)
                            Text(row.label)
                                .font(.system(size: 11))
                                .foregroundColor(Color(red: 0.25, green: 0.22, blue: 0.18))
                            Spacer()
                            Text("×\(row.count)")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(row.color)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 12)
                    .fill(Color(red: 0.94, green: 0.90, blue: 0.80).opacity(0.7)))
                .padding(.horizontal)
            }
        }
    }

    private func materialCard(chainID: ChainID, icon: String, label: String, cardColor: Color) -> some View {
        let count = viewModel.completedMaterialCount(chainID: chainID)
        return VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(cardColor)
                }
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(cardColor))
                        .offset(x: 6, y: -4)
                }
            }
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(cardColor.opacity(0.85))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(count > 0
                  ? cardColor.opacity(0.10)
                  : Color(red: 0.92, green: 0.90, blue: 0.86).opacity(0.6)))
        .overlay(RoundedRectangle(cornerRadius: 14)
            .strokeBorder(count > 0 ? cardColor.opacity(0.35) : Color.clear, lineWidth: 1.5))
    }

    // MARK: Supplies tab

    private var suppliesTab: some View {
        VStack(spacing: 16) {
            Text("Consumables earned by merging sub-objects on the board. Select one here, then close this screen and tap a Family Spawner to apply it.")
                .font(.system(size: 11)).foregroundColor(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            // 6-slot power-up grid (2 rows × 3)
            VStack(spacing: 8) {
                ForEach(0..<2, id: \.self) { row in
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { col in
                            let slot = row * 3 + col
                            powerUpSlotView(slot: slot)
                                .frame(maxWidth: .infinity)
                                .onTapGesture { viewModel.powerUpSlotTapped(slot) }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(Color(red: 0.94, green: 0.88, blue: 0.98).opacity(0.7)))
            .padding(.horizontal)

            if viewModel.selectedPowerUpSlot != nil {
                Text("Consumable selected ✓  —  close this screen and tap a Family Spawner.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(red: 0.50, green: 0.22, blue: 0.72))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private func powerUpSlotView(slot: Int) -> some View {
        let item = viewModel.inventoryStore.powerUpInventory[slot]
        let isSelected = viewModel.selectedPowerUpSlot == slot
        let (icon, label, tint) = powerUpAppearance(for: item)
        VStack(spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item != nil
                          ? tint.opacity(isSelected ? 0.22 : 0.10)
                          : Color(red: 0.90, green: 0.88, blue: 0.94).opacity(0.5))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(isSelected
                                      ? tint
                                      : (item != nil ? tint.opacity(0.35) : Color.clear),
                                      lineWidth: isSelected ? 2 : 1))
                    .frame(height: 62)
                if let _ = item {
                    VStack(spacing: 3) {
                        Image(systemName: icon)
                            .font(.system(size: 22))
                            .foregroundColor(tint)
                        Text(label)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(tint)
                            .multilineTextAlignment(.center)
                    }
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary.opacity(0.4))
                }
            }
        }
    }

    private func powerUpAppearance(for item: BoardItem?) -> (icon: String, label: String, tint: Color) {
        guard let item else { return ("", "", .clear) }
        switch item.tier {
        case 0: return ("bolt.circle.fill",          "Speed Burst",       Color(red: 0.90, green: 0.72, blue: 0.05))
        case 1: return ("map.fill",                  "Map Supplies",      Color(red: 0.20, green: 0.65, blue: 0.35))
        case 2: return ("arrow.clockwise.circle.fill","Spawner Refill",   Color(red: 0.25, green: 0.50, blue: 0.88))
        default: return ("star.circle.fill",         "High-Tier Drop",   Color(red: 0.60, green: 0.20, blue: 0.88))
        }
    }

    private struct InProgressRow { let label: String; let icon: String; let color: Color; let count: Int }
    private func inProgressRows() -> [InProgressRow] {
        // Chain definitions: (chainID, tier-name array, icon array, color array)
        typealias ChainInfo = (id: ChainID, names: [String], icons: [String], colors: [Color])
        let chains: [ChainInfo] = [
            (ContentRegistry.woodChainID,
             ["Log","Plank","Lumber","Timber","Framework"],
             ["leaf.fill","rectangle.fill","square.stack.fill","archivebox.fill","building.2.fill"],
             Array(repeating: Color(red: 0.58, green: 0.44, blue: 0.20), count: 5)),
            (ContentRegistry.metalChainID,
             ["Nail","Bolt","Rod","Pipe","I-Beam"],
             ["oval.fill","bolt.fill","minus.square.fill","capsule.fill","building.columns.fill"],
             Array(repeating: Color(red: 0.40, green: 0.45, blue: 0.58), count: 5)),
            (ContentRegistry.cementChainID,
             ["Pebble","Gravel","Stone","Mortar","Concrete Block"],
             ["circle.fill","seal.fill","hexagon.fill","drop.fill","square.fill"],
             Array(repeating: Color(red: 0.50, green: 0.48, blue: 0.44), count: 5))
        ]
        var rows: [InProgressRow] = []
        for chain in chains {
            let counts = viewModel.materialTierCounts(chainID: chain.id)
            for tier in 0..<5 {
                let n = tier < counts.count ? counts[tier] : 0
                if n > 0 {
                    rows.append(InProgressRow(label: chain.names[tier],
                                              icon: chain.icons[tier],
                                              color: chain.colors[tier],
                                              count: n))
                }
            }
        }
        return rows
    }
}

// MARK: - Producer Storage Slot View

struct ProducerStorageSlotView: View {
    let producer: ProducerTile?
    let isSelected: Bool
    let isLocked: Bool
    let unlockLevel: Int?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(isLocked ? Color.gray.opacity(0.08)
                      : isSelected ? Color.purple.opacity(0.25) : Color.gray.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isSelected ? Color.purple : Color.gray.opacity(0.25),
                                  lineWidth: isSelected ? 2 : 1))

            if isLocked {
                VStack(spacing: 2) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 14)).foregroundColor(.gray.opacity(0.4))
                    if let lvl = unlockLevel {
                        Text("Lv.\(lvl)")
                            .font(.system(size: 7)).foregroundColor(.gray.opacity(0.4))
                    }
                }
            } else if let p = producer {
                VStack(spacing: 2) {
                    Image(systemName: p.level.sfSymbol)
                        .font(.system(size: 18))
                        .foregroundColor(p.level.tintColor)
                    Text(p.level.displayName.components(separatedBy: " ").first ?? "")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.secondary).lineLimit(1)
                    Text("\(p.chargesRemaining)×")
                        .font(.system(size: 7)).foregroundColor(.secondary)
                }
            } else {
                Image(systemName: "plus")
                    .font(.system(size: 14)).foregroundColor(Color.gray.opacity(0.3))
            }
        }
    }
}
