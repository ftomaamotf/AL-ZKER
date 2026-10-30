# Apple Watch lifetime purchase

The watch app is unlocked by a **single non-consumable in-app purchase**, not a subscription. The iPhone remains free for dhikr, goals and qibla. Existing iPhone subscriptions for sounds and mistake-lock remain separate and do not unlock the watch. The bundled iPhone/watch app record is retained; this is not a separately priced watch-only App Store listing.

## Product to create in App Store Connect

- Reference name: Watch Lifetime Unlock
- Product ID: `com.abduallhajmi.fadhkuruni.watch.lifetime`
- Type: **Non-Consumable**
- Requested base storefront: United States, USD **1.00** (not a monthly/yearly price)
- Arabic display name: الشراء الدائم لنسخة الساعة
- Arabic description: افتح نسخة الساعة بشراء دائم واحد دون اشتراك.
- English display name: Watch Lifetime Unlock
- English description: Unlock Fadhkuruni on Apple Watch with a single purchase, no subscription.
- Family Sharing: off in the local test configuration; access is tied to the purchasing Apple account.

Keep the app's download free because the same App Store record includes the iPhone. Configure the one-time purchase product above instead. Ensure Paid Apps agreements and any required business/tax/banking details are valid, set availability and local prices, add the required review screenshot and submit the IAP with the app version. Do not change the prices of the existing iPhone subscription products to implement the watch price. Regional prices/taxes/currencies are managed in App Store Connect. The purchase UI always displays Apple's localized `Product.displayPrice` and never substitutes a hardcoded price if the product is unavailable.

**Store configuration status:** The local code and test configuration are ready. Product creation, actual storefront pricing and submission have not been completed. The user explicitly authorized accepting the presented App Store Connect Terms of Service. On resuming, that agreement was no longer shown. Reloading displayed Apple’s error: "Your Apple Account isn't enabled for App Store Connect." No agreement acceptance, product creation or price change was performed by the agent. Sign in with the developer account that owns Fadhkuruni (or an appropriately authorized team account) before continuing.

## Implementation

`WatchPurchaseAccess.swift` and `WatchPurchaseView.swift` are identical in both targets. Only verified, non-revoked transactions for the exact non-consumable product grant access. There is no time limit, free-trial clock, subscription entitlement, UserDefaults purchase flag or automatic DEBUG unlock for the watch purchase. StoreKit cached verified entitlements support reopening offline after ownership is known on that device. Restoring after reinstall/new devices may require Apple connectivity and the same purchasing account.

The watch root uses `WatchPurchaseGate`. Before purchase it shows price/purchase/restore/support/privacy controls, without starting the counting keep-awake session. After verification it shows the existing gesture welcome and watch counter. Locking or refunds do not erase counters or dhikr. The watch's former subscription manager and subscription screen were removed. The iPhone offers purchase/restore under Watch Settings and a separate link in its subscription screen.

Transactions from pending approval, cancelled payments, verification failures, wrong products and subscription purchases do not unlock the watch. Transaction updates and foreground refresh reconcile entitlement changes, including refunds/revocation. Repeated purchase taps are coalesced. Refresh calls await shared verification rather than granting access during an in-flight check.

WatchConnectivity sends only a `refreshWatchPurchase` hint after a change. The peer independently asks StoreKit for verified entitlements. A message from the phone, a transferred boolean or saved local counter data cannot grant purchase access. Delivery is eventual and may require opening the peer app or explicitly restoring there.

## Local testing

`WatchLifetime.storekit` contains a local test-only non-consumable priced at USD 1.00. Added schemes:

- `فذكروني - Watch Purchase Test`
- `فذكروني Watch App - Watch Purchase Test`

Their Run actions use the local StoreKit configuration. Normal schemes and Archive actions do not select a local configuration. The local configuration is not uploaded to App Store Connect. It contains only the watch lifetime product, so it is not intended for testing the existing iPhone subscriptions.

Run `sh Tests/WatchPurchaseRegression/run.sh` for 25 executable tests of the **actual purchase coordinator** using a controlled StoreKit adapter. These cover successful purchase, entitlement persistence, invalid/unrelated/revoked records, cancellation, pending approval, failure recovery, restore, localized price loading, asynchronous approval/revocation, concurrent refresh and double-tap purchase prevention. They do not simulate Apple payment sheets or assert a successful real/sandbox transaction.

The iPhone/watch Release build and the coordinator tests pass. Standalone SKTestSession validation could not run successfully outside an app/test host in this environment; the test configuration still requires an Xcode-hosted run. Before release, exercise the payment sheet, Ask to Buy, cancel/failure, restore after reinstall, refund/revocation and iPhone-to-watch ownership reconciliation on paired physical devices using Sandbox/StoreKit testing. No real purchase was made and no release was published.

References:
- https://developer.apple.com/documentation/watchos-apps/creating-independent-watchos-apps
- https://developer.apple.com/documentation/storekit/transaction/currententitlements
- https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode
