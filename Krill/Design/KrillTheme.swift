import SwiftUI
import UIKit

enum KrillTheme {
    private static func adaptive(_ light: UIColor, _ dark: UIColor) -> Color {
        Color(uiColor: UIColor { traits in traits.userInterfaceStyle == .dark ? dark : light })
    }
    static let background = adaptive(UIColor(white: 0.965, alpha: 1), UIColor(white: 0.045, alpha: 1))
    static let backgroundShade = adaptive(UIColor(white: 0.995, alpha: 1), UIColor(white: 0.095, alpha: 1))
    static let surface = adaptive(.white, UIColor(white: 0.105, alpha: 1))
    static let surfaceMuted = adaptive(UIColor(white: 0.935, alpha: 1), UIColor(white: 0.16, alpha: 1))
    static let border = adaptive(UIColor(white: 0.78, alpha: 0.45), UIColor(white: 1, alpha: 0.11))
    static let grid = adaptive(UIColor(white: 0.3, alpha: 0.09), UIColor(white: 1, alpha: 0.07))
    static let shadow = adaptive(UIColor(white: 0.15, alpha: 0.035), UIColor(white: 0, alpha: 0.18))
    static let glassTint = adaptive(UIColor(white: 1, alpha: 0.3), UIColor(white: 0.13, alpha: 0.25))
    static let accent = adaptive(UIColor(red: 0.91, green: 0.22, blue: 0.36, alpha: 1), UIColor(red: 1, green: 0.37, blue: 0.49, alpha: 1))
    static let cyan = adaptive(UIColor(red: 0.02, green: 0.48, blue: 0.58, alpha: 1), UIColor(red: 0.40, green: 0.83, blue: 0.90, alpha: 1))
    static let violet = adaptive(UIColor(red: 0.40, green: 0.42, blue: 0.68, alpha: 1), UIColor(red: 0.63, green: 0.65, blue: 0.88, alpha: 1))
    static let text = adaptive(UIColor(white: 0.09, alpha: 1), UIColor(white: 0.96, alpha: 1))
    static let muted = adaptive(UIColor(white: 0.43, alpha: 1), UIColor(white: 0.63, alpha: 1))
    static let green = adaptive(UIColor(red: 0.13, green: 0.46, blue: 0.35, alpha: 1), UIColor(red: 0.44, green: 0.77, blue: 0.63, alpha: 1))
    static let amber = adaptive(UIColor(red: 0.63, green: 0.37, blue: 0.08, alpha: 1), UIColor(red: 0.89, green: 0.69, blue: 0.39, alpha: 1))
    static let palette: [Color] = [cyan, violet, green, amber, muted]
}

struct KrillBackground: View {
    var body: some View {
        LinearGradient(colors: [KrillTheme.backgroundShade, KrillTheme.background], startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .accessibilityHidden(true)
    }
}

struct KrillMark: View {
    var size: CGFloat = 40
    var body: some View {
        ZStack(alignment: .topLeading) {
            Image("KrillLogo")
                .resizable()
                .frame(width: size * 192 / 72, height: size * 82 / 72)
                .offset(x: -size * 5 / 72, y: -size * 5 / 72)
        }
        .frame(width: size * 64 / 72, height: size, alignment: .topLeading)
        .clipped()
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct KrillCard: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var cornerRadius: CGFloat
    func body(content: Content) -> some View {
        content
            .padding(22)
            .background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(KrillTheme.surface.opacity(reduceTransparency ? 1 : 0.66))
            }
            .glassEffect(reduceTransparency ? .identity : .regular.tint(KrillTheme.glassTint), in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(KrillTheme.border, lineWidth: 0.7)
                    .allowsHitTesting(false)
            }
            .shadow(color: KrillTheme.shadow, radius: 16, x: 0, y: 7)
    }
}

extension View {
    func krillCard(cornerRadius: CGFloat = 28) -> some View {
        modifier(KrillCard(cornerRadius: cornerRadius))
    }
}

enum KrillFormat {
    static func number(_ value: Double) -> String {
        let absolute = abs(value)
        if absolute >= 1_000_000_000 { return String(format: "%.2fB", value / 1_000_000_000) }
        if absolute >= 1_000_000 { return String(format: "%.2fM", value / 1_000_000) }
        if absolute >= 1_000 { return String(format: "%.1fK", value / 1_000) }
        return value.formatted(.number.precision(.fractionLength(0)))
    }
    static func money(_ value: Double, precision: Int = 2) -> String {
        value.formatted(.currency(code: "USD").precision(.fractionLength(precision)))
    }
    static func percent(_ fraction: Double) -> String {
        fraction.formatted(.percent.precision(.fractionLength(1)))
    }
    static func date(_ date: Date, pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = TimeZone(identifier: "Asia/Shanghai")
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
}

struct SectionEyebrow: View {
    let title: String
    var trailing: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(.caption.weight(.semibold)).tracking(1.2)
            Spacer()
            if let trailing { Text(trailing).font(.caption).monospacedDigit() }
        }
        .foregroundStyle(KrillTheme.muted)
    }
}

struct MetricTile: View {
    let title: String
    let value: String
    let symbol: String
    var tint: Color = KrillTheme.cyan
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Image(systemName: symbol).foregroundStyle(tint)
                Spacer(minLength: 6)
                Text(title).foregroundStyle(KrillTheme.muted).font(.caption)
            }
            Text(value).font(.system(.title2, design: .rounded, weight: .semibold))
                .foregroundStyle(KrillTheme.text).monospacedDigit().minimumScaleFactor(0.6).lineLimit(1)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KrillTheme.surfaceMuted.opacity(0.6), in: .rect(cornerRadius: 19))
        .accessibilityElement(children: .combine)
    }
}
