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
                // A restore or family-shared entitlement can also surface here with
                // no price and/or a revocation date — not a new purchase, so don't count it.
                if let iap = IAPProduct(rawValue: product.id),
                   let price = tx.price, tx.revocationDate == nil {
                    onPurchaseComplete?(iap, price)
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
                    // listenForTransactions() delivers every transaction, including
                    // restores and family-shared entitlements — those have no price
                    // and/or a revocation date. A restore is not a new purchase.
                    if let price = tx.price, tx.revocationDate == nil {
                        onPurchaseComplete?(iap, price)
                    }
                }
                await tx.finish()
            } catch {
                print("StoreKit tx failed: \(error)")
            }
        }
    }
}
