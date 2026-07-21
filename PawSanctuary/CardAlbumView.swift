//
//  CardAlbumView.swift
//  PawSanctuary
//
//  Card album, pack opening, star shop, duplicate trading, and trade inbox.
//

import SwiftUI

// ============================================================
// MARK: - CARD ALBUM ROOT VIEW
// ============================================================

struct CardAlbumView: View {
    var viewModel: MergeBoardViewModel
    @State private var selectedTab: AlbumTab = .albums
    @State private var selectedAlbum: CardAlbumDefinition? = nil
    @State private var showOpenPack = false
    @State private var openedCards: [OpenedCard] = []
    @State private var showTradeSheet = false
    @State private var tradeTargetCardID: String? = nil

    enum AlbumTab: String, CaseIterable {
        case albums    = "Albums"
        case dupes     = "Duplicates"
        case inbox     = "Inbox"

        var sfSymbol: String {
            switch self { case .albums: return "rectangle.stack.fill"
                          case .dupes:  return "arrow.triangle.2.circlepath"
                          case .inbox:  return "tray.fill" }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            tabBar
            ScrollView {
                VStack(spacing: 16) {
                    switch selectedTab {
                    case .albums: albumsContent
                    case .dupes:  duplicatesContent
                    case .inbox:  inboxContent
                    }
                    Spacer(minLength: 20)
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(viewModel: viewModel, album: album)
        }
        .sheet(isPresented: $showOpenPack) {
            PackOpeningView(openedCards: openedCards)
        }
        .sheet(isPresented: $showTradeSheet) {
            if let cardID = tradeTargetCardID {
                FriendPickerSheet(viewModel: viewModel, cardID: cardID) {
                    showTradeSheet = false
                }
            }
        }
        .overlay {
            if let album = viewModel.showAlbumCompleteCard {
                AlbumCompleteOverlay(album: album)
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                    .zIndex(100)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.70), value: viewModel.showAlbumCompleteCard?.id)
        .task {
            await viewModel.refreshIncomingTrades()
            await viewModel.refreshOutgoingTrades()
        }
    }

    // MARK: Tab bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AlbumTab.allCases, id: \.rawValue) { tab in
                let isSelected = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    VStack(spacing: 3) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: tab.sfSymbol)
                                .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                            // Badge for inbox unread count
                            if tab == .inbox && !viewModel.pendingIncomingTrades.isEmpty {
                                Text("\(viewModel.pendingIncomingTrades.count)")
                                    .font(.system(size: 8, weight: .bold)).foregroundColor(.white)
                                    .padding(3)
                                    .background(Circle().fill(Color.red))
                                    .offset(x: 8, y: -6)
                            }
                            // Badge for duplicate count
                            if tab == .dupes && !viewModel.allDuplicateCards.isEmpty {
                                Circle().fill(Color(red: 0.55, green: 0.25, blue: 0.75))
                                    .frame(width: 7, height: 7)
                                    .offset(x: 8, y: -6)
                            }
                        }
                        Text(tab.rawValue).font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                    }
                    .foregroundColor(isSelected ? Color(red: 0.35, green: 0.25, blue: 0.55) : .secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(isSelected
                                ? Color(red: 0.94, green: 0.91, blue: 1.00)
                                : Color.clear)
                }
            }
        }
        .background(Color(red: 0.97, green: 0.95, blue: 1.00))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: Albums tab

    private var albumsContent: some View {
        VStack(spacing: 16) {
            headerRow
            packQueueBar
            albumsGrid
            starShopSection
        }
    }

    private var headerRow: some View {
        HStack {
            Label("Card Album", systemImage: "rectangle.stack.fill")
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                Text("\(viewModel.starCount)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Color(red: 0.55, green: 0.38, blue: 0.05))
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.93, blue: 0.78)))
        }
    }

    private var packQueueBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Packs to Open")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                if !viewModel.pendingCardPacks.isEmpty {
                    Text("\(viewModel.pendingCardPacks.count)")
                        .font(.system(size: 11, weight: .bold)).foregroundColor(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Color(red: 0.65, green: 0.30, blue: 0.80)))
                }
                Spacer()
                if !viewModel.pendingCardPacks.isEmpty {
                    Button("Open Pack") {
                        openedCards = viewModel.openNextCardPack()
                        showOpenPack = true
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.55, green: 0.25, blue: 0.75)))
                }
            }

            if viewModel.pendingCardPacks.isEmpty {
                Text("No packs waiting — earn them by leveling up or fulfilling adoption orders.")
                    .font(.caption).foregroundColor(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(viewModel.pendingCardPacks.enumerated()), id: \.offset) { _, pack in
                            PackChip(pack: pack)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 0.96, green: 0.93, blue: 1.00)))
    }

    private var albumsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Collections")
                .font(.headline)
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
            ForEach(CardRegistry.albums) { album in
                AlbumRowCard(viewModel: viewModel, album: album) {
                    selectedAlbum = album
                }
            }
        }
    }

    private var starShopSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Star Shop")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.60, green: 0.42, blue: 0.08))
                Spacer()
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                    Text("\(viewModel.starCount) stars")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                }
            }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(StarShopItem.allCases, id: \.rawValue) { item in
                    StarShopItemView(item: item, canAfford: viewModel.starCount >= item.starCost) {
                        viewModel.buyFromStarShop(item)
                    }
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14)
            .fill(Color(red: 1.00, green: 0.97, blue: 0.88)))
    }

    // MARK: Duplicates tab

    private var duplicatesContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            duplicatesHeader
            if viewModel.allDuplicateCards.isEmpty {
                emptyDuplicatesView
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                                    GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.allDuplicateCards, id: \.definition.id) { item in
                        DuplicateCardTile(
                            definition: item.definition,
                            extraCount: item.extraCount,
                            canSend: viewModel.gcIsAuthenticated && viewModel.remainingDailyTrades > 0,
                            onSend: {
                                tradeTargetCardID = item.definition.id
                                showTradeSheet = true
                            }
                        )
                    }
                }
            }
        }
    }

    private var duplicatesHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Duplicate Cards")
                    .font(.title3.bold())
                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                Text("Cards you own more than once. Send to friends or convert to Stars.")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            if !viewModel.allDuplicateCards.isEmpty {
                Button {
                    _ = viewModel.convertAllDuplicatesToStars()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13))
                            .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                        Text("Convert All")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 0.60, green: 0.40, blue: 0.08))
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.98, green: 0.93, blue: 0.78)))
                }
            }
        }
    }

    private var emptyDuplicatesView: some View {
        VStack(spacing: 10) {
            Image(systemName: "rectangle.stack.badge.checkmark")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No duplicates yet")
                .font(.subheadline).foregroundColor(.secondary)
            Text("Open more packs to collect duplicates and earn Stars or trade with friends.")
                .font(.caption).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    // MARK: Inbox tab

    private var inboxContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trade Inbox")
                        .font(.title3.bold())
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                    Text("Cards sent to you by friends.")
                        .font(.caption).foregroundColor(.secondary)
                }
                Spacer()
                Button {
                    Task {
                        await viewModel.refreshIncomingTrades()
                        await viewModel.refreshOutgoingTrades()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                }
            }

            if !viewModel.gcIsAuthenticated {
                gcSignInPrompt
            } else if viewModel.pendingIncomingTrades.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "tray")
                        .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.5))
                    Text("No incoming trades")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                ForEach(viewModel.pendingIncomingTrades) { trade in
                    IncomingTradeRow(trade: trade) {
                        viewModel.claimIncomingTrade(trade)
                    }
                }
            }

            // Outgoing trades summary
            if !viewModel.pendingOutgoingTrades.isEmpty {
                outgoingTradesSummary
            }
        }
    }

    private var gcSignInPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 36)).foregroundColor(.secondary.opacity(0.5))
            Text("Game Center Required")
                .font(.subheadline.bold()).foregroundColor(.primary)
            Text("Sign in to Game Center in Settings → Game Center to trade cards with friends.")
                .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 30)
    }

    private var outgoingTradesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sent (\(viewModel.pendingOutgoingTrades.count))")
                .font(.headline).foregroundColor(.secondary)
            ForEach(viewModel.pendingOutgoingTrades) { trade in
                if let def = trade.cardDefinition {
                    HStack(spacing: 10) {
                        Image(systemName: def.sfSymbol)
                            .font(.system(size: 16))
                            .foregroundColor(def.rarity.borderColor)
                            .frame(width: 32, height: 32)
                            .background(RoundedRectangle(cornerRadius: 8)
                                .fill(def.rarity.borderColor.opacity(0.10)))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(def.name).font(.system(size: 13, weight: .semibold))
                            Text("To: \(trade.toDisplayName)")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(trade.status == .claimed ? "Claimed" : "Pending")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(trade.status == .claimed ? .green : .orange)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Capsule()
                                .fill(trade.status == .claimed ? Color.green.opacity(0.1) : Color.orange.opacity(0.1)))
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.7)))
                }
            }
        }
    }
}

// ============================================================
// MARK: - DUPLICATE CARD TILE
// ============================================================

private struct DuplicateCardTile: View {
    let definition: CardDefinition
    let extraCount: Int
    let canSend: Bool
    let onSend: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(definition.rarity.borderColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(definition.rarity.borderColor, lineWidth: 2))
                    .shadow(color: definition.rarity.glowColor, radius: 4)

                Image(systemName: definition.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(definition.rarity == .rare
                                     ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                     : Color(red: 0.45, green: 0.35, blue: 0.65))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Duplicate count badge
                Text("+\(extraCount)")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background(Capsule().fill(Color(red: 0.55, green: 0.25, blue: 0.75)))
                    .offset(x: 6, y: -6)
            }
            .frame(height: 72)

            Text(definition.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            // Send button
            Button(action: onSend) {
                HStack(spacing: 3) {
                    Image(systemName: "paperplane.fill").font(.system(size: 8))
                    Text("Send").font(.system(size: 9, weight: .bold))
                }
                .foregroundColor(canSend ? Color(red: 0.30, green: 0.50, blue: 0.75) : .secondary)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule()
                    .fill(canSend ? Color(red: 0.30, green: 0.50, blue: 0.75).opacity(0.12) : Color.gray.opacity(0.08)))
            }
            .disabled(!canSend)
        }
    }
}

// ============================================================
// MARK: - INCOMING TRADE ROW
// ============================================================

private struct IncomingTradeRow: View {
    let trade: CardTrade
    let onClaim: () -> Void

    var body: some View {
        if let def = trade.cardDefinition {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(def.rarity.borderColor.opacity(0.12))
                        .overlay(RoundedRectangle(cornerRadius: 10)
                            .stroke(def.rarity.borderColor, lineWidth: 1.5))
                    Image(systemName: def.sfSymbol)
                        .font(.system(size: 22))
                        .foregroundColor(def.rarity == .rare
                                         ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                         : Color(red: 0.45, green: 0.35, blue: 0.65))
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 3) {
                    Text(def.name).font(.system(size: 14, weight: .semibold))
                    Text(def.rarity.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(def.rarity.borderColor)
                    Text("From \(trade.fromDisplayName)")
                        .font(.caption).foregroundColor(.secondary)
                }

                Spacer()

                Button("Claim!", action: onClaim)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 14)
                        .fill(Color(red: 0.30, green: 0.60, blue: 0.40)))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.85))
                .shadow(color: .black.opacity(0.07), radius: 4, y: 2))
        }
    }
}

// ============================================================
// MARK: - FRIEND PICKER SHEET
// ============================================================

struct FriendPickerSheet: View {
    var viewModel: MergeBoardViewModel
    let cardID: String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Card preview
                if let def = CardRegistry.cardsByID[cardID] {
                    cardPreviewHeader(def)
                }

                Divider()

                // Daily limit indicator
                dailyLimitBar

                // Friends list
                if viewModel.gcIsLoadingFriends {
                    ProgressView("Loading friends…").padding(.top, 40)
                    Spacer()
                } else if viewModel.gcFriends.isEmpty {
                    emptyFriendsView
                } else {
                    List(viewModel.gcFriends) { friend in
                        Button {
                            viewModel.sendDuplicateCard(cardID, to: friend)
                            onDismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(friend.displayName).font(.subheadline.bold())
                                    Text(friend.alias).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "paperplane.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.30, green: 0.50, blue: 0.75))
                            }
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.remainingDailyTrades == 0)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Send to Friend")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel", action: onDismiss) }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Refresh") { Task { await viewModel.loadGCFriends() } }
                }
            }
            #endif
            .task { if viewModel.gcFriends.isEmpty { await viewModel.loadGCFriends() } }
        }
    }

    private func cardPreviewHeader(_ def: CardDefinition) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(def.rarity.borderColor.opacity(0.12))
                    .overlay(RoundedRectangle(cornerRadius: 12)
                        .stroke(def.rarity.borderColor, lineWidth: 2))
                Image(systemName: def.sfSymbol)
                    .font(.system(size: 28))
                    .foregroundColor(def.rarity == .rare
                                     ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                     : Color(red: 0.45, green: 0.35, blue: 0.65))
            }
            .frame(width: 60, height: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sending:").font(.caption).foregroundColor(.secondary)
                Text(def.name).font(.headline)
                Text(def.rarity.displayName)
                    .font(.caption.bold())
                    .foregroundColor(def.rarity.borderColor)
            }
            Spacer()
        }
        .padding()
        .background(Color(red: 0.96, green: 0.93, blue: 1.00))
    }

    private var dailyLimitBar: some View {
        HStack {
            Image(systemName: "clock.fill")
                .font(.system(size: 11)).foregroundColor(.secondary)
            Text("Daily limit: \(viewModel.remainingDailyTrades)/\(viewModel.maxDailyCardSends) sends remaining")
                .font(.caption).foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal).padding(.vertical, 8)
        .background(Color.gray.opacity(0.06))
    }

    private var emptyFriendsView: some View {
        VStack {
            VStack(spacing: 12) {
                Image(systemName: "person.2.slash").font(.system(size: 36)).foregroundColor(.secondary.opacity(0.5))
                Text("No Game Center friends found")
                    .font(.subheadline.bold()).foregroundColor(.primary)
                Text("Make sure your friends play PawSanctuary and are connected via Game Center.")
                    .font(.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 40).padding(.horizontal, 24)
            Spacer()
        }
    }
}

// ============================================================
// MARK: - PACK CHIP
// ============================================================

private struct PackChip: View {
    let pack: CardPackType
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: pack.sfSymbol)
                .font(.system(size: 12, weight: .semibold))
            Text(pack.displayName)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundColor(pack.accentColor)
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Capsule().fill(pack.accentColor.opacity(0.12)))
        .overlay(Capsule().stroke(pack.accentColor.opacity(0.4), lineWidth: 1))
    }
}

// ============================================================
// MARK: - ALBUM ROW CARD
// ============================================================

private struct AlbumRowCard: View {
    var viewModel: MergeBoardViewModel
    let album: CardAlbumDefinition
    let action: () -> Void

    var body: some View {
        let total    = album.cardIDs.count
        let owned    = viewModel.ownedCount(in: album)
        let done     = viewModel.completedAlbumIDs.contains(album.id)
        let fraction = Double(owned) / Double(total)

        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle().fill(done
                                  ? Color(red: 0.88, green: 0.68, blue: 0.15).opacity(0.20)
                                  : Color.purple.opacity(0.10))
                        .frame(width: 46, height: 46)
                    Image(systemName: done ? "checkmark.seal.fill" : album.sfSymbol)
                        .font(.system(size: 22))
                        .foregroundColor(done
                                         ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                         : Color(red: 0.45, green: 0.25, blue: 0.65))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(album.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.primary)
                        Spacer()
                        Text("\(owned)/\(total)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(done ? Color(red: 0.78, green: 0.55, blue: 0.10) : .secondary)
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 3).fill(Color.gray.opacity(0.15))
                            RoundedRectangle(cornerRadius: 3)
                                .fill(done
                                      ? LinearGradient(colors: [Color(red: 0.88, green: 0.68, blue: 0.15),
                                                                 Color(red: 1.00, green: 0.82, blue: 0.30)],
                                                        startPoint: .leading, endPoint: .trailing)
                                      : LinearGradient(colors: [Color(red: 0.55, green: 0.25, blue: 0.75),
                                                                 Color(red: 0.70, green: 0.45, blue: 0.85)],
                                                        startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * fraction)
                                .animation(.easeInOut(duration: 0.4), value: fraction)
                        }
                    }.frame(height: 5)
                    Text(album.description)
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14)
                .fill(Color.white.opacity(0.85))
                .shadow(color: .black.opacity(0.07), radius: 4, y: 2))
        }
        .buttonStyle(.plain)
    }
}

// ============================================================
// MARK: - ALBUM DETAIL VIEW  (sheet)
// ============================================================

struct AlbumDetailView: View {
    var viewModel: MergeBoardViewModel
    let album: CardAlbumDefinition
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    rewardBanner
                    jokerBar
                    cardGrid
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle(album.name)
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }}
            #endif
        }
    }

    private var rewardBanner: some View {
        let done = viewModel.completedAlbumIDs.contains(album.id)
        return HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" : "gift.fill")
                .font(.system(size: 20))
                .foregroundColor(done ? .green : Color(red: 0.55, green: 0.25, blue: 0.75))
            VStack(alignment: .leading, spacing: 2) {
                Text(done ? "Reward claimed!" : "Complete to earn:")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(done ? .green : .primary)
                HStack(spacing: 10) {
                    if album.rewardKibble  > 0 { rewardPill("\(album.rewardKibble) Kibble", "pawprint.fill", .green) }
                    if album.rewardDogTags > 0 { rewardPill("\(album.rewardDogTags) Tags",  "tag.fill",       .blue)  }
                    if album.rewardCoins   > 0 { rewardPill("\(album.rewardCoins) Coins",   "coin.fill",      Color(red: 0.78, green: 0.56, blue: 0.08)) }
                }
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12)
            .fill(done ? Color.green.opacity(0.08) : Color.purple.opacity(0.08)))
    }

    private func rewardPill(_ text: String, _ symbol: String, _ color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: symbol).font(.system(size: 9))
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(color)
        .padding(.horizontal, 7).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.12)))
    }

    private var jokerBar: some View {
        HStack(spacing: 12) {
            jokerPill("Jokers", count: viewModel.jokerCards,
                      color: Color(red: 0.25, green: 0.60, blue: 0.40))
            jokerPill("Rare Jokers", count: viewModel.rareJokerCards,
                      color: Color(red: 0.88, green: 0.68, blue: 0.15))
            Spacer()
        }
    }

    private func jokerPill(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "j.circle.fill").font(.system(size: 12)).foregroundColor(color)
            Text("\(count) \(label)").font(.system(size: 11, weight: .semibold)).foregroundColor(color)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(Capsule().fill(color.opacity(0.10)))
    }

    private var cardGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()),
                            GridItem(.flexible())], spacing: 12) {
            ForEach(album.cardIDs, id: \.self) { cardID in
                if let def = CardRegistry.cardsByID[cardID] {
                    CardSlotView(
                        definition: def,
                        count: viewModel.cardInventory[cardID, default: 0],
                        canUseJoker: def.rarity == .rare
                            ? viewModel.rareJokerCards > 0
                            : viewModel.jokerCards > 0,
                        onJokerTap: { viewModel.useJoker(for: cardID) }
                    )
                }
            }
        }
    }
}

// ============================================================
// MARK: - CARD SLOT VIEW
// ============================================================

private struct CardSlotView: View {
    let definition: CardDefinition
    let count: Int             // copies owned; 0 = not collected
    let canUseJoker: Bool
    let onJokerTap: () -> Void

    private var owned: Bool { count > 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(owned
                          ? definition.rarity.borderColor.opacity(0.12)
                          : Color.gray.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(owned ? definition.rarity.borderColor : Color.gray.opacity(0.25),
                                lineWidth: owned ? 2 : 1))
                    .shadow(color: definition.rarity.glowColor, radius: owned ? 6 : 0)

                VStack(spacing: 4) {
                    if owned {
                        Image(systemName: definition.sfSymbol)
                            .font(.system(size: 26))
                            .foregroundColor(definition.rarity == .rare
                                             ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                             : Color(red: 0.45, green: 0.35, blue: 0.65))
                    } else {
                        Image(systemName: "questionmark")
                            .font(.system(size: 22))
                            .foregroundColor(.gray.opacity(0.35))
                    }
                    if definition.rarity == .rare {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Duplicate count badge — shows when player has more than 1 copy
                if count > 1 {
                    Text("+\(count - 1)")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, 4).padding(.vertical, 2)
                        .background(Capsule()
                            .fill(Color(red: 0.55, green: 0.25, blue: 0.75)))
                        .offset(x: 5, y: -5)
                }
            }
            .frame(height: 80)

            Text(owned ? definition.name : "???")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(owned ? .primary : .secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            if !owned && canUseJoker {
                Button(action: onJokerTap) {
                    Text("Use Joker")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Color(red: 0.25, green: 0.60, blue: 0.40))
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(Capsule()
                            .fill(Color(red: 0.25, green: 0.60, blue: 0.40).opacity(0.12)))
                }
            }
        }
    }
}

// ============================================================
// MARK: - PACK OPENING VIEW  (sheet)
// ============================================================

struct PackOpeningView: View {
    let openedCards: [OpenedCard]
    @Environment(\.dismiss) private var dismiss
    @State private var revealedCount = 0

    var body: some View {
        VStack(spacing: 0) {
            Text("Pack Opened!")
                .font(.title2.bold())
                .foregroundColor(Color(red: 0.35, green: 0.25, blue: 0.55))
                .padding(.top, 24).padding(.bottom, 16)

            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    ForEach(Array(openedCards.enumerated()), id: \.element.id) { idx, opened in
                        OpenedCardTile(opened: opened, isRevealed: idx < revealedCount)
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + Double(idx) * 0.25) {
                                    withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                                        revealedCount = max(revealedCount, idx + 1)
                                    }
                                }
                            }
                    }
                }
                .padding(.horizontal)
            }

            Button("Collect") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 40).padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 25)
                    .fill(Color(red: 0.35, green: 0.25, blue: 0.55)))
                .padding(.vertical, 20)
        }
    }
}

private struct OpenedCardTile: View {
    let opened: OpenedCard
    let isRevealed: Bool

    var body: some View {
        let def = opened.definition
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(isRevealed
                          ? (def.rarity == .rare
                             ? LinearGradient(colors: [Color(red: 0.98, green: 0.92, blue: 0.72),
                                                        Color(red: 1.00, green: 0.97, blue: 0.88)],
                                              startPoint: .topLeading, endPoint: .bottomTrailing)
                             : LinearGradient(colors: [Color(red: 0.93, green: 0.90, blue: 0.98),
                                                        Color.white],
                                              startPoint: .topLeading, endPoint: .bottomTrailing))
                          : LinearGradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.15)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing))
                    .overlay(RoundedRectangle(cornerRadius: 14)
                        .stroke(isRevealed ? def.rarity.borderColor : Color.gray.opacity(0.2), lineWidth: 2))
                    .shadow(color: isRevealed ? def.rarity.glowColor : .clear, radius: 8)

                if isRevealed {
                    VStack(spacing: 6) {
                        Image(systemName: def.sfSymbol)
                            .font(.system(size: 36))
                            .foregroundColor(def.rarity == .rare
                                             ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                             : Color(red: 0.45, green: 0.35, blue: 0.65))
                        if def.rarity == .rare {
                            HStack(spacing: 2) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                                }
                            }
                        }
                    }
                } else {
                    Image(systemName: "cube.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color.gray.opacity(0.3))
                }
            }
            .frame(height: 120)
            .scaleEffect(isRevealed ? 1.0 : 0.92)
            .animation(.spring(response: 0.35, dampingFraction: 0.65), value: isRevealed)

            if isRevealed {
                Text(def.name)
                    .font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(.center)

                if opened.wasDuplicate {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                        Text("+\(opened.starsEarned) stars")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Color(red: 0.60, green: 0.40, blue: 0.08))
                    }
                } else {
                    Text(def.rarity.displayName)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(def.rarity.borderColor)
                }
            }
        }
    }
}

// ============================================================
// MARK: - STAR SHOP ITEM VIEW
// ============================================================

private struct StarShopItemView: View {
    let item: StarShopItem
    let canAfford: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: item.sfSymbol)
                    .font(.system(size: 24))
                    .foregroundColor(canAfford ? item.sfSymbolColor : .gray)
                Text(item.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(canAfford ? .primary : .secondary)
                Text(item.description)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                HStack(spacing: 3) {
                    Image(systemName: "star.fill")
                        .font(.system(size: 10))
                        .foregroundColor(canAfford
                                         ? Color(red: 0.88, green: 0.68, blue: 0.15)
                                         : .gray)
                    Text("\(item.starCost)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(canAfford ? Color(red: 0.60, green: 0.40, blue: 0.08) : .gray)
                }
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Capsule()
                    .fill(canAfford
                          ? Color(red: 0.88, green: 0.68, blue: 0.15).opacity(0.15)
                          : Color.gray.opacity(0.10)))
            }
            .padding(10)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.9))
                .shadow(color: .black.opacity(0.06), radius: 3, y: 2))
            .opacity(canAfford ? 1.0 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!canAfford)
    }
}

// ============================================================
// MARK: - ALBUM COMPLETE OVERLAY
// ============================================================

private struct AlbumCompleteOverlay: View {
    let album: CardAlbumDefinition
    var body: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.88, green: 0.68, blue: 0.15).opacity(0.25))
                        .frame(width: 46, height: 46)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Color(red: 0.88, green: 0.68, blue: 0.15))
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Album Complete!")
                        .font(.headline).foregroundColor(.white)
                    Text("\(album.name) — reward collected!")
                        .font(.caption).foregroundColor(.white.opacity(0.85))
                }
                Spacer()
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(red: 0.50, green: 0.32, blue: 0.08),
                             Color(red: 0.70, green: 0.50, blue: 0.12)],
                    startPoint: .leading, endPoint: .trailing))
                .shadow(color: .black.opacity(0.2), radius: 10))
            .padding(.horizontal, 20).padding(.bottom, 100)
        }
    }
}
