//
//  PurchaseManager.swift
//  Outdoor Day
//
//  StoreKit 2 non-consumable: remove ads + unlock 3-day outlook.
//

import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let productID = "us.letshang.outdoor_day.remove_ads"

    @Published private(set) var isPremium = false
    @Published private(set) var product: Product?
    @Published var purchaseError: String?
    @Published var isPurchasing = false

    private var updatesTask: Task<Void, Never>?

    private init() {
        updatesTask = Task { await listenForTransactions() }
        Task {
            await refreshEntitlements()
            await loadProduct()
            if ProcessInfo.processInfo.arguments.contains("-forcePremium")
                || ProcessInfo.processInfo.environment["FORCE_PREMIUM"] == "1"
                || UserDefaults.standard.bool(forKey: "forcePremium") {
                isPremium = true
            }
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    func loadProduct() async {
        do {
            let products = try await Product.products(for: [Self.productID])
            product = products.first
        } catch {
            purchaseError = "Couldn’t load upgrade options."
        }
    }

    func purchase() async {
        await loadProduct()
        guard let product else {
            purchaseError = "Upgrade isn’t available yet. Try again shortly."
            return
        }
        isPurchasing = true
        purchaseError = nil
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isPremium = true
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed. Try again."
        }
    }

    func restore() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseError = "Restore failed."
        }
    }

    func refreshEntitlements() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result),
               transaction.productID == Self.productID {
                entitled = true
            }
        }
        isPremium = entitled
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if let transaction = try? checkVerified(result) {
                await transaction.finish()
                if transaction.productID == Self.productID {
                    isPremium = true
                }
            }
        }
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw URLError(.userAuthenticationRequired)
        case .verified(let safe):
            return safe
        }
    }
}
