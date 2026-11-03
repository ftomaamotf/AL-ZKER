import Foundation
import CoreLocation
import Combine

struct PrayerTime: Identifiable, Hashable {
    let id: String
    let title: String
    let symbol: String
    let date: Date
}

@MainActor
final class PrayerTimesManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    static let shared = PrayerTimesManager()

    @Published private(set) var times: [PrayerTime] = []
    @Published private(set) var statusMessage = "اضغط لعرض مواقيت الصلاة"
    @Published private(set) var isLoading = false

    private let locationManager = CLLocationManager()
    private var lastCoordinate: CLLocationCoordinate2D?

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer

        // استرجاع آخر إحداثيات معروفة فوراً لحساب المواقيت وجدولة التنبيهات دون انتظار GPS
        let savedLat = UserDefaults.standard.double(forKey: "fadhkuruni_last_latitude")
        let savedLon = UserDefaults.standard.double(forKey: "fadhkuruni_last_longitude")
        if savedLat != 0 || savedLon != 0 {
            let coord = CLLocationCoordinate2D(latitude: savedLat, longitude: savedLon)
            lastCoordinate = coord
            times = PrayerTimeCalculator.times(for: Date(), coordinate: coord)
            saveCalculatedPrayerMinutes(from: times)
        }
    }

    func refresh() {
        guard CLLocationManager.locationServicesEnabled() else {
            statusMessage = "فعّل خدمات الموقع لعرض المواقيت"
            return
        }
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isLoading = true
            statusMessage = "جاري تحديد موقعك…"
            locationManager.requestLocation()
        case .notDetermined:
            statusMessage = "يلزم السماح بالموقع لحساب المواقيت"
            locationManager.requestWhenInUseAuthorization()
        default:
            statusMessage = "اسمح بالموقع من إعدادات الآيفون لعرض المواقيت"
        }
    }

    func applyManualAdjustments() {
        guard let lastCoordinate else {
            refresh()
            return
        }
        times = PrayerTimeCalculator.times(for: Date(), coordinate: lastCoordinate)
        saveCalculatedPrayerMinutes(from: times)
        statusMessage = "تم تطبيق التعديلات اليدوية"
    }

    private func saveCalculatedPrayerMinutes(from prayerTimes: [PrayerTime]) {
        let calendar = Calendar.current
        for prayer in prayerTimes {
            let components = calendar.dateComponents([.hour, .minute], from: prayer.date)
            if let hour = components.hour, let minute = components.minute {
                let totalMinutes = hour * 60 + minute
                UserDefaults.standard.set(totalMinutes, forKey: "fadhkuruni_prayer_\(prayer.id)_minutes")
            }
        }
        DhikrSummaryNotificationScheduler.shared.refreshPrayerReminders()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            refresh()
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last, location.horizontalAccuracy >= 0 else { return }
        lastCoordinate = location.coordinate
        UserDefaults.standard.set(location.coordinate.latitude, forKey: "fadhkuruni_last_latitude")
        UserDefaults.standard.set(location.coordinate.longitude, forKey: "fadhkuruni_last_longitude")
        applyManualAdjustments()
        isLoading = false
        statusMessage = times.isEmpty ? "تعذر حساب المواقيت لهذا الموقع" : "تتحدث المواقيت حسب موقعك"
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLoading = false
        statusMessage = "تعذر تحديد الموقع، حاول مرة أخرى"
    }
}

private enum PrayerTimeCalculator {
    static func times(for date: Date, coordinate: CLLocationCoordinate2D) -> [PrayerTime] {
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.startOfDay(for: date)
        let zoneSeconds = Double(TimeZone.current.secondsFromGMT(for: date))
        let day = julianDay(for: date)
        let (declination, equationMinutes) = solarPosition(julianDay: day)
        let latitude = coordinate.latitude * .pi / 180
        let noonMinutes = 720 - 4 * coordinate.longitude - equationMinutes + zoneSeconds / 60

        func dateAt(_ minutes: Double, adjustmentID: String? = nil) -> Date {
            let adjustment = adjustmentID.map { PrayerTimeAdjustmentStore.offset(for: $0) } ?? 0
            return start.addingTimeInterval((minutes + Double(adjustment)) * 60)
        }
        func hourAngle(zenith: Double) -> Double? {
            let z = zenith * .pi / 180
            let cosine = (cos(z) - sin(latitude) * sin(declination)) / (cos(latitude) * cos(declination))
            guard (-1...1).contains(cosine) else { return nil }
            return acos(cosine) * 180 / .pi * 4
        }
        func asrHourAngle() -> Double? {
            let altitude = atan(1 / (1 + tan(abs(latitude - declination))))
            return hourAngle(zenith: 90 - altitude * 180 / .pi)
        }

        let sunriseAngle = hourAngle(zenith: 90.833) ?? 360
        let fajrAngle = hourAngle(zenith: 108) ?? 540
        let asrAngle = asrHourAngle() ?? 240
        let ishaAngle = hourAngle(zenith: 107) ?? 420

        return [
            PrayerTime(id: "fajr", title: "الفجر", symbol: "moon.stars.fill", date: dateAt(noonMinutes - fajrAngle, adjustmentID: "fajr")),
            PrayerTime(id: "sunrise", title: "الشروق", symbol: "sunrise.fill", date: dateAt(noonMinutes - sunriseAngle, adjustmentID: "sunrise")),
            PrayerTime(id: "dhuhr", title: "الظهر", symbol: "sun.max.fill", date: dateAt(noonMinutes, adjustmentID: "dhuhr")),
            PrayerTime(id: "asr", title: "العصر", symbol: "sun.haze.fill", date: dateAt(noonMinutes + asrAngle, adjustmentID: "asr")),
            PrayerTime(id: "maghrib", title: "المغرب", symbol: "sunset.fill", date: dateAt(noonMinutes + sunriseAngle, adjustmentID: "maghrib")),
            PrayerTime(id: "isha", title: "العشاء", symbol: "moon.fill", date: dateAt(noonMinutes + ishaAngle, adjustmentID: "isha"))
        ]
    }

    private static func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private static func solarPosition(julianDay jd: Double) -> (Double, Double) {
        let t = (jd - 2_451_545) / 36_525
        let l0 = wrap(280.46646 + t * (36_000.76983 + t * 0.0003032), 360)
        let m = wrap(357.52911 + t * (35_999.05029 - 0.0001537 * t), 360)
        let eccentricity = 0.016708634 - t * (0.000042037 + 0.0000001267 * t)
        let center = sin(radians(m)) * (1.914602 - t * (0.004817 + 0.000014 * t))
            + sin(2 * radians(m)) * (0.019993 - 0.000101 * t) + sin(3 * radians(m)) * 0.000289
        let trueLongitude = l0 + center
        let omega = 125.04 - 1934.136 * t
        let apparentLongitude = trueLongitude - 0.00569 - 0.00478 * sin(radians(omega))
        let meanObliquity = 23 + (26 + ((21.448 - t * (46.815 + t * (0.00059 - t * 0.001813))) / 60)) / 60
        let obliquity = meanObliquity + 0.00256 * cos(radians(omega))
        let declination = asin(sin(radians(obliquity)) * sin(radians(apparentLongitude)))
        let y = pow(tan(radians(obliquity) / 2), 2)
        let equation = 4 * degrees(
            y * sin(2 * radians(l0)) - 2 * eccentricity * sin(radians(m))
            + 4 * eccentricity * y * sin(radians(m)) * cos(2 * radians(l0))
            - 0.5 * y * y * sin(4 * radians(l0)) - 1.25 * eccentricity * eccentricity * sin(2 * radians(m))
        )
        return (declination, equation)
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }
    private static func degrees(_ radians: Double) -> Double { radians * 180 / .pi }
    private static func wrap(_ value: Double, _ modulus: Double) -> Double { (value.truncatingRemainder(dividingBy: modulus) + modulus).truncatingRemainder(dividingBy: modulus) }
}
