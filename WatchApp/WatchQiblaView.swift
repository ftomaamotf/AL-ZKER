//
//  WatchQiblaView.swift
//  Fadhkuruni Watch App (Qibla Compass)
//

import SwiftUI
import CoreLocation
import WatchKit
import Combine

// MARK: - مدير حساب اتجاه القبلة للساعة
public final class QiblaManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = QiblaManager()
    
    private let locationManager = CLLocationManager()
    
    // إحداثيات الكعبة المشرفة في مكة المكرمة
    private let meccaLatitude: Double = 21.422487
    private let meccaLongitude: Double = 39.826206
    
    @Published public var heading: Double = 0.0          // زاوية توجيه الساعة (0..360)
    @Published public var qiblaBearing: Double = 245.0   // زاوية القبلة بالنسبة للشمال (افتراضي لشبه الجزيرة)
    @Published public var needleAngle: Double = 0.0      // زاوية عقرب القبلة بالنسبة لشاشة الساعة (-180..180)
    @Published public var isAligned: Bool = false        // هل الساعة موجهة تماماً للقبلة
    @Published public var statusMessage: String = "جاري تحديد الموقع..."
    @Published public var isHeadingAvailable: Bool = true
    @Published public var hasLocationFix: Bool = false
    
    @Published public var hasHeadingFix = false
    private var isUpdating = false
    public var isReady: Bool { hasLocationFix && hasHeadingFix && isHeadingAvailable }

    private var lastHapticTime: Date = .distantPast
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 20.0
    }
    
    public func start() {
        isUpdating = true
        hasLocationFix = false
        hasHeadingFix = false
        isAligned = false
        statusMessage = "جاري تحديد الموقع واتجاه البوصلة..."
        isHeadingAvailable = CLLocationManager.headingAvailable()
        guard CLLocationManager.locationServicesEnabled() else {
            statusMessage = "خدمات الموقع متوقفة؛ فعّلها من إعدادات الجهاز"
            return
        }
        guard locationManager.authorizationStatus != .denied,
              locationManager.authorizationStatus != .restricted else {
            statusMessage = "يرجى السماح بالموقع من إعدادات الجهاز لعرض اتجاه القبلة"
            return
        }
        let auth = locationManager.authorizationStatus
        if auth == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if CLLocationManager.headingAvailable() {
            locationManager.headingFilter = 1.0
            locationManager.startUpdatingHeading()
            isHeadingAvailable = true
        } else {
            isHeadingAvailable = false
            statusMessage = "حساس البوصلة غير متوفر"
        }
        
        locationManager.startUpdatingLocation()
    }
    
    public func stop() {
        isUpdating = false
        hasLocationFix = false
        hasHeadingFix = false
        isAligned = false
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }
    
    // حساب زاوية القبلة الكروية العظمى (Great Circle Bearing)
    public func calculateBearing(from userCoord: CLLocationCoordinate2D) -> Double {
        let lat1 = userCoord.latitude * .pi / 180.0
        let lon1 = userCoord.longitude * .pi / 180.0
        let lat2 = meccaLatitude * .pi / 180.0
        let lon2 = meccaLongitude * .pi / 180.0
        
        let dLon = lon2 - lon1
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        var deg = atan2(y, x) * 180.0 / .pi
        if deg < 0 {
            deg += 360.0
        }
        return deg
    }
    
    // MARK: - CLLocationManagerDelegate
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isUpdating else { return }
        let auth = manager.authorizationStatus
        if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        } else if auth == .denied || auth == .restricted {
            hasLocationFix = false
            hasHeadingFix = false
            isAligned = false
            manager.stopUpdatingLocation()
            manager.stopUpdatingHeading()
            statusMessage = "يرجى السماح بالموقع من إعدادات الجهاز لعرض اتجاه القبلة"
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard isUpdating, let location = locations.last,
              location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 1000,
              abs(location.timestamp.timeIntervalSinceNow) < 60 else { return }
        let bearing = calculateBearing(from: location.coordinate)
        
        DispatchQueue.main.async {
            guard self.isUpdating else { return }
            self.qiblaBearing = bearing
            self.hasLocationFix = true
            self.statusMessage = "تم تحديد الموقع"
            self.refreshNeedle()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard isUpdating else { return }
        guard newHeading.headingAccuracy >= 0,
              abs(newHeading.timestamp.timeIntervalSinceNow) < 60,
              newHeading.trueHeading >= 0 else {
            hasHeadingFix = false
            isAligned = false
            statusMessage = "تعذر قراءة البوصلة؛ ابتعد عن المعادن وأعد المحاولة"
            return
        }
        let currentHeading = newHeading.trueHeading
        
        DispatchQueue.main.async {
            guard self.isUpdating else { return }
            self.hasHeadingFix = true
            self.heading = currentHeading
            self.refreshNeedle()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard isUpdating else { return }
        hasLocationFix = false
        isAligned = false
        statusMessage = "تعذر تحديد الموقع؛ تأكد من الأذونات وحاول مجددًا"
    }

    private func refreshNeedle() {
        guard isReady else {
            isAligned = false
            statusMessage = isHeadingAvailable ? "جاري تحديد الموقع واتجاه البوصلة؛ ابتعد عن المعادن" : "حساس البوصلة غير متوفر على هذا الجهاز"
            return
        }
        var diff = qiblaBearing - heading
        while diff > 180 { diff -= 360 }
        while diff < -180 { diff += 360 }
        
        self.needleAngle = diff
        
        // المحاذاة الدقيقة: عندما تكون الزاوية ضمن ±6 درجات
        let aligned = abs(diff) <= 6.0
        if aligned != self.isAligned {
            self.isAligned = aligned
            if aligned {
                let now = Date()
                if now.timeIntervalSince(lastHapticTime) > 1.2 {
                    lastHapticTime = now
                    WKInterfaceDevice.current().play(.directionUp)
                }
            }
        }
    }
}

// MARK: - واجهة القبلة
public struct WatchQiblaView: View {
    @StateObject private var qibla = QiblaManager.shared
    @Environment(\.dismiss) private var dismiss
    public init() {}
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 12, weight: .semibold))
                            .frame(width: 36, height: 36)
                            .fadhkuruniGlass(radius: 18)
                    }
                    .buttonStyle(.plain).accessibilityLabel("رجوع")
                    Spacer()
                    Text("القبلة").font(.headline)
                }
                if qibla.isReady {
                    ModernQiblaDial(heading: qibla.heading, bearing: qibla.qiblaBearing,
                                    needle: qibla.needleAngle, aligned: qibla.isAligned, compact: true)
                        .frame(maxWidth: 160)
                    QiblaDirectionStatus(aligned: qibla.isAligned, needle: qibla.needleAngle, compact: true)
                    Text("اتجاه الساعة: \(Int(qibla.heading))°")
                        .font(.caption2).monospacedDigit().foregroundStyle(.secondary)
                } else {
                    Image(systemName: "location.magnifyingglass")
                        .font(.title2).foregroundStyle(.teal)
                    Text(qibla.statusMessage).font(.caption).multilineTextAlignment(.center)
                    Button { qibla.stop(); qibla.start() } label: {
                        Text("إعادة المحاولة").font(.caption)
                            .frame(maxWidth: .infinity, minHeight: 42)
                            .fadhkuruniGlass(tint: .teal)
                    }.buttonStyle(.plain)
                }
                Text("أبقِ الساعة مستوية وبعيدة عن المعادن")
                    .font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(.horizontal, 8).padding(.bottom, 8)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear { qibla.start() }
        .onDisappear { qibla.stop() }
    }
}
