import Foundation

enum UsagePeriod: String, CaseIterable, Identifiable, Sendable {
    case day, week, month
    var id: String { rawValue }
    var label: String { switch self { case .day: "24 小时"; case .week: "7 天"; case .month: "30 天" } }
}

struct UsageFilter: Equatable, Sendable {
    var period: UsagePeriod = .week
    var model: String = ""
    var tokenID: Int? = nil
    var chargeType: String = ""
    var method: String = ""
    var status: Int? = nil
}

struct UsageStats: Sendable {
    var requests: Int = 0
    var inputTokens: Double = 0
    var outputTokens: Double = 0
    var cacheReadTokens: Double = 0
    var cacheWriteTokens: Double = 0
    var reasoningTokens: Double = 0
    var totalTokens: Double = 0
    var cost: Double = 0
    var cacheHitRate: Double = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var statusCountsAvailable: Bool = false
}

struct HourCell: Identifiable, Sendable {
    var date: Date
    var id: Date { date }
    var count: Int
    var cost: Double
}
struct HeatmapDay: Identifiable, Sendable {
    var date: Date
    var id: Date { date }
    var cells: [HourCell]
}
struct TrendPoint: Identifiable, Sendable {
    var date: Date
    var id: Date { date }
    var cost: Double
    var requests: Int
    var totalTokens: Double = 0
}
struct ModelUsage: Identifiable, Sendable {
    var id: String { name }
    var name: String
    var requests: Int
    var cost: Double
    var tokens: Double
}
struct QuotaUsage: Identifiable, Sendable {
    var id: String
    var name: String
    var used: Double
    var limit: Double
    var resetAt: Date?
    var kind: String
}
struct QuotaSummary: Sendable {
    var sameDay: Double = 0
    var carryover: Double = 0
    var credit: Double = 0
    var plan: Double = 0
    var totalDeducted: Double { plan + credit }
}
struct RequestLog: Identifiable, Sendable {
    var id: String
    var model: String
    var date: Date
    var cost: Double
    var inputTokens: Double
    var outputTokens: Double
    var cacheReadTokens: Double
    var cacheWriteTokens: Double
    var reasoningTokens: Double
    var durationMS: Double
    var status: String
    var method: String
    var tokenName: String
    var channel: String = ""
    var endpoint: String = ""
    var firstTokenMS: Double? = nil
    var planCost: Double? = nil
    var creditCost: Double? = nil
    var reasoningEffort: String = ""
    var errorMessage: String = ""
    var chargeSource: String = ""
    var durationAvailable: Bool = true
    var statusLabel: String {
        if isSuccess { return "请求成功" }
        if status == "102" { return "连接中" }
        return "请求异常"
    }
    var isSuccess: Bool { (Int(status).map { (200..<300).contains($0) }) ?? false }
}
struct TokenOption: Identifiable, Sendable { var id: Int; var name: String }
struct DashboardSnapshot: Sendable {
    var stats: UsageStats
    var today: UsageStats
    var month: UsageStats
    var yesterdayChange: Double?
    var heatmap: [HeatmapDay]
    var trend: [TrendPoint]
    var models: [ModelUsage]
    var quotas: [QuotaUsage]
    var quotaSummary: QuotaSummary
    var logs: [RequestLog]
    var updatedAt: Date
    var heatmapComplete: Bool
}

/// The web client and server interpret unzoned filter timestamps as UTC+8.
enum KrillDate {
    static let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
    static func filterString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.string(from: date)
    }
    static func parse(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        if let date = standard.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        for format in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
    static func range(for period: UsagePeriod, now: Date) -> (start: Date, end: Date) {
        let days = switch period { case .day: 1; case .week: 7; case .month: 30 }
        return (now.addingTimeInterval(-Double(days) * 86_400), now)
    }
}
