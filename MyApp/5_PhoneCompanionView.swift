//
//  PhoneCompanionView.swift
//  Fadhkuruni (iPhone Companion App View)
//

import SwiftUI

public struct PhoneCompanionView: View {
    @ObservedObject private var sync = WatchSyncService.shared
    @State private var selectedTab = 0
    
    // Add/Edit State
    @State private var showAddSheet = false
    @State private var newZekrTitle = ""
    @State private var newZekrTarget = 33
    
    @State private var editingItem: ZekrItem? = nil
    @State private var editZekrTitle = ""
    @State private var editZekrTarget = 33
    
    @State private var showResetAlert = false
    
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
            VStack(spacing: 28) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("الذكر الحالي")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(sync.currentZekr)
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                VStack(spacing: 4) {
                    Text("\(sync.currentCount)")
                        .font(.system(size: 92, weight: .heavy, design: .rounded))
                        .foregroundColor(.green)
                        .contentTransition(.numericText())
                    
                    Text("الهدف: \(sync.target)")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 10)
                
                HStack(spacing: 40) {
                    Button(action: {
                        if sync.currentCount > 0 {
                            sync.sendSyncPayload(count: sync.currentCount - 1, zekr: sync.currentZekr, target: sync.target)
                        }
                    }) {
                        Image(systemName: "minus.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.red.opacity(0.85))
                    }
                    
                    Button(action: {
                        sync.sendSyncPayload(count: sync.currentCount + 1, zekr: sync.currentZekr, target: sync.target)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 76))
                            .foregroundColor(.green)
                    }
                    
                    Button(action: {
                        sync.sendSyncPayload(count: 0, zekr: sync.currentZekr, target: sync.target)
                    }) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 52))
                            .foregroundColor(.orange)
                    }
                }
                
                Spacer()
            }
            .navigationTitle("فَذَكِّرُونِي")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Azkar Tab (Add / Edit / Delete)
    private var azkarTabView: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: {
                        newZekrTitle = ""
                        newZekrTarget = 33
                        showAddSheet = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundColor(.green)
                            Text("إضافة ذكر جديد")
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("قائمة الأذكار (اضغط للاختيار، أو اسحب للحذف)")) {
                    ForEach(sync.azkarList) { item in
                        HStack(spacing: 12) {
                            if sync.currentZekr == item.title {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.title3)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray.opacity(0.4))
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.headline)
                                    .foregroundColor(sync.currentZekr == item.title ? .green : .primary)
                                
                                Text("الهدف: \(item.defaultTarget) مرة")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Button(action: {
                                editZekrTitle = item.title
                                editZekrTarget = item.defaultTarget
                                editingItem = item
                            }) {
                                Image(systemName: "pencil.circle")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            sync.selectZekr(item)
                        }
                    }
                    .onDelete { offsets in
                        sync.deleteZekr(at: offsets)
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("استعادة الأذكار المدمجة الافتراضية")
                        }
                    }
                }
            }
            .navigationTitle("الأذكار والأهداف")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            // Sheet: Add New Zekr
            .sheet(isPresented: $showAddSheet) {
                NavigationStack {
                    Form {
                        Section(header: Text("نص الذكر")) {
                            TextField("مثال: سبحان الله وبحمده", text: $newZekrTitle)
                                .textInputAutocapitalization(.never)
                        }
                        
                        Section(header: Text("الهدف المحدد (عدد المرات)")) {
                            Stepper("الهدف: \(newZekrTarget)", value: $newZekrTarget, in: 1...10000)
                            
                            HStack(spacing: 12) {
                                Button("33") { newZekrTarget = 33 }.buttonStyle(.bordered)
                                Button("100") { newZekrTarget = 100 }.buttonStyle(.bordered)
                                Button("300") { newZekrTarget = 300 }.buttonStyle(.bordered)
                                Button("1000") { newZekrTarget = 1000 }.buttonStyle(.bordered)
                            }
                        }
                    }
                    .navigationTitle("إضافة ذكر جديد")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إلغاء") { showAddSheet = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("حفظ") {
                                sync.addZekr(title: newZekrTitle, target: newZekrTarget)
                                showAddSheet = false
                            }
                            .disabled(newZekrTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            // Sheet: Edit Zekr
            .sheet(item: $editingItem) { item in
                NavigationStack {
                    Form {
                        Section(header: Text("تعديل نص الذكر")) {
                            TextField("نص الذكر", text: $editZekrTitle)
                                .textInputAutocapitalization(.never)
                        }
                        
                        Section(header: Text("تعديل الهدف")) {
                            Stepper("الهدف: \(editZekrTarget)", value: $editZekrTarget, in: 1...10000)
                            
                            HStack(spacing: 12) {
                                Button("33") { editZekrTarget = 33 }.buttonStyle(.bordered)
                                Button("100") { editZekrTarget = 100 }.buttonStyle(.bordered)
                                Button("300") { editZekrTarget = 300 }.buttonStyle(.bordered)
                                Button("1000") { editZekrTarget = 1000 }.buttonStyle(.bordered)
                            }
                        }
                    }
                    .navigationTitle("تعديل الذكر")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("إلغاء") { editingItem = nil }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("حفظ") {
                                sync.updateZekr(item: item, newTitle: editZekrTitle, newTarget: editZekrTarget)
                                editingItem = nil
                            }
                            .disabled(editZekrTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .presentationDetents([.medium])
            }
            .alert("استعادة الأذكار الافتراضية", isPresented: $showResetAlert) {
                Button("إلغاء", role: .cancel) {}
                Button("استعادة", role: .destructive) {
                    sync.resetToDefaultAzkar()
                }
            } message: {
                Text("هل تريد بالتأكيد استعادة قائمة الأذكار المدمجة الأصلية وحذف الأذكار المخصصة؟")
            }
        }
    }
    
    // MARK: - Settings Tab
    private var settingsTabView: some View {
        NavigationStack {
            Form {
                Section(header: Text("حول التطبيق")) {
                    HStack {
                        Text("اسم البرنامج")
                        Spacer()
                        Text("فَذَكِّرُونِي")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("الإصدار")
                        Spacer()
                        Text("1.1.0 (إدارة الأذكار)")
                            .foregroundColor(.gray)
                    }
                    
                    HStack {
                        Text("المطور")
                        Spacer()
                        Text("عبدالله عجمي")
                            .foregroundColor(.gray)
                    }
                }
                
                Section(header: Text("المزامنة")) {
                    HStack {
                        Text("عدد الأذكار الحالية")
                        Spacer()
                        Text("\(sync.azkarList.count)")
                            .foregroundColor(.green)
                            .fontWeight(.bold)
                    }
                }
            }
            .navigationTitle("الإعدادات")
        }
    }
}
