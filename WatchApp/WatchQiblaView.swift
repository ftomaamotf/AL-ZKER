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

// MARK: - واجهة عرض اتجاه القبلة لساعة آبل
public struct WatchQiblaView: View {
    @StateObject private var qibla = QiblaManager.shared
    @Environment(\.dismiss) private var dismiss
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                // زر الرجوع في أعلى الشاشة في وسطها
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 11, weight: .bold))
                        Text("الرجوع")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.35))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                .padding(.bottom, 2)
                
                if qibla.isReady {
                // 1. المؤشر الرئيسي للقبلة والبوصلة
                ZStack {
                    // القرص الخارجي للبوصلة
                    Circle()
                        .stroke(
                            qibla.isAligned ? Color.green.opacity(0.8) : Color.gray.opacity(0.3),
                            lineWidth: qibla.isAligned ? 3 : 2
                        )
                        .frame(width: 134, height: 134)
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
                    .frame(height: 124)
                    
                    HStack {
                        Text("غ")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("شـ")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                    .frame(width: 124)
                    
                    // الدائرة الداخلية المركزية
                    Circle()
                        .fill(qibla.isAligned ? Color.green.opacity(0.15) : Color.white.opacity(0.06))
                        .frame(width: 56, height: 56)
                    
                    // مركز البوصلة: يعرض زاوية القبلة
                    VStack(spacing: 0) {
                        Text("\(Int(qibla.qiblaBearing))°")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
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
                                .frame(width: 28, height: 28)
                                .shadow(color: qibla.isAligned ? Color.green : Color.orange.opacity(0.5), radius: 4)
                            
                            Text("🕋")
                                .font(.system(size: 14))
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
                            .frame(width: 4, height: 40)
                        
                        Spacer()
                            .frame(height: 50)
                    }
                    .rotationEffect(Angle(degrees: qibla.needleAngle))
                    .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: qibla.needleAngle)
                }
                .padding(.top, 4)
                
                // 2. حالة التوجيه الحالية (توجيه يمين / يسار / اتجاه صحيح)
                if qibla.isAligned {
                    HStack(spacing: 5) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption2)
                        Text("أنت باتجاه القبلة 🕋")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.green)
                    .clipShape(Capsule())
                    .shadow(color: Color.green.opacity(0.4), radius: 5)
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
                
                // زاوية توجيه الساعة
                HStack(spacing: 12) {
                    VStack(spacing: 2) {
                        Text("اتجاه الساعة")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(Int(qibla.heading))°")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                        .frame(height: 16)
                    
                    VStack(spacing: 2) {
                        Text("زاوية القبلة")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text("\(Int(qibla.qiblaBearing))°")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.top, 4)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "location.slash").font(.title2)
                        Text(qibla.statusMessage).font(.caption).multilineTextAlignment(.center)
                        Button("إعادة المحاولة") { qibla.stop(); qibla.start() }
                    }
                    .padding(.vertical)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            qibla.start()
        }
        .onDisappear {
            qibla.stop()
        }
    }
}
