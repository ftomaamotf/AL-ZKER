import Foundation

@MainActor
final class TestWatchStore: WatchPurchaseStore {
    var records: [WatchEntitlement] = []
    var offeredProduct: WatchStoreProduct? = WatchStoreProduct(id: WatchPurchaseAccess.productID, displayPrice: "$1.00")
    var outcome = WatchPurchaseOutcome.cancelled
    var purchaseError = false
    var restoreError = false
    var loadError = false
    var delayReads = false
    var delayPurchase = false
    var purchases = 0
    var restores = 0
    var continuation: AsyncStream<Void>.Continuation?
    var afterPurchase: [WatchEntitlement]?
    enum Failure: Error { case simulated }
    func loadProduct() async throws -> WatchStoreProduct? {
        if loadError { throw Failure.simulated }
        return offeredProduct
    }
    func entitlements() async -> [WatchEntitlement] {
        if delayReads { try? await Task.sleep(for: .milliseconds(10)) }
        return records
    }
    func purchase() async throws -> WatchPurchaseOutcome {
        purchases += 1
        if delayPurchase { try? await Task.sleep(for: .milliseconds(10)) }
        if purchaseError { throw Failure.simulated }
        if let afterPurchase { records = afterPurchase }
        return outcome
    }
    func restore() async throws {
        restores += 1
        if restoreError { throw Failure.simulated }
    }
    func updates() -> AsyncStream<Void> {
        AsyncStream { continuation = $0 }
    }
}

@main
struct WatchPurchaseRegression {
    @MainActor
    static func main() async {
        var checks = 0
        func check(_ condition: @autoclosure () -> Bool, _ label: String) {
            precondition(condition(), label); checks += 1
        }
        func record(id: String = WatchPurchaseAccess.productID, verified: Bool = true,
                    permanent: Bool = true, revoked: Bool = false) -> WatchEntitlement {
            WatchEntitlement(productID: id, verified: verified, nonConsumable: permanent, revoked: revoked)
        }
        let valid = record()
        let store = TestWatchStore()
        let access = WatchPurchaseAccess(store: store, listenForUpdates: false)
        await access.refresh()
        check(!access.isPurchased && !access.isChecking, "fresh install stays locked")
        await access.purchase()
        check(store.purchases == 0, "unavailable product cannot trigger payment")
        await access.loadProduct()
        check(access.product?.displayPrice == "$1.00", "localized StoreKit price displayed without hardcoded production price")
        store.outcome = .purchased(valid); store.afterPurchase = [valid]
        await access.purchase()
        check(access.isPurchased && !access.isBusy, "verified lifetime purchase unlocks")
        await access.purchase()
        check(store.purchases == 1, "already-owned purchase is not submitted again")
        let relaunched = WatchPurchaseAccess(store: store, listenForUpdates: false)
        await relaunched.refresh()
        check(relaunched.isPurchased, "verified cached ownership survives relaunch/offline without a timer")
        store.records = []; await access.refresh()
        check(!access.isPurchased, "refund/revocation removes access without touching saved counters")
        for invalid in [record(verified: false), record(revoked: true), record(permanent: false), record(id: "com.abduallhajmi.fadhkuruni.premium.monthly")] {
            store.records = [invalid]; await access.refresh()
            check(!access.isPurchased, "invalid, revoked, subscription and unrelated records cannot unlock watch")
        }
        store.records = []; store.afterPurchase = nil
        store.outcome = .cancelled; await access.purchase()
        check(!access.isPurchased && !access.isBusy && access.message == nil, "cancelled payment stays locked and clears busy")
        store.outcome = .pending; await access.purchase()
        check(!access.isPurchased && access.message != nil, "pending approval cannot unlock")
        store.outcome = .unverified; await access.purchase()
        check(!access.isPurchased && access.message != nil, "unverified payment cannot unlock")
        store.outcome = .purchased(record(id: "wrong-product")); await access.purchase()
        check(!access.isPurchased, "mismatched successful payment cannot unlock")
        store.purchaseError = true; await access.purchase()
        check(!access.isPurchased && !access.isBusy && access.message != nil, "purchase error is recoverable")
        store.purchaseError = false
        store.records = [valid]; await access.restore()
        check(access.isPurchased && store.restores == 1, "explicit restore recovers lifetime access")
        store.records = []; await access.restore()
        check(!access.isPurchased && access.message != nil, "restore without purchase does not grant access")
        store.restoreError = true; await access.restore()
        check(!access.isBusy && !access.isPurchased, "restore failure does not unlock or get stuck")
        let unavailable = TestWatchStore(); unavailable.offeredProduct = nil
        let retry = WatchPurchaseAccess(store: unavailable, listenForUpdates: false)
        await retry.loadProduct(); await retry.purchase()
        check(retry.product == nil && unavailable.purchases == 0, "missing App Store product leaves restore available without fake purchase")
        unavailable.offeredProduct = WatchStoreProduct(id: WatchPurchaseAccess.productID, displayPrice: "1,00 US$")
        await retry.loadProduct()
        check(retry.product?.displayPrice == "1,00 US$" && retry.message == nil, "product loading recovers with storefront formatting")
        let live = TestWatchStore()
        let listener = WatchPurchaseAccess(store: live)
        for _ in 0..<20 where live.continuation == nil { await Task.yield() }
        live.records = [valid]; live.continuation?.yield(())
        for _ in 0..<100 where !listener.isPurchased { try? await Task.sleep(for: .milliseconds(5)) }
        check(listener.isPurchased, "delayed approval/cross-device update unlocks only after entitlement verification")
        live.records = []; live.continuation?.yield(())
        for _ in 0..<100 where listener.isPurchased { try? await Task.sleep(for: .milliseconds(5)) }
        check(!listener.isPurchased, "live revocation closes access")
        live.continuation?.finish()
        let concurrent = TestWatchStore(); concurrent.records = [valid]; concurrent.delayReads = true
        let sharedRefresh = WatchPurchaseAccess(store: concurrent, listenForUpdates: false)
        async let firstRefresh: Void = sharedRefresh.refresh()
        async let secondRefresh: Void = sharedRefresh.refresh()
        _ = await (firstRefresh, secondRefresh)
        check(sharedRefresh.isPurchased && !sharedRefresh.isChecking, "coalesced refresh callers await verified state")
        let doubleTapStore = TestWatchStore(); doubleTapStore.delayPurchase = true
        doubleTapStore.outcome = .purchased(valid); doubleTapStore.afterPurchase = [valid]
        let doubleTap = WatchPurchaseAccess(store: doubleTapStore, listenForUpdates: false)
        await doubleTap.loadProduct()
        async let firstBuy: Void = doubleTap.purchase()
        async let secondBuy: Void = doubleTap.purchase()
        _ = await (firstBuy, secondBuy)
        check(doubleTapStore.purchases == 1 && doubleTap.isPurchased, "simultaneous purchase taps submit only one transaction")
        print("Passed \(checks) watch-purchase regression checks")
    }
}
