import SwiftUI

@main
struct FadhkuruniWatchApp: App {
    @ObservedObject private var lang = AppLanguage.shared
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DrivingModePreviewGate {
                DrivingModeGate {
                    GestureWelcomeGate(storageKey: "fadhkuruni_watch_gesture_welcome_completed_v2") {
                        WatchContentView()
                    }
                }
            }
            .environment(\.layoutDirection, lang.layoutDirection)
            .environment(\.locale, lang.locale)
            .task {
                TapFeedback.shared.prepare()
                WatchPurchaseAccess.shared.onPurchaseChanged = { WatchSyncService.shared.notifyWatchPurchaseChanged() }
                WatchSyncService.shared.activateSession()
                await WatchPurchaseAccess.shared.refresh()
            }
            .task(id: scenePhase) {
                // SwiftUI cancels this loop when the scene becomes inactive.
                guard scenePhase == .active else { return }
                while !Task.isCancelled {
                    WatchSyncService.shared.refreshVisibleCounter()
                    do { try await Task.sleep(for: .seconds(2)) }
                    catch { return }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    TapFeedback.shared.prepare()
                    // Pull the phone ledger on every foreground entry, even when
                    // WCSession reachability did not change during suspension.
                    WatchSyncService.shared.refreshSynchronization()
                    Task { await WatchPurchaseAccess.shared.refresh() }
                }
            }
        }
    }
}
