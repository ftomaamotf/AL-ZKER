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
    private var counterTabView: some View {
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
                    .foregroundColor(.gray)
                
                HStack(spacing: 30) {
                    Button(action: {
                        if sync.currentCount > 0 {
                            sync.sendSyncPayload(count: sync.currentCount - 1, zekr: sync.currentZekr, target: sync.target)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 44))
                            .foregroundColor(.red)
                    }
                    
                    Button(action: {
                        sync.sendSyncPayload(count: sync.currentCount + 1, zekr: sync.currentZekr, target: sync.target)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("تطبيق الذكر")
        }
    }
    
    // MARK: - Azkar Tab
    private var azkarTabView: some View {
        NavigationStack {
            List {
                Section(header: Text("الأذكار المدمجة")) {
                    ForEach(ZekrItem.builtInAzkar) { item in
                        HStack {
                            Text(item.title)
                            Spacer()
                            Text("\(item.defaultTarget)")
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sync.sendSyncPayload(count: 0, zekr: item.title, target: item.defaultTarget)
                        }
                    }
                }
            }
            .navigationTitle("الأذكار")
        }
    }
    
    // MARK: - Settings Tab
    private var settingsTabView: some View {
        NavigationStack {
            Form {
                Section(header: Text("حول التطبيق")) {
                    HStack {
                        Text("الإصدار")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("الإعدادات")
        }
    }
}
