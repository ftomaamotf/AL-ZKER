import SwiftUI
import UserNotifications
import CoreLocation

struct DhikrStatisticsView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @AppStorage("fadhkuruni_daily_statistics_goal") private var dailyGoal = 100
    @State private var showClearStatisticsConfirmation = false
    @State private var statisticsDeletionMessage: String?

    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Text("تسبيح اليوم")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("\(sync.statistics.totalToday())")
                        .font(.system(size: 54, weight: .bold, design: .rounded)).foregroundStyle(.green)
                    Text(todayComparison)
                        .font(.subheadline).foregroundStyle(.secondary)
                    ProgressView(value: min(Double(sync.statistics.totalToday()), Double(dailyGoal)), total: Double(max(1, dailyGoal)))
                        .tint(.green)
                    Text("هدف اليوم: \(dailyGoal)").font(.caption).foregroundStyle(.secondary)
                    Text("المجموع من كل الأذكار على الآيفون والساعة")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.green.opacity(0.08))

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

    private var todayComparison: String {
        comparison(current: sync.statistics.totalToday(), previous: sync.statistics.totalYesterday(), unit: "الأمس")
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
        let summariesEnabled = true
        guard summariesEnabled || !DhikrCustomReminder.loadAll().isEmpty else {
            cancel()
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refreshPrayerReminders()
        refreshCustomReminder()
        guard summariesEnabled else { return }
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
        schedule(at: location.coordinate)
    }

    // iOS requires this delegate method whenever requestLocation() is used.
    // A denied permission or a temporary location failure must not close the app.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Prayer reminders use the user-selected times and remain scheduled without location.
    }

    private func schedule(at coordinate: CLLocationCoordinate2D) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers)
        let stats = WatchSyncService.shared.statistics
        let azkar = WatchSyncService.shared.azkarList
        schedule(center, id: identifiers[0], date: nextSunset(after: Date(), coordinate: coordinate), title: "ملخص اليوم", body: dailyBody(stats, azkar: azkar))
    }

    private func schedule(_ center: UNUserNotificationCenter, id: String, date: Date?, title: String, body: String) {
        guard let date else { return }
        let content = UNMutableNotificationContent(); content.title = title; content.body = body; content.sound = .default
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)))
    }

    private func dailyBody(_ stats: DhikrStatisticsLedger, azkar: [ZekrItem]) -> String {
        guard !azkar.isEmpty else { return "لا توجد أذكار مسجلة اليوم." }
        return azkar.map { item in
            "\(item.title): \(stats.totalToday(for: item.title))"
        }.joined(separator: "\n")
    }

    private func comparisonBody(current: Int, previous: Int, period: String, label: String) -> String {
        guard previous > 0 else { return "عدد الأذكار \(label): \(current)." }
        if current > previous { return "عدد الأذكار \(label): \(current)، أكثر من \(period) بـ \(current - previous)." }
        if current < previous { return "عدد الأذكار \(label): \(current)، أقل من \(period) بـ \(previous - current)." }
        return "عدد الأذكار \(label): \(current)، مثل \(period)."
    }

    private func nextSunset(after date: Date, coordinate: CLLocationCoordinate2D) -> Date? {
        var candidate = SolarTime.sunset(on: date, coordinate: coordinate)
        if candidate == nil || candidate! <= date { candidate = SolarTime.sunset(on: Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date, coordinate: coordinate) }
        return candidate
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

private enum SolarTime {
    static func sunset(on date: Date, coordinate: CLLocationCoordinate2D) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        let day = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let longitudeHour = coordinate.longitude / 15
        let t = day + ((18 - longitudeHour) / 24)
        let m = 0.9856 * t - 3.289
        var l = m + 1.916 * sin(radians(m)) + 0.020 * sin(2 * radians(m)) + 282.634; l = wrap(l, 360)
        var ra = degrees(atan(0.91764 * tan(radians(l)))); ra = wrap(ra, 360)
        let lQuadrant = floor(l / 90) * 90, raQuadrant = floor(ra / 90) * 90; ra = (ra + lQuadrant - raQuadrant) / 15
        let sinDec = 0.39782 * sin(radians(l)), cosDec = cos(asin(sinDec))
        let cosH = (cos(radians(90.833)) - sinDec * sin(radians(coordinate.latitude))) / (cosDec * cos(radians(coordinate.latitude)))
        guard (-1...1).contains(cosH) else { return nil }
        let h = degrees(acos(cosH)) / 15
        let ut = wrap(h + ra - 0.06571 * t - 6.622 - longitudeHour, 24)
        return calendar.startOfDay(for: date).addingTimeInterval(ut * 3600)
    }
    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func wrap(_ value: Double, _ modulus: Double) -> Double { (value.truncatingRemainder(dividingBy: modulus) + modulus).truncatingRemainder(dividingBy: modulus) }
}
