//
//  ShopView.swift
//  PawSanctuary
//

import SwiftUI
import StoreKit

struct ShopView: View {
    var storeManager: StoreManager
    var viewModel: MergeBoardViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(colors: [Color(red: 0.85, green: 0.95, blue: 0.85),
                                        Color(red: 0.95, green: 0.88, blue: 0.75)],
                               startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        (Text(Image(systemName: "pawprint")) + Text(" \(viewModel.kibble)  ")
                         + Text(Image(systemName: "tag.fill")) + Text(" \(viewModel.dogTags)"))
                            .font(.subheadline.bold()).padding().frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))

                        Text("Kibble regenerates 1/min up to \(kibbleRegenCap). Purchases and quest rewards can exceed the cap.")
                            .font(.caption).multilineTextAlignment(.center).foregroundColor(.secondary).padding(.horizontal)

                        // Sound toggle
                        HStack {
                            Label("Sound", systemImage: SoundManager.shared.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.subheadline)
                                .foregroundColor(SoundManager.shared.isMuted ? .secondary : .primary)
                            Spacer()
                            Toggle("", isOn: Binding(
                                get: { !SoundManager.shared.isMuted },
                                set: { SoundManager.shared.isMuted = !$0 }
                            ))
                            .labelsHidden()
                        }
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.7)))

                        // ── Generators (Dog Tag purchases) ──────────────
                        GeneratorShopSection(viewModel: viewModel)

                        Divider().padding(.horizontal)

                        // ── Board items for Dog Tags (recirculation) ──────
                        DogTagStoreSection(viewModel: viewModel)

                        Divider().padding(.horizontal)

                        // ── Dog Tag → Kibble exchange ─────────────────────
                        DogTagKibbleSection(viewModel: viewModel)

                        Divider().padding(.horizontal)

                        // ── Energy Packs (IAP bundles) ───────────────────
                        EnergyPackShopSection(storeManager: storeManager)

                        Divider().padding(.horizontal)

                        // ── Other real-money IAP ─────────────────────────
                        if storeManager.isLoading {
                            ProgressView("Loading shop...").padding()
                        } else if storeManager.products.isEmpty {
                            VStack(spacing: 12) {
                                Label("Shop Preview", systemImage: "cart.fill").font(.headline)
                                ForEach(IAPProduct.allCases, id: \.rawValue) { ShopItemPreviewRow(product: $0) }
                                Text("Pricing set in App Store Connect. Purchases not yet active.")
                                    .font(.caption).foregroundColor(.secondary)
                                    .multilineTextAlignment(.center).padding(.top)
                            }
                        } else {
                            ForEach(storeManager.products, id: \.id) { product in
                                if let iap = IAPProduct(rawValue: product.id) {
                                    ShopItemRow(product: product, iap: iap, storeManager: storeManager)
                                }
                            }
                        }

                        Button("Restore Purchases") { Task { await storeManager.restorePurchases() } }
                            .font(.footnote).foregroundColor(.secondary).padding(.bottom, 20)

                        #if DEBUG
                        Button(role: .destructive) {
                            viewModel.resetToFreshGame()
                            dismiss()
                        } label: {
                            Label("Reset Save (Debug)", systemImage: "trash")
                                .font(.footnote)
                        }
                        .padding(.bottom, 20)
                        #endif
                    }
                    .padding()
                }
            }
            .navigationTitle("Sanctuary Shop")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .navigationBarTrailing) { Button("Done") { dismiss() } } }
            #else
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            #endif
        }
    }
}

// ============================================================
// MARK: - GENERATOR SHOP
// ============================================================

/// In-game Dog Tag purchases for producer tiles.
struct GeneratorShopSection: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill").foregroundColor(.orange)
                Text("Generators")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.25, green: 0.12, blue: 0.04))
                Spacer()
                Text("Paid with Dog Tags")
                    .font(.caption).foregroundColor(.secondary)
            }

            Text("Place a generator on the board and tap it to produce animals. Merge two of the same tier to upgrade!")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(ProducerLevel.allCases.filter { $0.isShopProducer && viewModel.unlockedProducerShopTiers.contains($0) },
                    id: \.rawValue) { level in
                GeneratorShopRow(level: level, viewModel: viewModel)
            }
            let shopLevels = ProducerLevel.allCases.filter(\.isShopProducer)
            if viewModel.unlockedProducerShopTiers.filter(\.isShopProducer).count < shopLevels.count {
                let nextUnlock = shopLevels.first { !viewModel.unlockedProducerShopTiers.contains($0) }
                if let next = nextUnlock {
                    let unlockLevel = next == .shelterPod ? 4 : 7
                    HStack(spacing: 8) {
                        Image(systemName: next.sfSymbol)
                            .font(.system(size: 20)).foregroundColor(.gray.opacity(0.4))
                        Text("\(next.displayName) — unlocks at Level \(unlockLevel)")
                            .font(.caption).foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.gray.opacity(0.06)))
                }
            }
        }
    }
}

struct GeneratorShopRow: View {
    let level: ProducerLevel
    var viewModel: MergeBoardViewModel

    private var canAfford: Bool { viewModel.dogTags >= level.dogTagCost }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: level.sfSymbol)
                .font(.title2)
                .foregroundColor(level.tintColor)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(level.tintColor.opacity(0.12)))

            // Description
            VStack(alignment: .leading, spacing: 3) {
                Text(level.displayName).font(.subheadline.bold())
                HStack(spacing: 6) {
                    Image(systemName: QuestGoal.animalTierSymbol(level.startTier))
                        .font(.system(size: 10))
                        .foregroundColor(QuestGoal.animalTierColor(level.startTier))
                    Text("Produces \(QuestGoal.animalTierLabel(level.startTier))")
                        .font(.caption).foregroundColor(.secondary)
                    Text("·")
                        .font(.caption).foregroundColor(.secondary)
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(Int(level.cooldown))s")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            // Buy button
            Button {
                SoundManager.shared.playButtonTap()
                HapticManager.shared.lightTap()
                viewModel.buyProducer(level)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 11))
                    Text("\(level.dogTagCost)").font(.subheadline.bold())
                }
                .foregroundColor(canAfford ? .white : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(canAfford ? level.tintColor : Color.gray.opacity(0.25)))
            }
            .disabled(!canAfford)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}

// ============================================================
// MARK: - DOG TAG STORE (recirculation, Task 2.3c)
// ============================================================

/// Three board items, rotating daily, stock 1 each. The release valve for a
/// player blocked on one specific item.
struct DogTagStoreSection: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.fill")
                    .foregroundColor(Color(red: 0.25, green: 0.50, blue: 0.88))
                Text("Item Store")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.18, green: 0.36, blue: 0.66))
                Spacer()
                Text("Rotates daily").font(.caption).foregroundColor(.secondary)
            }

            if viewModel.dogTagStore.slots.isEmpty {
                Text("Merge deeper to unlock the item store.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(viewModel.dogTagStore.slots) { slot in
                    DogTagStoreRow(slot: slot, viewModel: viewModel)
                }
                Text("One of each per day. Sold items return tomorrow.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .onAppear { viewModel.refreshDogTagStore() }
    }
}

struct DogTagStoreRow: View {
    let slot: DogTagStoreSlot
    var viewModel: MergeBoardViewModel

    private var def: ChainTier? { ContentRegistry.shared.tier(slot.chainID, slot.tier) }
    private var canAfford: Bool { viewModel.dogTags >= slot.priceDogTags }
    private var isAvailable: Bool { !slot.purchased && canAfford }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: def?.symbol ?? "pawprint.fill")
                .font(.title2)
                .foregroundColor(def?.tint ?? .brown)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill((def?.tint ?? .brown).opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text(def?.name ?? "Item").font(.subheadline.bold())
                Text("Level \(slot.tier + 1)")
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            Button {
                SoundManager.shared.playButtonTap()
                viewModel.purchaseDogTagStoreSlot(slot)
            } label: {
                HStack(spacing: 4) {
                    if slot.purchased {
                        Text("Sold").font(.subheadline.bold())
                    } else {
                        Image(systemName: "tag.fill").font(.system(size: 11))
                        Text("\(slot.priceDogTags)").font(.subheadline.bold())
                    }
                }
                .foregroundColor(isAvailable ? .white : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(isAvailable
                          ? Color(red: 0.25, green: 0.50, blue: 0.88)
                          : Color(red: 0.90, green: 0.90, blue: 0.92)))
            }
            .disabled(!isAvailable)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}

// ============================================================
// MARK: - DOG TAG → KIBBLE EXCHANGE
// ============================================================

struct DogTagKibbleSection: View {
    var viewModel: MergeBoardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
                Text("Exchange")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.15, green: 0.45, blue: 0.3))
                Spacer()
                Text("Tags for Kibble")
                    .font(.caption).foregroundColor(.secondary)
            }

            Text("Spend your Dog Tags for an instant Kibble boost. Kibble can exceed the regen cap this way.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // A single escalating rung, not a volume discount (Task 2.4).
            DogTagKibbleRow(exchange: viewModel.currentTagExchange, viewModel: viewModel)

            Text(viewModel.currentTagExchange.isAtFlatRate
                 ? "Today's discounted exchanges are used up. The price resets tomorrow."
                 : "Each exchange today costs more than the last. Resets tomorrow.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct DogTagKibbleRow: View {
    let exchange: DogTagKibbleExchange
    var viewModel: MergeBoardViewModel

    private var canAfford: Bool { viewModel.dogTags >= exchange.dogTagCost }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "pawprint.fill")
                .font(.title2)
                .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.2, green: 0.6, blue: 0.4).opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Image(systemName: "pawprint").font(.system(size: 11))
                    Text("+\(exchange.kibbleGain) Kibble").font(.subheadline.bold())
                }
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 10)).foregroundColor(.blue)
                    Text("Costs \(exchange.dogTagCost) Dog Tags")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                SoundManager.shared.playButtonTap()
                HapticManager.shared.lightTap()
                viewModel.exchangeTagsForKibble()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 11))
                    Text("\(exchange.dogTagCost)").font(.subheadline.bold())
                }
                .foregroundColor(canAfford ? .white : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(canAfford ? Color(red: 0.2, green: 0.6, blue: 0.4) : Color.gray.opacity(0.25)))
            }
            .disabled(!canAfford)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}

// ============================================================
// MARK: - IAP ROWS
// ============================================================

struct ShopItemPreviewRow: View {
    let product: IAPProduct
    var body: some View {
        HStack {
            Image(systemName: product.icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(product.displayName).font(.subheadline.bold())
                HStack(spacing: 8) {
                    if let k = product.kibbleAmount {
                        (Text(Image(systemName: "pawprint")) + Text(" +\(k)")).font(.caption).foregroundColor(.green)
                    }
                    if let t = product.dogTagAmount {
                        (Text(Image(systemName: "tag.fill")) + Text(" +\(t)")).font(.caption).foregroundColor(.blue)
                    }
                    if product.isSubscription {
                        VStack(alignment: .leading, spacing: 2) {
                            (Text(Image(systemName: "pawprint.fill")) + Text(" +\(passDailyKibble) kibble/day"))
                                .font(.caption).foregroundColor(.green)
                            Text("1.5× kibble rewards  ·  2× ad kibble")
                                .font(.caption).foregroundColor(.purple)
                        }
                    }
                }
            }
            Spacer()
            Text("—").font(.subheadline.bold()).foregroundColor(.secondary)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.2)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}

struct ShopItemRow: View {
    let product: Product
    let iap: IAPProduct
    var storeManager: StoreManager
    var body: some View {
        // Energy packs are shown in the dedicated EnergyPackShopSection — skip here
        if iap.energyPackContents != nil { EmptyView() } else {
        HStack {
            Image(systemName: iap.icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(iap.displayName).font(.subheadline.bold())
                HStack(spacing: 8) {
                    if let k = iap.kibbleAmount {
                        (Text(Image(systemName: "pawprint")) + Text(" +\(k)")).font(.caption).foregroundColor(.green)
                    }
                    if let t = iap.dogTagAmount {
                        (Text(Image(systemName: "tag.fill")) + Text(" +\(t)")).font(.caption).foregroundColor(.blue)
                    }
                    if iap.isSubscription {
                        VStack(alignment: .leading, spacing: 2) {
                            (Text(Image(systemName: "pawprint.fill")) + Text(" +\(passDailyKibble) kibble/day"))
                                .font(.caption).foregroundColor(.green)
                            Text("1.5× kibble rewards  ·  2× ad kibble")
                                .font(.caption).foregroundColor(.purple)
                        }
                    }
                }
            }
            Spacer()
            Button(product.displayPrice) { Task { await storeManager.purchase(product) } }
                .font(.subheadline.bold()).foregroundColor(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.3, green: 0.5, blue: 0.7)))
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
        }
    }
}

// ============================================================
// MARK: - ENERGY PACK SHOP SECTION
// ============================================================

/// IAP bundles that include kibble, dog tags, a spawner, and a card pack.
struct EnergyPackShopSection: View {
    var storeManager: StoreManager

    private let energyCases: [IAPProduct] = [.energySmall, .energyMedium, .energyLarge, .energyXL]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.circle.fill")
                    .foregroundColor(Color(red: 0.55, green: 0.25, blue: 0.75))
                Text("Energy Packs")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.40, green: 0.22, blue: 0.60))
                Spacer()
                Text("Kibble · Tags · Spawner · Pack")
                    .font(.caption).foregroundColor(.secondary)
            }

            Text("Each bundle includes kibble, dog tags, a board spawner, and a card pack. Higher tiers include rarer packs and spawners.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ForEach(energyCases, id: \.rawValue) { iap in
                if let contents = iap.energyPackContents {
                    EnergyPackRow(iap: iap, contents: contents, storeManager: storeManager)
                }
            }
        }
    }
}

struct EnergyPackRow: View {
    let iap: IAPProduct
    let contents: EnergyPackContents
    var storeManager: StoreManager

    private var liveProduct: Product? {
        storeManager.products.first { $0.id == iap.rawValue }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                Image(systemName: iap.icon)
                    .font(.title2)
                    .foregroundColor(contents.cardPack.accentColor)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(contents.cardPack.accentColor.opacity(0.12)))
                HStack(spacing: 1) {
                    ForEach(0..<min(contents.cardPack.stars, 3), id: \.self) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 6))
                            .foregroundColor(contents.cardPack.accentColor)
                    }
                }
                .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(iap.displayName).font(.subheadline.bold())
                HStack(spacing: 8) {
                    Label("+\(contents.kibble)", systemImage: "pawprint")
                        .font(.caption).foregroundColor(.green)
                    Label("+\(contents.dogTags)", systemImage: "tag.fill")
                        .font(.caption).foregroundColor(.blue)
                    Label(contents.spawnerCount > 1
                          ? "\(contents.spawnerCount)x \(contents.spawnerLevel.displayName)"
                          : contents.spawnerLevel.displayName,
                          systemImage: contents.spawnerLevel.sfSymbol)
                        .font(.caption).foregroundColor(contents.spawnerLevel.tintColor)
                }
                HStack(spacing: 4) {
                    Image(systemName: contents.cardPack.sfSymbol)
                        .font(.system(size: 9))
                        .foregroundColor(contents.cardPack.accentColor)
                    Text(contents.cardPack.displayName)
                        .font(.caption).foregroundColor(contents.cardPack.accentColor)
                }
            }

            Spacer()

            if let product = liveProduct {
                Button(product.displayPrice) { Task { await storeManager.purchase(product) } }
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(contents.cardPack.accentColor))
            } else {
                Text(contents.previewPrice)
                    .font(.subheadline.bold()).foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.4)))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}
