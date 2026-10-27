import SwiftUI
import Charts

struct TodayCard: View {
    @ScaledMetric(relativeTo: .largeTitle) private var costSize = 50.0
    let snapshot: DashboardSnapshot
    @Binding var selectedHour: HourCell?
    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            SectionEyebrow(title: "今日消耗", trailing: "本月 " + KrillFormat.money(snapshot.month.cost))
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .lastTextBaseline, spacing: 16) {
                    cost
                    change
                    Spacer(minLength: 0)
                }
                VStack(alignment: .leading, spacing: 8) { cost; change }
            }
            HStack(spacing: 7) {
                Circle().fill(KrillTheme.green).frame(width: 5, height: 5)
                Text("\(snapshot.today.requests.formatted()) 次请求")
                Spacer()
                Text("缓存命中 \(KrillFormat.percent(snapshot.today.cacheHitRate))")
            }
            .font(.caption).foregroundStyle(KrillTheme.muted)
            TokenBreakdown(stats: snapshot.today)
            Rectangle().fill(KrillTheme.grid).frame(height: 1)
            HeatmapPanel(days: snapshot.heatmap, complete: snapshot.heatmapComplete, selectedHour: $selectedHour)
        }
        .krillCard()
    }
    private var cost: some View {
        Text(KrillFormat.money(snapshot.today.cost))
            .font(.system(size: costSize, weight: .semibold, design: .rounded))
            .tracking(-2).monospacedDigit().foregroundStyle(KrillTheme.text)
            .minimumScaleFactor(0.6).lineLimit(1)
            .contentTransition(.numericText())
    }
    @ViewBuilder private var change: some View {
        if let change = snapshot.yesterdayChange {
            Label("\(abs(change).formatted(.percent.precision(.fractionLength(0)))) 较昨日同期", systemImage: change > 0 ? "arrow.up.right" : "arrow.down.right")
                .font(.caption2.weight(.medium))
                .foregroundStyle(change > 0 ? KrillTheme.amber : KrillTheme.green)
                .padding(.horizontal, 10).padding(.vertical, 7)
                .background(KrillTheme.surfaceMuted, in: .capsule)
                .lineLimit(1)
        }
    }
}

struct TokenBreakdown: View {
    let stats: UsageStats
    private var values: [(String, Double, Color)] {
        var result: [(String, Double, Color)] = [("缓存读取", stats.cacheReadTokens, KrillTheme.cyan), ("输入", stats.inputTokens, .blue), ("输出", stats.outputTokens, KrillTheme.violet)]
        if stats.cacheWriteTokens > 0 { result.append(("缓存写入", stats.cacheWriteTokens, KrillTheme.green)) }
        return result
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            GeometryReader { geometry in
                let total = values.reduce(0) { $0 + max(0, $1.1) }
                HStack(spacing: 2) {
                    ForEach(values.indices, id: \.self) { index in
                        let value = values[index]
                        Rectangle().fill(value.2)
                            .frame(width: total > 0 ? max(0, max(0, geometry.size.width - CGFloat(values.count - 1) * 2) * max(0, value.1) / total) : 0)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(KrillTheme.surfaceMuted)
                .clipShape(.capsule)
            }.frame(height: 8).accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 14) { legend }
                VStack(alignment: .leading, spacing: 8) { legend }
            }
        }
    }
    @ViewBuilder private var legend: some View {
        ForEach(values.indices, id: \.self) { index in
            let item = values[index]
            HStack(spacing: 5) {
                Circle().fill(item.2).frame(width: 5, height: 5)
                Text(item.0).foregroundStyle(KrillTheme.muted)
                Text(KrillFormat.number(item.1)).foregroundStyle(KrillTheme.text)
            }
            .font(.system(size: 10, weight: .medium)).monospacedDigit()
            .accessibilityElement(children: .combine)
        }
    }
}

struct HeatmapPanel: View {
    let days: [HeatmapDay]
    let complete: Bool
    @Binding var selectedHour: HourCell?
    private var maximum: Int { max(1, days.flatMap(\.cells).map(\.count).max() ?? 1) }
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return value
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Text("请求活跃度").font(.caption.weight(.semibold))
                Spacer()
                Text("近 7 天 · 北京时间").font(.system(size: 10)).foregroundStyle(KrillTheme.muted)
            }
            if days.isEmpty {
                Text("暂无活跃记录").font(.caption).foregroundStyle(KrillTheme.muted).frame(height: 120).frame(maxWidth: .infinity)
            } else {
                GeometryReader { geometry in
                    let cellWidth = max(3, (geometry.size.width - 30 - 23 * 3) / 24)
                    VStack(spacing: 4) {
                        ForEach(days) { day in
                            HStack(spacing: 3) {
                                Text(calendar.isDateInToday(day.date) ? "今日" : KrillFormat.date(day.date, pattern: "EEEEE"))
                                    .font(.system(size: 9)).foregroundStyle(KrillTheme.muted).frame(width: 27, alignment: .leading)
                                ForEach(day.cells) { cell in
                                    let future = cell.date > Date()
                                    RoundedRectangle(cornerRadius: 3)
                                        .fill(future ? Color.clear : heatColor(cell.count))
                                        .overlay(RoundedRectangle(cornerRadius: 3).stroke(selectedHour?.id == cell.id ? KrillTheme.text : KrillTheme.border.opacity(future ? 1 : 0), lineWidth: selectedHour?.id == cell.id ? 1.5 : 0.5))
                                        .frame(width: cellWidth, height: 12)
                                        .contentShape(.rect)
                                        .onTapGesture { if !future { selectedHour = selectedHour?.id == cell.id ? nil : cell } }
                                        .accessibilityLabel(KrillFormat.date(cell.date, pattern: "M月d日 H点") + "，\(cell.count) 次请求")
                                        .accessibilityAddTraits(.isButton)
                                }
                            }
                        }
                        HStack {
                            Text("00"); Spacer(); Text("06"); Spacer(); Text("12"); Spacer(); Text("18"); Spacer(); Text("23")
                        }.font(.system(size: 9, design: .monospaced)).foregroundStyle(KrillTheme.muted).padding(.leading, 30).padding(.top, 3)
                    }
                }.frame(height: CGFloat(days.count * 16 + 18))
            }
            HStack(spacing: 4) {
                if let cell = selectedHour {
                    Text("\(KrillFormat.date(cell.date, pattern: "M/d HH:00"))  ·  \(cell.count) 次  ·  \(KrillFormat.money(cell.cost, precision: 3))")
                        .foregroundStyle(KrillTheme.cyan).lineLimit(1).minimumScaleFactor(0.75)
                } else {
                    Text(complete ? "轻触方格查看详情" : "当前已载入记录 · 数据未完整")
                        .foregroundStyle(complete ? KrillTheme.muted : KrillTheme.amber)
                }
                Spacer(minLength: 2)
                Text("少").foregroundStyle(KrillTheme.muted)
                ForEach(1..<5) { value in RoundedRectangle(cornerRadius: 2).fill(KrillTheme.cyan.opacity(Double(value) / 4)).frame(width: 7, height: 7) }
                Text("多").foregroundStyle(KrillTheme.muted)
            }.font(.system(size: 9))
        }
    }
    private func heatColor(_ count: Int) -> Color {
        count == 0 ? KrillTheme.surfaceMuted : KrillTheme.cyan.opacity(0.2 + pow(Double(count) / Double(maximum), 0.55) * 0.8)
    }
}

struct SpendTrendCard: View {
    let points: [TrendPoint]
    let period: String
    let total: Double
    private var spansDays: Bool {
        guard let first = points.map(\.date).min(), let last = points.map(\.date).max() else { return false }
        return last.timeIntervalSince(first) >= 86_400
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionEyebrow(title: "消耗趋势", trailing: period)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(KrillFormat.money(total)).font(.system(.title, design: .rounded, weight: .semibold)).monospacedDigit()
                Text("USD").font(.caption).foregroundStyle(KrillTheme.muted)
            }
            if points.isEmpty {
                ContentUnavailableView("暂无趋势数据", systemImage: "chart.xyaxis.line")
                    .frame(height: 145)
            } else {
                Chart(points) { point in
                    AreaMark(x: .value("时间", point.date), y: .value("费用", point.cost))
                        .foregroundStyle(LinearGradient(colors: [KrillTheme.cyan.opacity(0.25), KrillTheme.cyan.opacity(0)], startPoint: .top, endPoint: .bottom))
                        .interpolationMethod(.monotone)
                    LineMark(x: .value("时间", point.date), y: .value("费用", point.cost))
                        .foregroundStyle(KrillTheme.cyan).lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.monotone)
                    PointMark(x: .value("时间", point.date), y: .value("费用", point.cost))
                        .foregroundStyle(KrillTheme.cyan).symbolSize(points.count > 14 ? 7 : 18)
                }
                .chartYScale(domain: 0...max(0.01, (points.map(\.cost).max() ?? 0) * 1.15))
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                        AxisGridLine().foregroundStyle(KrillTheme.grid)
                        AxisValueLabel { if let amount = value.as(Double.self) { Text(amount, format: .number.precision(.fractionLength(0...2))).foregroundStyle(KrillTheme.muted) } }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisValueLabel(format: spansDays ? .dateTime.month().day() : .dateTime.hour(), centered: false).foregroundStyle(KrillTheme.muted)
                    }
                }
                .frame(height: 145)
                .environment(\.timeZone, TimeZone(identifier: "Asia/Shanghai")!)
            }
        }.krillCard()
    }
}

struct ModelUsageCard: View {
    let models: [ModelUsage]
    private var sorted: [ModelUsage] { models.sorted { $0.cost > $1.cost } }
    private var shown: [ModelUsage] { Array(sorted.prefix(5)) }
    private var total: Double { models.reduce(0) { $0 + $1.cost } }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionEyebrow(title: "模型分布", trailing: "按消耗")
            if models.isEmpty {
                Text("所选时间内暂无模型用量").font(.caption).foregroundStyle(KrillTheme.muted).frame(maxWidth: .infinity, minHeight: 100)
            } else {
                HStack(spacing: 22) {
                    Chart(Array(sorted.enumerated()), id: \.element.id) { index, model in
                        SectorMark(angle: .value("费用", max(0, model.cost)), innerRadius: .ratio(0.78), angularInset: 3)
                            .cornerRadius(3).foregroundStyle(KrillTheme.palette[index % KrillTheme.palette.count])
                    }
                    .chartLegend(.hidden).frame(width: 104, height: 104)
                    .chartBackground { _ in
                        VStack(spacing: 4) {
                            Text("\(models.count)").font(.system(size: 27, weight: .semibold, design: .rounded))
                            Text("个模型").font(.system(size: 10)).foregroundStyle(KrillTheme.muted)
                        }
                    }
                    VStack(alignment: .leading, spacing: 13) {
                        ForEach(Array(shown.enumerated()), id: \.element.id) { index, model in
                            HStack(spacing: 6) {
                                Circle().fill(KrillTheme.palette[index % KrillTheme.palette.count]).frame(width: 5, height: 5)
                                Text(model.name).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 2)
                                Text(KrillFormat.percent(total > 0 ? model.cost / total : 0)).foregroundStyle(KrillTheme.muted).monospacedDigit()
                            }.font(.system(size: 10, weight: .medium))
                        }
                    }
                }
                VStack(spacing: 13) {
                    ForEach(Array(shown.prefix(3).enumerated()), id: \.element.id) { index, model in
                        HStack {
                            Text(String(format: "%02d", index + 1)).font(.system(size: 11, design: .monospaced)).foregroundStyle(KrillTheme.muted)
                            Text(model.name).font(.caption.weight(.medium)).lineLimit(1)
                            Spacer()
                            Text(KrillFormat.money(model.cost)).font(.system(.caption, design: .rounded, weight: .semibold)).monospacedDigit()
                        }
                    }
                }
            }
        }.krillCard()
    }
}

struct QuotaCard: View {
    let quotas: [QuotaUsage]
    let summary: QuotaSummary
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionEyebrow(title: "订阅额度", trailing: "USD")
            if quotas.isEmpty {
                Text("暂无可用订阅额度").font(.caption).foregroundStyle(KrillTheme.muted)
            }
            ForEach(quotas) { quota in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(quota.name).font(.caption.weight(.medium)).lineLimit(1)
                        Spacer()
                        Text("\(KrillFormat.money(quota.used)) / \(KrillFormat.money(quota.limit))")
                            .font(.system(size: 10, design: .rounded)).monospacedDigit().foregroundStyle(KrillTheme.muted)
                    }
                    ProgressView(value: min(max(quota.used, 0), max(quota.limit, 0)), total: max(quota.limit, 0.000001))
                        .tint(quota.limit > 0 && quota.used / quota.limit > 0.9 ? KrillTheme.amber : KrillTheme.cyan)
                    if let reset = quota.resetAt {
                        Text("\(KrillFormat.date(reset, pattern: "M月d日 HH:mm")) 重置").font(.system(size: 10)).foregroundStyle(KrillTheme.muted)
                    }
                }
            }
            Rectangle().fill(KrillTheme.grid).frame(height: 1)
            HStack {
                Text("当前范围订阅扣费").font(.system(size: 11)).foregroundStyle(KrillTheme.muted)
                Spacer()
                Text(KrillFormat.money(summary.plan)).font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit()
            }
            HStack {
                charge("当日额度", summary.sameDay)
                Spacer()
                charge("结转额度", summary.carryover)
                Spacer()
                charge("余额扣费", summary.credit)
            }
        }.krillCard()
    }
    private func charge(_ title: String, _ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 10)).foregroundStyle(KrillTheme.muted)
            Text(KrillFormat.money(value)).font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}
