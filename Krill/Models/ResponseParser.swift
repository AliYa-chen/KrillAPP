import Foundation

enum ResponseParser {
    static func stats(_ json: JSONValue) throws -> UsageStats {
        guard json["total_requests"].numericValue != nil, json["total_cost_usd"].numericValue != nil else { throw APIError.malformedResponse }
        let read = json["cache_read_input_tokens"].number
        let write = json["cache_creation_input_tokens"].number
        let input = json["input_tokens"].number
        let hasEligibleCounters = json["cache_rate_read_tokens"].numericValue != nil && json["cache_rate_eligible_tokens"].numericValue != nil
        let numerator = hasEligibleCounters ? json["cache_rate_read_tokens"].number : read
        let denominator = hasEligibleCounters ? json["cache_rate_eligible_tokens"].number : input + read + write
        return UsageStats(requests: json["total_requests"].int, inputTokens: input,
            outputTokens: json["output_tokens"].number, cacheReadTokens: read, cacheWriteTokens: write,
            reasoningTokens: json["reasoning_tokens"].number, totalTokens: json["total_tokens"].number,
            cost: json["total_cost_usd"].number, cacheHitRate: denominator > 0 ? min(1, max(0, numerator / denominator)) : 0)
    }
    static func trend(_ json: JSONValue) -> [TrendPoint] {
        json["trend"].array.compactMap { row in
            guard let date = KrillDate.parse(row["bucket_start"].string) else { return nil }
            return TrendPoint(date: date, cost: row["total_cost_usd"].number, requests: row["request_count"].int)
        }.sorted { $0.date < $1.date }
    }
    static func models(_ json: JSONValue) -> [ModelUsage] {
        json["items"].array.map { row in ModelUsage(name: row["model"].string,
            requests: row["request_count"].int, cost: row["total_cost_usd"].number, tokens: row["total_tokens"].number) }
            .sorted { $0.cost > $1.cost }
    }
    static func quotas(_ json: JSONValue) -> [QuotaUsage] {
        json["items"].array.map { row in QuotaUsage(id: row["subscription_id"].string,
            name: row["plan_name"].string, used: row["used_usd"].number, limit: row["limit_usd"].number,
            resetAt: KrillDate.parse(row["reset_at"].string), kind: "订阅额度") }
    }
    static func quotaSummary(_ json: JSONValue) -> QuotaSummary {
        QuotaSummary(sameDay: json["same_day_quota_charged_usd"].number,
            carryover: json["carryover_quota_charged_usd"].number,
            credit: json["total_credit_cost_usd"].number, plan: json["total_plan_cost_usd"].number)
    }
    static func logs(_ json: JSONValue, page: Int) throws -> [RequestLog] {
        guard json["items"].isArray, json["total"].numericValue != nil else { throw APIError.malformedResponse }
        return try json["items"].array.enumerated().map { index, row in
            guard let date = KrillDate.parse(row["request_time"].string), !row["model"].string.isEmpty,
                  row["status"].numericValue != nil, row["cost_usd"].numericValue != nil else { throw APIError.malformedResponse }
            // Upstream has no unique row ID. Preserve identical independent requests using page and row ordinal.
            let id = "\(page)-\(index)-\(row["request_time"].string)-\(row["model"].string)"
            return RequestLog(id: id, model: row["model"].string, date: date, cost: row["cost_usd"].number,
                inputTokens: row["input_tokens"].number, outputTokens: row["output_tokens"].number,
                cacheReadTokens: row["cache_read_input_tokens"].number, cacheWriteTokens: row["cache_creation_input_tokens"].number,
                reasoningTokens: row["reasoning_tokens"].number, durationMS: row["total_time_ms"].number,
                status: row["status"].string, method: methodName(row["method"].int), tokenName: row["token_name"].string)
        }
    }
    static func methodName(_ code: Int) -> String {
        switch code {
        case 1: "Anthropic"
        case 2: "Chat Completions"
        case 3: "Responses"
        case 4: "远程压缩"
        case 5: "图像生成"
        case 6: "图像编辑"
        case 7: "视频生成"
        case 9: "搜索"
        case 10: "语音合成"
        case 11: "语音转录"
        case 12: "实时通话"
        case 13: "上下文管理"
        case 14: "后台压缩"
        default: "协议 \(code)"
        }
    }
    static func hourlyDay(_ json: JSONValue, day: Date, now: Date) -> (HeatmapDay, Bool) {
        let start = KrillDate.calendar.startOfDay(for: day)
        let bucket = json["bucket_seconds"].int
        let points = trend(json)
        var cells = (0..<24).map { hour in HourCell(date: KrillDate.calendar.date(byAdding: .hour, value: hour, to: start)!, count: 0, cost: 0) }
        var valid = bucket > 0 && bucket <= 3600 && json["total_requests"].numericValue != nil && json["trend"].isArray
        for point in points {
            guard KrillDate.calendar.isDate(point.date, inSameDayAs: start) else { continue }
            let hour = KrillDate.calendar.component(.hour, from: point.date)
            cells[hour].count += point.requests
            cells[hour].cost += point.cost
        }
        let sum = cells.reduce(0) { $0 + $1.count }
        if sum != json["total_requests"].int { valid = false }
        return (HeatmapDay(date: start, cells: cells), valid)
    }
}
