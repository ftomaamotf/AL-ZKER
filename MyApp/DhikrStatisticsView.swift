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
        let prevName = previousDayName
        if L10n.isEnglish {
            guard previousDayCount > 0 else {
                return count > 0 ? "Previous day (\(prevName)): 0" : "No tasbih recorded"
            }
            if count > previousDayCount {
                return "More than \(prevName) by \((count - previousDayCount).formatted())"
            } else if count < previousDayCount {
                return "Less than \(prevName) by \((previousDayCount - count).formatted())"
            } else {
                return "Same as \(prevName) (\(count.formatted()))"
            }
        } else {
            guard previousDayCount > 0 else {
                return count > 0 ? "اليوم السابق (\(prevName)): 0" : "لم يُسجل تسبيح"
            }
            if count > previousDayCount {
                return "أكثر من \(prevName) بـ \((count - previousDayCount).formatted())"
            } else if count < previousDayCount {
                return "أقل من \(prevName) بـ \((previousDayCount - count).formatted())"
            } else {
                return "مثل \(prevName) تماماً (\(count.formatted()))"
            }
        }
    }

    var comparisonToNextText: String {
        let nxtName = nextDayName
        if L10n.isEnglish {
            guard let nxtName, let nextDayCount else {
                return isToday ? "Current day in progress" : "Latest day"
            }
            guard nextDayCount > 0 else {
                return count > 0 ? "More than \(nxtName) (0 recorded)" : "0 recorded"
            }
            if count > nextDayCount {
                return "More than \(nxtName) by \((count - nextDayCount).formatted())"
            } else if count < nextDayCount {
                return "Less than \(nxtName) by \((nextDayCount - count).formatted())"
            } else {
                return "Same as \(nxtName) (\(count.formatted()))"
            }
        } else {
            guard let nxtName, let nextDayCount else {
                return isToday ? "اليوم الحالي قيد التسبيح (مستمر)" : "اليوم الأحدث"
            }
            guard nextDayCount > 0 else {
                return count > 0 ? "أكثر من \(nxtName) (لم يُسجل فيها)" : "لم يُسجل فيها"
            }
            if count > nextDayCount {
                return "أكثر من \(nxtName) بـ \((count - nextDayCount).formatted())"
            } else if count < nextDayCount {
                return "أقل من \(nxtName) بـ \((nextDayCount - count).formatted())"
            } else {
                return "مثل \(nxtName) تماماً (\(count.formatted()))"
            }
        }
    }
}

struct DhikrStatisticsView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @ObservedObject private var access = DhikrSummariesSubscriptionAccess.shared
    @AppStorage("fadhkuruni_daily_statistics_goal") private var dailyGoal = 100
    @State private var selectedDhikrTitle = ""
    @State private var dhikrStripPosition: String?
    @State private var showClearStatisticsConfirmation = false
    @State private var statisticsDeletionMessage: String?

    var body: some View {
        Group {
            if access.hasAccess {
                statisticsContent
            } else {
                DhikrSummariesSubscriptionView()
            }
        }
    }

    private var statisticsContent: some View {
        List {
            if !access.isSubscribed && access.isWithinFreeTrial {
                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "gift.fill")
                            .font(.title2)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.isEnglish ? "Free Trial Active" : "أنت في فترة التجربة المجانية")
                                .font(.subheadline.weight(.bold))
                            Text(L10n.isEnglish ? "\(access.trialDaysRemaining) days remaining in your free trial of Dhikr Summaries, then $1/month." : "متبقي لك \(access.trialDaysRemaining) يوماً من الشهر المجاني لملخصات الذكر، بعدها بـ 1$ شهرياً.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        NavigationLink(L10n.isEnglish ? "Subscribe" : "الاشتراك") {
                            DhikrSummariesSubscriptionView()
                        }
                        .font(.caption.weight(.bold))
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                    }
                    .padding(.vertical, 3)
                }
            }

            Section {
                if recordedDhikrTitles.isEmpty {
                    ContentUnavailableView(L10n.isEnglish ? "No Dhikr recorded yet" : "لا يوجد ذكر مسجل بعد", systemImage: "sparkles", description: Text(L10n.isEnglish ? "Start counting and your Dhikr summary will appear here." : "ابدأ بالتسبيح وسيظهر الذكر هنا مع ملخصه."))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(L10n.isEnglish ? "Azkar you counted" : "الأذكار التي سبّحت بها").font(.subheadline.weight(.semibold))
                            Spacer()
                            Text("\(recordedDhikrTitles.count) \(L10n.isEnglish ? "Azkar" : "أذكار")")
                                .font(.caption.weight(.bold)).foregroundStyle(.green)
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(Color.green.opacity(0.12), in: Capsule())
                        }
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 10) {
                                ForEach(recordedDhikrTitles, id: \.self) { title in
                                    let isSelected = title == activeDhikrTitle
                                    Button {
                                        withAnimation(.snappy(duration: 0.28)) {
                                            selectedDhikrTitle = title
                                            dhikrStripPosition = title
                                        }
                                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    } label: {
                                        VStack(alignment: .trailing, spacing: 5) {
                                            Text(L10n.zekrTitle(title))
                                                .font(.caption.weight(.semibold))
                                                .lineLimit(2)
                                                .minimumScaleFactor(0.72)
                                                .multilineTextAlignment(.trailing)
                                                .frame(maxWidth: .infinity, minHeight: 32, alignment: .trailing)
                                            Text("\(sync.statistics.totalAllTime(for: title).formatted()) \(L10n.isEnglish ? "total" : "إجمالي")")
                                                .font(.caption2.monospacedDigit())
                                                .frame(maxWidth: .infinity, alignment: .trailing)
                                        }
                                        .foregroundStyle(isSelected ? Color.white : Color.primary)
                                        .padding(.horizontal, 14).padding(.vertical, 10)
                                        .frame(width: 224, height: 76)
                                        .background {
                                            Capsule().fill(isSelected ? AnyShapeStyle(LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(.ultraThinMaterial))
                                        }
                                        .overlay { Capsule().strokeBorder(isSelected ? Color.clear : Color.green.opacity(0.16), lineWidth: 0.8) }
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(L10n.isEnglish ? "View summary for " : "عرض ملخص ")\(title)")
                                }
                            }
                            .scrollTargetLayout()
                            .padding(.horizontal, 4)
                        }
                        .scrollTargetBehavior(.viewAligned)
                        .scrollPosition(id: $dhikrStripPosition, anchor: .center)
                        .scrollClipDisabled()
                        .frame(height: 82)
                    }
                }
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
                        Text("\(L10n.isEnglish ? "Daily Goal: " : "هدف اليوم: ")\(dailyGoal)").font(.caption).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(min(1.0, Double(todayCount) / Double(max(1, dailyGoal))) * 100))٪ \(L10n.isEnglish ? "completed" : "تم إنجازه")")
                            .font(.caption.bold())
                            .foregroundStyle(.green)
                    }

                    Divider().padding(.vertical, 4)

                    // 3 بطاقات ملخص سريع
                    HStack(spacing: 8) {
                        statBadge(title: L10n.isEnglish ? "Weekly Total" : "مجموع الأسبوع", value: "\(weeklyTotalCount)", icon: "chart.bar.fill", tint: .green)
                        statBadge(title: L10n.isEnglish ? "Daily Average" : "معدل اليوم", value: "\(dailyAverageCount)", icon: "flame.fill", tint: .orange)
                        statBadge(title: L10n.isEnglish ? "Most Active" : "أنشط الأيام", value: bestDayName, icon: "crown.fill", tint: .yellow)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .listRowBackground(Color.green.opacity(0.08))

            // 2. المخطط البياني لأيام الأسبوع (7 أيام)
            Section(header: Text(L10n.isEnglish ? "Past 7 Days Chart" : "مخطط أيام الأسبوع (الـ 7 أيام الماضية)")) {
                weeklyBarChart
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            // 3. ملخص أيام الأسبوع ومقارنة اليوم السابق واليوم التالي
            Section(header: Text(L10n.isEnglish ? "Weekly Breakdown & Comparisons" : "ملخص أيام الأسبوع والمقارنات")) {
                ForEach(daysOfWeekData) { day in
                    dayRowView(day: day)
                }
            }

            // 4. حذف الإحصاءات
            Section {
                Button(L10n.isEnglish ? "Clear Selected Dhikr Statistics" : "حذف إحصاءات الذكر المختار", role: .destructive) {
                    showClearStatisticsConfirmation = true
                }
                .disabled(activeDhikrTitle.isEmpty)
            } footer: {
                Text(L10n.isEnglish ? "Deletes statistics for \(activeDhikrTitle.isEmpty ? "selected Dhikr" : activeDhikrTitle) only from iPhone and Apple Watch." : "يحذف إحصاءات \(activeDhikrTitle.isEmpty ? "الذكر المختار" : activeDhikrTitle) فقط من الآيفون والساعة، ولا يحذف بقية الأذكار أو الأهداف أو العداد الحالي.")
            }
        }
        .navigationTitle(L10n.isEnglish ? "Dhikr Statistics" : "إحصائيات الذكر")
        .onAppear { selectFirstRecordedDhikrIfNeeded() }
        .onChange(of: recordedDhikrTitles) { _, _ in selectFirstRecordedDhikrIfNeeded() }
        .alert("حذف الإحصاءات؟", isPresented: $showClearStatisticsConfirmation) {
            Button("إلغاء", role: .cancel) {}
            Button("متابعة", role: .destructive) {
                Task {
                    switch await BiometricStatisticsDeletionAuthorizer.authorize() {
                    case .success:
                        sync.clearStatistics(for: activeDhikrTitle)
                    case .failure(let failure):
                        statisticsDeletionMessage = failure.message
                    }
                }
            }
        } message: {
            Text("سيُطلب تأكيد بصمة الوجه أو بصمة الإصبع قبل الحذف. سيُحذف سجل \(activeDhikrTitle) فقط من الآيفون والساعة، وسيبدأ احتساب هذا الذكر من الصفر.")
        }
        .alert("حذف الإحصاءات", isPresented: Binding(get: { statisticsDeletionMessage != nil }, set: { if !$0 { statisticsDeletionMessage = nil } })) {
            Button("حسناً", role: .cancel) {}
        } message: {
            Text(statisticsDeletionMessage ?? "")
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                NavigationLink {
                    DhikrSummariesSubscriptionView()
                } label: {
                    Image(systemName: access.isSubscribed ? "checkmark.seal.fill" : "gift.fill")
                        .font(.subheadline)
                        .foregroundStyle(access.isSubscribed ? .green : .mint)
                }
                .accessibilityLabel("اشتراك ملخصات الذكر")
            }
        }
    }

    private var todayHeaderTitle: String {
        activeDhikrTitle.isEmpty ? "تسبيح اليوم" : "تسبيح اليوم (\(activeDhikrTitle))"
    }

    private var todayCount: Int {
        activeDhikrTitle.isEmpty ? 0 : sync.statistics.totalToday(for: activeDhikrTitle)
    }

    private var yesterdayCount: Int {
        activeDhikrTitle.isEmpty ? 0 : sync.statistics.totalYesterday(for: activeDhikrTitle)
    }

    private var recordedDhikrTitles: [String] {
        let titles = sync.statistics.recordedDhikrTitles(from: sync.azkarList.map(\.title))
        // Keep the highest lifetime count first. Equal totals retain the user's
        // original dhikr-library order instead of jumping around.
        return titles.enumerated().sorted { left, right in
            let leftTotal = sync.statistics.totalAllTime(for: left.element)
            let rightTotal = sync.statistics.totalAllTime(for: right.element)
            return leftTotal == rightTotal ? left.offset < right.offset : leftTotal > rightTotal
        }.map(\.element)
    }

    private var activeDhikrTitle: String {
        recordedDhikrTitles.contains(selectedDhikrTitle) ? selectedDhikrTitle : (recordedDhikrTitles.first ?? "")
    }

    private func selectFirstRecordedDhikrIfNeeded() {
        if !recordedDhikrTitles.contains(selectedDhikrTitle) {
            selectedDhikrTitle = recordedDhikrTitles.first ?? ""
        }
        dhikrStripPosition = selectedDhikrTitle
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
        dayFormatter.locale = L10n.locale
        dayFormatter.dateFormat = "EEEE"

        let shortDateFormatter = DateFormatter()
        shortDateFormatter.locale = L10n.locale
        shortDateFormatter.dateFormat = "d MMMM"

        let idFormatter = DateFormatter()
        idFormatter.locale = Locale(identifier: "en_US_POSIX")
        idFormatter.dateFormat = "yyyy-MM-dd"

        for offset in 0...6 {
            let dayOffset = -offset
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let count = activeDhikrTitle.isEmpty
                ? 0
                : sync.statistics.total(dayOffset: dayOffset, for: activeDhikrTitle)

            let prevOffset = dayOffset - 1
            let prevDate = calendar.date(byAdding: .day, value: prevOffset, to: now) ?? date
            let prevCount = activeDhikrTitle.isEmpty
                ? 0
                : sync.statistics.total(dayOffset: prevOffset, for: activeDhikrTitle)
            let prevDayName = dayFormatter.string(from: prevDate)

            var nextDayName: String? = nil
            var nextCount: Int? = nil
            if dayOffset < 0 {
                let nextOffset = dayOffset + 1
                let nextDate = calendar.date(byAdding: .day, value: nextOffset, to: now) ?? date
                nextDayName = dayFormatter.string(from: nextDate)
                nextCount = activeDhikrTitle.isEmpty
                    ? 0
                    : sync.statistics.total(dayOffset: nextOffset, for: activeDhikrTitle)
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
final class DhikrSummaryNotificationScheduler {
    static let shared = DhikrSummaryNotificationScheduler()
    private let identifiers = ["fadhkuruni.summary.daily"]
    private let removedPeriodIdentifiers = ["fadhkuruni.summary.week", "fadhkuruni.summary.month", "fadhkuruni.summary.year"]
    private let prayerIdentifiers = ["fajr", "dhuhr", "asr", "maghrib", "isha"].map { "fadhkuruni.prayer.\($0)" }

    private init() {}

    func refresh() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        refreshPrayerReminders()
        refreshCustomReminder()
        refreshDailySummaryReminder()
    }

    func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers + prayerIdentifiers + customReminderIDs())
    }

    func cancelPrayerReminders() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: prayerIdentifiers)
    }

    func cancelDailySummaryReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers)
    }

    func refreshPrayerReminders() {
        guard UserDefaults.standard.object(forKey: "fadhkuruni_prayer_reminders_enabled") as? Bool ?? true else {
            cancelPrayerReminders()
            return
        }
        PrayerAdhanRecorder.ensureBuiltInSoundsInLibraryDirectory()
        let center = UNUserNotificationCenter.current()
        // Wait for the current notification settings before adding requests. On
        // a first launch, adding them before the sound authorization settled
        // could leave the old/default sound attached to a repeating request.
        center.requestAuthorization(options: [.alert, .sound, .timeSensitive]) { [weak self] _, _ in
            DispatchQueue.main.async {
                self?.schedulePrayerReminders(center)
            }
        }
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

    func currentIshaTime() -> (hour: Int, minute: Int) {
        // الدقائق المعتمدة في البرنامج لصلاة العشاء (المحسوبة والمعدلة يدوياً في إعدادات التطبيق)
        let totalMinutes = UserDefaults.standard.object(forKey: "fadhkuruni_prayer_isha_minutes") as? Int ?? 1200
        let clamped = (totalMinutes + 1_440) % 1_440
        return (clamped / 60, clamped % 60)
    }

    func ishaFormattedTimeString() -> String {
        let (h, m) = currentIshaTime()
        let now = Date()
        let targetDate = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: targetDate)
    }

    func currentMaghribTime() -> (hour: Int, minute: Int) {
        let totalMinutes = UserDefaults.standard.object(forKey: "fadhkuruni_prayer_maghrib_minutes") as? Int ?? 1080
        let clamped = (totalMinutes + 1_440) % 1_440
        return (clamped / 60, clamped % 60)
    }

    func maghribFormattedTimeString() -> String {
        let (h, m) = currentMaghribTime()
        let now = Date()
        let targetDate = Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: now) ?? now
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: targetDate)
    }

    func refreshDailySummaryReminder() {
        let center = UNUserNotificationCenter.current()
        let identifier = identifiers[0]
        center.removePendingNotificationRequests(withIdentifiers: identifiers + removedPeriodIdentifiers)

        let (ishaHour, ishaMinute) = currentIshaTime()
        let stats = WatchSyncService.shared.statistics
        let todayCount = stats.totalToday()
        let currentZekr = WatchSyncService.shared.currentZekr
        let currentZekrCount = stats.totalToday(for: currentZekr)

        let content = UNMutableNotificationContent()
        content.title = "ملخص الذكر اليومي (صلاة العشاء)"

        if todayCount > 0 {
            content.body = "حان وقت صلاة العشاء 🕌 | مجموع تسبيحك اليوم: \(todayCount.formatted()) تسبيحة (\(currentZekr): \(currentZekrCount.formatted())). تقبّل الله طاعتكم."
        } else {
            content.body = "حان وقت صلاة العشاء 🕌 | تقبّل الله طاعتكم. افتح التطبيق لتفقد وردك اليومي وملخص أيام الأسبوع."
        }

        content.sound = .default
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        var components = DateComponents()
        components.hour = ishaHour
        components.minute = ishaMinute
        components.second = 0

        // يتكرر الإشعار يومياً في نفس توقيت صلاة العشاء المعتمد في البرنامج
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }
}
