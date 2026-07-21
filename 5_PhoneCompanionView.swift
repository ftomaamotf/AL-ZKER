//
//  PhoneCompanionView.swift
//  Fathkoroni (iPhone Companion App View)
//

import SwiftUI

public struct PhoneCompanionView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @State private var selectedTab = 0
    @State private var customZekrText = ""
    @State private var customTargetText = ""
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            counterTabView
                .tabItem {
                    Label("العداد", systemImage: "timer")
                }
                .tag(0)
            
            azkarTabView
                .tabItem {
                    Label("الأذكار والأهداف", systemImage: "list.bullet")
                }
                .tag(1)
            
            settingsTabView
                .tabItem {
                    Label("الإعدادات", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(.green)
    }
    
    // MARK: - Counter Tab
    private var counterTabView: View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                
                Text(sync.currentZekr)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(sync.currentCount)")
                    .font(.system(size: 84, weight: .heavy, design: .rounded))
                    .foregroundColor(.green)
                
                Text("الهدف المحدد: \(sync.target)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    Button {
                        let next = sync.currentCount + 1
                        sync.sendSyncPayload(count: next, zekr: sync.currentZekr, target: sync.target)
                    } label: {
                        Text("+ إضافة تسبيحة")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(16)
                    }
                    
                    Button {
                        sync.sendSyncPayload(count: 0, zekr: sync.currentZekr, target: sync.target)
                    } label: {
                        Text("تصفير")
                            .font(.headline)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.15))
                            .cornerRadius(16)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("فاذكروني")
        }
    }
    
    // MARK: - Azkar & Targets Tab
    private var azkarTabView: View {
        NavigationStack {
            List {
                Section("اختر الذكر الحالي") {
                    ForEach(ZekrItem.builtInAzkar) { zekr in
                        HStack {
                            Text(zekr.title)
                                .fontWeight(.medium)
                            Spacer()
                            if zekr.title == sync.currentZekr {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sync.sendSyncPayload(count: 0, zekr: zekr.title, target: zekr.defaultTarget)
                        }
                    }
                }
                
                Section("أهداف التسبيح") {
                    let targets = [33, 34, 66, 99, 100, 300, 500, 1000]
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(targets, id: \.self) { num in
                                Button {
                                    sync.sendSyncPayload(count: sync.currentCount, zekr: sync.currentZekr, target: num)
                                } label: {
                                    Text("\(num)")
                                        .fontWeight(.bold)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(sync.target == num ? Color.green : Color.gray.opacity(0.2))
                                        .foregroundColor(sync.target == num ? .black : .primary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("الأذكار والأهداف")
        }
    }
    
    // MARK: - Settings Tab
    private var settingsTabView: View {
        NavigationStack {
            Form {
                Section("المزامنة والحفظ") {
                    HStack {
                        Text("حالة الاتصال بـ Apple Watch")
                        Spacer()
                        Text("متصل عبر WatchConnectivity 🟢")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                
                Section("الاهتزاز والتنبيهات") {
                    Toggle("تشغيل الاهتزاز (Haptics)", isOn: .constant(true))
                    Toggle("التذكير الذكي بعد التوقف", isOn: .constant(true))
                }
            }
            .navigationTitle("الإعدادات")
        }
    }
}
