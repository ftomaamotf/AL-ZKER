import Foundation

func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Asia/Baghdad")!
    return calendar.date(from: DateComponents(timeZone: calendar.timeZone, year: year, month: month, day: day, hour: hour))!
}

var statistics = DhikrStatisticsLedger()
let thursday = date(2026, 11, 5)
let friday = date(2026, 11, 6)

for _ in 0..<125 { statistics.recordTap(origin: "phone", title: "سبحان الله", date: thursday) }
for _ in 0..<37 { statistics.recordTap(origin: "phone", title: "سبحان الله", date: friday) }

precondition(statistics.total(on: thursday) == 125, "Thursday must not include Friday")
precondition(statistics.total(on: friday) == 37, "Friday must not include Thursday")
precondition(statistics.total(on: thursday, for: "سبحان الله") == 125, "Per-dhikr Thursday total must stay isolated")
precondition(statistics.total(on: friday, for: "سبحان الله") == 37, "Per-dhikr Friday total must stay isolated")
print("Daily statistics regression checks passed")
