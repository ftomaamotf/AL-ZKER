import SwiftUI

struct ContentView: View {
    var body: some View {
        PhoneCompanionView()
            .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    ContentView()
}
