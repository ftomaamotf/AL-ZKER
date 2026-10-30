import Foundation
var checks = 0
func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    precondition(condition(), message); checks += 1
}
let item = ZekrItem(title: "سبحان الله", count: 20)
let base = DhikrLedger.Stamp(time: 1, origin: "migration")
var seed = DhikrLedger()
seed.capture([item], previous: [], stamp: base)
var phone = seed, watch = seed
var p = item; p.count += 2
var w = item; w.count += 3
phone.capture([p], previous: [item], stamp: .init(time: 2, origin: "phone"))
watch.capture([w], previous: [item], stamp: .init(time: 3, origin: "watch"))
phone.merge(watch); watch.merge(phone)
check(phone == watch, "convergence")
check(phone.items[0].count == 25, "concurrent increments preserved")
phone.merge(watch); phone.merge(watch)
check(phone.items[0].count == 25, "replay is idempotent")
let stale = watch
phone.capture([], previous: phone.items, stamp: .init(time: 5, origin: "phone"))
phone.merge(stale)
check(phone.items.isEmpty, "stale snapshots do not resurrect deletions")
watch.merge(phone)
check(watch.items.isEmpty, "deletion propagates")
var readded = item; readded.count = 1
phone.capture([readded], previous: [], stamp: .init(time: 6, origin: "phone"))
watch.merge(phone)
check(watch.items.count == 1 && watch.items[0].count == 1, "explicit re-add starts fresh")
var zero = readded; zero.count = 0
phone.capture([zero], previous: [readded], stamp: .init(time: 7, origin: "phone"))
phone.merge(stale)
check(phone.items[0].count == 0, "reset survives stale counts")
var one = zero; one.count = 1
phone.capture([one], previous: [zero], stamp: .init(time: 8, origin: "phone"))
check(phone.items[0].count == 1, "count after reset")
let encoded = try JSONEncoder().encode(phone)
let restored = try JSONDecoder().decode(DhikrLedger.self, from: encoded)
check(restored == phone && restored.isValid, "persistence round trip")
check(DhikrText.key("سُبْحَانَ اللَّه") == "سبحان الله", "Arabic marks")
check(DhikrText.key("أستغفر الله") == DhikrText.key("استغفر الله"), "alef equivalence")
// Updates on different dhikr must both survive a disconnection.
let second = ZekrItem(title: "الحمد لله", count: 4)
var initial = DhikrLedger(); initial.capture([item, second], previous: [], stamp: base)
var a = initial, b = initial
var secondPlus = second; secondPlus.count += 1
var firstPlus = item; firstPlus.count += 1
a.capture([firstPlus, second], previous: [item, second], stamp: .init(time: 2, origin: "a"))
b.capture([item, secondPlus], previous: [item, second], stamp: .init(time: 2, origin: "b"))
a.merge(b); b.merge(a)
check(a == b && a.items.map(\.count).reduce(0,+) == 26, "different dhikr concurrent changes")
var empty = DhikrLedger()
empty.capture([item], previous: [], stamp: base)
check(empty.items[0].count == 20, "add to empty library")
var duplicate = item; duplicate.id = UUID(); duplicate.count = 30
a = DhikrLedger(); a.capture([item, duplicate], previous: [], stamp: base)
check(a.items.count == 1 && a.items[0].count == 30, "duplicate migration keeps larger existing counter")
var replicas = [initial, initial]
for i in 0..<500 {
    let device = i % 2
    let before = replicas[device].items
    var after = before
    let index = i % after.count
    after[index].count += 1
    replicas[device].capture(after, previous: before, stamp: .init(time: Double(10+i), origin: "device\(device)"))
    if i % 7 == 0 { replicas[0].merge(replicas[1]) }
    if i % 11 == 0 { replicas[1].merge(replicas[0]) }
}
replicas[0].merge(replicas[1]); replicas[1].merge(replicas[0])
check(replicas[0] == replicas[1], "500-operation reordered convergence")
check(replicas[0].items.map(\.count).reduce(0,+) == 524, "500 increments preserved")

// Built-in protection survives migration, edits, persistence, and sync.
check(ZekrItem.builtInAzkar.allSatisfy(\.isBuiltIn), "all defaults are protected")
let legacyBuiltIn = try! JSONDecoder().decode(ZekrItem.self, from: Data("{\"title\":\"سُبْحَانَ الله\",\"count\":12}".utf8))
check(legacyBuiltIn.isBuiltIn && legacyBuiltIn.count == 12, "legacy built-in migrated without losing count")
let legacyCustom = try! JSONDecoder().decode(ZekrItem.self, from: Data("{\"title\":\"ذكري المضاف يدويا\"}".utf8))
check(!legacyCustom.isBuiltIn, "legacy custom remains deletable")
var renamedBuiltIn = ZekrItem.builtInAzkar[0]
renamedBuiltIn.title = "ذكر أساسي معدل"
let restoredBuiltIn = try! JSONDecoder().decode(ZekrItem.self, from: JSONEncoder().encode(renamedBuiltIn))
check(restoredBuiltIn.isBuiltIn, "renamed default stays protected after persistence")
let manual = ZekrItem(title: "ذكر يدوي", isBuiltIn: false)
check(!(try! JSONDecoder().decode(ZekrItem.self, from: JSONEncoder().encode(manual))).isBuiltIn, "manual origin persists")
var protectedLedger = DhikrLedger()
protectedLedger.capture([renamedBuiltIn, manual], previous: [], stamp: .init(time: 1, origin: "phone"))
var protectedReplica = DhikrLedger()
protectedReplica.merge(try! JSONDecoder().decode(DhikrLedger.self, from: JSONEncoder().encode(protectedLedger)))
check(protectedReplica.items.first { $0.id == renamedBuiltIn.id }?.isBuiltIn == true, "built-in protection syncs")
check(protectedReplica.items.first { $0.id == manual.id }?.isBuiltIn == false, "custom remains deletable after sync")

print("Total: \(checks) regression checks passed")
