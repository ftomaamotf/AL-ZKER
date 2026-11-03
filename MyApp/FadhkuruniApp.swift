import SwiftUI

@main
struct FadhkuruniApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DrivingModePreviewGate { DrivingModeGate { GestureWelcomeGate { ContentView() } } }
                .task {
                    // Ask for motion/location access as soon as the app opens; StoreKit refresh can wait on the network.
                    DrivingModeManager.shared.start()
                    DhikrSummaryNotificationScheduler.shared.refresh()
                    PrayerTimesManager.shared.refresh()
                    IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
                    TapFeedback.shared.prepare()
                    WatchPurchaseAccess.shared.onPurchaseChanged = { WatchSyncService.shared.notifyWatchPurchaseChanged() }
                    await WatchPurchaseAccess.shared.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
                    if phase == .active {
                        TapFeedback.shared.prepare()
                        DrivingModeManager.shared.start()
                        DhikrSummaryNotificationScheduler.shared.refresh()
                        PrayerTimesManager.shared.refresh()
                        Task { await WatchPurchaseAccess.shared.refresh() }
                    }
                }
        }
    }
}
