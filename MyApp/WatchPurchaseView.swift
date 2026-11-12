import SwiftUI

struct WatchPurchaseView: View {
    @ObservedObject private var access = WatchPurchaseAccess.shared
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label("نسخة الساعة", systemImage: "applewatch").font(.headline)
                Text("شراء دائم لمرة واحدة").font(.headline)
                Text("افتح التسبيح باللمس والإيماءات والأذكار والأهداف والقبلة والمزامنة على Apple Watch. لا تجديد تلقائي ولا اشتراك شهري أو سنوي.")
                    .font(.footnote)
                if access.isChecking {
                    ProgressView("التحقق من الشراء…")
                } else if access.isPurchased {
                    Label("نسخة الساعة مفتوحة دائماً", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                } else if let product = access.product {
                    Button("شراء دائم — \(product.displayPrice)") { Task { await access.purchase() } }
                        .buttonStyle(.borderedProminent)
                        .disabled(access.isBusy)
                } else if access.isLoadingProduct {
                    ProgressView("تحميل السعر…")
                } else {
                    Text("السعر غير متاح حالياً").font(.caption).foregroundStyle(.secondary)
                }
                if access.isBusy { ProgressView() }
                if let message = access.message { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button("استعادة الشراء") { Task { await access.restore() } }.disabled(access.isBusy)
                Button("إعادة التحقق والتحميل") {
                    Task { await access.refresh(); await access.loadProduct() }
                }.disabled(access.isBusy || access.isLoadingProduct)
                Text("الشراء مرتبط بحساب Apple، ويمكن استعادته دون الدفع مجدداً على الجهاز الآخر المرتبط بالحساب نفسه.")
                    .font(.caption).foregroundStyle(.secondary)
                Text("القبلة والأذكار والأهداف على الآيفون تبقى مجانية.")
                    .font(.caption).foregroundStyle(.secondary)
                #if os(iOS)
                SupportLink()
                #else
                Link("الدعم", destination: URL(string: "mailto:ffazkuruni@gmail.com")!)
                #endif
                NavigationLink("سياسة الخصوصية") { PrivacyPolicyView() }
            }.padding()
        }
        .navigationTitle("شراء نسخة الساعة")
        .environment(\.layoutDirection, AppLanguage.shared.layoutDirection)
        .task { await access.refresh(); if !access.isPurchased { await access.loadProduct() } }
    }
}

#if os(watchOS)
struct WatchPurchaseGate: View {
    @ObservedObject private var access = WatchPurchaseAccess.shared
    var body: some View {
        Group {
            if access.isChecking {
                ProgressView("التحقق من الشراء…")
            } else if access.isPurchased {
                GestureWelcomeGate(storageKey: "fadhkuruni_watch_gesture_welcome_completed_v2") { WatchContentView() }
            } else {
                NavigationStack { WatchPurchaseView() }
            }
        }
    }
}
#endif
