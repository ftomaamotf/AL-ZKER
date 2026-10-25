import SwiftUI
import WatchKit

struct WatchContentView: View {
    @ObservedObject private var sync = WatchSyncService.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("فَذَكِّرُونِي")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Text(sync.currentZekr)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("\(sync.currentCount)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())

                Text("الهدف: \(sync.target)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button {
                    let next = sync.currentCount + 1
                    sync.sendSyncPayload(count: next, zekr: sync.currentZekr, target: sync.target)
                    WKInterfaceDevice.current().play(.click)
                    if next == sync.target {
                        WKInterfaceDevice.current().play(.success)
                    }
                } label: {
                    Text("سَبِّح")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)

                HStack {
                    Button {
                        sync.sendSyncPayload(count: 0, zekr: sync.currentZekr, target: sync.target)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("تصفير العداد")

                    Button {
                        let nextTarget = sync.target >= 100 ? 33 : sync.target + 33
                        sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: nextTarget)
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "target")
                    }
                    .accessibilityLabel("تغيير الهدف")
                }
                .buttonStyle(.bordered)
            }
            .padding(.vertical, 6)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    WatchContentView()
}
