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

// MARK: - واجهة عرض اتجاه القبلة للآيفون
public struct PhoneQiblaView: View {
    @StateObject private var qibla = PhoneQiblaManager.shared
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 12)
                    
                    if qibla.isReady {
                    // 1. بطاقة البوصلة الرئيسية
                    ZStack {
                        // هالة متوهجة عند محاذاة القبلة
                        if qibla.isAligned {
                            Circle()
                                .fill(Color.green.opacity(0.14))
                                .frame(width: 300, height: 300)
                                .blur(radius: 16)
                        }
                        
                        // القرص الدائري الخارجي للبوصلة
                        Circle()
                            .stroke(
                                qibla.isAligned ? Color.green : Color.gray.opacity(0.25),
                                lineWidth: qibla.isAligned ? 4 : 2
                            )
                            .frame(width: 270, height: 270)
                            .shadow(color: qibla.isAligned ? Color.green.opacity(0.4) : Color.clear, radius: 12)
                        
                        // تدريجات البوصلة والاتجاهات الأربعة
                        VStack {
                            Text("ش (شمال)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                            Spacer()
                            Text("ج (جنوب)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 250)
                        
                        HStack {
                            Text("غ (غرب)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("شـ (شرق)")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 250)
                        
                        // القرص المركزي
                        Circle()
                            .fill(qibla.isAligned ? Color.green.opacity(0.12) : Color(UIColor.secondarySystemBackground))
                            .frame(width: 104, height: 104)
                            .overlay(
                                Circle()
                                    .stroke(qibla.isAligned ? Color.green.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1.5)
                            )
                        
                        VStack(spacing: 2) {
                            Text("\(Int(qibla.qiblaBearing))°")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(qibla.isAligned ? .green : .primary)
                            Text("القبلة")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        // سهم وعقرب الكعبة المشرفة الدوار
                        VStack(spacing: 0) {
                            // رأس السهم يحمل مجسم الكعبة
                            ZStack {
                                Circle()
                                    .fill(qibla.isAligned ? Color.green : Color.orange)
                                    .frame(width: 44, height: 44)
                                    .shadow(color: qibla.isAligned ? Color.green.opacity(0.6) : Color.orange.opacity(0.4), radius: 6)
                                
                                Text("🕋")
                                    .font(.system(size: 22))
                            }
                            .offset(y: -10)
                            
                            // جسم السهم
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            qibla.isAligned ? Color.green : Color.orange,
                                            qibla.isAligned ? Color.green.opacity(0.2) : Color.orange.opacity(0.2)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 6, height: 82)
                            
                            Spacer()
                                .frame(height: 96)
                        }
                        .rotationEffect(Angle(degrees: qibla.needleAngle))
                        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: qibla.needleAngle)
                    }
                    .frame(height: 310)
                    .padding(.vertical, 8)
                    
                    // 2. شارة التوجيه والمحاذاة
                    if qibla.isAligned {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title3)
                            Text("أنت الآن باتجاه القبلة المشرفة 🕋")
                                .font(.headline.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.green)
                        .clipShape(Capsule())
                        .shadow(color: Color.green.opacity(0.4), radius: 8, y: 3)
                    } else {
                        let diff = qibla.needleAngle
                        HStack(spacing: 8) {
                            if diff > 4 {
                                Image(systemName: "arrow.clockwise")
                                Text("دُر يميناً \(abs(Int(diff)))° نحو الكعبة")
                            } else if diff < -4 {
                                Image(systemName: "arrow.counterclockwise")
                                Text("دُر يساراً \(abs(Int(diff)))° نحو الكعبة")
                            } else {
                                Text("احمل الهاتف أفقياً لتحديد دقيق")
                            }
                        }
                        .font(.headline)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    // 3. بطاقات البيانات والمعلومات
                    HStack(spacing: 12) {
                        // زاوية القبلة
                        VStack(spacing: 4) {
                            Text("زاوية القبلة")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(qibla.qiblaBearing))°")
                                .font(.title3.bold())
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // اتجاه الهاتف
                        VStack(spacing: 4) {
                            Text("اتجاه الهاتف")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(qibla.heading))°")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        
                        // المسافة لمكة
                        if qibla.distanceToMeccaKm > 0 {
                            VStack(spacing: 4) {
                                Text("المسافة لمكة")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(qibla.distanceToMeccaKm)) كم")
                                    .font(.title3.bold())
                                    .foregroundColor(.teal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "location.slash").font(.largeTitle)
                            Text(qibla.statusMessage).multilineTextAlignment(.center)
                            Button("إعادة المحاولة") { qibla.stop(); qibla.start() }
                            if qibla.authorizationStatus == .denied || qibla.authorizationStatus == .restricted {
                                Link("فتح إعدادات الموقع", destination: URL(string: UIApplication.openSettingsURLString)!)
                            }
                        }
                        .padding()
                    }
                    Text("ملاحظة: لضمان أعلى دقة، يُفضل حمل الهاتف بشكل أفقي مستوٍ والابتعاد عن المعادن أو المجالات المغناطيسية.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("اتِّجَاهُ الْقِبْلَةِ")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                qibla.start()
            }
            .onDisappear {
                qibla.stop()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
