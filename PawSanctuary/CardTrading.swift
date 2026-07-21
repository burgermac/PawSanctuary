//
//  CardTrading.swift
//  PawSanctuary
//
//  Data models and infrastructure for duplicate card trading via Game Center.
//
//  SETUP REQUIRED before trading goes live (code below is fully wired — these are
//  Xcode/dashboard configuration steps only, not code changes):
//    1. Enable "Game Center" capability in Xcode → Signing & Capabilities.
//    2. Enable "iCloud" capability → check "CloudKit" service → create/select a container.
//       (Separate from the Key-Value Storage capability GameStore uses.)
//    3. In the CloudKit Dashboard (or on first save from a debug build, which
//       auto-creates the schema), confirm the "CardTrade" record type has fields:
//       cardID(String), fromPlayerID(String), fromDisplayName(String),
//       toPlayerID(String), toDisplayName(String), sentAt(Date), status(String).
//       Mark `toPlayerID` and `status` as **Queryable** in the schema — the
//       fetchIncoming query below filters on both and CloudKit rejects predicates
//       on non-queryable fields.
//    4. Deploy the schema from Development to Production before release.
//

import CloudKit
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

// ============================================================
// MARK: - CLOUDKIT MAPPING
// ============================================================

extension CardTrade {
    static let recordType = "CardTrade"

    /// The record's identity is the trade's own UUID, so `markClaimed` can fetch
    /// it directly by ID instead of needing a second query.
    var recordID: CKRecord.ID { CKRecord.ID(recordName: id.uuidString) }

    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: Self.recordType, recordID: recordID)
        record["cardID"]          = cardID as CKRecordValue
        record["fromPlayerID"]    = fromPlayerID as CKRecordValue
        record["fromDisplayName"] = fromDisplayName as CKRecordValue
        record["toPlayerID"]      = toPlayerID as CKRecordValue
        record["toDisplayName"]   = toDisplayName as CKRecordValue
        record["sentAt"]          = sentAt as CKRecordValue
        record["status"]          = status.rawValue as CKRecordValue
        return record
    }

    /// Reconstructs a trade from a fetched record. `nil` if the record is missing
    /// an expected field or holds an unrecognised status — treated as unusable by callers.
    init?(record: CKRecord) {
        guard let id = UUID(uuidString: record.recordID.recordName),
              let cardID          = record["cardID"] as? String,
              let fromPlayerID    = record["fromPlayerID"] as? String,
              let fromDisplayName = record["fromDisplayName"] as? String,
              let toPlayerID      = record["toPlayerID"] as? String,
              let toDisplayName   = record["toDisplayName"] as? String,
              let sentAt          = record["sentAt"] as? Date,
              let statusRaw       = record["status"] as? String,
              let status          = CardTradeStatus(rawValue: statusRaw)
        else { return nil }

        self.id = id
        self.cardID = cardID
        self.fromPlayerID = fromPlayerID
        self.fromDisplayName = fromDisplayName
        self.toPlayerID = toPlayerID
        self.toDisplayName = toDisplayName
        self.sentAt = sentAt
        self.status = status
    }
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
// MARK: - CLOUD BACKEND
// ============================================================
//
// Public-database CloudKit calls. Degrades gracefully (logs + returns empty/no-op)
// when the user isn't signed into iCloud or the container isn't yet provisioned —
// mirrors the guard pattern GameStore uses for its iCloud KVS sync.

enum CardTradeBackend {

    /// True only when the device has an iCloud account signed in. Doesn't guarantee
    /// the CloudKit capability/container is provisioned, but avoids firing doomed
    /// network calls when the user isn't signed into iCloud at all.
    private static var isCloudAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    private static var database: CKDatabase { CKContainer.default().publicCloudDatabase }

    /// Uploads a newly-created trade so the recipient's device can fetch it.
    static func upload(_ trade: CardTrade) async {
        guard isCloudAvailable else {
            print("[CardTradeBackend] upload skipped — no iCloud account signed in")
            return
        }
        do {
            _ = try await database.save(trade.toCKRecord())
        } catch {
            print("[CardTradeBackend] upload failed for trade \(trade.id): \(error.localizedDescription)")
        }
    }

    /// Fetches trades where toPlayerID == playerID and status == "pending".
    static func fetchIncoming(for playerID: String) async -> [CardTrade] {
        guard isCloudAvailable else { return [] }
        let predicate = NSPredicate(format: "toPlayerID == %@ AND status == %@",
                                     playerID, CardTradeStatus.pending.rawValue)
        return await runQuery(predicate: predicate, context: "fetchIncoming for \(playerID)")
    }

    /// Fetches every trade this player has sent, any status. Lets the sender's device
    /// pick up the `.claimed` transition the recipient wrote via `markClaimed`.
    static func fetchOutgoing(for playerID: String) async -> [CardTrade] {
        guard isCloudAvailable else { return [] }
        let predicate = NSPredicate(format: "fromPlayerID == %@", playerID)
        return await runQuery(predicate: predicate, context: "fetchOutgoing for \(playerID)")
    }

    private static func runQuery(predicate: NSPredicate, context: String) async -> [CardTrade] {
        let query = CKQuery(recordType: CardTrade.recordType, predicate: predicate)
        query.sortDescriptors = [NSSortDescriptor(key: "sentAt", ascending: false)]
        do {
            let (matchResults, _) = try await database.records(matching: query)
            return matchResults.compactMap { _, result in
                guard case .success(let record) = result else { return nil }
                return CardTrade(record: record)
            }
        } catch {
            print("[CardTradeBackend] \(context) failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Updates the trade record to status = "claimed" so the sender's device (on its
    /// next fetch of its own outgoing trades) can reflect the claim.
    static func markClaimed(tradeID: UUID) async {
        guard isCloudAvailable else { return }
        let recordID = CKRecord.ID(recordName: tradeID.uuidString)
        do {
            let record = try await database.record(for: recordID)
            record["status"] = CardTradeStatus.claimed.rawValue as CKRecordValue
            _ = try await database.save(record)
        } catch {
            print("[CardTradeBackend] markClaimed failed for \(tradeID): \(error.localizedDescription)")
        }
    }
}
