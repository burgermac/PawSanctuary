//
//  StoreManager.swift
//  PawSanctuary
//

import SwiftUI
import StoreKit
import Observation

// ============================================================
// MARK: - STORE MANAGER
// ============================================================

/// @Observable replaces ObservableObject/Published — SwiftUI only re-renders
/// views that read a property that actually changed.
@Observable
@MainActor
class StoreManager {
    var products: [Product] = []
    var isLoading = false
    var purchaseError: String? = nil

    /// True when the Sanctuary Pass subscription is currently active.
    var isPassActive: Bool = false

    /// Called by the ViewModel when a purchase or subscription renewal is verified.
    /// The `Decimal` is the transaction's price (Task 1.4, Phase 1 — recorded into
    /// PlayerCommerceState.totalSpendMicros; treated as USD without currency
    /// conversion, an accepted simplification for this phase's plumbing).
    @ObservationIgnored var onPurchaseComplete: ((IAPProduct, Decimal) -> Void)?

    /// Guards against granting the same transaction twice. StoreKit 2 delivers every
    /// transaction on `Transaction.updates` — including ones this session just made
    /// via `purchase()` directly — so without this, a single paid purchase could be
    /// seen and granted once by `purchase()` and again by `listenForTransactions()`.
    private var grantedTransactionIDs: Set<UInt64> = []

    /// Grants a transaction via `onPurchaseComplete` at most once, regardless of
    /// which of the two observation paths (direct purchase vs. the update listener)
    /// sees it first. Restores/family-shared entitlements (no price, or revoked)
    /// are never new purchases and are left ungranted, same as before.
    private func grantIfNew(_ tx: StoreKit.Transaction, iap: IAPProduct) {
        guard let price = tx.price, tx.revocationDate == nil else { return }
        guard !grantedTransactionIDs.contains(tx.id) else { return }
        grantedTransactionIDs.insert(tx.id)
        onPurchaseComplete?(iap, price)
    }

    init() {
        Task {
            await loadProducts()
            await checkPassEntitlement()
            await listenForTransactions()
        }
    }

    /// Checks StoreKit current entitlements and sets isPassActive accordingly.
    func checkPassEntitlement() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let tx) = result,
               tx.productID == IAPProduct.sanctuaryPass.rawValue,
               tx.revocationDate == nil {
                isPassActive = true
                return
            }
        }
        isPassActive = false
    }

    func loadProducts() async {
        isLoading = true
        do {
            let ids = IAPProduct.allCases.map { $0.rawValue }
            products = try await Product.products(for: Set(ids))
            products.sort { $0.price < $1.price }
        } catch {
            print("StoreKit load: \(error.localizedDescription)")
        }
        isLoading = false
    }

    func purchase(_ product: Product) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let v):
                let tx = try checkVerified(v)
                if let iap = IAPProduct(rawValue: product.id) {
                    grantIfNew(tx, iap: iap)
                }
                await tx.finish()
            case .pending:
                purchaseError = "Purchase pending."
            default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    func restorePurchases() async {
        do { try await AppStore.sync() }
        catch { purchaseError = "Restore failed: \(error.localizedDescription)" }
    }

    // MARK: Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw StoreKitError.notEntitled
        case .verified(let safe): return safe
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            do {
                let tx = try checkVerified(result)
                if let iap = IAPProduct(rawValue: tx.productID) {
                    if iap == .sanctuaryPass { isPassActive = tx.revocationDate == nil }
                    grantIfNew(tx, iap: iap)
                }
                await tx.finish()
            } catch {
                print("StoreKit tx failed: \(error)")
            }
        }
    }
}
