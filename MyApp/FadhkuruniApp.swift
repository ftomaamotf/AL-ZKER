import SwiftUI

@main
struct FadhkuruniApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        PrayerAlertPreference.configureLongToneForAllPrayersIfNeeded()
        // ضمان تفعيل مستلم الإشعارات فور إقلاع التطبيق لعرض البانر وتشغيل الصوت حتى والتطبيق مفتوح
        _ = NotificationManager.shared
        PrayerAdhanRecorder.ensureBuiltInSoundsInLibraryDirectory()
    }

    var body: some Scene {
        WindowGroup {
            DrivingModePreviewGate { DrivingModeGate { GestureWelcomeGate { ContentView() } } }
                .task {
                    // Ask for motion/location access as soon as the app opens; StoreKit refresh can wait on the network.
                    WatchSyncService.shared.activateSession()
                    DrivingModeManager.shared.start()
                    DhikrSummaryNotificationScheduler.shared.refresh()
                    PrayerTimesManager.shared.refresh()
                    IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
                    TapFeedback.shared.prepare()
                    WatchPurchaseAccess.shared.onPurchaseChanged = { WatchSyncService.shared.notifyWatchPurchaseChanged() }
                    await WatchPurchaseAccess.shared.refresh()
                }
                .task(id: scenePhase) {
                    guard scenePhase == .active else { return }
                    while !Task.isCancelled {
                        WatchSyncService.shared.refreshVisibleCounter()
                        do { try await Task.sleep(for: .seconds(2)) }
                        catch { return }
                    }
                }
                .onChange(of: scenePhase) { _, phase in
                    IconBadgeManager.shared.update(count: WatchSyncService.shared.currentCount)
                    if phase == .active {
                        // Reachability may stay unchanged while the app is suspended.
                        WatchSyncService.shared.refreshSynchronization()
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
