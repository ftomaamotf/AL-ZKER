import SwiftUI

@main
struct FadhkuruniApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // ملخص الذكر اليومي خدمة تلقائية للجميع؛ نعيد تفعيلها أيضاً لمن أوقفها في إصدار سابق.
        UserDefaults.standard.set(true, forKey: "fadhkuruni_daily_summary_enabled")
        PrayerAlertPreference.configureLongToneForAllPrayersIfNeeded()
        // ضمان تفعيل مستلم الإشعارات فور إقلاع التطبيق لعرض البانر وتشغيل الصوت حتى والتطبيق مفتوح
        _ = NotificationManager.shared
        PrayerAdhanRecorder.ensureBuiltInSoundsInLibraryDirectory()
        #if DEBUG
        // Used only when launching from Xcode with the test argument. It lets
        // us verify the selected prayer sound on the actual iPhone.
        if ProcessInfo.processInfo.arguments.contains("--prayer-sound-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                let delayed = ProcessInfo.processInfo.arguments.contains("--prayer-sound-test-delayed")
                PrayerAdhanRecorder.shared.scheduleTestNotification(
                    for: "fajr",
                    title: "الفجر",
                    after: delayed ? 20 : 5
                )
            }
        }
        if ProcessInfo.processInfo.arguments.contains("--default-sound-test") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                PrayerAdhanRecorder.shared.scheduleDefaultSoundTest()
            }
        }
        #endif
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
                    WatchSyncService.shared.publishPrayerTimesToWatch()
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
                        WatchSyncService.shared.publishPrayerTimesToWatch()
                        Task { await WatchPurchaseAccess.shared.refresh() }
                    } else if phase == .background {
                        DhikrSummaryNotificationScheduler.shared.refreshDailySummaryReminder()
                    }
                }
        }
    }
}
