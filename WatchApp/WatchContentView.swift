import SwiftUI
import WatchKit

struct WatchContentView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @State private var showAzkarListSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("فَذَكِّرُونِي")
                    .font(.headline)
                    .multilineTextAlignment(.center)

                Button {
                    showAzkarListSheet = true
                } label: {
                    HStack(spacing: 6) {
                        Text(sync.currentZekr)
                            .font(.footnote)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                        
                        Image(systemName: "chevron.down.circle")
                            .font(.caption2)
                            .foregroundStyle(.green)
                    }
                }
                .buttonStyle(.plain)

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
                        showAzkarListSheet = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel("قائمة الأذكار")

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
        .sheet(isPresented: $showAzkarListSheet) {
            NavigationStack {
                List {
                    ForEach(sync.azkarList) { item in
                        Button {
                            sync.selectZekr(item)
                            WKInterfaceDevice.current().play(.click)
                            showAzkarListSheet = false
                        } label: {
                            HStack {
                                if sync.currentZekr == item.title {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green)
                                }
                                Text(item.title)
                                    .font(.footnote)
                                    .foregroundStyle(sync.currentZekr == item.title ? .green : .primary)
                                Spacer()
                                Text("\(item.defaultTarget)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("اختر الذكر")
            }
        }
    }
}

#Preview {
    WatchContentView()
}
