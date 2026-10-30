import SwiftUI

@main
struct FadhkuruniApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            GestureWelcomeGate { ContentView() }
                .task {
                    IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
                    TapFeedback.shared.prepare()
                    WatchPurchaseAccess.shared.onPurchaseChanged = { WatchSyncService.shared.notifyWatchPurchaseChanged() }
                    await WatchPurchaseAccess.shared.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
                    if phase == .active { TapFeedback.shared.prepare(); Task { await WatchPurchaseAccess.shared.refresh() } }
                }
        }
    }
}
