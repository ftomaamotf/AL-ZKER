import Foundation

// Shared identity: exact Arabic words after removing vocalization and normalizing alef.
enum DhikrText {
    static func key(_ text: String) -> String {
        let text = text.replacingOccurrences(of: "[\\u064B-\\u065F\\u0670\\u0640]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "[أإآٱ]", with: "ا", options: .regularExpression)
            .replacingOccurrences(of: "ى", with: "ي")
        return text.components(separatedBy: CharacterSet.letters.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }
}

struct DhikrLedger: Codable, Equatable {
    struct Stamp: Codable, Comparable {
        var time: Double = 0
        var origin: String = ""
        static func < (a: Self, b: Self) -> Bool { a.time == b.time ? a.origin < b.origin : a.time < b.time }
    }
    struct Entry: Codable, Equatable {
        var item: ZekrItem
        var edited: Stamp
        var deleted = false
        var epoch = Stamp()
        var baseline: Int
        var increments: [String: Int] = [:]
        // Optional so ledgers saved before correction support still decode safely.
        var decrements: [String: Int]? = nil
        // Optional for compatibility with saved ledgers from before goal cycling.
        var cyclesAtTarget: Bool? = nil
        var totalCount: Int {
            let added = increments.values.reduce(baseline) { min(Int.max / 2, $0 + $1) }
            let removed = (decrements ?? [:]).values.reduce(0, +)
            return max(0, added - removed)
        }
        var count: Int {
            guard cyclesAtTarget == true, item.defaultTarget > 0 else { return totalCount }
            return totalCount % item.defaultTarget
        }
        var completedCycles: Int {
            guard cyclesAtTarget == true, item.defaultTarget > 0 else { return 0 }
            return totalCount / item.defaultTarget
        }
    }
    var entries: [String: Entry] = [:]

    mutating func capture(_ items: [ZekrItem], previous: [ZekrItem], stamp: Stamp) {
        let keys = Set(items.map { DhikrText.key($0.title) })
        for old in previous where !keys.contains(DhikrText.key(old.title)) {
            let key = DhikrText.key(old.title)
            if var entry = entries[key] { entry.deleted = true; entry.edited = stamp; entries[key] = entry }
        }
        for item in items {
            let key = DhikrText.key(item.title)
            guard !key.isEmpty else { continue }
            guard var entry = entries[key] else {
                entries[key] = Entry(item: item, edited: stamp, baseline: item.count)
                continue
            }
            let old = previous.first { DhikrText.key($0.title) == key }
            if old == nil { entry.baseline = max(entry.baseline, item.count) }
            if entry.deleted { entry.edited = stamp; entry.deleted = false; entry.epoch = stamp; entry.baseline = item.count; entry.increments = [:]; entry.decrements = nil }
            if let old, old.defaultTarget != item.defaultTarget, entry.cyclesAtTarget == true {
                // A new target starts from the currently displayed progress, not old cycles.
                entry.epoch = stamp; entry.baseline = item.count; entry.increments = [:]; entry.decrements = nil
            } else if let old, item.count < old.count {
                entry.epoch = stamp; entry.baseline = item.count; entry.increments = [:]; entry.decrements = nil
            } else if let old, item.count > old.count {
                entry.increments[stamp.origin, default: 0] += item.count - old.count
            }
            if old?.title != item.title || old?.defaultTarget != item.defaultTarget || old?.isBuiltIn != item.isBuiltIn || entry.deleted {
                entry.item = item; entry.edited = stamp
            }
            entries[key] = entry
        }
    }
    mutating func merge(_ other: Self) {
        for (key, remote) in other.entries {
            guard var local = entries[key] else { entries[key] = remote; continue }
            if local.edited < remote.edited {
                local.item = remote.item; local.edited = remote.edited; local.deleted = remote.deleted
            }
            if local.epoch < remote.epoch {
                local.epoch = remote.epoch; local.baseline = remote.baseline; local.increments = remote.increments; local.decrements = remote.decrements
            } else if local.epoch == remote.epoch {
                local.baseline = max(local.baseline, remote.baseline)
                for (device, value) in remote.increments { local.increments[device] = max(local.increments[device] ?? 0, value) }
                var corrections = local.decrements ?? [:]
                for (device, value) in remote.decrements ?? [:] { corrections[device] = max(corrections[device] ?? 0, value) }
                local.decrements = corrections.isEmpty ? nil : corrections
            }
            if local.cyclesAtTarget == true || remote.cyclesAtTarget == true { local.cyclesAtTarget = true }
            entries[key] = local
        }
    }

    /// Keep monotonic per-device totals; project the current cycle with modulo.
    /// No reset epoch is emitted at an automatic boundary, so offline taps still add up.
    mutating func recordTap(title: String, stamp: Stamp) -> Bool? {
        let key = DhikrText.key(title)
        guard var entry = entries[key], !entry.deleted, entry.item.defaultTarget > 0,
              entry.increments[stamp.origin, default: 0] < Int.max / 4 - 1 else { return nil }
        let oldCycles = entry.totalCount / entry.item.defaultTarget
        entry.cyclesAtTarget = true
        entry.increments[stamp.origin, default: 0] += 1
        entries[key] = entry
        return entry.completedCycles > oldCycles
    }

    /// Record an intentional correction as a per-device monotonic value, so it survives merges.
    mutating func recordDecrement(title: String, stamp: Stamp) -> Bool {
        let key = DhikrText.key(title)
        guard var entry = entries[key], !entry.deleted, entry.count > 0 else { return false }
        var corrections = entry.decrements ?? [:]
        guard corrections[stamp.origin, default: 0] < Int.max / 4 - 1 else { return false }
        corrections[stamp.origin, default: 0] += 1
        entry.decrements = corrections
        entries[key] = entry
        return true
    }

    var items: [ZekrItem] {
        entries.sorted { $0.key < $1.key }.compactMap { _, entry in
            guard !entry.deleted else { return nil }
            var item = entry.item; item.count = entry.count; return item
        }
    }
    var isValid: Bool {
        entries.allSatisfy { key, entry in
            key == DhikrText.key(entry.item.title) && !key.isEmpty && entry.baseline >= 0 && entry.baseline < Int.max / 4 &&
            entry.increments.values.allSatisfy { $0 >= 0 && $0 < Int.max / 4 } &&
            (entry.decrements ?? [:]).values.allSatisfy { $0 >= 0 && $0 < Int.max / 4 } &&
            (1...10000).contains(entry.item.defaultTarget) && entry.edited.time.isFinite && entry.epoch.time.isFinite
        }
    }
}
