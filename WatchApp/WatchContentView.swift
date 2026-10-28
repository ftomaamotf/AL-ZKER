import SwiftUI
import WatchKit

// مدير إبقاء الساعة مستيقظة أثناء استخدام التطبيق وإنهاء الجلسة عند الخروج
final class WatchKeepAwakeManager: NSObject, WKExtendedRuntimeSessionDelegate {
    static let shared = WatchKeepAwakeManager()
    private var session: WKExtendedRuntimeSession?

    func startKeepAwake() {
        if let s = session, s.state == .running || s.state == .scheduled {
            return
        }
        let newSession = WKExtendedRuntimeSession()
        newSession.delegate = self
        newSession.start()
        self.session = newSession
    }

    func stopKeepAwake() {
        if let s = session, s.state == .running || s.state == .scheduled {
            s.invalidate()
        }
        session = nil
    }

    func extendedRuntimeSessionDidStart(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("KeepAwake: Mindfulness session started successfully")
    }

    func extendedRuntimeSessionWillExpire(_ extendedRuntimeSession: WKExtendedRuntimeSession) {
        print("KeepAwake: Session expiring, restarting...")
        session = nil
        startKeepAwake()
    }

    func extendedRuntimeSession(_ extendedRuntimeSession: WKExtendedRuntimeSession, didInvalidateWith reason: WKExtendedRuntimeSessionInvalidationReason, error: Error?) {
        print("KeepAwake: Session invalidated: reason=\(reason.rawValue), error=\(String(describing: error))")
        session = nil
        if reason == .expired {
            startKeepAwake()
        }
    }
}

// دعم إيماءة النقر المزدوج باليد على ساعة آبل (Apple Watch Double Tap)
extension View {
    @ViewBuilder
    func enableDoubleTapGesture() -> some View {
        if #available(watchOS 11.0, *) {
            self.handGestureShortcut(.primaryAction)
        } else {
            self
        }
    }
}

struct WatchContentView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @Environment(\.scenePhase) private var scenePhase
    
    // استشعار تدوير زر التاج (Digital Crown)
    @State private var crownRotation: Double = 0.0
    @State private var showCrownMenu: Bool = false
    @FocusState private var isCrownFocused: Bool

    // توقيت آخر تسبيحة لإلغاء وتفادي أي هزة ثانية متكررة عند تحريك الأصابع
    @State private var lastIncrementTime: Date = .distantPast

    var body: some View {
        VStack(spacing: 6) {
            // 1. المنطقة العلوية (العنوان + الذكر + العداد) قابلة للمس المباشر
            VStack(spacing: 4) {
                Text("فَاذْكُرُونِي")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(sync.currentZekr)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 4)

                Text("\(sync.currentCount)")
                    .font(.system(size: 54, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                    .contentTransition(.numericText())
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            // لمس المنطقة العلوية للعد (اهتزاز بنقرة واحدة عند لمس الشاشة)
            .onTapGesture {
                incrementCount(playClickHaptic: true)
            }

            // 2. زر سَبِّح الأساسي (مخصص لاستقبال إيماءة Double Tap باليد)
            Button {
                // استخدام أول هزة عند تحريك الأصابع وإلغاء الهزة الثانية تماماً
                incrementCount(playClickHaptic: false)
            } label: {
                Text("سَبِّح")
                    .font(.title3.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .tint(.green)
            .enableDoubleTapGesture() // تفعيل إيماءة النقر المزدوج بالسبابة والإبهام
        }
        .padding(.horizontal, 8)
        .environment(\.layoutDirection, .rightToLeft)
        // ربط تدوير زر التاج (Digital Crown) لإظهار الخيارات
        .focusable()
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $crownRotation,
            from: -100.0,
            through: 100.0,
            by: 1.0,
            sensitivity: .low,
            isContinuous: false,
            isHapticFeedbackEnabled: false // تعطيل اهتزاز التاج لعدم إصدار أي نقرة ثانوية عند حركة اليد
        )
        .onChange(of: crownRotation) { newValue in
            if abs(newValue) >= 1.0 && !showCrownMenu {
                crownRotation = 0
                WKInterfaceDevice.current().play(.directionUp)
                showCrownMenu = true
            }
        }
        // عرض شاشة الخيارات (تحديد الهدف وتغيير نوع الذكر)
        .sheet(isPresented: $showCrownMenu) {
            CrownOptionsView(sync: sync, isPresented: $showCrownMenu)
        }
        .onChange(of: showCrownMenu) { isShowing in
            if !isShowing {
                crownRotation = 0
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isCrownFocused = true
                }
            }
        }
        // إبقاء الساعة مستيقظة طالما التطبيق مفتوح ومزامنة العداد فوراً مع الآيفون
        .onAppear {
            sync.activateSession()
            WatchKeepAwakeManager.shared.startKeepAwake()
            sync.requestSyncFromPhone()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isCrownFocused = true
            }
        }
        // إعادة الساعة إلى طبيعتها وحفظ الطاقة فور الخروج من التطبيق
        .onDisappear {
            WatchKeepAwakeManager.shared.stopKeepAwake()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                sync.activateSession()
                WatchKeepAwakeManager.shared.startKeepAwake()
                sync.requestSyncFromPhone()
                isCrownFocused = true
            } else {
                WatchKeepAwakeManager.shared.stopKeepAwake()
            }
        }
    }

    // MARK: - التسبيح والاهتزاز
    private func incrementCount(playClickHaptic: Bool) {
        let now = Date()
        // إلغاء أي هزة ثانية متكررة عند تحريك الأصابع فوراً (Debounce 0.4s)
        guard now.timeIntervalSince(lastIncrementTime) > 0.4 else {
            return
        }
        lastIncrementTime = now
        
        // تنشيط جلسة إبقاء الشاشة مستيقظة مع كل تسبيحة
        WatchKeepAwakeManager.shared.startKeepAwake()

        let next = sync.currentCount + 1
        sync.sendSyncPayload(count: next, zekr: sync.currentZekr, target: sync.target)
        if playClickHaptic {
            WKInterfaceDevice.current().play(.click)
        }
        if next == sync.target {
            WKInterfaceDevice.current().play(.success)
        }
    }
}

// MARK: - قائمة الخيارات التي تظهر عند تدوير زر التاج (Digital Crown)
struct CrownOptionsView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // زر إغلاق في أعلى الشاشة في وسطها
                Button {
                    isPresented = false
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                        Text("إغلاق")
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
                .padding(.top, 4)
                .padding(.bottom, 2)
                
                List {
                    // 1. الخيار الأول: تحديد الهدف
                    NavigationLink {
                        WatchSetTargetView(sync: sync, isPresented: $isPresented)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "target")
                                .font(.title3)
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("تحديد الهدف")
                                    .font(.headline)
                                Text("الهدف الحالي: \(sync.target)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 2. الخيار الثاني: تغيير نوع الذكر
                    NavigationLink {
                        WatchSelectZekrView(sync: sync, isPresented: $isPresented)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "repeat.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("تغيير نوع الذكر")
                                    .font(.headline)
                                Text(sync.currentZekr)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // 3. الخيار الثالث: اتجاه القبلة
                    NavigationLink {
                        WatchQiblaView()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "safari.fill")
                                .font(.title3)
                                .foregroundColor(.teal)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("اتجاه القبلة")
                                    .font(.headline)
                                Text("بوصلة دقيقة نحو الكعبة")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .environment(\.layoutDirection, .rightToLeft)
    }
}

// MARK: - شاشة تحديد الهدف في الساعة
struct WatchSetTargetView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    @State private var currentTarget: Int = 33
    @FocusState private var isTargetCrownFocused: Bool
    
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Text("\(currentTarget)")
                    .font(.system(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(.orange)
                
                // أزرار الزيادة والنقصان
                HStack(spacing: 14) {
                    Button {
                        if currentTarget > 1 {
                            currentTarget = max(1, currentTarget - (currentTarget > 10 ? 10 : 1))
                            WKInterfaceDevice.current().play(.click)
                        }
                    } label: {
                        Image(systemName: "minus")
                            .font(.headline.bold())
                    }
                    .buttonStyle(.bordered)
                    
                    Button {
                        currentTarget += 10
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Image(systemName: "plus")
                            .font(.headline.bold())
                    }
                    .buttonStyle(.bordered)
                }
                
                // أهداف سريعة
                Text("أهداف سريعة:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    ForEach([33, 100, 300, 1000], id: \.self) { val in
                        Button("\(val)") {
                            currentTarget = val
                            WKInterfaceDevice.current().play(.click)
                        }
                        .buttonStyle(.bordered)
                        .tint(currentTarget == val ? .orange : .gray)
                        .font(.caption2.bold())
                    }
                }
                
                Button("تأكيد وحفظ") {
                    sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: currentTarget)
                    WKInterfaceDevice.current().play(.success)
                    isPresented = false
                }
                .tint(.green)
                .padding(.top, 4)
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("تحديد الهدف")
        .environment(\.layoutDirection, .rightToLeft)
        .onAppear {
            currentTarget = sync.target
            isTargetCrownFocused = true
        }
        .focusable()
        .focused($isTargetCrownFocused)
        .digitalCrownRotation(
            Binding(
                get: { Double(currentTarget) },
                set: { currentTarget = max(1, Int($0)) }
            ),
            from: 1,
            through: 10000,
            by: 1,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
    }
}

// MARK: - شاشة اختيار وتغيير نوع الذكر في الساعة
struct WatchSelectZekrView: View {
    @ObservedObject var sync: WatchSyncService
    @Binding var isPresented: Bool
    
    var body: some View {
        List {
            ForEach(sync.azkarList) { item in
                Button {
                    sync.selectZekr(item)
                    WKInterfaceDevice.current().play(.success)
                    isPresented = false
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.headline)
                                .foregroundColor(sync.currentZekr == item.title ? .green : .primary)
                            HStack(spacing: 6) {
                                Text("المنجز: \(item.count)")
                                    .font(.caption2.bold())
                                    .foregroundColor(.green)
                                Text("•")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("الهدف: \(item.defaultTarget)")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if sync.currentZekr == item.title {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.body)
                        }
                    }
                }
            }
        }
        .navigationTitle("نوع الذكر")
        .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    WatchContentView()
}
