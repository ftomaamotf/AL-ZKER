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

    public mutating func merge(_ other: DhikrStatisticsLedger) {
        for (day, remoteSources) in other.days {
            var local = days[day] ?? [:]
            for (origin, remoteCount) in remoteSources { local[origin] = max(local[origin] ?? 0, remoteCount) }
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
    public func totalToday() -> Int { total(in: Self.interval(.day, offset: 0)) }
    public func totalYesterday() -> Int { total(in: Self.interval(.day, offset: -1)) }
    public func totalToday(for title: String) -> Int { total(for: title, in: Self.interval(.day, offset: 0)) }
    public func totalYesterday(for title: String) -> Int { total(for: title, in: Self.interval(.day, offset: -1)) }
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
