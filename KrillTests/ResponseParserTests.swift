import XCTest
@testable import Krill

final class ResponseParserTests: XCTestCase {
    private func json(_ text: String) throws -> JSONValue {
        try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    func testNumericStringCostsAndOptionalNullTokens() throws {
        let payload = try json("""
        {"total_requests":12,"total_cost_usd":"20.53","input_tokens":1290000,
         "cache_read_input_tokens":68700000,"cache_creation_input_tokens":null,
         "output_tokens":108000,"total_tokens":70098000}
        """)
        let stats = try ResponseParser.stats(payload)
        XCTAssertEqual(stats.cost, 20.53, accuracy: 0.000001)
        XCTAssertEqual(stats.requests, 12)
        XCTAssertEqual(stats.cacheWriteTokens, 0)
        XCTAssertEqual(stats.cacheHitRate, 68_700_000.0 / 69_990_000.0, accuracy: 0.000001)
    }

    func testEligibleCacheCountersTakePrecedence() throws {
        let payload = try json("""
        {"total_requests":1,"total_cost_usd":"0.01","input_tokens":100,
         "cache_read_input_tokens":900,"cache_rate_read_tokens":30,
         "cache_rate_eligible_tokens":40}
        """)
        XCTAssertEqual(try ResponseParser.stats(payload).cacheHitRate, 0.75)
    }

    func testZeroCacheDenominatorIsFinite() throws {
        let payload = try json("""
        {"total_requests":0,"total_cost_usd":"0","cache_rate_read_tokens":0,"cache_rate_eligible_tokens":0}
        """)
        XCTAssertEqual(try ResponseParser.stats(payload).cacheHitRate, 0)
    }

    func testPartialEligibleCountersUseRawTokenFallback() throws {
        let payload = try json("""
        {"total_requests":1,"total_cost_usd":"0.01","input_tokens":100,
         "cache_read_input_tokens":900,"cache_rate_read_tokens":30}
        """)
        XCTAssertEqual(try ResponseParser.stats(payload).cacheHitRate, 0.9)
    }

    func testMalformedPrimaryResponsesAreRejected() throws {
        XCTAssertThrowsError(try ResponseParser.stats(try json("{}")))
        XCTAssertThrowsError(try ResponseParser.stats(try json("{\"total_requests\":1,\"total_cost_usd\":\"NaN\"}")))
        XCTAssertThrowsError(try ResponseParser.logs(try json("{\"total\":0,\"items\":null}"), page: 1))
    }

    func testLogFieldsAndDuplicateRequestsRemainDistinct() throws {
        let row = """
        {"request_time":"2026-10-27T09:05:40Z","model":"test-model",
         "status":200,"method":3,"cost_usd":"0.0123","input_tokens":400,
         "output_tokens":20,"cache_creation_input_tokens":null,
         "cache_read_input_tokens":5000,"total_time_ms":1500}
        """
        let rows = try ResponseParser.logs(try json("{\"total\":2,\"items\":[\(row),\(row)]}"), page: 1)
        XCTAssertEqual(rows.count, 2)
        XCTAssertNotEqual(rows[0].id, rows[1].id)
        XCTAssertTrue(rows[0].isSuccess)
        XCTAssertEqual(rows[0].cost, 0.0123, accuracy: 0.000001)
        XCTAssertEqual(rows[0].cacheWriteTokens, 0)
        XCTAssertEqual(rows[0].durationMS, 1500)
        XCTAssertEqual(KrillDate.filterString(rows[0].date), "2026-10-27T17:05:40")
        XCTAssertEqual(rows[0].method, "Responses")
    }

    func testHourlyHeatmapFillsEmptyHoursAndConvertsUTC() throws {
        let payload = try json("""
        {"total_requests":3,"bucket_seconds":3600,"trend":[
          {"bucket_start":"2026-10-26T16:00:00Z","request_count":1,"total_cost_usd":"0.1"},
          {"bucket_start":"2026-10-27T09:00:00Z","request_count":2,"total_cost_usd":"0.3"}]}
        """)
        let now = try XCTUnwrap(KrillDate.parse("2026-10-27T18:00:00"))
        let (day, complete) = ResponseParser.hourlyDay(payload, day: now, now: now)
        XCTAssertTrue(complete)
        XCTAssertEqual(day.cells.count, 24)
        XCTAssertEqual(day.cells[0].count, 1)
        XCTAssertEqual(day.cells[17].count, 2)
        XCTAssertEqual(day.cells[17].cost, 0.3, accuracy: 0.000001)
        XCTAssertEqual(day.cells[12].count, 0)
    }

    func testDailyBucketsCannotMasqueradeAsHourlyData() throws {
        let payload = try json("{\"total_requests\":0,\"bucket_seconds\":86400,\"trend\":[]}")
        XCTAssertFalse(ResponseParser.hourlyDay(payload, day: Date(), now: Date()).1)
    }

    func testMissingHourlyRequestsAreFlaggedIncomplete() throws {
        let payload = try json("{\"total_requests\":12,\"bucket_seconds\":3600,\"trend\":[]}")
        XCTAssertFalse(ResponseParser.hourlyDay(payload, day: Date(), now: Date()).1)
    }

    func testMissingHourlyFieldsAreNotAcceptedAsEmptyActivity() throws {
        let payload = try json("{\"bucket_seconds\":3600}")
        XCTAssertFalse(ResponseParser.hourlyDay(payload, day: Date(), now: Date()).1)
    }

    func testQuotaAndModelDecimalStrings() throws {
        let quotas = ResponseParser.quotas(try json("{\"items\":[{\"subscription_id\":7,\"plan_name\":\"Test\",\"used_usd\":\"12.5\",\"limit_usd\":\"30\"}]}"))
        XCTAssertEqual(quotas.first?.used, 12.5)
        XCTAssertEqual(quotas.first?.limit, 30)
        let models = ResponseParser.models(try json("{\"items\":[{\"model\":\"test-model\",\"request_count\":42,\"total_cost_usd\":\"3.14\",\"total_tokens\":1000}]}"))
        XCTAssertEqual(models.first?.cost, 3.14)
        let summary = ResponseParser.quotaSummary(try json("{\"same_day_quota_charged_usd\":\"3.2\",\"carryover_quota_charged_usd\":\"0.7\",\"total_credit_cost_usd\":\"1.1\",\"total_plan_cost_usd\":\"3.9\"}"))
        XCTAssertEqual(summary.sameDay, 3.2)
        XCTAssertEqual(summary.plan, 3.9)
    }

    func testFilterPayloadHasNumericProtocolAndFixedTimezone() throws {
        let start = try XCTUnwrap(KrillDate.parse("2026-10-26T16:00:00Z"))
        var filter = UsageFilter()
        filter.model = "test-model"
        filter.tokenID = 42
        filter.chargeType = "plan"
        filter.method = "3"
        let body = AppStore.query(filter: filter, start: start, end: start)
        XCTAssertEqual(body["start_time"]?.string, "2026-10-27T00:00:00")
        XCTAssertEqual(body["model"]?.string, "test-model")
        XCTAssertEqual(body["token_id"]?.int, 42)
        XCTAssertEqual(body["method"]?.int, 3)
        XCTAssertEqual(body["charge_type"]?.string, "plan")
    }
}
