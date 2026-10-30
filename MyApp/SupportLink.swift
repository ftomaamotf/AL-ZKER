import SwiftUI

struct SupportLink: View {
    var body: some View {
        Link(destination: URL(string: "https://fadhkuruni-support.hazycandy2048.chatgpt.site/")!) {
            Label("الدعم والمساعدة", systemImage: "questionmark.circle")
        }
        .accessibilityHint("يفتح صفحة دعم فاذكروني في المتصفح")
    }
}
