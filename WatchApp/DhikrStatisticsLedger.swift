import Foundation

/// Merge-safe daily totals. Each device owns its own counter so a WatchConnectivity
/// retry cannot add the same tap twice.
public struct DhikrStatisticsLedger: Codable, Equatable {
    private var days: [String: [String: Int]] = [:]

    public init() {}

    public mutating func recordTap(origin: String, date: Date = Date()) {
        let key = Self.dayKey(date)
        var sources = days[key] ?? [:]
        sources[origin, default: 0] += 1
        days[key] = sources
    }

    public mutating func merge(_ other: DhikrStatisticsLedger) {
        for (day, remoteSources) in other.days {
            var local = days[day] ?? [:]
            for (origin, remoteCount) in remoteSources { local[origin] = max(local[origin] ?? 0, remoteCount) }
            days[day] = local
        }
    }

    public func total(in interval: DateInterval) -> Int {
        days.reduce(0) { partial, entry in
            guard let date = Self.date(from: entry.key), interval.contains(date) else { return partial }
            return partial + entry.value.values.reduce(0, +)
        }
    }
    public func totalToday() -> Int { total(in: Self.interval(.day, offset: 0)) }
    public func totalYesterday() -> Int { total(in: Self.interval(.day, offset: -1)) }
    public func totalThisWeek() -> Int { total(in: Self.interval(.weekOfYear, offset: 0)) }
    public func totalLastWeek() -> Int { total(in: Self.interval(.weekOfYear, offset: -1)) }
    public func totalThisMonth() -> Int { total(in: Self.interval(.month, offset: 0)) }
    public func totalLastMonth() -> Int { total(in: Self.interval(.month, offset: -1)) }
    public func totalThisYear() -> Int { total(in: Self.interval(.year, offset: 0)) }
    public func totalLastYear() -> Int { total(in: Self.interval(.year, offset: -1)) }

    private static func interval(_ component: Calendar.Component, offset: Int) -> DateInterval {
        let calendar = Calendar.current; let now = Date()
        let anchor = calendar.date(byAdding: component, value: offset, to: now) ?? now
        return calendar.dateInterval(of: component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }
    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    private static func date(from key: String) -> Date? {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = .current; formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
}
