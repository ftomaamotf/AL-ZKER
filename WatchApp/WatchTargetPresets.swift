import SwiftUI
import WatchKit

// Two columns give four-digit targets enough room on 40mm watches.
struct WatchTargetPresets: View {
    @Binding var selection: Int
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach([33, 100, 300, 1000], id: \.self) { value in
                Button {
                    selection = value
                    WKInterfaceDevice.current().play(.click)
                } label: {
                    Text(value.formatted())
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(selection == value ? Color.green : Color.primary)
                        .fadhkuruniGlass(tint: selection == value ? .green : .white, radius: 12)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("هدف \(value) مرة")
                .accessibilityAddTraits(selection == value ? [.isSelected] : [])
            }
        }
    }
}
