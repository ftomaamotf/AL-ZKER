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
    @ObservedObject private var summariesAccess = DhikrSummariesSubscriptionAccess.shared
    @State private var customReminders = DhikrCustomReminder.loadAll()
    @State private var editor: DhikrCustomReminder?
    @State private var showStartFromTodayConfirmation = false
    @State private var resetErrorMessage: String?

    var body: some View {
        Form {
            Section(L10n.tr("ملخصات الذكر")) {
                summaryRow(title: L10n.zekrTitle(sync.currentZekr), symbol: "sun.max.fill", detail: selectedDhikrComparison)
                
                NavigationLink {
                    DhikrStatisticsView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(.green)
                            .frame(width: 34, height: 34)
                            .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(L10n.tr("ملخص أيام الأسبوع والمقارنات"))
                                .font(.body.weight(.medium))
                            Text(summariesAccess.statusDescription)
                                .font(.caption)
                                .foregroundStyle(summariesAccess.isSubscribed ? .green : (summariesAccess.isWithinFreeTrial ? .mint : .secondary))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 3)
                }

                // ملخص الذكر اليومي إلزامي ويصل عند صلاة العشاء.
                HStack(spacing: 12) {
                    Image(systemName: "moon.stars.fill")
                        .foregroundStyle(.indigo)
                        .frame(width: 34, height: 34)
                        .background(Color.indigo.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(L10n.tr("إشعار ملخص الذكر اليومي"))
                            .font(.body.weight(.medium))
                        Text(AppLanguage.shared.isEnglish ? "Arrives daily at Isha prayer (\(ishaDisplayTime))" : "يصلك يومياً عند صلاة العشاء (\(ishaDisplayTime))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(AppLanguage.shared.isEnglish ? "Automatic" : "تلقائي")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.green.opacity(0.12), in: Capsule())
                }
                .padding(.vertical, 3)

                Button(L10n.tr("بدء الإحصاءات من اليوم"), role: .destructive) {
                    showStartFromTodayConfirmation = true
                }
            }

            Section(L10n.tr("تذكيراتك المخصصة")) {
                if customReminders.isEmpty {
                    Text(L10n.tr("أضف تذكيراً بالوقت والنص اللذين تختارهما."))
                        .foregroundStyle(.secondary)
                }
                ForEach($customReminders) { $reminder in
                    Button {
                        editor = reminder
                    } label: {
                        HStack {
                            VStack(alignment: AppLanguage.shared.isRTL ? .trailing : .leading, spacing: 3) {
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
                    editor = DhikrCustomReminder(
                        title: AppLanguage.shared.isEnglish ? "Reminder" : "تذكير",
                        message: AppLanguage.shared.isEnglish ? "Remember Allah" : "لا تنسَ ذكر الله",
                        minutes: 20 * 60
                    )
                } label: {
                    Label(L10n.tr("تذكير جديد"), systemImage: "plus.circle.fill")
                }
            }
        }
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
        .navigationTitle(L10n.tr("التذكيرات"))
        .task { DhikrSummaryNotificationScheduler.shared.refresh() }
        .alert(L10n.tr("بدء الإحصاءات من اليوم؟"), isPresented: $showStartFromTodayConfirmation) {
            Button(L10n.tr("إلغاء"), role: .cancel) {}
            Button(L10n.tr("بدء جديد"), role: .destructive) {
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
            Text(L10n.tr("سيُحذف سجل أرقام الإحصاءات القديم فقط، ويبدأ احتساب اليوم من الصفر. لن تُحذف الأذكار أو الأهداف أو العداد الحالي."))
        }
        .alert(L10n.tr("لم يتم بدء الإحصاءات الجديدة"), isPresented: Binding(get: { resetErrorMessage != nil }, set: { if !$0 { resetErrorMessage = nil } })) {
            Button(L10n.tr("حسناً"), role: .cancel) {}
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
            period: AppLanguage.shared.isEnglish ? "yesterday" : "البارحة",
            label: AppLanguage.shared.isEnglish ? "today" : "اليوم"
        )
    }

    private var ishaDisplayTime: String {
        DhikrSummaryNotificationScheduler.shared.ishaFormattedTimeString()
    }

    private func comparison(current: Int, previous: Int, period: String, label: String) -> String {
        if AppLanguage.shared.isEnglish {
            guard previous > 0 else { return "Dhikr count \(label): \(current)." }
            if current > previous { return "Dhikr count \(label): \(current), \(current - previous) more than \(period)." }
            if current < previous { return "Dhikr count \(label): \(current), \(previous - current) fewer than \(period)." }
            return "Dhikr count \(label): \(current), same as \(period)."
        } else {
            guard previous > 0 else { return "عدد الأذكار \(label): \(current)." }
            if current > previous { return "عدد الأذكار \(label): \(current)، أكثر من \(period) بـ \(current - previous)." }
            if current < previous { return "عدد الأذكار \(label): \(current)، أقل من \(period) بـ \(previous - current)." }
            return "عدد الأذكار \(label): \(current)، مثل \(period)."
        }
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
                TextField(L10n.tr("اسم التذكير"), text: $reminder.title)
                TextField(L10n.tr("نص التذكير"), text: $reminder.message, axis: .vertical)
                    .lineLimit(2...4)
                DatePicker(L10n.tr("الوقت"), selection: Binding(
                    get: { Calendar.current.startOfDay(for: Date()).addingTimeInterval(Double(reminder.minutes) * 60) },
                    set: { date in
                        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                        reminder.minutes = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
                    }
                ), displayedComponents: .hourAndMinute)
                Toggle(L10n.tr("تشغيل التذكير"), isOn: $reminder.isEnabled).tint(.green)
            }
            .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
            .navigationTitle(L10n.tr("تذكير مخصص"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(L10n.tr("إلغاء")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("حفظ")) {
                        reminder.title = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
                        reminder.message = reminder.message.trimmingCharacters(in: .whitespacesAndNewlines)
                        if reminder.title.isEmpty || reminder.title == "تذكير بالذكر" {
                            reminder.title = AppLanguage.shared.isEnglish ? "Reminder" : "تذكير"
                        }
                        if reminder.message.isEmpty {
                            reminder.message = AppLanguage.shared.isEnglish ? "Don't forget to remember Allah" : "لا تنسَ ذكر الله"
                        }
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
