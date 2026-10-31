import SwiftUI

@main
struct FadhkuruniWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            DrivingModePreviewGate { DrivingModeGate { WatchPurchaseGate() } }
                .task {
                    TapFeedback.shared.prepare()
                    WatchPurchaseAccess.shared.onPurchaseChanged = { WatchSyncService.shared.notifyWatchPurchaseChanged() }
                    WatchSyncService.shared.activateSession()
                    await WatchPurchaseAccess.shared.refresh()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active { TapFeedback.shared.prepare(); Task { await WatchPurchaseAccess.shared.refresh() } }
                }
        }
    }
}
