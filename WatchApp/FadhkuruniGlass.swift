import SwiftUI

private struct FadhkuruniGlass: ViewModifier {
    var tint: Color
    var radius: CGFloat
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if reduceTransparency {
            content.background(Color.gray.opacity(0.22), in: shape)
                .overlay(shape.strokeBorder(tint.opacity(0.6), lineWidth: 1))
        } else if #available(iOS 26.0, watchOS 26.0, *) {
            content.glassEffect(.regular.tint(tint.opacity(0.2)).interactive(), in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
                .background(tint.opacity(0.12), in: shape)
                .overlay(shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.5), tint.opacity(0.2), .white.opacity(0.12)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
        }
    }
}

extension View {
    func fadhkuruniGlass(tint: Color = .white, radius: CGFloat = 16) -> some View {
        modifier(FadhkuruniGlass(tint: tint, radius: radius))
    }
}
