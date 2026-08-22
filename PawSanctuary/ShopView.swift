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

                        // ── Wildcard (Gap_Analysis_Round2 3.5) ────────────
                        WildcardSection(viewModel: viewModel)

                        Divider().padding(.horizontal)

                        // ── Piggy bank (Gap_Analysis_Round2 3.4) ──────────
                        PiggyBankSection(viewModel: viewModel)

                        Divider().padding(.horizontal)

                        // ── Dog Tag → Kibble exchange ─────────────────────
                        DogTagKibbleSection(viewModel: viewModel)

                        Divider().padding(.horizontal)

                        // ── VIP ladder (Gap_Analysis_Round2 3.7) ──────────
                        VIPSection(viewModel: viewModel)

                        // ── Reward Ladder (Phase 6b, Task 3.4) ────────────
                        // Gated on isRewardLadderAvailable, per spec §3.4 — hidden
                        // entirely (including its own divider) rather than shown
                        // empty/locked, same posture VIPSection's neighbors take
                        // for content that isn't relevant yet.
                        if viewModel.isRewardLadderAvailable {
                            Divider().padding(.horizontal)
                            RewardLadderSection(viewModel: viewModel, storeManager: storeManager)
                        }

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
                        // No "Unlock Monetization" button here — ShopView is
                        // itself only reachable once isMonetizationUnlocked is
                        // already true (MergeBoardView's Shop button is gated
                        // on the same condition), so a toggle placed here
                        // could only ever fire as a no-op. The real debug
                        // affordance lives in MergeBoardView's HUD, in the
                        // same slot the Shop button occupies once unlocked —
                        // see MergeBoardViewModel.unlockMonetizationForTesting().
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
                if !viewModel.dogTagStore.slots.isEmpty {
                    DogTagStoreRefreshButton(viewModel: viewModel)
                }
            }

            if viewModel.dogTagStore.slots.isEmpty {
                Text("Merge deeper to unlock the item store.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ForEach(viewModel.dogTagStore.slots) { slot in
                    DogTagStoreRow(slot: slot, viewModel: viewModel)
                }
                Text("Rotates daily, one of each. Sold items return tomorrow.")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .onAppear { viewModel.refreshDogTagStore() }
    }
}

/// Paid reroll (Task 3.2): priced well below the store's cheapest slot so it
/// reads as an impulse — a fresh shot at the item the player actually wants.
struct DogTagStoreRefreshButton: View {
    var viewModel: MergeBoardViewModel

    private var canAfford: Bool { viewModel.dogTags >= dogTagStoreRefreshCost }

    var body: some View {
        Button {
            viewModel.paidRefreshDogTagStore()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 11, weight: .bold))
                Text("\(dogTagStoreRefreshCost)")
                    .font(.caption.bold())
            }
            .foregroundColor(canAfford ? .white : .secondary)
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 8)
                .fill(canAfford
                      ? Color(red: 0.25, green: 0.50, blue: 0.88)
                      : Color(red: 0.90, green: 0.90, blue: 0.92)))
        }
        .disabled(!canAfford)
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
// MARK: - WILDCARD (Gap_Analysis_Round2 3.5)
// ============================================================

/// Always available, unlike the daily-limited Item Store above — merges with
/// any single item on the board, becoming a second copy of whatever it's
/// paired with. See `MergeBoardViewModel.attemptMergeOrMove`.
struct WildcardSection: View {
    var viewModel: MergeBoardViewModel

    private var chain: MergeChain? { ContentRegistry.shared.chain(ContentRegistry.wildcardChainID) }
    private var def: ChainTier? { ContentRegistry.shared.tier(ContentRegistry.wildcardChainID, 0) }
    private var canAfford: Bool { viewModel.dogTags >= wildcardCostDogTags }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let art = chain?.artImage(forTier: 0) {
                    art.resizable().scaledToFit().frame(width: 34, height: 34)
                } else {
                    Image(systemName: def?.symbol ?? "wand.and.stars")
                        .font(.title2)
                        .foregroundColor(def?.tint ?? .purple)
                }
            }
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill((def?.tint ?? .purple).opacity(0.12)))

            VStack(alignment: .leading, spacing: 3) {
                Text("Wildcard").font(.subheadline.bold())
                Text("Merges with anything on the board")
                    .font(.caption).foregroundColor(.secondary)
            }

            Spacer()

            Button {
                SoundManager.shared.playButtonTap()
                viewModel.purchaseWildcard()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "tag.fill").font(.system(size: 11))
                    Text("\(wildcardCostDogTags)").font(.subheadline.bold())
                }
                .foregroundColor(canAfford ? .white : .secondary)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(canAfford
                          ? Color(red: 0.62, green: 0.30, blue: 0.78)
                          : Color(red: 0.90, green: 0.90, blue: 0.92)))
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
// MARK: - PIGGY BANK (Gap_Analysis_Round2 3.4)
// ============================================================

/// Passive coin accumulator, skimmed from every coin gain on top of the direct
/// reward (see `MergeBoardViewModel.earnCoins`). Cracked for Dog Tags once full.
struct PiggyBankSection: View {
    var viewModel: MergeBoardViewModel

    private var fillFraction: Double {
        Double(viewModel.piggyBankCoins) / Double(piggyBankCap)
    }
    private var canCrack: Bool {
        viewModel.isPiggyBankFull && viewModel.dogTags >= piggyBankCrackCostDogTags
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "banknote.fill")
                    .foregroundColor(Color(red: 0.85, green: 0.45, blue: 0.65))
                Text("Piggy Bank")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.65, green: 0.25, blue: 0.45))
                Spacer()
                (Text(Image(systemName: "dollarsign.circle.fill"))
                 + Text(" \(viewModel.piggyBankCoins)/\(piggyBankCap)"))
                    .font(.caption.bold())
                    .foregroundColor(Color(red: 0.55, green: 0.35, blue: 0.02))
            }

            ProgressView(value: fillFraction)
                .tint(Color(red: 0.85, green: 0.45, blue: 0.65))

            Text("Fills automatically as you earn coins — this is on top of the coins you're already earning, not instead of them.")
                .font(.caption).foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                SoundManager.shared.playButtonTap()
                viewModel.crackPiggyBank()
            } label: {
                HStack {
                    Text(viewModel.isPiggyBankFull ? "Crack it open" : "Not full yet")
                        .font(.subheadline.bold())
                    Spacer()
                    if viewModel.isPiggyBankFull {
                        HStack(spacing: 4) {
                            Image(systemName: "tag.fill").font(.system(size: 11))
                            Text("\(piggyBankCrackCostDogTags)")
                        }
                        .font(.subheadline.bold())
                    }
                }
                .foregroundColor(canCrack ? .white : .secondary)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 10)
                    .fill(canCrack
                          ? Color(red: 0.85, green: 0.45, blue: 0.65)
                          : Color(red: 0.90, green: 0.90, blue: 0.92)))
            }
            .disabled(!canCrack)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}

// ============================================================
// MARK: - VIP LADDER (Gap_Analysis_Round2 3.7)
// ============================================================

/// Status display, not a purchase button — VIP level moves only as a side
/// effect of buying something elsewhere in the shop (`MergeBoardViewModel.
/// applyPurchase`). Placed just above the Energy Packs so the next tier's
/// reward is the last thing seen before a purchase button.
struct VIPSection: View {
    var viewModel: MergeBoardViewModel

    private func dollarString(_ micros: Int) -> String {
        let dollars = Double(micros) / 1_000_000
        return dollars == dollars.rounded()
            ? String(format: "$%.0f", dollars)
            : String(format: "$%.2f", dollars)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "crown.fill")
                    .foregroundColor(Color(red: 0.80, green: 0.62, blue: 0.10))
                Text(viewModel.vipLevel > 0 ? "VIP \(viewModel.vipLevel)" : "VIP Club")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.55, green: 0.42, blue: 0.05))
                Spacer()
            }

            if let next = viewModel.nextVIPTier {
                ProgressView(value: viewModel.vipProgressFraction)
                    .tint(Color(red: 0.80, green: 0.62, blue: 0.10))

                Text("VIP \(next.level) at \(dollarString(next.thresholdMicros)) lifetime — \(next.bonus.primaryDescription), +\(next.kibbleReward) kibble, +\(next.dogTagReward) tags, +\(next.coinReward) coins")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Top VIP tier reached — every permanent bonus below is active.")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color.white.opacity(0.75))
            .shadow(color: .black.opacity(0.05), radius: 4))
    }
}

// ============================================================
// MARK: - REWARD LADDER (Phase 6b, D8, Task 3.4)
// ============================================================

/// Vertical rung-by-rung layout — `EventSheetView`/`MilestoneRowView` are
/// row-per-milestone but table-shaped for a different purpose (free vs. paid
/// lane side by side); this needs "which single rung is next" front and
/// center, closer in spirit to `ParallelBoardView`'s own "needed a new view"
/// precedent. Gated by the caller on `isRewardLadderAvailable` (spec §3.4);
/// also degrades to nothing here if `rewardLadderTrackID` has no
/// `ProgressTrackRegistry` content yet (Task 3.5), rather than rendering an
/// empty box.
struct RewardLadderSection: View {
    var viewModel: MergeBoardViewModel
    var storeManager: StoreManager

    private var milestones: [TrackMilestone] {
        (ProgressTrackRegistry.tracks[rewardLadderTrackID] ?? []).sorted { $0.index < $1.index }
    }
    private var progress: Int { viewModel.progressTrack.progress(trackID: rewardLadderTrackID) }
    private var product: Product? {
        storeManager.products.first { $0.id == IAPProduct.rewardLadderRung.rawValue }
    }

    var body: some View {
        if !milestones.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Image(systemName: IAPProduct.rewardLadderRung.icon)
                        .foregroundColor(Color(red: 0.55, green: 0.25, blue: 0.75))
                    Text("Reward Ladder")
                        .font(.headline)
                        .foregroundColor(Color(red: 0.40, green: 0.18, blue: 0.55))
                    Spacer()
                    Text("Rung \(min(progress + 1, milestones.count))/\(milestones.count)")
                        .font(.caption).foregroundColor(.secondary)
                }

                Text("Buy the next rung to instantly release its paid reward and unlock the free reward beside it.")
                    .font(.caption).foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                ForEach(milestones, id: \.index) { milestone in
                    RewardLadderRungRow(milestone: milestone, progress: progress,
                                        product: product, viewModel: viewModel, storeManager: storeManager)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.75))
                .shadow(color: .black.opacity(0.05), radius: 4))
        }
    }
}

private struct RewardLadderRungRow: View {
    let milestone: TrackMilestone
    let progress: Int
    let product: Product?
    var viewModel: MergeBoardViewModel
    var storeManager: StoreManager

    /// Purchases claim both lanes immediately (Task 3.1) — a rung's state is
    /// fully determined by comparing its index to progress, no separate
    /// claimed-lane query needed the way MilestoneRowView needs one.
    private var isPurchased: Bool { milestone.index < progress }
    private var isNext: Bool { milestone.index == progress }
    private let accent = Color(red: 0.55, green: 0.25, blue: 0.75)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isPurchased ? Color.green.opacity(0.8)
                              : isNext ? accent : Color.gray.opacity(0.25))
                        .frame(width: 30, height: 30)
                    if isPurchased {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    } else if isNext {
                        Text("\(milestone.threshold)")
                            .font(.system(size: 12, weight: .bold)).foregroundColor(.white)
                    } else {
                        // Coercive (D8): future rungs are visible, not hidden —
                        // just not purchasable out of order. See spec §3.4/§0.
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11)).foregroundColor(.white)
                    }
                }

                Text("Rung \(milestone.threshold)")
                    .font(.subheadline.bold())
                    .foregroundColor(isPurchased || isNext ? .primary : .secondary)

                Spacer()

                if isPurchased {
                    Text("Purchased").font(.caption.bold()).foregroundColor(.green)
                } else if isNext, let product {
                    Button(action: {
                        // Captured now, before the async purchase — see
                        // MergeBoardViewModel.pendingRewardLadderRung's doc comment.
                        viewModel.pendingRewardLadderRung = milestone.threshold
                        Task { await storeManager.purchase(product) }
                    }) {
                        Text(product.displayPrice)
                            .font(.subheadline.bold()).foregroundColor(.white)
                            .padding(.horizontal, 14).padding(.vertical, 7)
                            .background(RoundedRectangle(cornerRadius: 10).fill(accent))
                    }
                }
            }

            HStack(alignment: .top, spacing: 16) {
                rewardGroup("Direct", milestone.paidRewards)
                rewardGroup("Unlocks", milestone.freeRewards)
            }
            .opacity(isPurchased || isNext ? 1.0 : 0.45)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(isNext ? accent.opacity(0.08) : Color.gray.opacity(0.05)))
    }

    private func rewardGroup(_ label: String, _ rewards: [OrderReward]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9)).foregroundColor(.secondary)
            HStack(spacing: 6) {
                ForEach(Array(rewards.enumerated()), id: \.offset) { _, reward in
                    rewardIcon(reward)
                }
            }
        }
    }

    /// Kibble and dog tags only — §4's table has no other reward kind, unlike
    /// Pass's paid lane, which needed a `.cardPack` case for its hero reward.
    @ViewBuilder
    private func rewardIcon(_ reward: OrderReward) -> some View {
        switch reward.kind {
        case .kibble:
            Label("+\(reward.amount)", systemImage: "pawprint.fill")
                .font(.caption.bold()).foregroundColor(.green)
        case .dogTags:
            Label("+\(reward.amount)", systemImage: "tag.fill")
                .font(.caption.bold()).foregroundColor(.blue)
        default:
            Text("+\(reward.amount)").font(.caption.bold()).foregroundColor(.secondary)
        }
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
        // Energy packs are shown in the dedicated EnergyPackShopSection — skip here.
        // Event Pass is purchasable only from the active event's own sheet
        // (EventSheetView) — out of context here there's no event to attach the
        // purchase to (specs/Spec_Phase6b_Pass.md §3.3). Reward Ladder rungs are
        // purchasable only from the dedicated Reward Ladder section (Task 3.4,
        // not yet built) — this generic row has no way to show which rung is
        // next or capture pendingRewardLadderRung correctly.
        if iap.energyPackContents != nil || iap == .eventPass || iap == .rewardLadderRung { EmptyView() } else {
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
