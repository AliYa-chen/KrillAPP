import SwiftUI

struct LoginBrandPanel: View {
    let expanded: Bool

    var body: some View {
        VStack(alignment: expanded ? .leading : .center, spacing: expanded ? 34 : 0) {
            Image("KrillLogo")
                .resizable()
                .scaledToFit()
                .frame(width: expanded ? 156 : 116, height: expanded ? 67 : 50)
                .accessibilityLabel("Krill")

            if expanded {
                VStack(alignment: .leading, spacing: 14) {
                    Text("每一次调用，\n都一目了然。")
                        .font(.system(size: 38, weight: .semibold, design: .rounded))
                        .tracking(-1)
                        .lineSpacing(8)
                        .foregroundStyle(KrillTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("你的 AI 用量，随时掌握。")
                        .font(.subheadline)
                        .foregroundStyle(KrillTheme.muted)
                }

                VStack(alignment: .leading, spacing: 18) {
                    feature("chart.xyaxis.line", "消耗与趋势")
                    feature("square.stack.3d.up", "缓存与模型")
                    feature("text.alignleft", "每一条请求")
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: expanded ? .leading : .center)
        .padding(.vertical, expanded ? 12 : 0)
    }

    private func feature(_ symbol: String, _ title: String) -> some View {
        HStack(spacing: 13) {
            Image(systemName: symbol)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(KrillTheme.accent)
                .frame(width: 40, height: 40)
                .background(KrillTheme.surfaceMuted.opacity(0.6), in: .rect(cornerRadius: 12))
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(KrillTheme.text.opacity(0.8))
        }
    }
}
