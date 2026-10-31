import SwiftUI
import WatchKit

struct WatchAddZekrView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var target = 33

    private var titleKey: String { DhikrText.key(title) }
    private var existingItem: ZekrItem? {
        guard !titleKey.isEmpty else { return nil }
        return sync.azkarList.first { DhikrText.key($0.title) == titleKey }
    }
    private var canSave: Bool { !titleKey.isEmpty && existingItem == nil }

    var body: some View {
        Form {
            Section("نص الذكر") {
                TextField("اكتب الذكر", text: $title)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .accessibilityLabel("نص الذكر الجديد")
            }

            Section("هدف التسبيح") {
                Stepper(value: $target, in: 1...10000) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("عدد المرات").font(.caption2).foregroundStyle(.secondary)
                        Text(target.formatted())
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                WatchTargetPresets(selection: $target)
            }

            if existingItem != nil {
                Section {
                    Text("هذا الذكر موجود بالفعل. يمكنك اختياره مع الاحتفاظ بعدّاده.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("اختيار الذكر الموجود") {
                        if let item = existingItem { selectAndClose(item) }
                    }
                    .tint(.green)
                }
            }

            Section {
                Button("حفظ واختيار") {
                    // Recheck against the live synchronized list before creating anything.
                    guard canSave else { return }
                    let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    sync.addZekr(title: trimmed, target: target)
                    if let item = sync.azkarList.first(where: { DhikrText.key($0.title) == titleKey }) {
                        selectAndClose(item)
                    }
                }
                .tint(.green)
                .disabled(!canSave)
                Button("إلغاء", role: .cancel) { dismiss() }
            }
        }
        .navigationTitle("ذكر جديد")
        .environment(\.layoutDirection, .rightToLeft)
    }

    private func selectAndClose(_ item: ZekrItem) {
        sync.selectZekr(item)
        WatchKeepAwakeManager.shared.recordCountingActivity()
        WKInterfaceDevice.current().play(.success)
        isPresented = false
    }
}
