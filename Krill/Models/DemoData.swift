import Foundation

/// Local sample data is only reachable through the explicit demo action.
enum DemoData {
    static func snapshot(filter: UsageFilter, now: Date = Date()) -> DashboardSnapshot {
        let calendar = KrillDate.calendar
        let today = calendar.startOfDay(for: now)
        let names = ["claude-sonnet-4.5", "gpt-5", "gemini-2.5-pro"]
        var all: [RequestLog] = []
        for day in -30...0 {
            let start = calendar.date(byAdding: .day, value: day, to: today)!
            for hour in 0..<24 {
                let volume = hour >= 9 && hour <= 22 ? 9 : 2
                for index in 0..<volume {
                    let date = start.addingTimeInterval(Double(hour * 3600 + index * 347 + 61))
                    guard date <= now else { continue }
                    let seed = (day + 30) * 113 + hour * 19 + index * 7
                    let model = names[seed % names.count]
                    let tokenID = seed % 4 == 0 ? 2 : 1
                    guard filter.model.isEmpty || filter.model == model else { continue }
                    guard filter.tokenID == nil || filter.tokenID == tokenID else { continue }
                    guard filter.method.isEmpty || filter.method == "3" else { continue }
                    let usePlan = seed % 6 != 0
                    guard filter.chargeType.isEmpty || filter.chargeType == (usePlan ? "plan" : "balance") else { continue }
                    let status = seed % 37 == 0 ? 500 : 200
                    if let selected = filter.status {
                        if selected == 1 && status != 200 { continue }
                        if selected == 0 && status == 200 { continue }
                        if selected > 1 && selected != status { continue }
                    }
                    let cost = Double(seed % 27 + 6) / 100
                    all.append(RequestLog(id: "demo-\(day)-\(hour)-\(index)", model: model, date: date,
                        cost: cost,
                        inputTokens: Double(1800 + seed % 2100), outputTokens: Double(220 + seed % 450),
                        cacheReadTokens: Double(95000 + seed % 89000), cacheWriteTokens: Double(seed % 5 == 0 ? 1200 : 0),
                        reasoningTokens: Double(seed % 500), durationMS: Double(750 + seed % 3600),
                        status: String(status), method: "Responses",
                        tokenName: tokenID == 1 ? "工作空间" : "个人项目",
                        channel: "演示渠道", endpoint: "demo.krill.local", firstTokenMS: Double(250 + seed % 750),
                        planCost: usePlan ? cost : 0, creditCost: usePlan ? 0 : cost, reasoningEffort: "High",
                        errorMessage: status == 500 ? "演示请求异常" : "", chargeSource: usePlan ? "演示订阅" : "余额"))
                }
            }
        }
        let range = KrillDate.range(for: filter.period, now: now)
        let selected = all.filter { $0.date >= range.start }
        let todays = all.filter { $0.date >= today }
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let month = all.filter { $0.date >= monthStart }
        let grouped = Dictionary(grouping: selected) { row in
            filter.period == .day ? calendar.dateInterval(of: .hour, for: row.date)!.start : calendar.startOfDay(for: row.date)
        }
        let trend: [TrendPoint] = grouped.map { date, rows in
            let stats = summarize(rows)
            return TrendPoint(date: date, cost: stats.cost, requests: rows.count, totalTokens: stats.totalTokens)
        }.sorted { $0.date < $1.date }
        let modelGroups: [String: [RequestLog]] = Dictionary(grouping: selected, by: \.model)
        let models: [ModelUsage] = modelGroups.map { name, rows in
            let stats = summarize(rows)
            return ModelUsage(name: name, requests: rows.count, cost: stats.cost, tokens: stats.totalTokens)
        }.sorted { $0.cost > $1.cost }
        let heatmap = (-6...0).map { offset in
            let date = calendar.date(byAdding: .day, value: offset, to: today)!
            return HeatmapDay(date: date, cells: (0..<24).map { hour in
                let start = date.addingTimeInterval(Double(hour * 3600))
                let rows = all.filter { $0.date >= start && $0.date < start.addingTimeInterval(3600) }
                return HourCell(date: start, count: rows.count, cost: rows.reduce(0) { $0 + $1.cost })
            })
        }
        let todayCost = todays.reduce(0) { $0 + $1.cost }
        let yesterday = today.addingTimeInterval(-86400)
        let priorCost = all.filter { $0.date >= yesterday && $0.date <= yesterday.addingTimeInterval(now.timeIntervalSince(today)) }.reduce(0) { $0 + $1.cost }
        let planCost = selected.reduce(0) { $0 + ($1.planCost ?? 0) }
        let creditCost = selected.reduce(0) { $0 + ($1.creditCost ?? 0) }
        return DashboardSnapshot(stats: summarize(selected), today: summarize(todays), month: summarize(month),
            yesterdayChange: priorCost > 0 ? (todayCost - priorCost) / priorCost : nil,
            heatmap: heatmap, trend: trend, models: models,
            quotas: [QuotaUsage(id: "demo-pro", name: "Pro 月度订阅", used: planCost, limit: 1200,
                resetAt: nil, kind: "订阅额度")],
            quotaSummary: QuotaSummary(sameDay: planCost * 0.8, carryover: planCost * 0.2, credit: creditCost, plan: planCost),
            logs: Array(selected.sorted { $0.date > $1.date }.prefix(30)), updatedAt: now, heatmapComplete: true)
    }
    static func summarize(_ rows: [RequestLog]) -> UsageStats {
        let input = rows.reduce(0) { $0 + $1.inputTokens }
        let output = rows.reduce(0) { $0 + $1.outputTokens }
        let read = rows.reduce(0) { $0 + $1.cacheReadTokens }
        let write = rows.reduce(0) { $0 + $1.cacheWriteTokens }
        return UsageStats(requests: rows.count, inputTokens: input, outputTokens: output,
            cacheReadTokens: read, cacheWriteTokens: write, reasoningTokens: rows.reduce(0) { $0 + $1.reasoningTokens },
            totalTokens: input + output + read + write, cost: rows.reduce(0) { $0 + $1.cost },
            cacheHitRate: input + read + write > 0 ? read / (input + read + write) : 0,
            successfulRequests: rows.filter(\.isSuccess).count, failedRequests: rows.filter { !$0.isSuccess }.count,
            statusCountsAvailable: true)
    }
}
