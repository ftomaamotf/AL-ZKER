import Foundation
import Combine
import StoreKit

struct WatchEntitlement: Sendable {
    let productID: String
    let verified: Bool
    let nonConsumable: Bool
    let revoked: Bool
    var grantsAccess: Bool {
        productID == WatchPurchaseAccess.productID && verified && nonConsumable && !revoked
    }
}

struct WatchStoreProduct: Sendable {
    let id: String
    let displayPrice: String
}

enum WatchPurchaseOutcome: Sendable {
    case purchased(WatchEntitlement), pending, cancelled, unverified
}

@MainActor
protocol WatchPurchaseStore {
    func loadProduct() async throws -> WatchStoreProduct?
    func entitlements() async -> [WatchEntitlement]
    func purchase() async throws -> WatchPurchaseOutcome
    func restore() async throws
    func updates() -> AsyncStream<Void>
}

@MainActor
final class AppleWatchPurchaseStore: WatchPurchaseStore {
    private var product: Product?

    func loadProduct() async throws -> WatchStoreProduct? {
        #if DEBUG
        return WatchStoreProduct(id: WatchPurchaseAccess.productID, displayPrice: "مجاني للمطور")
        #else
        product = try await Product.products(for: [WatchPurchaseAccess.productID]).first {
            $0.id == WatchPurchaseAccess.productID && $0.type == .nonConsumable
        }
        return product.map { WatchStoreProduct(id: $0.id, displayPrice: $0.displayPrice) }
        #endif
    }

    private static func entitlement(_ transaction: Transaction, verified: Bool) -> WatchEntitlement {
        WatchEntitlement(productID: transaction.productID, verified: verified,
                         nonConsumable: transaction.productType == .nonConsumable,
                         revoked: transaction.revocationDate != nil)
    }

    func entitlements() async -> [WatchEntitlement] {
        #if DEBUG
        // Developer unlock in DEBUG builds (مجاني للمطور)
        return [WatchEntitlement(productID: WatchPurchaseAccess.productID, verified: true, nonConsumable: true, revoked: false)]
        #else
        var result: [WatchEntitlement] = []
        // StoreKit verifies cached entitlements offline; no local boolean grants access.
        for await verification in Transaction.currentEntitlements {
            switch verification {
            case .verified(let transaction): result.append(Self.entitlement(transaction, verified: true))
            case .unverified(let transaction, _): result.append(Self.entitlement(transaction, verified: false))
            }
        }
        return result
        #endif
    }

    func purchase() async throws -> WatchPurchaseOutcome {
        #if DEBUG
        let record = WatchEntitlement(productID: WatchPurchaseAccess.productID, verified: true, nonConsumable: true, revoked: false)
        return .purchased(record)
        #else
        guard let product, product.id == WatchPurchaseAccess.productID, product.type == .nonConsumable else {
            throw StoreError.productUnavailable
        }
        switch try await product.purchase() {
        case .success(.verified(let transaction)):
            let record = Self.entitlement(transaction, verified: true)
            if record.grantsAccess { await transaction.finish() }
            return .purchased(record)
        case .success(.unverified): return .unverified
        case .pending: return .pending
        case .userCancelled: return .cancelled
        @unknown default: return .unverified
        }
        #endif
    }

    func restore() async throws {
        #if !DEBUG
        try await AppStore.sync()
        #endif
    }

    func updates() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let listener = Task {
                for await verification in Transaction.updates {
                    guard !Task.isCancelled else { break }
                    switch verification {
                    case .verified(let transaction) where transaction.productID == WatchPurchaseAccess.productID:
                        continuation.yield(())
                        await transaction.finish()
                    case .unverified(let transaction, _) where transaction.productID == WatchPurchaseAccess.productID:
                        continuation.yield(())
                    default: break
                    }
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in listener.cancel() }
        }
    }
    enum StoreError: Error { case productUnavailable }
}

@MainActor
final class WatchPurchaseAccess: ObservableObject {
    nonisolated static let productID = "com.abduallhajmi.fadhkuruni.watch.lifetime"
    static let shared = WatchPurchaseAccess(store: AppleWatchPurchaseStore())
    @Published private(set) var isPurchased = false
    @Published private(set) var isChecking = true
    @Published private(set) var isBusy = false
    @Published private(set) var isLoadingProduct = false
    @Published private(set) var product: WatchStoreProduct?
    @Published private(set) var message: String?
    var onPurchaseChanged: (() -> Void)?
    private let store: any WatchPurchaseStore
    private var updatesTask: Task<Void, Never>?
    private var refreshing = false
    private var refreshAgain = false
    private var refreshWaiters: [CheckedContinuation<Void, Never>] = []

    init(store: any WatchPurchaseStore, listenForUpdates: Bool = true) {
        self.store = store
        #if DEBUG
        if store is AppleWatchPurchaseStore {
            self.isPurchased = true
            self.isChecking = false
        }
        #endif
        if listenForUpdates {
            updatesTask = Task { [weak self, store] in
                for await _ in store.updates() {
                    guard !Task.isCancelled else { return }
                    await self?.refresh()
                    self?.onPurchaseChanged?()
                }
            }
        }
    }

    func refresh() async {
        guard !refreshing else {
            refreshAgain = true
            await withCheckedContinuation { refreshWaiters.append($0) }
            return
        }
        refreshing = true
        repeat {
            refreshAgain = false
            let records = await store.entitlements()
            isPurchased = records.contains { $0.grantsAccess }
        } while refreshAgain
        isChecking = false
        refreshing = false
        let waiters = refreshWaiters
        refreshWaiters.removeAll()
        for waiter in waiters { waiter.resume() }
    }

    func loadProduct() async {
        guard !isLoadingProduct else { return }
        isLoadingProduct = true
        defer { isLoadingProduct = false }
        do {
            let result = try await store.loadProduct()
            product = result?.id == Self.productID ? result : nil
            if product == nil { message = "الشراء غير متاح حالياً. حاول إعادة التحميل، أو استعد شراءك السابق." }
            else { message = nil }
        } catch {
            message = "تعذر تحميل سعر نسخة الساعة. تحقق من الاتصال وحاول مجدداً."
        }
    }

    func purchase() async {
        guard !isBusy, !isPurchased, product?.id == Self.productID else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            switch try await store.purchase() {
            case .purchased(let record) where record.grantsAccess:
                isPurchased = true
                await refresh()
                onPurchaseChanged?()
            case .pending:
                message = "عملية الشراء تنتظر الموافقة. ستُفتح نسخة الساعة بعد تأكيد Apple."
            case .cancelled: break
            case .unverified, .purchased:
                message = "تعذر التحقق من الشراء. لم تُفتح نسخة الساعة."
            }
        } catch { message = "لم يكتمل الشراء. تحقق من الاتصال وحاول مجدداً." }
    }

    func restore() async {
        guard !isBusy else { return }
        isBusy = true; message = nil
        defer { isBusy = false }
        do {
            // Authentication is requested only after an explicit Restore tap.
            try await store.restore()
            await refresh()
            message = isPurchased ? "تمت استعادة الشراء الدائم لنسخة الساعة." : "لا يوجد شراء دائم لنسخة الساعة على حساب Apple الحالي."
            onPurchaseChanged?()
        } catch { message = "تعذرت استعادة الشراء. تحقق من حساب Apple والاتصال." }
    }
}
