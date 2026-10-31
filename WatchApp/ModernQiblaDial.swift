import SwiftUI

struct ModernQiblaDial: View {
    let heading: Double
    let bearing: Double
    let needle: Double
    let aligned: Bool
    var compact = false
    private var accent: Color { aligned ? .green : .teal }
    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(RadialGradient(colors: [accent.opacity(0.12), .clear], center: .center, startRadius: 0, endRadius: side / 2))
                Circle().strokeBorder(accent.opacity(0.25), lineWidth: 1)
                ForEach(0..<60) { tick in
                    Capsule()
                        .fill(tick % 5 == 0 ? Color.primary.opacity(0.5) : Color.secondary.opacity(0.25))
                        .frame(width: tick % 5 == 0 ? 2 : 1, height: tick % 5 == 0 ? side * 0.045 : side * 0.022)
                        .offset(y: -side * 0.455)
                        .rotationEffect(.degrees(Double(tick) * 6 - heading))
                }
                ForEach(0..<4) { index in
                    let angle = (Double(index) * 90 - heading) * .pi / 180
                    Text(["ش", "شرق", "ج", "غ"][index])
                        .font(.system(size: compact ? 9 : 12, weight: .medium))
                        .foregroundStyle(index == 0 ? Color.red : Color.secondary)
                        .position(x: side / 2 + sin(angle) * side * 0.35,
                                  y: side / 2 - cos(angle) * side * 0.35)
                }
                Circle().fill(.ultraThinMaterial)
                    .frame(width: side * 0.43, height: side * 0.43)
                VStack(spacing: 2) {
                    Text("🕋").font(.system(size: compact ? 19 : 30))
                    Text("\(Int(bearing.rounded()))°")
                        .font(.system(size: compact ? 15 : 26, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(accent)
                    if !compact { Text("زاوية القبلة").font(.caption2).foregroundStyle(.secondary) }
                }
                Image(systemName: "location.north.fill")
                    .font(.system(size: compact ? 20 : 32, weight: .semibold))
                    .foregroundStyle(accent)
                    .offset(y: -side * 0.335)
                    .rotationEffect(.degrees(needle))
            }
            .frame(width: side, height: side)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("زاوية القبلة \(Int(bearing)) درجة، اتجاه الجهاز \(Int(heading)) درجة")
    }
}

struct QiblaDirectionStatus: View {
    let aligned: Bool
    let needle: Double
    var compact = false
    var body: some View {
        Label(aligned ? "أنت باتجاه القبلة" : (needle >= 0 ? "اتجه يميناً" : "اتجه يساراً"),
              systemImage: aligned ? "checkmark.circle.fill" : (needle >= 0 ? "arrow.turn.up.right" : "arrow.turn.up.left"))
            .font(compact ? .caption : .headline)
            .foregroundStyle(aligned ? Color.green : Color.teal)
            .multilineTextAlignment(.center)
            .padding(.horizontal, compact ? 10 : 18)
            .padding(.vertical, compact ? 8 : 12)
            .background((aligned ? Color.green : Color.teal).opacity(0.1), in: Capsule())
    }
}
