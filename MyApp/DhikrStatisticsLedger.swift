import Foundation

/// Merge-safe daily totals. Each device owns its own counter so a WatchConnectivity
/// retry cannot add the same tap twice.
public struct DhikrStatisticsLedger: Codable, Equatable {
    private var days: [String: [String: Int]] = [:]
    private var corrections: [String: [String: Int]] = [:]
    private var dhikrDays: [String: [String: [String: Int]]] = [:]
    private var dhikrCorrections: [String: [String: [String: Int]]] = [:]

    private enum CodingKeys: String, CodingKey { case days, corrections, dhikrDays, dhikrCorrections }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        days = try container.decodeIfPresent([String: [String: Int]].self, forKey: .days) ?? [:]
        corrections = try container.decodeIfPresent([String: [String: Int]].self, forKey: .corrections) ?? [:]
        dhikrDays = try container.decodeIfPresent([String: [String: [String: Int]]].self, forKey: .dhikrDays) ?? [:]
        dhikrCorrections = try container.decodeIfPresent([String: [String: [String: Int]]].self, forKey: .dhikrCorrections) ?? [:]
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(days, forKey: .days)
        try container.encode(corrections, forKey: .corrections)
        try container.encode(dhikrDays, forKey: .dhikrDays)
        try container.encode(dhikrCorrections, forKey: .dhikrCorrections)
    }

    public mutating func recordTap(origin: String, title: String, date: Date = Date()) {
        let key = Self.dayKey(date)
        var sources = days[key] ?? [:]
        sources[origin, default: 0] += 1
        days[key] = sources
        let dhikrKey = DhikrText.key(title)
        guard !dhikrKey.isEmpty else { return }
        var perDhikr = dhikrDays[key] ?? [:]
        var perSource = perDhikr[dhikrKey] ?? [:]
        perSource[origin, default: 0] += 1
        perDhikr[dhikrKey] = perSource
        dhikrDays[key] = perDhikr
    }

    /// A correction made with the minus button must lower the same period's total.
    public mutating func recordDecrement(origin: String, title: String, date: Date = Date()) {
        let key = Self.dayKey(date)
        var sources = corrections[key] ?? [:]
        sources[origin, default: 0] += 1
        corrections[key] = sources
        let dhikrKey = DhikrText.key(title)
        guard !dhikrKey.isEmpty else { return }
        var perDhikr = dhikrCorrections[key] ?? [:]
        var perSource = perDhikr[dhikrKey] ?? [:]
        perSource[origin, default: 0] += 1
        perDhikr[dhikrKey] = perSource
        dhikrCorrections[key] = perDhikr
    }

    /// Filters display titles to dhikr that have at least one stored tap.
    public func recordedDhikrTitles(from titles: [String]) -> [String] {
        titles.filter { title in
            let key = Self.dhikrKey(title)
            guard !key.isEmpty else { return false }
            return dhikrDays.values.contains { $0[key] != nil }
                || dhikrCorrections.values.contains { $0[key] != nil }
        }
    }

    public mutating func merge(_ other: DhikrStatisticsLedger) {
        for (day, remoteSources) in other.days {
            var local = days[day] ?? [:]
            for (origin, remoteCount) in remoteSources {
                local[origin] = max(local[origin] ?? 0, remoteCount)
            }
            days[day] = local
        }
        for (day, remoteSources) in other.corrections {
            var local = corrections[day] ?? [:]
            for (origin, remoteCount) in remoteSources {
                local[origin] = max(local[origin] ?? 0, remoteCount)
            }
            corrections[day] = local
        }
        mergePerDhikr(&dhikrDays, other.dhikrDays)
        mergePerDhikr(&dhikrCorrections, other.dhikrCorrections)
    }

    /// Removes only one dhikr's detailed history. Aggregate totals and every
    /// other dhikr remain untouched.
    public mutating func clear(dhikrKey: String) {
        guard !dhikrKey.isEmpty else { return }
        for day in Array(dhikrDays.keys) {
            var perDhikr = dhikrDays[day] ?? [:]
            perDhikr.removeValue(forKey: dhikrKey)
            if perDhikr.isEmpty { dhikrDays.removeValue(forKey: day) }
            else { dhikrDays[day] = perDhikr }
        }
        for day in Array(dhikrCorrections.keys) {
            var perDhikr = dhikrCorrections[day] ?? [:]
            perDhikr.removeValue(forKey: dhikrKey)
            if perDhikr.isEmpty { dhikrCorrections.removeValue(forKey: day) }
            else { dhikrCorrections[day] = perDhikr }
        }
    }

    public func total(in interval: DateInterval) -> Int {
        let increments = days.reduce(0) { partial, entry in
            guard let date = Self.date(from: entry.key), interval.contains(date) else { return partial }
            return partial + entry.value.values.reduce(0, +)
        }
        let decrements = corrections.reduce(0) { partial, entry in
            guard let date = Self.date(from: entry.key), interval.contains(date) else { return partial }
            return partial + entry.value.values.reduce(0, +)
        }
        return max(0, increments - decrements)
    }

    /// Daily totals use the stored date key directly. Re-parsing a date through a
    /// formatter could make adjacent days appear identical after calendar changes.
    public func totalToday() -> Int { total(on: Date()) }
    public func totalYesterday() -> Int { total(dayOffset: -1) }
    public func totalToday(for title: String) -> Int { total(on: Date(), for: title) }
    public func totalYesterday(for title: String) -> Int { total(dayOffset: -1, for: title) }
    /// Lifetime net total for ranking the most frequently recited dhikr.
    public func totalAllTime(for title: String) -> Int {
        let dhikrKey = Self.dhikrKey(title)
        guard !dhikrKey.isEmpty else { return 0 }
        let increments = dhikrDays.values.reduce(0) { $0 + ($1[dhikrKey]?.values.reduce(0, +) ?? 0) }
        let decrements = dhikrCorrections.values.reduce(0) { $0 + ($1[dhikrKey]?.values.reduce(0, +) ?? 0) }
        return max(0, increments - decrements)
    }
    public func total(dayOffset: Int) -> Int {
        total(on: Self.dayCalendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date())
    }
    public func total(dayOffset: Int, for title: String) -> Int {
        total(on: Self.dayCalendar.date(byAdding: .day, value: dayOffset, to: Date()) ?? Date(), for: title)
    }
    public func total(on date: Date) -> Int {
        let key = Self.dayKey(date)
        return max(0, (days[key]?.values.reduce(0, +) ?? 0) - (corrections[key]?.values.reduce(0, +) ?? 0))
    }
    public func total(on date: Date, for title: String) -> Int {
        let dhikrKey = Self.dhikrKey(title)
        guard !dhikrKey.isEmpty else { return 0 }
        let key = Self.dayKey(date)
        return max(0, (dhikrDays[key]?[dhikrKey]?.values.reduce(0, +) ?? 0) - (dhikrCorrections[key]?[dhikrKey]?.values.reduce(0, +) ?? 0))
    }
    public func totalThisWeek() -> Int { total(in: Self.interval(.weekOfYear, offset: 0)) }
    public func totalLastWeek() -> Int { total(in: Self.interval(.weekOfYear, offset: -1)) }
    public func totalThisMonth() -> Int { total(in: Self.interval(.month, offset: 0)) }
    public func totalLastMonth() -> Int { total(in: Self.interval(.month, offset: -1)) }
    public func totalThisYear() -> Int { total(in: Self.interval(.year, offset: 0)) }
    public func totalLastYear() -> Int { total(in: Self.interval(.year, offset: -1)) }

    private static func interval(_ component: Calendar.Component, offset: Int) -> DateInterval {
        let calendar = Calendar.current
        let now = Date()
        let anchor = calendar.date(byAdding: component, value: offset, to: now) ?? now
        return calendar.dateInterval(of: component, for: anchor) ?? DateInterval(start: anchor, duration: 86_400)
    }

    private func total(for title: String, in interval: DateInterval) -> Int {
        let dhikrKey = Self.dhikrKey(title)
        guard !dhikrKey.isEmpty else { return 0 }
        let increments = Self.total(dhikrDays, key: dhikrKey, in: interval)
        let decrements = Self.total(dhikrCorrections, key: dhikrKey, in: interval)
        return max(0, increments - decrements)
    }

    private static func total(_ source: [String: [String: [String: Int]]], key: String, in interval: DateInterval) -> Int {
        source.reduce(0) { total, entry in
            guard let date = date(from: entry.key), interval.contains(date) else { return total }
            return total + (entry.value[key]?.values.reduce(0, +) ?? 0)
        }
    }

    private func mergePerDhikr(_ local: inout [String: [String: [String: Int]]], _ remote: [String: [String: [String: Int]]]) {
        for (day, remoteDhikr) in remote {
            var localDhikr = local[day] ?? [:]
            for (dhikr, remoteSources) in remoteDhikr {
                var localSources = localDhikr[dhikr] ?? [:]
                for (origin, remoteCount) in remoteSources { localSources[origin] = max(localSources[origin] ?? 0, remoteCount) }
                localDhikr[dhikr] = localSources
            }
            local[day] = localDhikr
        }
    }

    private static func dhikrKey(_ title: String) -> String { DhikrText.key(title) }

    private static var dayCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .current
        return calendar
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = dayCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func date(from key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = dayCalendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
}
