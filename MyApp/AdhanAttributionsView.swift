import SwiftUI

struct AdhanAttributionsView: View {
    var body: some View {
        List {
            Section {
                Text("تتضمن التطبيق خمس نغمات تنبيه أصلية قصيرة، صُممت للعمل مع إشعارات الآيفون عند قفل الشاشة.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("نغمات الصلاة")
        .navigationBarTitleDisplayMode(.inline)
    }
}
