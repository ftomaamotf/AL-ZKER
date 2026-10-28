//
//  PhoneQiblaView.swift
//  Fadhkuruni (iPhone Companion Qibla Compass & Prayer Times)
//

import SwiftUI
import CoreLocation
import Combine
import UIKit

// MARK: - مدير حساب اتجاه القبلة ومواقيت الصلاة للآيفون
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
    @Published public var cityName: String = ""
    @Published public var prayerTimes: DailyPrayerTimes = DailyPrayerTimes(items: [], nextPrayer: nil, timeRemainingText: "")
    
    private var lastHapticTime: Date = .distantPast
    private var userCoordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 24.7136, longitude: 46.6753) // افتراضي
    
    public override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 50.0
        refreshPrayerTimes()
    }
    
    public func start() {
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
        refreshPrayerTimes()
    }
    
    public func stop() {
        locationManager.stopUpdatingHeading()
        locationManager.stopUpdatingLocation()
    }
    
    public func refreshPrayerTimes() {
        self.prayerTimes = PrayerTimesCalculator.calculate(for: userCoordinate)
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
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
            if CLLocationManager.headingAvailable() {
                manager.startUpdatingHeading()
            }
        } else if authorizationStatus == .denied || authorizationStatus == .restricted {
            statusMessage = "يرجى تفعيل خدمة الموقع لتحديد اتجاه القبلة والمواقيت"
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        self.userCoordinate = location.coordinate
        let bearing = calculateBearing(from: location.coordinate)
        
        let meccaLoc = CLLocation(latitude: meccaLatitude, longitude: meccaLongitude)
        let distanceKm = location.distance(from: meccaLoc) / 1000.0
        
        DispatchQueue.main.async {
            self.qiblaBearing = bearing
            self.distanceToMeccaKm = distanceKm
            self.statusMessage = "تم تحديد الموقع"
            self.refreshNeedle()
            self.refreshPrayerTimes()
        }
        
        // تحديد اسم المدينة تلقائياً
        CLGeocoder().reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let city = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea {
                DispatchQueue.main.async {
                    self?.cityName = city
                }
            }
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

// MARK: - واجهة عرض اتجاه القبلة ومواقيت الصلاة للآيفون
public struct PhoneQiblaView: View {
    @StateObject private var qibla = PhoneQiblaManager.shared
    @State private var timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Spacer(minLength: 4)
                    
                    // 1. بطاقة البوصلة الرئيسية
                    ZStack {
                        // هالة متوهجة عند محاذاة القبلة
                        if qibla.isAligned {
                            Circle()
                                .fill(Color.green.opacity(0.14))
                                .frame(width: 280, height: 280)
                                .blur(radius: 14)
                        }
                        
                        // القرص الدائري الخارجي للبوصلة
                        Circle()
                            .stroke(
                                qibla.isAligned ? Color.green : Color.gray.opacity(0.25),
                                lineWidth: qibla.isAligned ? 4 : 2
                            )
                            .frame(width: 250, height: 250)
                            .shadow(color: qibla.isAligned ? Color.green.opacity(0.4) : Color.clear, radius: 12)
                        
                        // تدريجات البوصلة والاتجاهات الأربعة
                        VStack {
                            Text("ش (شمال)")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.red)
                            Spacer()
                            Text("ج (جنوب)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(height: 230)
                        
                        HStack {
                            Text("غ (غرب)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("شـ (شرق)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 230)
                        
                        // القرص المركزي
                        Circle()
                            .fill(qibla.isAligned ? Color.green.opacity(0.12) : Color(UIColor.secondarySystemBackground))
                            .frame(width: 96, height: 96)
                            .overlay(
                                Circle()
                                    .stroke(qibla.isAligned ? Color.green.opacity(0.5) : Color.gray.opacity(0.2), lineWidth: 1.5)
                            )
                        
                        VStack(spacing: 2) {
                            Text("\(Int(qibla.qiblaBearing))°")
                                .font(.system(size: 24, weight: .heavy, design: .rounded))
                                .foregroundColor(qibla.isAligned ? .green : .primary)
                            Text("القبلة")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        
                        // سهم وعقرب الكعبة المشرفة الدوار
                        VStack(spacing: 0) {
                            // رأس السهم يحمل مجسم الكعبة
                            ZStack {
                                Circle()
                                    .fill(qibla.isAligned ? Color.green : Color.orange)
                                    .frame(width: 42, height: 42)
                                    .shadow(color: qibla.isAligned ? Color.green.opacity(0.6) : Color.orange.opacity(0.4), radius: 6)
                                
                                Text("🕋")
                                    .font(.system(size: 20))
                            }
                            .offset(y: -8)
                            
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
                                .frame(width: 5.5, height: 75)
                            
                            Spacer()
                                .frame(height: 86)
                        }
                        .rotationEffect(Angle(degrees: qibla.needleAngle))
                        .animation(.interactiveSpring(response: 0.35, dampingFraction: 0.7), value: qibla.needleAngle)
                    }
                    .frame(height: 270)
                    .padding(.vertical, 4)
                    
                    // 2. شارة التوجيه والمحاذاة
                    if qibla.isAligned {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.headline)
                            Text("أنت الآن باتجاه القبلة المشرفة 🕋")
                                .font(.headline.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
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
                        .font(.subheadline.bold())
                        .foregroundColor(.orange)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.12))
                        .clipShape(Capsule())
                    }
                    
                    // 3. بطاقات البيانات والمعلومات السريعة
                    HStack(spacing: 12) {
                        // زاوية القبلة
                        VStack(spacing: 4) {
                            Text("زاوية القبلة")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(qibla.qiblaBearing))°")
                                .font(.headline.bold())
                                .foregroundColor(.green)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        // اتجاه الهاتف
                        VStack(spacing: 4) {
                            Text("اتجاه الهاتف")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(Int(qibla.heading))°")
                                .font(.headline.bold())
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        
                        // المسافة لمكة
                        if qibla.distanceToMeccaKm > 0 {
                            VStack(spacing: 4) {
                                Text("المسافة لمكة")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(Int(qibla.distanceToMeccaKm)) كم")
                                    .font(.headline.bold())
                                    .foregroundColor(.teal)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal, 16)
                    
                    // 4. قسم مواقيت الصلاة
                    VStack(alignment: .leading, spacing: 14) {
                        // ترويسة القسم
                        HStack {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("مَوَاقِيتُ الصَّلَاةِ")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !qibla.cityName.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.caption)
                                    Text(qibla.cityName)
                                        .font(.caption.bold())
                                }
                                .foregroundColor(.teal)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.teal.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        // بطاقة الصلاة القادمة والوقت المتبقي
                        if let next = qibla.prayerTimes.nextPrayer {
                            HStack(spacing: 14) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green)
                                        .frame(width: 48, height: 48)
                                        .shadow(color: Color.green.opacity(0.4), radius: 6)
                                    
                                    Image(systemName: next.type.icon)
                                        .font(.title3)
                                        .foregroundColor(.white)
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("الصَّلَاةُ الْقَادِمَةُ: \(next.type.rawValue)")
                                        .font(.headline.bold())
                                        .foregroundColor(.primary)
                                    
                                    if !qibla.prayerTimes.timeRemainingText.isEmpty {
                                        Text(qibla.prayerTimes.timeRemainingText)
                                            .font(.subheadline)
                                            .foregroundColor(.green)
                                    }
                                }
                                
                                Spacer()
                                
                                Text(next.formattedTime)
                                    .font(.title3.bold())
                                    .foregroundColor(.green)
                            }
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color.green.opacity(0.16),
                                        Color.green.opacity(0.06)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.green.opacity(0.4), lineWidth: 1.5)
                            )
                        }
                        
                        // شبكة مواقيت الصلوات اليومية
                        LazyVGrid(columns: gridColumns, spacing: 10) {
                            ForEach(qibla.prayerTimes.items) { item in
                                HStack(spacing: 10) {
                                    Image(systemName: item.type.icon)
                                        .font(.headline)
                                        .foregroundColor(item.isNext ? .green : .secondary)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.type.rawValue)
                                            .font(.subheadline)
                                            .fontWeight(item.isNext ? .bold : .medium)
                                            .foregroundColor(item.isNext ? .green : .primary)
                                        
                                        Text(item.formattedTime)
                                            .font(.caption)
                                            .fontWeight(item.isNext ? .bold : .regular)
                                            .foregroundColor(item.isNext ? .green : .secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    if item.isNext {
                                        Text("القادمة")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2.5)
                                            .background(Color.green)
                                            .clipShape(Capsule())
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(
                                    item.isNext
                                        ? Color.green.opacity(0.12)
                                        : Color(UIColor.secondarySystemBackground)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(item.isNext ? Color.green.opacity(0.4) : Color.clear, lineWidth: 1.2)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    
                    Text("تُحسب المواقيت فلكياً بدقة وفق تقويم أم القرى بناءً على إحداثيات موقعك الفعلي دون الحاجة للاتصال بالإنترنت.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 4)
                    
                    Spacer(minLength: 24)
                }
            }
            .navigationTitle("الْقِبْلَةُ وَمَوَاقِيتُ الصَّلَاةِ")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                qibla.start()
            }
            .onDisappear {
                qibla.stop()
            }
            .onReceive(timer) { _ in
                qibla.refreshPrayerTimes()
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}
