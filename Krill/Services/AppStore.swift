import Foundation
import Observation

@MainActor @Observable
final class AppStore {
    var isAuthenticated = false
    var isDemo = false
    var isRestoring = true
    var isLoading = false
    var isLoadingMore = false
    var errorMessage: String?
    var warnings: [String] = []
    var userDisplayName = "Krill"
    var snapshot: DashboardSnapshot?
    var filter = UsageFilter()
    var pendingTOTP = false
    var hasMoreLogs = false
    var availableModels: [String] = []
    var availableTokens: [TokenOption] = []
    var quotaSummaryAvailable = false
    var quotasAvailable = false
    private let api = APIClient()
    private var token: String?
    private var pendingToken: String?
    private var generation = UUID()
    private var page = 1
    private var loadedFilter: UsageFilter?
    private var activeQuery: [String: JSONValue] = [:]

    func restoreSession() async {
        guard isRestoring else { return }
        defer { isRestoring = false }
        guard let saved = TokenVault.read() else { return }
        token = saved
        do {
            let user = try await api.request("api/auth/me", token: saved)
            setUser(user)
            isAuthenticated = true
            await refresh()
        } catch APIError.unauthorized {
            logout()
            errorMessage = APIError.unauthorized.localizedDescription
        } catch {
            isAuthenticated = true
            errorMessage = "暂时无法连接服务，请下拉重试。\n\(error.localizedDescription)"
        }
    }

    func login(email: String, password: String) async {
        await authenticate(path: "api/auth/login", body: ["email": .string(email.trimmingCharacters(in: .whitespacesAndNewlines)), "password": .string(password)])
    }
    func loginWithCode(email: String, code: String) async {
        await authenticate(path: "api/auth/login/verify", body: ["email": .string(email.trimmingCharacters(in: .whitespacesAndNewlines)), "verification_code": .string(code)])
    }
    func sendLoginCode(email: String) async -> Int? {
        errorMessage = nil
        do {
            let response = try await api.request("api/auth/login/send-code", body: ["email": .string(email.trimmingCharacters(in: .whitespacesAndNewlines))])
            return min(3600, max(1, response["resend_after_seconds"].numericValue == nil ? 60 : response["resend_after_seconds"].int))
        } catch { errorMessage = error.localizedDescription; return nil }
    }
    func verifyTOTP(code: String) async {
        guard let pendingToken else { return }
        await authenticate(path: "api/auth/login/totp", body: ["pending_token": .string(pendingToken), "totp_code": .string(code)])
    }
    private func authenticate(path: String, body: [String: JSONValue]) async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await api.request(path, body: body)
            if result["requires_totp"].bool {
                guard !result["pending_token"].string.isEmpty else { throw APIError.malformedResponse }
                pendingToken = result["pending_token"].string
                pendingTOTP = true
            } else {
                let value = result["token"].string
                guard !value.isEmpty else { throw APIError.malformedResponse }
                try TokenVault.save(value)
                token = value
                setUser(result["user"])
                pendingToken = nil
                pendingTOTP = false
                isDemo = false
                isAuthenticated = true
                await refresh()
            }
        } catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
    private func setUser(_ user: JSONValue) {
        let name = user["name"].string.isEmpty ? user["email"].string : user["name"].string
        userDisplayName = name.isEmpty ? "Krill" : name
    }
    func enterDemo() {
        generation = UUID()
        isDemo = true
        isAuthenticated = true
        isRestoring = false
        isLoading = false
        errorMessage = nil
        warnings = []
        userDisplayName = "探索者"
        availableModels = ["claude-sonnet-4.5", "gpt-5", "gemini-2.5-pro"]
        availableTokens = [TokenOption(id: 1, name: "工作空间"), TokenOption(id: 2, name: "个人项目")]
        hasMoreLogs = false
        quotaSummaryAvailable = true
        quotasAvailable = true
        snapshot = DemoData.snapshot(filter: filter)
        loadedFilter = filter
    }
    func logout() {
        generation = UUID()
        TokenVault.delete()
        token = nil
        pendingToken = nil
        pendingTOTP = false
        isAuthenticated = false
        isDemo = false
        isRestoring = false
        isLoading = false
        isLoadingMore = false
        snapshot = nil
        loadedFilter = nil
        userDisplayName = "Krill"
        availableModels = []
        availableTokens = []
        hasMoreLogs = false
        quotaSummaryAvailable = false
        quotasAvailable = false
        errorMessage = nil
        warnings = []
        filter = UsageFilter()
    }
    func refresh() async {
        if isDemo { snapshot = DemoData.snapshot(filter: filter); loadedFilter = filter; return }
        guard let token else { return }
        let requestID = UUID()
        generation = requestID
        let selectedFilter = filter
        isLoadingMore = false
        if loadedFilter != selectedFilter {
            snapshot = nil
            hasMoreLogs = false
            quotaSummaryAvailable = false
            quotasAvailable = false
        }
        let now = Date()
        let selectedRange = KrillDate.range(for: selectedFilter.period, now: now)
        let todayStart = KrillDate.calendar.startOfDay(for: now)
        let monthStart = KrillDate.calendar.date(from: KrillDate.calendar.dateComponents([.year, .month], from: now))!
        let yesterday = KrillDate.calendar.date(byAdding: .day, value: -1, to: todayStart)!
        let yesterdayEnd = yesterday.addingTimeInterval(now.timeIntervalSince(todayStart))
        let query = Self.query(filter: selectedFilter, start: selectedRange.start, end: selectedRange.end)
        isLoading = true
        errorMessage = nil
        warnings = []
        defer { if generation == requestID { isLoading = false } }
        do {
            async let primary = api.request("api/request-logs/stats", token: token, body: query)
            async let todayRaw = api.request("api/request-logs/stats", token: token, body: Self.query(filter: selectedFilter, start: todayStart, end: now))
            async let monthRaw = api.request("api/request-logs/stats", token: token, body: Self.query(filter: selectedFilter, start: monthStart, end: now))
            async let logRaw = api.request("api/request-logs", token: token, body: Self.pageQuery(query, page: 1))
            let (main, day, month, logs) = try await (primary, todayRaw, monthRaw, logRaw)
            let mainStats = try ResponseParser.stats(main)
            let todayStats = try ResponseParser.stats(day)
            let monthStats = try ResponseParser.stats(month)
            let parsedLogs = try ResponseParser.logs(logs, page: 1)
            guard generation == requestID else { return }
            activeQuery = query
            loadedFilter = selectedFilter
            page = 1
            hasMoreLogs = parsedLogs.count < logs["total"].int
            snapshot = DashboardSnapshot(stats: mainStats, today: todayStats, month: monthStats,
                yesterdayChange: nil, heatmap: [], trend: ResponseParser.trend(main), models: [], quotas: [],
                quotaSummary: QuotaSummary(), logs: parsedLogs, updatedAt: now, heatmapComplete: false)
            quotaSummaryAvailable = false
            quotasAvailable = false

            async let previous = optional("api/request-logs/stats", token: token, body: Self.query(filter: selectedFilter, start: yesterday, end: yesterdayEnd))
            async let models = optional("api/request-logs/model-stats", token: token, body: query)
            async let quotas = optional("api/subscription/quota-usage", token: token, body: query)
            async let quotaSummary = optional("api/request-logs/quota-summary", token: token, body: query)
            async let choices = loadChoices(token: token)
            async let heatmap = loadHeatmap(filter: selectedFilter, now: now, token: token)
            let supplements = await (previous, models, quotas, quotaSummary, choices, heatmap)
            guard generation == requestID else { return }
            if let raw = supplements.0, let stats = try? ResponseParser.stats(raw), stats.cost > 0 {
                snapshot?.yesterdayChange = (todayStats.cost - stats.cost) / stats.cost
            }
            if let raw = supplements.1 { snapshot?.models = ResponseParser.models(raw) }
            else { warnings.append("模型分布暂时不可用") }
            if let raw = supplements.2, raw["items"].isArray {
                snapshot?.quotas = ResponseParser.quotas(raw)
                quotasAvailable = true
            }
            else { warnings.append("订阅额度暂时不可用") }
            if let raw = supplements.3,
               raw["total_plan_cost_usd"].numericValue != nil,
               raw["total_credit_cost_usd"].numericValue != nil {
                snapshot?.quotaSummary = ResponseParser.quotaSummary(raw)
                quotaSummaryAvailable = true
            }
            else { warnings.append("扣费明细暂时不可用") }
            availableModels = supplements.4.0
            availableTokens = supplements.4.1
            snapshot?.heatmap = supplements.5.0
            snapshot?.heatmapComplete = supplements.5.1
            if !supplements.5.1 { warnings.append("部分小时统计不可用，热力图仅显示已成功加载的日期") }
        } catch APIError.unauthorized {
            guard generation == requestID else { return }
            logout()
            errorMessage = APIError.unauthorized.localizedDescription
        } catch {
            guard generation == requestID else { return }
            errorMessage = error.localizedDescription
        }
    }
    func loadMoreLogs() async {
        guard !isDemo, !isLoading, !isLoadingMore, hasMoreLogs, let token else { return }
        let requestID = generation
        let nextPage = page + 1
        isLoadingMore = true
        defer { if generation == requestID { isLoadingMore = false } }
        do {
            let raw = try await api.request("api/request-logs", token: token, body: Self.pageQuery(activeQuery, page: nextPage))
            let rows = try ResponseParser.logs(raw, page: nextPage)
            guard generation == requestID else { return }
            snapshot?.logs.append(contentsOf: rows)
            page = nextPage
            hasMoreLogs = !rows.isEmpty && (snapshot?.logs.count ?? 0) < raw["total"].int
        } catch APIError.unauthorized {
            guard generation == requestID else { return }
            logout()
            errorMessage = APIError.unauthorized.localizedDescription
        } catch {
            guard generation == requestID else { return }
            errorMessage = error.localizedDescription
        }
    }
    private func optional(_ path: String, token: String, body: [String: JSONValue]) async -> JSONValue? {
        try? await api.request(path, token: token, body: body)
    }
    private func loadChoices(token: String) async -> ([String], [TokenOption]) {
        async let models = try? api.request("api/models", token: token)
        async let keys = try? api.request("api/tokens", token: token)
        let (modelRaw, keyRaw) = await (models, keys)
        return (modelRaw?.array.map(\.string) ?? [], keyRaw?.array.map { row in
            TokenOption(id: row["id"].int, name: row["name"].string.isEmpty ? row["token_prefix"].string : row["name"].string)
        } ?? [])
    }
    private func loadHeatmap(filter: UsageFilter, now: Date, token: String) async -> ([HeatmapDay], Bool) {
        let today = KrillDate.calendar.startOfDay(for: now)
        let client = api
        let results = await withTaskGroup(of: (HeatmapDay?, Bool).self) { group in
            for offset in -6...0 {
                let start = KrillDate.calendar.date(byAdding: .day, value: offset, to: today)!
                let end = offset == 0 ? now : KrillDate.calendar.date(byAdding: .day, value: 1, to: start)!.addingTimeInterval(-1)
                let body = Self.query(filter: filter, start: start, end: end)
                group.addTask {
                    do {
                        let json = try await client.request("api/request-logs/stats", token: token, body: body)
                        let result = ResponseParser.hourlyDay(json, day: start, now: now)
                        return result.1 ? (result.0, true) : (nil, false)
                    } catch { return (nil, false) }
                }
            }
            var days: [HeatmapDay] = []
            var complete = true
            for await (day, valid) in group { if let day { days.append(day) }; complete = complete && valid }
            return (days.sorted { $0.date < $1.date }, complete)
        }
        return results
    }
    nonisolated static func query(filter: UsageFilter, start: Date, end: Date) -> [String: JSONValue] {
        var query: [String: JSONValue] = ["start_time": .string(KrillDate.filterString(start)), "end_time": .string(KrillDate.filterString(end))]
        if !filter.model.isEmpty { query["model"] = .string(filter.model) }
        if let id = filter.tokenID { query["token_id"] = .number(Double(id)) }
        if !filter.chargeType.isEmpty { query["charge_type"] = .string(filter.chargeType) }
        if let method = Int(filter.method) { query["method"] = .number(Double(method)) }
        if let status = filter.status { query["status"] = .number(Double(status)) }
        return query
    }
    nonisolated private static func pageQuery(_ query: [String: JSONValue], page: Int) -> [String: JSONValue] {
        query.merging(["page": .number(Double(page)), "page_size": .number(30)]) { _, new in new }
    }
}
