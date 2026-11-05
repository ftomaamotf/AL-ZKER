import SwiftUI
import UserNotifications
import CoreLocation

enum StatisticsScope: String, CaseIterable, Identifiable {
    case allAzkar = "كافة الأذكار"
    case currentZekr = "الذكر الحالي"
    var id: String { rawValue }
}

struct DayComparisonInfo: Identifiable {
    let id: String
    let date: Date
    let dayName: String
    let dateFormatted: String
    let isToday: Bool
    let count: Int
    let previousDayName: String
    let previousDayCount: Int
    let nextDayName: String?
    let nextDayCount: Int?

    var diffFromPrevious: Int { count - previousDayCount }

    var comparisonToPreviousText: String {
        guard previousDayCount > 0 else {
            return count > 0 ? "اليوم السابق (\(previousDayName)): 0" : "لم يُسجل تسبيح"
        }
        if count > previousDayCount {
            return "أكثر من \(previousDayName) بـ \((count - previousDayCount).formatted())"
        } else if count < previousDayCount {
            return "أقل من \(previousDayName) بـ \((previousDayCount - count).formatted())"
        } else {
            return "مثل \(previousDayName) تماماً (\(count.formatted()))"
        }
    }

    var comparisonToNextText: String {
        guard let nextDayName, let nextDayCount else {
            return isToday ? "اليوم الحالي قيد التسبيح (مستمر)" : "اليوم الأحدث"
        }
        guard nextDayCount > 0 else {
            return count > 0 ? "أكثر من \(nextDayName) (لم يُسجل فيها)" : "لم يُسجل فيها"
        }
        if count > nextDayCount {
            return "أكثر من \(nextDayName) بـ \((count - nextDayCount).formatted())"
        } else if count < nextDayCount {
            return "أقل من \(nextDayName) بـ \((nextDayCount - count).formatted())"
        } else {
            return "مثل \(nextDayName) تماماً (\(count.formatted()))"
        }
    }
}

struct DhikrStatisticsView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @AppStorage("fadhkuruni_daily_statistics_goal") private var dailyGoal = 100
    @State private var selectedScope: StatisticsScope = .allAzkar
    @State private var showClearStatisticsConfirmation = false
    @State private var statisticsDeletionMessage: String?

    var body: some View {
        List {
            // اختيار نطاق الإحصاءات: كافة الأذكار أو الذكر الحالي
            Section {
                Picker("نطاق الإحصاءات", selection: $selectedScope) {
                    ForEach(StatisticsScope.allCases) { scope in
                        Text(scope == .currentZekr ? "\(scope.rawValue) (\(sync.currentZekr))" : scope.rawValue)
                            .tag(scope)
                    }
                }
                .pickerStyle(.segmented)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

            // 1. بطاقة نظرة عامة لليوم
            Section {
                VStack(spacing: 12) {
                    Text(todayHeaderTitle)
                        .font(.subheadline).foregroundStyle(.secondary)
                    
                    Text("\(todayCount)")
                        .font(.system(size: 54, weight: .bold, design: .rounded))
                        .foregroundStyle(.green)
                    
                    Text(todayComparisonText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    ProgressView(value: min(Double(todayCount), Double(dailyGoal)), total: Double(max(1, dailyGoal)))
                        .tint(.green)
                    
                    HStack {
                        Text("هدف اليوم: \(dailyGoal)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(min(1.0, Double(todayCount) / Double(max(1, dailyGoal))) * 100))٪ تم إنجازه")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }

                    Divider().padding(.vertical, 4)

                    // 3 بطاقات ملخص سريع
                    HStack(spacing: 8) {
                        statBadge(title: "مجموع الأسبوع", value: "\(weeklyTotalCount)", icon: "chart.bar.fill", tint: .green)
                        statBadge(title: "معدل اليوم", value: "\(dailyAverageCount)", icon: "flame.fill", tint: .orange)
                        statBadge(title: "أنشط الأيام", value: bestDayName, icon: "crown.fill", tint: .yellow)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.green.opacity(0.08))

            // 2. المخطط البياني لأيام الأسبوع (7 أيام)
            Section(header: Text("مخطط أيام الأسبوع (الـ 7 أيام الماضية)")) {
                weeklyBarChart
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            // 3. ملخص أيام الأسبوع ومقارنة اليوم السابق واليوم التالي
            Section(header: Text("ملخص أيام الأسبوع والمقارنات")) {
                ForEach(daysOfWeekData) { day in
                    dayRowView(day: day)
                }
            }

            // 4. حذف الإحصاءات
            Section {
                Button("حذف الإحصاءات", role: .destructive) {
                    showClearStatisticsConfirmation = true
                }
            } footer: {
                Text("يحذف أرقام الإحصاءات فقط من الآيفون والساعة، ولا يحذف الأذكار أو الأهداف أو العداد الحالي.")
            }
        }
        .navigationTitle("إحصاءات الذكر")
        .alert("حذف الإحصاءات؟", isPresented: $showClearStatisticsConfirmation) {
            Button("إلغاء", role: .cancel) {}
            Button("متابعة", role: .destructive) {
                Task {
                    switch await BiometricStatisticsDeletionAuthorizer.authorize() {
                    case .success:
                        sync.clearStatistics()
                    case .failure(let failure):
                        statisticsDeletionMessage = failure.message
                    }
                }
            }
        } message: {
            Text("سيُطلب تأكيد بصمة الوجه أو بصمة الإصبع قبل الحذف. سيُحذف سجل الإحصاءات من الآيفون والساعة، وسيبدأ الاحتساب من الصفر.")
        }
        .alert("حذف الإحصاءات", isPresented: Binding(get: { statisticsDeletionMessage != nil }, set: { if !$0 { statisticsDeletionMessage = nil } })) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text(statisticsDeletionMessage ?? "")
        }
    }

    private var todayHeaderTitle: String {
        selectedScope == .allAzkar ? "تسبيح اليوم (كافة الأذكار)" : "تسبيح اليوم (\(sync.currentZekr))"
    }

    private var todayCount: Int {
        selectedScope == .allAzkar ? sync.statistics.totalToday() : sync.statistics.totalToday(for: sync.currentZekr)
    }

    private var yesterdayCount: Int {
        selectedScope == .allAzkar ? sync.statistics.totalYesterday() : sync.statistics.totalYesterday(for: sync.currentZekr)
    }

    private var todayComparisonText: String {
        comparison(current: todayCount, previous: yesterdayCount, unit: "الأمس")
    }

    private var weeklyTotalCount: Int {
        daysOfWeekData.map(\.count).reduce(0, +)
    }

    private var dailyAverageCount: Int {
        let total = weeklyTotalCount
        return total > 0 ? total / 7 : 0
    }

    private var bestDayName: String {
        guard let best = daysOfWeekData.max(by: { $0.count < $1.count }), best.count > 0 else {
            return "—"
        }
        return "\(best.dayName) (\(best.count))"
    }

    private var weeklyBarChart: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(daysOfWeekData.reversed()) { day in
                    VStack(spacing: 4) {
                        Text("\(day.count)")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(day.isToday ? Color.green : .secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        let maxCount = max(1, daysOfWeekData.map(\.count).max() ?? 1)
                        let barHeight = max(6.0, CGFloat(day.count) / CGFloat(maxCount) * 65.0)

                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(
                                day.isToday
                                ? LinearGradient(colors: [.green, .mint], startPoint: .top, endPoint: .bottom)
                                : LinearGradient(colors: [Color.green.opacity(day.count > 0 ? 0.45 : 0.15), Color.green.opacity(day.count > 0 ? 0.25 : 0.08)], startPoint: .top, endPoint: .bottom)
                            )
                            .frame(height: barHeight)

                        Text(shortDayName(day.dayName))
                            .font(.system(size: 10, weight: day.isToday ? .bold : .regular))
                            .foregroundStyle(day.isToday ? Color.green : .secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 100)
            .padding(.top, 4)
        }
        .padding(10)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }

    private func dayRowView(day: DayComparisonInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // سطر العنوان والعدد
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(day.dayName)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(day.isToday ? Color.green : .primary)
                        
                        if day.isToday {
                            Text("اليوم")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green, in: Capsule())
                        }
                    }
                    Text(day.dateFormatted)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 1) {
                    Text("\(day.count)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(day.count > 0 ? Color.green : .secondary)
                    Text("تسبيحة")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
            }

            // شريط التقدم لليوم مقارنة بأعلى يوم في الأسبوع
            let maxCount = max(1, daysOfWeekData.map(\.count).max() ?? 1)
            ProgressView(value: Double(day.count), total: Double(maxCount))
                .tint(day.isToday ? .green : .mint)

            // بطاقة المقارنات (اليوم السابق واليوم التالي)
            VStack(spacing: 5) {
                // 1. مقارنة باليوم الذي قبله
                HStack(spacing: 6) {
                    Image(systemName: diffIcon(diff: day.diffFromPrevious, count: day.count, prev: day.previousDayCount))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(diffColor(diff: day.diffFromPrevious, count: day.count, prev: day.previousDayCount))
                    
                    Text(day.comparisonToPreviousText)
                        .font(.caption)
                        .foregroundStyle(day.count != day.previousDayCount ? .primary : .secondary)
                    
                    Spacer()
                }

                // 2. مقارنة باليوم الذي يليه
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.left.circle")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.teal)
                    
                    Text(day.comparisonToNextText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
            }
            .padding(8)
            .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(.vertical, 4)
    }

    private func diffIcon(diff: Int, count: Int, prev: Int) -> String {
        guard prev > 0 else { return count > 0 ? "star.fill" : "circle" }
        if diff > 0 { return "arrow.up.right.circle.fill" }
        if diff < 0 { return "arrow.down.right.circle.fill" }
        return "equal.circle.fill"
    }

    private func diffColor(diff: Int, count: Int, prev: Int) -> Color {
        guard prev > 0 else { return count > 0 ? .green : .secondary }
        if diff > 0 { return .green }
        if diff < 0 { return .orange }
        return .secondary
    }

    private func statBadge(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text(title)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color(UIColor.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
    }

    private func shortDayName(_ full: String) -> String {
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("ال") {
            return String(trimmed.dropFirst(2))
        }
        return trimmed
    }

    private var daysOfWeekData: [DayComparisonInfo] {
        let calendar = Calendar(identifier: .gregorian)
        let now = Date()
        var list: [DayComparisonInfo] = []

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "ar_SA")
        dayFormatter.dateFormat = "EEEE"

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.locale = Locale(identifier: "ar_SA")
        shortDateFormatter.dateFormat = "d MMMM"

        let idFormatter = DateFormatter()
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyy-MM-dd"

        for offset in 0...6 {
            let dayOffset = -offset
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let count = selectedScope == .allAzkar
                ? sync.statistics.total(dayOffset: dayOffset)
                : sync.statistics.total(dayOffset: dayOffset, for: sync.currentZekr)

            let prevOffset = dayOffset - 1
            let prevDate = calendar.date(byAdding: .day, value: prevOffset, to: now) ?? date
            let prevCount = selectedScope == .allAzkar
                ? sync.statistics.total(dayOffset: prevOffset)
                : sync.statistics.total(dayOffset: prevOffset, for: sync.currentZekr)
            let prevDayName = dayFormatter.string(from: prevDate)

            var nextDayName: String? = nil
            var nextCount: Int? = nil
            if dayOffset < 0 {
                let nextOffset = dayOffset + 1
                let nextDate = calendar.date(byAdding: .day, value: nextOffset, to: now) ?? date
                nextDayName = dayFormatter.string(from: nextDate)
                nextCount = selectedScope == .allAzkar
                    ? sync.statistics.total(dayOffset: nextOffset)
                    : sync.statistics.total(dayOffset: nextOffset, for: sync.currentZekr)
            }

            let info = DayComparisonInfo(
                id: idFormatter.string(from: date),
                date: date,
                dayName: dayFormatter.string(from: date),
                dateFormatted: shortDateFormatter.string(from: date),
                isToday: dayOffset == 0,
                count: count,
                previousDayName: prevDayName,
                previousDayCount: prevCount,
                nextDayName: nextDayName,
                nextDayCount: nextCount
            )
            list.append(info)
        }

        return list
    }

    private func comparison(current: Int, previous: Int, unit: String) -> String {
        guard previous > 0 else { return current > 0 ? "بداية طيبة اليوم" : "ابدأ وردك اليوم" }
        if current > previous { return "أكثر من \(unit) بـ \(current - previous)" }
        if current < previous { return "أقل من \(unit) بـ \(previous - current)" }
        return "مثل \(unit) تماماً"
    }

}

@MainActor
final class DhikrSummaryNotificationScheduler: NSObject, CLLocationManagerDelegate {
    static let shared = DhikrSummaryNotificationScheduler()
    private let locationManager = CLLocationManager()
    private let identifiers = ["fadhkuruni.summary.daily"]
    private let removedPeriodIdentifiers = ["fadhkuruni.summary.week", "fadhkuruni.summary.month", "fadhkuruni.summary.year"]
    private let prayerIdentifiers = ["fajr", "dhuhr", "asr", "maghrib", "isha"].map { "fadhkuruni.prayer.\($0)" }

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func refresh() {
        let summariesEnabled = UserDefaults.standard.object(forKey: "fadhkuruni_daily_summary_enabled") as? Bool ?? true
        guard summariesEnabled || !DhikrCustomReminder.loadAll().isEmpty else {
            cancel()
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refreshPrayerReminders()
        refreshCustomReminder()
        refreshDailySummaryReminder()
        guard CLLocationManager.locationServicesEnabled() else { return }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse: locationManager.requestLocation()
        case .notDetermined: locationManager.requestWhenInUseAuthorization()
        default: break
        }
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers + prayerIdentifiers + customReminderIDs())
    }

    func cancelPrayerReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: prayerIdentifiers)
    }

    func refreshPrayerReminders() {
        guard UserDefaults.standard.object(forKey: "fadhkuruni_prayer_reminders_enabled") as? Bool ?? true else {
            cancelPrayerReminders()
            return
        }
        PrayerAdhanRecorder.ensureBuiltInSoundsInLibraryDirectory()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        schedulePrayerReminders(UNUserNotificationCenter.current())
    }

    func refreshCustomReminder() {
        let center = UNUserNotificationCenter.current()
        let reminders = DhikrCustomReminder.loadAll()
        center.removePendingNotificationRequests(withIdentifiers: customReminderIDs())
        UserDefaults.standard.set(reminders.map(\.id.uuidString), forKey: "fadhkuruni_custom_reminder_known_ids")
        guard !reminders.isEmpty else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        for reminder in reminders where reminder.isEnabled {
            let content = UNMutableNotificationContent()
            var reminderTitle = reminder.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if reminderTitle == "تذكير بالذكر" || reminderTitle.isEmpty {
                reminderTitle = "تذكير"
            } else if reminderTitle.hasSuffix(" بالذكر") {
                reminderTitle = String(reminderTitle.dropLast(" بالذكر".count))
            }
            content.title = reminderTitle
            content.body = reminder.message
            content.sound = .default
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }
            var components = DateComponents()
            components.hour = reminder.minutes / 60
            components.minute = reminder.minutes % 60
            components.second = 0
            center.add(UNNotificationRequest(identifier: "fadhkuruni.reminder.custom.\(reminder.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
        }
    }

    private func customReminderIDs() -> [String] {
        let current = DhikrCustomReminder.loadAll().map { "fadhkuruni.reminder.custom.\($0.id.uuidString)" }
        let known = (UserDefaults.standard.stringArray(forKey: "fadhkuruni_custom_reminder_known_ids") ?? []).map { "fadhkuruni.reminder.custom.\($0)" }
        return Array(Set(current + known))
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        PrayerTimesManager.shared.refresh()
        refreshDailySummaryReminder()
    }

    // iOS requires this delegate method whenever requestLocation() is used.
    // A denied permission or a temporary location failure must not close the app.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Prayer reminders use the user-selected times and remain scheduled without location.
    }

    func cancelDailySummaryReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers)
    }

    func currentMaghribTime() -> (hour: Int, minute: Int) {
        // 1. أولوية أولى: من مواقيت الصلاة المحسوبة لموقع المستخدم في PrayerTimesManager
        if let maghrib = PrayerTimesManager.shared.times.first(where: { $0.id == "maghrib" }) {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: maghrib.date)
            if let h = comps.hour, let m = comps.minute {
                return (h, m)
            }
        }

        // 2. أولوية ثانية: من الدقائق المخزنة في إعدادات التطبيق (المحسوبة والمعدلة يدوياً لمواقيت البرنامج)
        let totalMinutes = UserDefaults.standard.object(forKey: "fadhkuruni_prayer_maghrib_minutes") as? Int ?? 1080
        let clamped = (totalMinutes + 1_440) % 1_440
        return (clamped / 60, clamped % 60)
    }

    func maghribFormattedTimeString() -> String {
        let (h, m) = currentMaghribTime()
        var components = DateComponents()
        components.hour = h
        components.minute = m
        if let date = Calendar.current.date(from: components) {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "ar_SA")
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        }
        return String(format: "%02d:%02d", h, m)
    }

    func refreshDailySummaryReminder() {
        let center = UNUserNotificationCenter.current()
        let identifier = identifiers[0]
        center.removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers)

        let isEnabled = UserDefaults.standard.object(forKey: "fadhkuruni_daily_summary_enabled") as? Bool ?? true
        guard isEnabled else { return }

        let (maghribHour, maghribMinute) = currentMaghribTime()
        let stats = WatchSyncService.shared.statistics
        let todayCount = stats.totalToday()
        let currentZekr = WatchSyncService.shared.currentZekr
        let currentZekrCount = stats.totalToday(for: currentZekr)

        let content = UNMutableNotificationContent()
        content.title = "ملخص الذكر اليومي (صلاة المغرب)"

        if todayCount > 0 {
            content.body = "حان وقت صلاة المغرب 🕌 | مجموع تسبيحك اليوم: \(todayCount.formatted()) تسبيحة (\(currentZekr): \(currentZekrCount.formatted())). تقبّل الله طاعتكم."
        } else {
            content.body = "حان وقت صلاة المغرب 🕌 | تقبّل الله طاعتكم. افتح التطبيق لتفقد وردك اليومي وملخص أيام الأسبوع."
        }

        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        var components = DateComponents()
        components.hour = maghribHour
        components.minute = maghribMinute
        components.second = 0

        // يتكرر الإشعار يومياً في نفس توقيت صلاة المغرب المعتمد في البرنامج
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
    private func schedulePrayerReminders(_ center: UNUserNotificationCenter) {
        guard UserDefaults.standard.object(forKey: "fadhkuruni_prayer_reminders_enabled") as? Bool ?? true else { return }
        center.removePendingNotificationRequests(withIdentifiers: prayerIdentifiers)
        let messages = [
            "fajr": ("حان وقت صلاة الفجر", "حي على الصلاة"),
            "dhuhr": ("حان وقت صلاة الظهر", "حي على الصلاة"),
            "asr": ("حان وقت صلاة العصر", "حي على الصلاة"),
            "maghrib": ("حان وقت صلاة المغرب", "حي على الصلاة"),
            "isha": ("حان وقت صلاة العشاء", "حي على الصلاة")
        ]
        let minutesByPrayer = [
            "fajr": UserDefaults.standard.object(forKey: "fadhkuruni_prayer_fajr_minutes") as? Int ?? 330,
            "dhuhr": UserDefaults.standard.object(forKey: "fadhkuruni_prayer_dhuhr_minutes") as? Int ?? 750,
            "asr": UserDefaults.standard.object(forKey: "fadhkuruni_prayer_asr_minutes") as? Int ?? 930,
            "maghrib": UserDefaults.standard.object(forKey: "fadhkuruni_prayer_maghrib_minutes") as? Int ?? 1080,
            "isha": UserDefaults.standard.object(forKey: "fadhkuruni_prayer_isha_minutes") as? Int ?? 1200
        ]
        for (name, baseMinutes) in minutesByPrayer {
            guard let message = messages[name] else { continue }
            let alertMode = PrayerAlertPreference.mode(for: name)
            guard alertMode != .none else { continue }
            let content = UNMutableNotificationContent()
            content.title = message.0
            content.body = message.1
            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
            }
            switch alertMode {
            case .none:
                continue
            case .silent:
                content.sound = nil
            case .system:
                content.sound = .default
            case .builtIn:
                content.sound = BuiltInAdhan.notificationSound(for: name)
            case .custom:
                content.sound = PrayerAdhanRecorder.notificationSound(for: name) ?? .default
            }
            let minutes = (baseMinutes + 1_440) % 1_440
            var components = DateComponents()
            components.hour = minutes / 60
            components.minute = minutes % 60
            components.second = 0
            center.add(UNNotificationRequest(identifier: "fadhkuruni.prayer.\(name)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
        }
    }
}
