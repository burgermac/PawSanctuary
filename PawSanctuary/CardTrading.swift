//
//  CardTrading.swift
//  PawSanctuary
//
//  Data models and infrastructure for duplicate card trading via Game Center.
//
//  SETUP REQUIRED before trading goes live:
//    1. Enable "Game Center" capability in Xcode → Signing & Capabilities.
//    2. Enable "CloudKit" capability and create/select a container.
//    3. In App Store Connect, create a CloudKit record type "CardTrade" with fields:
//       id(String), cardID(String), fromPlayerID(String), fromDisplayName(String),
//       toPlayerID(String), toDisplayName(String), sentAt(Date), status(String).
//    4. Replace the stubs in CardTradeBackend with live CKDatabase calls.
//

import GameKit
import SwiftUI

// ============================================================
// MARK: - DATA MODELS
// ============================================================

enum CardTradeStatus: String, Codable, Equatable {
    case pending   // sent, not yet claimed by recipient
    case claimed   // recipient has claimed the card
}

struct CardTrade: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    let cardID: String
    let fromPlayerID: String
    let fromDisplayName: String
    let toPlayerID: String
    let toDisplayName: String
    let sentAt: Date
    var status: CardTradeStatus

    var cardDefinition: CardDefinition? { CardRegistry.cardsByID[cardID] }
}

/// Lightweight Game Center friend record (safe to store locally).
struct GameCenterFriend: Identifiable, Codable, Equatable {
    let id: String          // GKPlayer.gamePlayerID
    let alias: String
    let displayName: String
}

// ============================================================
// MARK: - GAME CENTER AUTH
// ============================================================

/// Call once on app launch. Sets up the GC auth handler and notifies the
/// ViewModel when authentication state changes.
@MainActor
func authenticateGameCenter(onAuthenticated: @escaping (String, String) -> Void) {
    GKLocalPlayer.local.authenticateHandler = { _, error in
        if let error {
            print("[GameCenter] Auth error: \(error.localizedDescription)")
            return
        }
        let player = GKLocalPlayer.local
        if player.isAuthenticated {
            onAuthenticated(player.gamePlayerID, player.alias)
        }
    }
}

/// Fetches the local player's Game Center friends.
/// Requires the Game Center entitlement and user consent.
@MainActor
func loadGameCenterFriends() async -> [GameCenterFriend] {
    guard GKLocalPlayer.local.isAuthenticated else { return [] }
    do {
        let players = try await GKLocalPlayer.local.loadFriends()
        return players.map {
            GameCenterFriend(id: $0.gamePlayerID,
                             alias: $0.alias,
                             displayName: $0.displayName)
        }
    } catch {
        print("[GameCenter] loadFriends error: \(error.localizedDescription)")
        return []
    }
}

// ============================================================
// MARK: - CLOUD BACKEND STUBS
// ============================================================
//
// BACKEND REQUIRED — Replace each method body with the corresponding
// CloudKit public-database call once the container is configured.

enum CardTradeBackend {

    /// Uploads a newly-created trade so the recipient's device can fetch it.
    static func upload(_ trade: CardTrade) async {
        // TODO: let record = trade.toCKRecord()
        //       try await CKContainer.default().publicCloudDatabase.save(record)
        print("[CardTradeBackend stub] upload trade \(trade.id) card=\(trade.cardID) to=\(trade.toDisplayName)")
    }

    /// Fetches trades where toPlayerID == playerID and status == "pending".
    static func fetchIncoming(for playerID: String) async -> [CardTrade] {
        // TODO: let pred = NSPredicate(format: "toPlayerID == %@ AND status == 'pending'", playerID)
        //       let query = CKQuery(recordType: "CardTrade", predicate: pred)
        //       let records = try await CKContainer.default().publicCloudDatabase.records(matching: query)
        //       return records.compactMap { CardTrade(from: $0) }
        print("[CardTradeBackend stub] fetchIncoming for \(playerID)")
        return []
    }

    /// Updates the trade record to status = "claimed" so the sender knows.
    static func markClaimed(tradeID: UUID) async {
        // TODO: Fetch record by tradeID, update status field, re-save.
        print("[CardTradeBackend stub] markClaimed \(tradeID)")
    }
}
