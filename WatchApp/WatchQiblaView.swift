//
//  WatchQiblaView.swift
//  Fadhkuruni Watch App
//

import SwiftUI
import CoreLocation
import WatchKit
import Combine

// MARK: - مدير حساب اتجاه القبلة والبوصلة
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
    
    private var lastHapticTime: Date = .distantPast
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 20.0
    }
    
    public func start() {
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
        let auth = manager.authorizationStatus
        if auth == .authorizedWhenInUse || auth == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        } else if auth == .denied || auth == .restricted {
            statusMessage = "يرجى السماح بالوصول للموقع"
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let bearing = calculateBearing(from: location.coordinate)
        DispatchQueue.main.async {
            self.qiblaBearing = bearing
            self.hasLocationFix = true
            self.statusMessage = "تم تحديد الموقع"
            self.refreshNeedle()
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let currentHeading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
        guard currentHeading >= 0 else { return }
        
        DispatchQueue.main.async {
            self.heading = currentHeading
            self.refreshNeedle()
        }
    }
    
    private func refreshNeedle() {
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

// MARK: - واجهة عرض اتجاه القبلة لساعة آبل
public struct WatchQiblaView: View {
    @StateObject private var qibla = QiblaManager.shared
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                // 1. المؤشر الرئيسي للقبلة والبوصلة
                ZStack {
                    // القرص الخارجي للبوصلة
                    Circle()
                        .stroke(
                            qibla.isAligned ? Color.green.opacity(0.8) : Color.gray.opacity(0.3),
                            lineWidth: qibla.isAligned ? 3 : 2
                        )
                        .frame(width: 130, height: 130)
                        .shadow(color: qibla.isAligned ? Color.green.opacity(0.6) : Color.clear, radius: 8)
                    
                    // الاتجاهات الأربعة الرئيسية على القرص
                    VStack {
                        Text("ش")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Spacer()
                        Text("ج")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 122)
                    
                    HStack {
                        Text("غ")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("شـ")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 122)
                    
                    // الدائرة الداخلية المركزية
                    Circle()
                        .fill(qibla.isAligned ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 54, height: 54)
                    
                    // مركز البوصلة: يعرض زاوية القبلة
                    VStack(spacing: 0) {
                        Text("\(Int(qibla.qiblaBearing))°")
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundColor(qibla.isAligned ? .green : .primary)
                        Text("القبلة")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    
                    // سهم وعقرب الكعبة المشرفة الدوار
                    VStack(spacing: 0) {
                        // مجسم الكعبة عند رأس السهم
                        ZStack {
                            Circle()
                                .fill(qibla.isAligned ? Color.green : Color.orange)
                                .frame(width: 26, height: 26)
                                .shadow(color: qibla.isAligned ? Color.green : Color.orange.opacity(0.5), radius: 4)
                            
                            Text("🕋")
                                .font(.system(size: 13))
                        }
                        .offset(y: -5)
                        
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
                            .frame(width: 3.5, height: 38)
                        
                        Spacer()
                            .frame(height: 48)
                    }
                    .rotationEffect(Angle(degrees: qibla.needleAngle))
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: qibla.needleAngle)
                }
                .padding(.top, 4)
                
                // 2. حالة التوجيه الحالية (توجيه يمين / يسار / اتجاه صحيح)
                if qibla.isAligned {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                        Text("أنت باتجاه القبلة 🕋")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .shadow(color: Color.green.opacity(0.4), radius: 4)
                } else {
                    let diff = qibla.needleAngle
                    HStack(spacing: 5) {
                        if diff > 6 {
                            Text("دُر يميناً ⟳")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        } else if diff < -6 {
                            Text("دُر يساراً ⟲")
                                .font(.caption.bold())
                                .foregroundColor(.orange)
                        } else {
                            Text("اضبط الساعة أفقياً")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // 3. معلومات البوصلة السريعة
                HStack(spacing: 12) {
                    VStack(alignment: .center, spacing: 1) {
                        Text("اتجاه ساعتك")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(Int(qibla.heading))°")
                            .font(.caption2.bold())
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                        .frame(height: 16)
                    
                    VStack(alignment: .center, spacing: 1) {
                        Text("مكة المكرمة")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(Int(qibla.qiblaBearing))°")
                            .font(.caption2.bold())
                            .foregroundColor(.green)
                    }
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("اتجاه القبلة")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            qibla.start()
        }
        .onDisappear {
            qibla.stop()
        }
    }
}
