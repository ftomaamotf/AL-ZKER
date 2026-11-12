import SwiftUI

struct ContentView: View {
    @ObservedObject private var lang = AppLanguage.shared

    var body: some View {
        PhoneCompanionView()
            .environment(\.layoutDirection, lang.layoutDirection)
            .environment(\.locale, lang.locale)
    }
}

#Preview {
    ContentView()
}
