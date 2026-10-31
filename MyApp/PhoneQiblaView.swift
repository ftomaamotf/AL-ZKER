//
//  PhoneQiblaView.swift
//  Fadhkuruni (iPhone Companion Qibla Compass)
//

import SwiftUI
import CoreLocation
import Combine
import UIKit

// MARK: - مدير حساب اتجاه القبلة للآيفون
public final class PhoneQiblaManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    public static let shared = PhoneQiblaManager()
    
    private let locationManager = CLLocationManager()
    
    // إحداثيات الكعبة المشرفة في مكة المكرمة
    private let meccaLatitude: Double = 21.422487
    private let meccaLongitude: Double = 39.826206
    
    @Published public var heading: Double = 0.0          // زاوية توجيه الهاتف الحالية (0..360)
    @Published public var qiblaBearing: Double = 245.0   // زاوية القبلة بالنسبة للشمال الحقيقي
    @Published public var needleAngle: Double = 0.0      // زاوية العقرب بالنسبة لمقدمة الهاتف (-180..180)
    @Published public var isAligned: Bool = false        // هل الهاتف موجه نحو القبلة
    @Published public var distanceToMeccaKm: Double = 0.0 // المسافة بالكيلومتر إلى مكة المكرمة
    @Published public var statusMessage: String = "جاري تحديد الموقع..."
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    @Published public var hasLocationFix = false
    @Published public var hasHeadingFix = false
    @Published public var isHeadingAvailable = true
    private var isUpdating = false
    public var isReady: Bool { hasLocationFix && hasHeadingFix && isHeadingAvailable }

    private var lastHapticTime: Date = .distantPast
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50.0
    }
    
    public func start() {
        isUpdating = true
        authorizationStatus = locationManager.authorizationStatus
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
        authorizationStatus = locationManager.authorizationStatus
        if authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }
        
        if CLLocationManager.headingAvailable() {
            locationManager.headingFilter = 1.0
            locationManager.startUpdatingHeading()
        } else {
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
    
    // حساب زاوية القبلة الكروية العظمى (Great Circle Azimuth)
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
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
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
        
        let meccaLoc = CLLocation(latitude: meccaLatitude, longitude: meccaLongitude)
        let distanceKm = location.distance(from: meccaLoc) / 1000.0
        
        DispatchQueue.main.async {
            guard self.isUpdating else { return }
            self.hasLocationFix = true
            self.qiblaBearing = bearing
            self.distanceToMeccaKm = distanceKm
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
        
        // المحاذاة الدقيقة: عندما تكون الزاوية ضمن ±4 درجات
        let aligned = abs(diff) <= 4.0
        if aligned != self.isAligned {
            self.isAligned = aligned
            if aligned {
                let now = Date()
                if now.timeIntervalSince(lastHapticTime) > 1.5 {
                    lastHapticTime = now
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            }
        }
    }
}

// MARK: - واجهة القبلة
public struct PhoneQiblaView: View {
    @StateObject private var qibla = PhoneQiblaManager.shared
    public init() {}
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    VStack(spacing: 6) {
                        Text("وجهتك إلى الكعبة").font(.title2.weight(.semibold))
                        Text("أمسك الهاتف مستوياً واتبع المؤشر")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    if qibla.isReady {
                        ModernQiblaDial(heading: qibla.heading, bearing: qibla.qiblaBearing,
                                        needle: qibla.needleAngle, aligned: qibla.isAligned)
                            .frame(maxWidth: 330)
                        QiblaDirectionStatus(aligned: qibla.isAligned, needle: qibla.needleAngle)
                        HStack(spacing: 10) {
                            metric("زاوية القبلة", value: "\(Int(qibla.qiblaBearing))°", symbol: "location.north")
                            metric("اتجاه الهاتف", value: "\(Int(qibla.heading))°", symbol: "compass.drawing")
                        }
                        if qibla.distanceToMeccaKm > 0 {
                            Label("المسافة إلى مكة: \(Int(qibla.distanceToMeccaKm).formatted()) كم", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "location.magnifyingglass")
                                .font(.system(size: 42, weight: .light)).foregroundStyle(.teal)
                            Text(qibla.statusMessage).multilineTextAlignment(.center)
                            Button { qibla.stop(); qibla.start() } label: {
                                Label("إعادة المحاولة", systemImage: "arrow.clockwise")
                                    .padding(.horizontal, 18).padding(.vertical, 12)
                                    .fadhkuruniGlass(tint: .teal)
                            }.buttonStyle(.plain)
                            if qibla.authorizationStatus == .denied || qibla.authorizationStatus == .restricted {
                                Link("فتح إعدادات الموقع", destination: URL(string: UIApplication.openSettingsURLString)!)
                            }
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 32)
                    }
                    Label("ابتعد عن المعادن والمغناطيس للحصول على قراءة أدق", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .frame(maxWidth: 520).frame(maxWidth: .infinity)
            }
            .background {
                LinearGradient(colors: [Color.teal.opacity(0.09), Color.clear], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            .navigationTitle("القبلة")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { qibla.start() }
            .onDisappear { qibla.stop() }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(spacing: 8) {
            Label(title, systemImage: symbol).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.teal.opacity(0.15), lineWidth: 0.5))
    }
}
