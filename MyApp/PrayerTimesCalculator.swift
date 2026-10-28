//
//  PrayerTimesCalculator.swift
//  Fadhkuruni (Shared Islamic Astronomical Prayer Times Engine)
//

import Foundation
import CoreLocation

public enum PrayerType: String, CaseIterable, Identifiable {
    case fajr = "الفجر"
    case sunrise = "الشروق"
    case dhuhr = "الظهر"
    case asr = "العصر"
    case maghrib = "المغرب"
    case isha = "العشاء"
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .fajr: return "sun.haze.fill"
        case .sunrise: return "sunrise.fill"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.min.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

public struct PrayerTimeItem: Identifiable {
    public var id: String { type.rawValue }
    public let type: PrayerType
    public let time: Date
    public let isNext: Bool
    
    public var formattedTime: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ar_SA")
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
}

public struct DailyPrayerTimes {
    public let items: [PrayerTimeItem]
    public let nextPrayer: PrayerTimeItem?
    public let timeRemainingText: String
}

public final class PrayerTimesCalculator {
    public static func calculate(for coordinate: CLLocationCoordinate2D, date: Date = Date(), timeZone: TimeZone = .current) -> DailyPrayerTimes {
        let calendar = Calendar.current
        let comps = calendar.dateComponents(in: timeZone, from: date)
        guard let year = comps.year, let month = comps.month, let day = comps.day else {
            return DailyPrayerTimes(items: [], nextPrayer: nil, timeRemainingText: "")
        }
        
        let tzOffsetHours = Double(timeZone.secondsFromGMT(for: date)) / 3600.0
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        
        let d2r = Double.pi / 180.0
        let r2d = 180.0 / Double.pi
        
        var Y = Double(year)
        var M = Double(month)
        let D = Double(day)
        
        if M <= 2 {
            Y -= 1
            M += 12
        }
        
        let A = floor(Y / 100.0)
        let B = 2.0 - A + floor(A / 4.0)
        let JD = floor(365.25 * (Y + 4716.0)) + floor(30.6001 * (M + 1.0)) + D + B - 1524.5
        let d = JD - 2451545.0
        
        let q = 280.459 + 0.98564736 * d
        let L = ((q.truncatingRemainder(dividingBy: 360.0)) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let g = ((357.529 + 0.98560028 * d).truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        let lambdaSun = L + 1.915 * sin(g * d2r) + 0.020 * sin(2.0 * g * d2r)
        let e = 23.439 - 0.00000036 * d
        
        var alpha = atan2(cos(e * d2r) * sin(lambdaSun * d2r), cos(lambdaSun * d2r)) * r2d
        alpha = (alpha.truncatingRemainder(dividingBy: 360.0) + 360.0).truncatingRemainder(dividingBy: 360.0)
        alpha = alpha + floor(L / 90.0) * 90.0 - floor(alpha / 90.0) * 90.0
        
        var EqT = (q - alpha) / 15.0
        while EqT > 0.5 { EqT -= 24.0 }
        while EqT < -0.5 { EqT += 24.0 }
        
        let delta = asin(sin(e * d2r) * sin(lambdaSun * d2r)) * r2d
        
        // Solar Noon (الظهر)
        let dhuhrHours = 12.0 + tzOffsetHours - (lon / 15.0) - EqT
        
        func hourAngle(forAltitude alt: Double) -> Double {
            var val = (sin(alt * d2r) - sin(lat * d2r) * sin(delta * d2r)) / (cos(lat * d2r) * cos(delta * d2r))
            val = max(-1.0, min(1.0, val))
            return acos(val) * r2d / 15.0
        }
        
        // الشروق والغروب (Sun altitude -0.833°)
        let h0 = hourAngle(forAltitude: -0.833)
        let sunriseHours = dhuhrHours - h0
        let sunsetHours = dhuhrHours + h0
        
        // الفجر (Umm Al-Qura: 18.5°)
        let hFajr = hourAngle(forAltitude: -18.5)
        let fajrHours = dhuhrHours - hFajr
        
        // العصر (Shafi'i/Hanbali shadow ratio = 1)
        let altAsr = atan(1.0 / (1.0 + tan(abs(lat - delta) * d2r))) * r2d
        let hAsr = hourAngle(forAltitude: altAsr)
        let asrHours = dhuhrHours + hAsr
        
        // المغرب (عند الغروب + 2 دقيقة احتياط)
        let maghribHours = sunsetHours + (2.0 / 60.0)
        
        // العشاء (Umm Al-Qura: 90 دقيقة بعد المغرب)
        let ishaHours = maghribHours + 1.5
        
        func dateFrom(hours: Double) -> Date {
            let normalized = (hours.truncatingRemainder(dividingBy: 24.0) + 24.0).truncatingRemainder(dividingBy: 24.0)
            let hour = Int(normalized)
            let minute = Int(round((normalized - Double(hour)) * 60.0))
            
            var c = DateComponents()
            c.year = year
            c.month = month
            c.day = day
            c.hour = hour
            c.minute = minute
            c.second = 0
            c.timeZone = timeZone
            return calendar.date(from: c) ?? date
        }
        
        let fajrDate = dateFrom(hours: fajrHours)
        let sunriseDate = dateFrom(hours: sunriseHours)
        let dhuhrDate = dateFrom(hours: dhuhrHours)
        let asrDate = dateFrom(hours: asrHours)
        let maghribDate = dateFrom(hours: maghribHours)
        let ishaDate = dateFrom(hours: ishaHours)
        
        let timesList: [(PrayerType, Date)] = [
            (.fajr, fajrDate),
            (.sunrise, sunriseDate),
            (.dhuhr, dhuhrDate),
            (.asr, asrDate),
            (.maghrib, maghribDate),
            (.isha, ishaDate)
        ]
        
        let now = Date()
        
        // تحديد الصلاة القادمة
        var nextItem: (PrayerType, Date)? = timesList.first(where: { $0.1 > now })
        var nextPrayerTomorrow = false
        if nextItem == nil {
            let tomorrowFajr = fajrDate.addingTimeInterval(86400)
            nextItem = (.fajr, tomorrowFajr)
            nextPrayerTomorrow = true
        }
        
        let nextType = nextItem?.0
        var items: [PrayerTimeItem] = []
        for (type, time) in timesList {
            let isNext = (type == nextType && !nextPrayerTomorrow)
            items.append(PrayerTimeItem(type: type, time: time, isNext: isNext))
        }
        
        var timeRemainingString = ""
        var nextPrayerItem: PrayerTimeItem? = nil
        if let next = nextItem {
            nextPrayerItem = PrayerTimeItem(type: next.0, time: next.1, isNext: true)
            let diff = max(0, next.1.timeIntervalSince(now))
            let hoursLeft = Int(diff) / 3600
            let minutesLeft = (Int(diff) % 3600) / 60
            
            if hoursLeft > 0 {
                timeRemainingString = "متبقي \(hoursLeft) س و \(minutesLeft) د"
            } else if minutesLeft > 0 {
                timeRemainingString = "متبقي \(minutesLeft) دقيقة"
            } else {
                timeRemainingString = "حان الآن وقت الصلاة"
            }
        }
        
        return DailyPrayerTimes(items: items, nextPrayer: nextPrayerItem, timeRemainingText: timeRemainingString)
    }
}
