import SwiftUI
import Charts

/// The four summaries share one date range and use their own measured series.
struct PeriodStatisticsPanel: View {
    let snapshot: DashboardSnapshot
    var quotaAvailable = true
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var width: CGFloat = 0

    private var columnCount: Int {
        if dynamicTypeSize.isAccessibilitySize { return 1 }
        return width >= 780 ? 4 : 2
    }

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 0), spacing: 12), count: columnCount), spacing: 12) {
            SummaryStatisticCard(title: "请求花费", value: KrillFormat.money(snapshot.stats.cost), tint: KrillTheme.green,
                                 series: snapshot.trend.map { SummarySample(date: $0.date, value: $0.cost) }) {
                Text("请求产生的费用").foregroundStyle(KrillTheme.muted)
            }
            QuotaDeductionCard(summary: snapshot.quotaSummary, available: quotaAvailable)
            SummaryStatisticCard(title: "请求数", value: KrillFormat.number(Double(snapshot.stats.requests)), tint: KrillTheme.violet,
                                 series: snapshot.trend.map { SummarySample(date: $0.date, value: Double($0.requests)) }) {
                if snapshot.stats.statusCountsAvailable {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("成功 \(snapshot.stats.successfulRequests.formatted())")
                        Text("失败 \(snapshot.stats.failedRequests.formatted())")
                    }.foregroundStyle(KrillTheme.muted)
                } else {
                    Text("请求总量").foregroundStyle(KrillTheme.muted)
                }
            }
            SummaryStatisticCard(title: "Tokens", value: KrillFormat.number(snapshot.stats.totalTokens), tint: KrillTheme.cyan,
                                 series: snapshot.trend.map { SummarySample(date: $0.date, value: $0.totalTokens) }) {
                Text("含思考 \(KrillFormat.number(snapshot.stats.reasoningTokens))")
                    .foregroundStyle(KrillTheme.muted)
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
    }

}

private struct QuotaDeductionCard: View {
    let summary: QuotaSummary
    let available: Bool
    private var total: Double { summary.plan + summary.credit }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("额度扣减").font(.caption.weight(.medium)).foregroundStyle(KrillTheme.muted)
            Text(available ? KrillFormat.money(total) : "—")
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit().foregroundStyle(KrillTheme.text)
                .lineLimit(1).minimumScaleFactor(0.65).contentTransition(.numericText())
            Group {
                if available {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("当日 " + KrillFormat.money(summary.sameDay))
                        Text("结转 " + KrillFormat.money(summary.carryover))
                        Text("余额 " + KrillFormat.money(summary.credit))
                    }
                } else {
                    Text("暂时无法获取")
                }
            }
            .font(.caption2).monospacedDigit().foregroundStyle(KrillTheme.muted)
            .frame(minHeight: 45, alignment: .topLeading)
            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    HStack(spacing: 1) {
                        Rectangle().fill(KrillTheme.amber)
                            .frame(width: available && total > 0 ? max(0, geometry.size.width - 1) * min(1, max(0, summary.plan) / total) : 0)
                        Rectangle().fill(KrillTheme.cyan)
                            .frame(width: available && total > 0 ? max(0, geometry.size.width - 1) * min(1, max(0, summary.credit) / total) : 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KrillTheme.surfaceMuted)
                    .clipShape(.capsule)
                }
                .frame(height: 6).accessibilityHidden(true)
                if available {
                    HStack(spacing: 9) {
                        Label("订阅", systemImage: "circle.fill").foregroundStyle(KrillTheme.amber)
                        Label("余额", systemImage: "circle.fill").foregroundStyle(KrillTheme.cyan)
                    }.font(.system(size: 9))
                }
            }.frame(height: 40, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .krillCard(cornerRadius: 22)
    }
}

private struct SummarySample: Identifiable {
    var date: Date
    var value: Double
    var id: Date { date }
}

private struct SummaryStatisticCard<Detail: View>: View {
    let title: String
    let value: String
    let tint: Color
    let series: [SummarySample]
    let detail: Detail

    init(title: String, value: String, tint: Color, series: [SummarySample], @ViewBuilder detail: () -> Detail) {
        self.title = title
        self.value = value
        self.tint = tint
        self.series = series
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.caption.weight(.medium)).foregroundStyle(KrillTheme.muted)
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(KrillTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
                .contentTransition(.numericText())
            detail
                .font(.caption2)
                .monospacedDigit()
                .frame(minHeight: 45, alignment: .topLeading)
            if series.isEmpty {
                RoundedRectangle(cornerRadius: 1)
                    .fill(KrillTheme.grid)
                    .frame(height: 1)
                    .frame(height: 40)
                    .accessibilityHidden(true)
            } else {
                Chart(series) { sample in
                    AreaMark(x: .value("时间", sample.date), y: .value(title, sample.value))
                        .foregroundStyle(LinearGradient(colors: [tint.opacity(0.12), tint.opacity(0)], startPoint: .top, endPoint: .bottom))
                    LineMark(x: .value("时间", sample.date), y: .value(title, sample.value))
                        .foregroundStyle(tint)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...max(0.01, (series.map(\.value).max() ?? 0) * 1.15))
                .frame(height: 40)
                .accessibilityLabel(title + "趋势")
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .krillCard(cornerRadius: 22)
    }
}
