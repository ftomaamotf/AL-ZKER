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
    @State private var customReminders = DhikrCustomReminder.loadAll()
    @State private var editor: DhikrCustomReminder?

    var body: some View {
        Form {
            Section("ملخص اليوم") {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ملخص اليوم")
                    Text("يصل تلقائياً عند دخول الظلام، ويقارن عدد أذكار اليوم بالبارحة اعتماداً على موقعك.")
                        .font(.caption).foregroundStyle(.secondary)
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
                    editor = DhikrCustomReminder(title: "تذكير بالذكر", message: "لا تنسَ ذكر الله", minutes: 20 * 60)
                } label: {
                    Label("تذكير جديد", systemImage: "plus.circle.fill")
                }
            }
        }
        .navigationTitle("التذكيرات")
        .task { DhikrSummaryNotificationScheduler.shared.refresh() }
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
                        if reminder.title.isEmpty { reminder.title = "تذكير بالذكر" }
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
              let reminders = try? JSONDecoder().decode([DhikrCustomReminder].self, from: data) else { return [] }
        return reminders
    }

    static func saveAll(_ reminders: [DhikrCustomReminder]) {
        UserDefaults.standard.set(try? JSONEncoder().encode(reminders), forKey: storageKey)
    }
}
