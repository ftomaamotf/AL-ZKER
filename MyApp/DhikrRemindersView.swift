import SwiftUI

struct DhikrCustomReminder: Identifiable, Codable, Hashable {
    var id = UUID()
    var title: String
    var message: String
    var minutes: Int
    var isEnabled: Bool = true
}

/// Notification controls intentionally live separately from statistics.
struct DhikrRemindersView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @State private var customReminders = DhikrCustomReminder.loadAll()
    @State private var editor: DhikrCustomReminder?
    @State private var showStartFromTodayConfirmation = false
    @State private var resetErrorMessage: String?

    var body: some View {
        Form {
            Section("ملخصات الذكر") {
                summaryRow(title: sync.currentZekr, symbol: "sun.max.fill", detail: selectedDhikrComparison)
                
                NavigationLink {
                    DhikrStatisticsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.green)
                            .frame(width: 34, height: 34)
                            .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("ملخص أيام الأسبوع والمقارنات")
                                .font(.body.weight(.medium))
                            Text("معرفة تسبيح كل يوم ومقارنته باليوم السابق واللاحق")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }

                Button("بدء الإحصاءات من اليوم", role: .destructive) {
                    showStartFromTodayConfirmation = true
                }
            }

            Section("تذكيراتك المخصصة") {
                if customReminders.isEmpty {
                    Text("أضف تذكيراً بالوقت والنص اللذين تختارهما.")
                        .foregroundStyle(.secondary)
                }
                ForEach($customReminders) { $reminder in
                    Button {
                        editor = reminder
                    } label: {
                        HStack {
                            VStack(alignment: .trailing, spacing: 3) {
                                Text(reminder.title).foregroundStyle(.primary)
                                Text(reminder.message).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Text(timeText(reminder.minutes)).monospacedDigit().foregroundStyle(.green)
                            Toggle("", isOn: $reminder.isEnabled)
                                .labelsHidden()
                                .tint(.green)
                                .onChange(of: reminder.isEnabled) { _, _ in saveCustomReminders() }
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete(perform: deleteCustomReminders)
                Button {
                    editor = DhikrCustomReminder(title: "تذكير", message: "لا تنسَ ذكر الله", minutes: 20 * 60)
                } label: {
                    Label("تذكير جديد", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("التذكيرات")
        .task { DhikrSummaryNotificationScheduler.shared.refresh() }
        .alert("بدء الإحصاءات من اليوم؟", isPresented: $showStartFromTodayConfirmation) {
            Button("إلغاء", role: .cancel) {}
            Button("بدء جديد", role: .destructive) {
                Task {
                    switch await BiometricStatisticsDeletionAuthorizer.authorize() {
                    case .success:
                        sync.clearStatistics()
                    case .failure(let failure):
                        resetErrorMessage = failure.message
                    }
                }
            }
        } message: {
            Text("سيُحذف سجل أرقام الإحصاءات القديم فقط، ويبدأ احتساب اليوم من الصفر. لن تُحذف الأذكار أو الأهداف أو العداد الحالي.")
        }
        .alert("لم يتم بدء الإحصاءات الجديدة", isPresented: Binding(get: { resetErrorMessage != nil }, set: { if !$0 { resetErrorMessage = nil } })) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text(resetErrorMessage ?? "")
        }
        .sheet(item: $editor) { selectedReminder in
            DhikrCustomReminderEditor(reminder: selectedReminder) { savedReminder in
                if let index = customReminders.firstIndex(where: { $0.id == savedReminder.id }) {
                    customReminders[index] = savedReminder
                } else {
                    customReminders.append(savedReminder)
                }
                saveCustomReminders()
            }
        }
    }

    private func saveCustomReminders() {
        DhikrCustomReminder.saveAll(customReminders)
        DhikrSummaryNotificationScheduler.shared.refreshCustomReminder()
    }

    private func deleteCustomReminders(at offsets: IndexSet) {
        customReminders.remove(atOffsets: offsets)
        saveCustomReminders()
    }

    private func timeText(_ minutes: Int) -> String {
        let date = Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(minutes) * 60)
        return date.formatted(date: .omitted, time: .shortened)
    }

    private var selectedDhikrComparison: String {
        comparison(
            current: sync.statistics.totalToday(for: sync.currentZekr),
            previous: sync.statistics.totalYesterday(for: sync.currentZekr),
            period: "البارحة",
            label: "اليوم"
        )
    }

    private func comparison(current: Int, previous: Int, period: String, label: String) -> String {
        guard previous > 0 else { return "عدد الأذكار \(label): \(current)." }
        if current > previous { return "عدد الأذكار \(label): \(current)، أكثر من \(period) بـ \(current - previous)." }
        if current < previous { return "عدد الأذكار \(label): \(current)، أقل من \(period) بـ \(previous - current)." }
        return "عدد الأذكار \(label): \(current)، مثل \(period)."
    }

    private func summaryRow(title: String, symbol: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.green)
                .frame(width: 34, height: 34)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 3)
    }
}

private struct DhikrCustomReminderEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var reminder: DhikrCustomReminder
    let onSave: (DhikrCustomReminder) -> Void

    init(reminder: DhikrCustomReminder, onSave: @escaping (DhikrCustomReminder) -> Void) {
        _reminder = State(initialValue: reminder)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("اسم التذكير", text: $reminder.title)
                TextField("نص التذكير", text: $reminder.message, axis: .vertical)
                    .lineLimit(2...4)
                DatePicker("الوقت", selection: Binding(
                    get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(reminder.minutes) * 60) },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        reminder.minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                    }
                ), displayedComponents: .hourAndMinute)
                Toggle("تشغيل التذكير", isOn: $reminder.isEnabled).tint(.green)
            }
            .navigationTitle("تذكير مخصص")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("إلغاء") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("حفظ") {
                        reminder.title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        reminder.message = reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
                        if reminder.title.isEmpty || reminder.title == "تذكير بالذكر" { reminder.title = "تذكير" }
                        if reminder.message.isEmpty { reminder.message = "لا تنسَ ذكر الله" }
                        onSave(reminder)
                        dismiss()
                    }
                }
            }
        }
    }
}

extension DhikrCustomReminder {
    static let storageKey = "fadhkuruni_custom_reminders_v1"

    static func loadAll() -> [DhikrCustomReminder] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              var reminders = try? JSONDecoder().decode([DhikrCustomReminder].self, from: data) else { return [] }
        var didMigrate = false
        for i in 0..<reminders.count {
            if reminders[i].title == "تذكير بالذكر" {
                reminders[i].title = "تذكير"
                didMigrate = true
            }
        }
        if didMigrate {
            saveAll(reminders)
        }
        return reminders
    }

    static func saveAll(_ reminders: [DhikrCustomReminder]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(reminders), forKey: storageKey)
    }
}
